import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'sync_merge.dart';

/// Ce dont la synchronisation a besoin de l'application. Interface plutot
/// que le `AppStateProvider` lui-meme : le service reste testable sans Flutter
/// ni base de donnees.
abstract class SyncHost {
  /// Identifiant stable de cet appareil (genere une fois).
  Future<String> syncDeviceId();

  /// Nom lisible de l'appareil, montre a l'autre cote.
  Future<String> syncDeviceName();

  /// Toutes les donnees, au format « sauvegarde » (cf. [SyncMerge]).
  Future<Map<String, dynamic>> syncSnapshot();

  /// Remplace les donnees locales par [snapshot] (deja fusionne).
  Future<void> syncApply(Map<String, dynamic> snapshot);

  /// Chemins relatifs (`profiles/x.jpg`) des photos et notes vocales presentes.
  Future<List<String>> syncMediaList();

  Future<Uint8List?> syncReadMedia(String relativePath);

  Future<void> syncWriteMedia(String relativePath, Uint8List bytes);

  /// Empreintes enregistrees a la derniere synchronisation avec [peerId].
  Future<Map<String, String>?> syncLoadBase(String peerId);

  Future<void> syncSaveBase(String peerId, Map<String, String> fingerprints);
}

/// Dossiers de medias synchronises. Liste blanche : le chemin recu du reseau
/// ne doit jamais pouvoir sortir de ces dossiers.
const syncMediaDirs = [
  'profiles',
  'workshops',
  'activities',
  'ateliers',
  'settings',
  'audio',
];

/// Vrai si [rel] est de la forme `dossier/fichier`, sans remontee de chemin.
bool isSafeMediaPath(String rel) {
  final parts = rel.split('/');
  if (parts.length != 2) return false;
  final dir = parts[0];
  final name = parts[1];
  if (!syncMediaDirs.contains(dir)) return false;
  if (name.isEmpty || name == '.' || name == '..') return false;
  if (name.contains('\\') || name.contains('\u0000')) return false;
  return true;
}

const int kSyncDefaultPort = 48765;
const int _protocol = 1;
const int _maxJsonBytes = 64 * 1024 * 1024;
const int _maxMediaBytes = 64 * 1024 * 1024;

/// Contenu du QR code affiche par le Mac et lu par l'iPhone.
class SyncPairing {
  const SyncPairing({
    required this.hosts,
    required this.port,
    required this.token,
    required this.name,
  });

  final List<String> hosts;
  final int port;
  final String token;
  final String name;

  String encode() => json.encode({
        'app': 'petitpas-sync',
        'v': _protocol,
        'hosts': hosts,
        'port': port,
        'token': token,
        'name': name,
      });

  /// Null si [raw] n'est pas un code d'appairage de cette application.
  static SyncPairing? decode(String raw) {
    try {
      final map = json.decode(raw);
      if (map is! Map || map['app'] != 'petitpas-sync') return null;
      final hosts = (map['hosts'] as List).map((h) => h.toString()).toList();
      final port = map['port'];
      final token = map['token'];
      if (hosts.isEmpty || port is! int || token is! String || token.isEmpty) return null;
      return SyncPairing(
        hosts: hosts,
        port: port,
        token: token,
        name: (map['name'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class SyncException implements Exception {
  SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _randomToken() {
  final rnd = Random.secure();
  return List.generate(16, (_) => rnd.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Adresses IPv4 locales de cette machine, la plus probablement celle du
/// Wi-Fi/Ethernet en premier (c'est elle qu'affichent le QR et la saisie
/// manuelle). Les adresses auto-attribuees et les interfaces virtuelles (VPN,
/// Docker, Hyper-V, machines virtuelles, donnees mobiles) sont ecartees ou
/// reléguees en fin de liste.
Future<List<String>> localIPv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  final candidates = <(String, int)>[
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.address.startsWith('169.254.')) (a.address, lanAddressScore(i.name, a.address)),
  ];
  // Tri stable : a score egal, l'ordre du systeme est conserve.
  final indexed = candidates.indexed.toList()
    ..sort((x, y) {
      final c = y.$2.$2.compareTo(x.$2.$2);
      return c != 0 ? c : x.$1.compareTo(y.$1);
    });
  return [for (final e in indexed) e.$2.$1];
}

/// Plus le score est haut, plus [address] sur l'interface [name] a de
/// chances d'etre l'adresse du reseau local de l'ecole.
int lanAddressScore(String name, String address) {
  final n = name.toLowerCase();
  // Noms courts (Mac, iPhone, Linux) : reconnus en debut de nom.
  const virtualPrefixes = [
    'utun', 'tun', 'tap', 'ppp', 'ipsec', 'wg', 'zt', 'pdp_ip', 'rmnet', 'awdl',
    'llw', 'anpi', 'bridge', 'br-', 'veth', 'docker', 'vmnet', 'vboxnet',
  ];
  // Noms longs (Windows) : reconnus n'importe ou dans le nom.
  const virtualWords = [
    'vethernet', 'virtualbox', 'vmware', 'hyper-v', 'wsl', 'docker', 'tailscale',
    'zerotier', 'wireguard', 'hamachi', 'vpn', 'loopback',
  ];
  var score = 0;
  // « Connexion au réseau local* 2 » : adaptateurs Wi-Fi Direct de Windows.
  if (virtualPrefixes.any(n.startsWith) || virtualWords.any(n.contains) || n.contains('*')) {
    score -= 100;
  }
  // en0/en1 (Mac, iPhone), wlan/eth (Linux, Android), « Wi-Fi »/« Ethernet » (Windows).
  if (RegExp(r'^(en\d|wlan|wlp|eth|enp|wi-?fi|ethernet|wireless)').hasMatch(n)) score += 20;
  if (address.startsWith('192.168.')) {
    score += 10;
  } else if (address.startsWith('10.')) {
    score += 8;
  } else if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(address)) {
    // Plage souvent occupee par Docker / Hyper-V / WSL.
    score += 4;
  }
  return score;
}

// ─────────────────────────── SERVEUR ───────────────────────────

/// Serveur HTTP local, lance a la demande sur l'appareil qui « recoit »
/// (typiquement le Mac). Tourne seulement tant que l'ecran de synchronisation
/// l'a demande, et chaque demarrage genere un nouveau jeton d'appairage.
class SyncServer {
  SyncServer(this.host);

  final SyncHost host;

  HttpServer? _server;
  String _token = '';
  bool _busy = false;

  /// Appele apres chaque synchronisation recue avec succes.
  void Function(SyncSummary summary)? onSynced;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  String get token => _token;

  Future<SyncPairing> start() async {
    if (_server != null) await stop();
    _token = _randomToken();
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, kSyncDefaultPort);
    } on SocketException {
      // Port occupe : on laisse le systeme en choisir un, le QR le contient.
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen(_handle, onError: (_) {});
    return SyncPairing(
      hosts: await localIPv4Addresses(),
      port: _server!.port,
      token: _token,
      name: await host.syncDeviceName(),
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _token = '';
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final auth = req.headers.value('authorization') ?? '';
      if (_token.isEmpty || !_constantTimeEquals(auth, 'Bearer $_token')) {
        return _reply(req, HttpStatus.unauthorized, {'error': 'Jeton invalide'});
      }
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/hello') {
        return _reply(req, HttpStatus.ok, {
          'protocol': _protocol,
          'deviceId': await host.syncDeviceId(),
          'name': await host.syncDeviceName(),
        });
      }
      if (req.method == 'GET' && path == '/snapshot') {
        return _reply(req, HttpStatus.ok, {
          'data': await host.syncSnapshot(),
          'media': await host.syncMediaList(),
        });
      }
      if (req.method == 'GET' && path == '/media') {
        final rel = req.uri.queryParameters['path'] ?? '';
        if (!isSafeMediaPath(rel)) {
          return _reply(req, HttpStatus.badRequest, {'error': 'Chemin refuse'});
        }
        final bytes = await host.syncReadMedia(rel);
        if (bytes == null) return _reply(req, HttpStatus.notFound, {'error': 'Absent'});
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.binary
          ..add(bytes);
        await req.response.close();
        return;
      }
      if (req.method == 'PUT' && path == '/media') {
        final rel = req.uri.queryParameters['path'] ?? '';
        if (!isSafeMediaPath(rel)) {
          return _reply(req, HttpStatus.badRequest, {'error': 'Chemin refuse'});
        }
        final bytes = await _readBytes(req, _maxMediaBytes);
        await host.syncWriteMedia(rel, bytes);
        return _reply(req, HttpStatus.ok, {'ok': true});
      }
      if (req.method == 'POST' && path == '/apply') {
        if (_busy) return _reply(req, HttpStatus.conflict, {'error': 'Synchronisation en cours'});
        _busy = true;
        try {
          final body = json.decode(utf8.decode(await _readBytes(req, _maxJsonBytes)));
          final data = Map<String, dynamic>.from(body['data'] as Map);
          final peerId = body['deviceId'] as String;
          final fingerprints = Map<String, String>.from(body['fingerprints'] as Map);
          await host.syncApply(data);
          await host.syncSaveBase(peerId, fingerprints);
          // Compte rendu prepare par l'autre appareil, deja vu de ce cote-ci.
          final changes = [
            for (final raw in (body['changes'] as List? ?? const []))
              if (MergeChange.fromMap(raw) case final c?) c,
          ];
          onSynced?.call(SyncSummary(
            peerName: (body['deviceName'] ?? '').toString(),
            changes: changes,
            snapshot: data,
            mediaDownloaded: (body['mediaUploaded'] as num?)?.toInt() ?? 0,
            mediaUploaded: (body['mediaDownloaded'] as num?)?.toInt() ?? 0,
          ));
          return _reply(req, HttpStatus.ok, {'ok': true});
        } finally {
          _busy = false;
        }
      }
      return _reply(req, HttpStatus.notFound, {'error': 'Inconnu'});
    } on _TooLarge {
      return _reply(req, HttpStatus.requestEntityTooLarge, {'error': 'Trop volumineux'});
    } catch (e) {
      // Le detail remonte a l'autre appareil : sans lui, une erreur 500 est
      // impossible a diagnostiquer sur le terrain. Reseau local, jeton exige.
      try {
        await _reply(req, HttpStatus.internalServerError,
            {'error': '${req.method} ${req.uri.path} : $e'});
      } catch (_) {}
    }
  }

  Future<void> _reply(HttpRequest req, int status, Map<String, dynamic> body) async {
    final bytes = utf8.encode(json.encode(body));
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..add(bytes);
    await req.response.close();
  }
}

class _TooLarge implements Exception {}

Future<Uint8List> _readBytes(Stream<List<int>> stream, int max) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
    if (builder.length > max) throw _TooLarge();
  }
  return builder.takeBytes();
}

// ─────────────────────────── CLIENT ───────────────────────────

/// Resume d'une synchronisation, montre a l'utilisateur.
/// Vu depuis l'appareil qui l'affiche : [MergeChange.onLocal] vrai = ici.
class SyncSummary {
  const SyncSummary({
    required this.peerName,
    required this.changes,
    required this.snapshot,
    required this.mediaDownloaded,
    required this.mediaUploaded,
  });

  final String peerName;
  final List<MergeChange> changes;

  /// Donnees fusionnees, pour retrouver les noms dans le compte rendu.
  final Map<String, dynamic> snapshot;
  final int mediaDownloaded;
  final int mediaUploaded;

  /// Elements en conflit (un meme element peut changer des deux cotes).
  int get conflicts =>
      changes.where((c) => c.conflict).map((c) => '${c.category}/${c.key}').toSet().length;
}

/// Cote qui lance la synchronisation (typiquement l'iPhone, mais le Mac peut
/// aussi se connecter a un autre appareil).
String _contentHash(Map<String, dynamic> snapshot) =>
    SyncMerge.hash(SyncMerge.fingerprints(SyncMerge.flatten(snapshot)));

class SyncClient {
  SyncClient(this.host, {this.timeout = const Duration(seconds: 10)});

  final SyncHost host;
  final Duration timeout;

  /// [resolveConflicts] : appele s'il y a des conflits, avant toute ecriture
  /// sur l'un ou l'autre appareil. Renvoie la valeur choisie par
  /// [MergeConflict.id] (absente = garder la version d'ici), ou null pour
  /// annuler la synchronisation. Sans lui, la version d'ici l'emporte.
  Future<SyncSummary> sync(
    SyncPairing pairing, {
    void Function(String step)? onProgress,
    Future<Map<String, Object?>?> Function(
            List<MergeConflict> conflicts, String peerName, Map<String, dynamic> merged)?
        resolveConflicts,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      onProgress?.call('Connexion…');
      final base = await _firstReachable(client, pairing);
      final hello = await _getJson(client, base, pairing.token, '/hello');
      if (hello['protocol'] != _protocol) {
        throw SyncException('Versions incompatibles : mettez à jour les deux applications.');
      }
      final peerId = hello['deviceId'] as String;
      final peerName = (hello['name'] ?? pairing.name).toString();

      onProgress?.call('Lecture des données de $peerName…');
      final remote = await _getJson(client, base, pairing.token, '/snapshot');
      final remoteData = Map<String, dynamic>.from(remote['data'] as Map);
      final remoteMedia = (remote['media'] as List).map((e) => e.toString()).toSet();

      onProgress?.call('Fusion…');
      final local = await host.syncSnapshot();
      final mergeBase = await host.syncLoadBase(peerId);
      var result = SyncMerge.merge(local: local, remote: remoteData, base: mergeBase);
      if (result.conflicts.isNotEmpty && resolveConflicts != null) {
        onProgress?.call('En attente de vos choix…');
        final choices = await resolveConflicts(result.conflicts, peerName, result.snapshot);
        if (choices == null) {
          throw SyncException('Synchronisation annulée : rien n’a été modifié.');
        }
        // Le choix peut prendre du temps : si l'autre appareil a ete modifie
        // entre-temps, appliquer la fusion ecraserait ces modifications.
        // Comparaison par empreintes : `exportedAt` change a chaque lecture.
        final again = await _getJson(client, base, pairing.token, '/snapshot');
        if (_contentHash(Map<String, dynamic>.from(again['data'] as Map)) !=
            _contentHash(remoteData)) {
          throw SyncException('$peerName a été modifié pendant vos choix : '
              'relancez la synchronisation (rien n’a été modifié).');
        }
        result = SyncMerge.merge(
            local: local, remote: remoteData, base: mergeBase, resolutions: choices);
      }

      // Medias d'abord : les donnees fusionnees y font reference.
      final localMedia = (await host.syncMediaList()).toSet();
      var downloaded = 0;
      var uploaded = 0;
      for (final rel in remoteMedia.difference(localMedia)) {
        if (!isSafeMediaPath(rel)) continue;
        onProgress?.call('Réception des photos ($downloaded)…');
        final bytes = await _getBytes(client, base, pairing.token, '/media?path=${Uri.encodeQueryComponent(rel)}');
        await host.syncWriteMedia(rel, bytes);
        downloaded++;
      }
      for (final rel in localMedia.difference(remoteMedia)) {
        if (!isSafeMediaPath(rel)) continue;
        final bytes = await host.syncReadMedia(rel);
        if (bytes == null) continue;
        onProgress?.call('Envoi des photos ($uploaded)…');
        await _putBytes(client, base, pairing.token, '/media?path=${Uri.encodeQueryComponent(rel)}', bytes);
        uploaded++;
      }

      onProgress?.call('Enregistrement…');
      // L'autre appareil d'abord : s'il echoue, rien n'a change ici et la
      // prochaine tentative repart de la meme base.
      await _postJson(client, base, pairing.token, '/apply', {
        'deviceId': await host.syncDeviceId(),
        'deviceName': await host.syncDeviceName(),
        'data': result.snapshot,
        'fingerprints': result.fingerprints,
        'changes': [for (final c in result.stats.changes) c.flipped().toMap()],
        'mediaDownloaded': downloaded,
        'mediaUploaded': uploaded,
      });
      await host.syncApply(result.snapshot);
      await host.syncSaveBase(peerId, result.fingerprints);

      return SyncSummary(
        peerName: peerName,
        changes: result.stats.changes,
        snapshot: result.snapshot,
        mediaDownloaded: downloaded,
        mediaUploaded: uploaded,
      );
    } on _TooLarge {
      throw SyncException('Les données sont trop volumineuses pour être synchronisées.');
    } on SocketException {
      throw SyncException('Appareil injoignable. Vérifiez qu’ils sont sur le même Wi‑Fi.');
    } on TimeoutException {
      throw SyncException('L’appareil ne répond pas.');
    } on HandshakeException {
      throw SyncException('Connexion refusée.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Uri> _firstReachable(HttpClient client, SyncPairing pairing) async {
    for (final h in pairing.hosts) {
      final base = Uri(scheme: 'http', host: h, port: pairing.port);
      try {
        await _getJson(client, base, pairing.token, '/hello');
        return base;
      } on SyncException {
        rethrow;
      } catch (_) {
        // Adresse suivante (un Mac a souvent plusieurs interfaces).
      }
    }
    throw const SocketException('aucune adresse joignable');
  }

  Future<HttpClientResponse> _send(
    HttpClient client,
    String method,
    Uri base,
    String token,
    String pathAndQuery, {
    List<int>? body,
    ContentType? contentType,
  }) async {
    final uri = base.resolve(pathAndQuery);
    final req = await client.openUrl(method, uri).timeout(timeout);
    req.headers.set('authorization', 'Bearer $token');
    if (body != null) {
      req.headers.contentType = contentType ?? ContentType.json;
      req.contentLength = body.length;
      req.add(body);
    }
    final res = await req.close().timeout(timeout);
    if (res.statusCode == HttpStatus.unauthorized) {
      await res.drain<void>();
      throw SyncException('Code d’appairage invalide ou expiré : rescannez le QR code.');
    }
    if (res.statusCode == HttpStatus.conflict) {
      await res.drain<void>();
      throw SyncException('L’autre appareil est déjà en cours de synchronisation.');
    }
    if (res.statusCode != HttpStatus.ok) {
      var detail = '';
      try {
        final body = json.decode(utf8.decode(await _readBytes(res, 64 * 1024)));
        if (body is Map && body['error'] != null) detail = ' (${body['error']})';
      } catch (_) {}
      throw SyncException('Erreur ${res.statusCode} de l’autre appareil$detail.');
    }
    return res;
  }

  Future<Map<String, dynamic>> _getJson(HttpClient c, Uri base, String token, String path) async {
    final res = await _send(c, 'GET', base, token, path);
    final bytes = await _readBytes(res, _maxJsonBytes);
    return Map<String, dynamic>.from(json.decode(utf8.decode(bytes)) as Map);
  }

  Future<Uint8List> _getBytes(HttpClient c, Uri base, String token, String path) async {
    final res = await _send(c, 'GET', base, token, path);
    return _readBytes(res, _maxMediaBytes);
  }

  Future<void> _putBytes(HttpClient c, Uri base, String token, String path, Uint8List bytes) async {
    final res = await _send(c, 'PUT', base, token, path,
        body: bytes, contentType: ContentType.binary);
    await res.drain<void>();
  }

  Future<void> _postJson(HttpClient c, Uri base, String token, String path, Map<String, dynamic> body) async {
    final res = await _send(c, 'POST', base, token, path, body: utf8.encode(json.encode(body)));
    await res.drain<void>();
  }
}
