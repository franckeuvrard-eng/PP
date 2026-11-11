import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'sync_service.dart';

/// Type Bonjour de l'application. Doit rester identique a `NSBonjourServices`
/// (ios/Runner/Info.plist et workflow macOS).
const kSyncServiceType = '_petitpas._tcp';

/// Appareil trouve sur le reseau local, pret a etre synchronise.
class DiscoveredPeer {
  const DiscoveredPeer({required this.deviceId, required this.pairing});

  final String deviceId;
  final SyncPairing pairing;

  String get name => pairing.name;
}

/// Annonce le [SyncServer] en cours sur le reseau local.
///
/// Pas de code a saisir : le jeton du serveur est publie avec l'annonce. La
/// protection vient de l'accord demande sur cet appareil a chaque nouvel
/// appareil qui se connecte (cf. [SyncServer.onConsentRequest]).
class SyncAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start({required SyncPairing pairing, required String deviceId}) async {
    await stop();
    final service = BonsoirService(
      name: pairing.name.isEmpty ? 'A petits pas' : pairing.name,
      type: kSyncServiceType,
      port: pairing.port,
      attributes: {
        'id': deviceId,
        'token': pairing.token,
        'name': pairing.name,
        // Adresses IP en plus du nom d'hote : la resolution des noms .local
        // n'est pas fiable partout (Windows notamment).
        'ips': pairing.hosts.join(','),
      },
    );
    final broadcast = BonsoirBroadcast(service: service);
    _broadcast = broadcast;
    await broadcast.initialize();
    await broadcast.start();
  }

  Future<void> stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    await broadcast?.stop();
  }
}

/// Cherche les autres appareils qui annoncent [kSyncServiceType].
class SyncBrowser {
  SyncBrowser({required this.ownDeviceId});

  /// Pour ne pas se lister soi-meme.
  final String ownDeviceId;

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  // Cle : nom du service Bonjour (seul identifiant connu a la disparition).
  final Map<String, DiscoveredPeer> _peers = {};
  final _controller = StreamController<List<DiscoveredPeer>>.broadcast();

  Stream<List<DiscoveredPeer>> get peers => _controller.stream;

  Future<void> start() async {
    await stop();
    final discovery = BonsoirDiscovery(type: kSyncServiceType);
    _discovery = discovery;
    await discovery.initialize();
    _sub = discovery.eventStream?.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          event.service.resolve(discovery.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent():
          _onResolved(event.service);
        case BonsoirDiscoveryServiceUpdatedEvent():
          _onResolved(event.service);
        case BonsoirDiscoveryServiceLostEvent():
          if (_peers.remove(event.service.name) != null) _emit();
        default:
          break;
      }
    });
    await discovery.start();
  }

  void _onResolved(BonsoirService service) {
    final a = service.attributes;
    final id = a['id'] ?? '';
    final token = a['token'] ?? '';
    if (id.isEmpty || token.isEmpty || id == ownDeviceId) return;
    // Adresses resolues par le systeme d'abord (les plus sures), puis celles
    // annoncees par l'appareil, puis son nom .local en dernier recours.
    final ips = (a['ips'] ?? '').split(',').where((s) => s.isNotEmpty);
    final hostname = _stripDot(service.hostname ?? '');
    final hosts = <String>{
      ...service.hostAddresses.where((h) => !h.contains(':')), // IPv4 seulement
      ...ips,
      if (hostname.isNotEmpty) hostname,
    }.toList();
    if (hosts.isEmpty) return;
    // Un meme appareil peut reapparaitre sous un autre nom de service
    // (renommage Bonjour apres redemarrage) : on dedoublonne par identifiant.
    _peers.removeWhere((key, p) => p.deviceId == id && key != service.name);
    _peers[service.name] = DiscoveredPeer(
      deviceId: id,
      pairing: SyncPairing(
        hosts: hosts,
        port: service.port,
        token: token,
        name: (a['name'] ?? '').isEmpty ? service.name : a['name']!,
      ),
    );
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_peers.values.toList());
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    final discovery = _discovery;
    _discovery = null;
    await discovery?.stop();
    _peers.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

String _stripDot(String host) =>
    host.endsWith('.') ? host.substring(0, host.length - 1) : host;
