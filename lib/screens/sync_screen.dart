import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/app_provider.dart';
import '../providers/provider_sync_host.dart';
import '../services/sync_discovery.dart';
import '../services/sync_service.dart';
import '../utils/platform_support.dart';
import '../widgets/sync_report_view.dart';

/// Synchronisation locale Mac ⇄ iPhone/iPad, sans serveur ni compte.
///
/// A l'ouverture de l'ecran, l'appareil se met en reception et s'annonce sur
/// le reseau local (Bonjour) ; il liste les autres appareils qui ont aussi
/// cet ecran ouvert. Un appui sur l'un d'eux lit ses donnees, fusionne, puis
/// lui envoie le resultat. Le QR code et la saisie manuelle restent en
/// secours si la decouverte est bloquee par le reseau.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late final ProviderSyncHost _host;
  late final SyncServer _server;
  final _advertiser = SyncAdvertiser();
  SyncBrowser? _browser;
  StreamSubscription<List<DiscoveredPeer>>? _peersSub;
  List<DiscoveredPeer> _peers = const [];
  // Cause de l'echec de la decouverte, affichee telle quelle (diagnostic).
  String? _discoveryError;

  SyncPairing? _pairing;
  bool _starting = false;

  final _addressController = TextEditingController();
  final _portController = TextEditingController(text: '$kSyncDefaultPort');
  final _codeController = TextEditingController();

  bool _syncing = false;
  String _step = '';
  String? _error;
  SyncSummary? _summary;
  DateTime? _summaryAt;
  // Vrai si la synchronisation a ete lancee par l'autre appareil.
  bool _summaryReceived = false;

  @override
  void initState() {
    super.initState();
    _host = ProviderSyncHost(Provider.of<AppStateProvider>(context, listen: false));
    _server = SyncServer(_host)
      ..onSynced = (summary) {
        if (!mounted) return;
        setState(() {
          _summary = summary;
          _summaryAt = DateTime.now();
          _summaryReceived = true;
          _error = null;
        });
      };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
      _startBrowsing();
    });
  }

  Future<void> _startBrowsing() async {
    try {
      final browser = SyncBrowser(ownDeviceId: await _host.syncDeviceId());
      _browser = browser;
      _peersSub = browser.peers.listen((peers) {
        if (mounted) setState(() => _peers = peers);
      });
      await browser.start();
    } catch (e) {
      // Bonjour indisponible (reseau qui bloque le multicast, plugin absent) :
      // le QR code et la saisie manuelle restent possibles.
      if (mounted) setState(() => _discoveryError = '$e');
    }
  }

  @override
  void dispose() {
    // Le serveur et son annonce ne doivent jamais survivre a l'ecran : ils
    // exposent les donnees de la classe sur le reseau.
    _advertiser.stop();
    _server.stop();
    _peersSub?.cancel();
    _browser?.dispose();
    _addressController.dispose();
    _portController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final pairing = await _server.start();
      if (!mounted) return;
      setState(() => _pairing = pairing);
      try {
        await _advertiser.start(pairing: pairing, deviceId: await _host.syncDeviceId());
      } catch (e) {
        // Sans annonce, l'appareil reste joignable par QR code.
        if (mounted) setState(() => _discoveryError = '$e');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de démarrer la réception : $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopServer() async {
    await _advertiser.stop();
    await _server.stop();
    if (mounted) setState(() => _pairing = null);
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _PairingScannerPage()),
    );
    if (raw == null || !mounted) return;
    final pairing = SyncPairing.decode(raw);
    if (pairing == null) {
      setState(() => _error = 'Ce QR code n’est pas un code de synchronisation.');
      return;
    }
    await _run(pairing);
  }

  Future<void> _connectManually() async {
    final port = int.tryParse(_portController.text.trim());
    final address = _addressController.text.trim();
    final token = _codeController.text.trim();
    if (address.isEmpty || port == null || token.isEmpty) {
      setState(() => _error = 'Renseignez l’adresse, le port et le code.');
      return;
    }
    await _run(SyncPairing(hosts: [address], port: port, token: token, name: ''));
  }

  Future<void> _run(SyncPairing pairing) async {
    setState(() {
      _syncing = true;
      _error = null;
      _summary = null;
      _step = 'Connexion…';
    });
    try {
      final summary = await SyncClient(_host).sync(
        pairing,
        onProgress: (s) {
          if (mounted) setState(() => _step = s);
        },
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _summaryAt = DateTime.now();
          _summaryReceived = false;
        });
      }
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Échec de la synchronisation : $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Les deux appareils doivent être sur le même réseau Wi‑Fi. '
                'Les données restent dans l’école : rien ne passe par internet.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildNearbyCard(),
              if (_syncing) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_step)),
                ]),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _banner(_error!, Icons.error_outline, Colors.red),
              ],
              if (_summary != null) ...[
                const SizedBox(height: 16),
                SyncReportView(
                  summary: _summary!,
                  at: _summaryAt!,
                  receivedFromPeer: _summaryReceived,
                ),
              ],
              const SizedBox(height: 16),
              _buildReceiveCard(),
              const SizedBox(height: 16),
              _buildConnectCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: SelectableText(text)),
          ],
        ),
      );

  Widget _buildNearbyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.devices, color: Color(0xFF4E9F3D)),
              SizedBox(width: 8),
              Text('Appareils à proximité',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            Text(
              _discoveryError != null
                  ? 'La recherche automatique ne fonctionne pas ($_discoveryError). '
                      'Utilisez le QR code ou la saisie manuelle ci-dessous.'
                  : 'Ouvrez aussi cet écran sur l’autre appareil : il apparaît ici tout seul.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_peers.isEmpty && _discoveryError == null)
              const Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Recherche…', style: TextStyle(fontSize: 13)),
              ])
            else
              for (final peer in _peers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.laptop_mac),
                  title: Text(peer.name),
                  trailing: FilledButton.icon(
                    onPressed: _syncing ? null : () => _run(peer.pairing),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Synchroniser'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveCard() {
    final pairing = _pairing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.qr_code_2, color: Color(0xFF4E9F3D)),
              SizedBox(width: 8),
              Text('Si l’appareil n’apparaît pas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Scannez ce code depuis l’autre appareil. '
              'Le code change à chaque ouverture et cet appareil n’est plus visible quand vous quittez cet écran.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (pairing == null)
              FilledButton.icon(
                onPressed: _starting ? null : _startServer,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Démarrer la réception'),
              )
            else ...[
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: pairing.encode(), size: 220),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Ou saisir manuellement :', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              _copyRow('Adresse', pairing.hosts.isEmpty ? 'inconnue' : pairing.hosts.first),
              if (pairing.hosts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 70, bottom: 4),
                  child: Text(
                    'Si elle ne fonctionne pas : ${pairing.hosts.skip(1).join(', ')}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              _copyRow('Port', '${pairing.port}'),
              _copyRow('Code', pairing.token),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _stopServer,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Arrêter la réception'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _copyRow(String label, String value) => Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontFamily: 'Courier'))),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
        ],
      );

  Widget _buildConnectCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.sync, color: Color(0xFF4E9F3D)),
              SizedBox(width: 8),
              Text('Synchroniser avec un autre appareil',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Les ajouts, modifications et suppressions des deux appareils sont fusionnés. '
              'Une sauvegarde automatique est faite avant chaque synchronisation.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (isMobilePlatform) ...[
              FilledButton.icon(
                onPressed: _syncing ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner le code de l’autre appareil'),
              ),
              const SizedBox(height: 12),
              const Text('Ou saisir manuellement :', style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adresse (ex. 192.168.1.20)'),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Code'),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _syncing ? null : _connectManually,
                icon: const Icon(Icons.sync),
                label: const Text('Synchroniser'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera plein ecran qui renvoie le contenu du premier QR code de
/// synchronisation reconnu.
class _PairingScannerPage extends StatefulWidget {
  const _PairingScannerPage();

  @override
  State<_PairingScannerPage> createState() => _PairingScannerPageState();
}

class _PairingScannerPageState extends State<_PairingScannerPage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && SyncPairing.decode(raw) != null) {
        _done = true;
        Navigator.pop(context, raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le code de synchronisation')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
