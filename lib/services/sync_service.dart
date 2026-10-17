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

/// Adresses IPv4 locales de cette machine (hors boucle locale).
Future<List<String>> localIPv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  return [
    for (final i in interfaces)
      for (final a in i.addresses) a.address,
  ];
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
  void Function()? onSynced;

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
          onSynced?.call();
          return _reply(req, HttpStatus.ok, {'ok': true});
        } finally {
          _busy = false;
        }
      }
      return _reply(req, HttpStatus.notFound, {'error': 'Inconnu'});
    } on _TooLarge {
      return _reply(req, HttpStatus.requestEntityTooLarge, {'error': 'Trop volumineux'});
    } catch (e) {
      try {
        await _reply(req, HttpStatus.internalServerError, {'error': 'Erreur interne'});
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
class SyncSummary {
  const SyncSummary({
    required this.peerName,
    required this.stats,
    required this.mediaDownloaded,
    required this.mediaUploaded,
  });

  final String peerName;
  final MergeStats stats;
  final int mediaDownloaded;
  final int mediaUploaded;
}

/// Cote qui lance la synchronisation (typiquement l'iPhone, mais le Mac peut
/// aussi se connecter a un autre appareil).
class SyncClient {
  SyncClient(this.host, {this.timeout = const Duration(seconds: 10)});

  final SyncHost host;
  final Duration timeout;

  Future<SyncSummary> sync(
    SyncPairing pairing, {
    void Function(String step)? onProgress,
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
      final result = SyncMerge.merge(
        local: local,
        remote: remoteData,
        base: await host.syncLoadBase(peerId),
      );

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
        'data': result.snapshot,
        'fingerprints': result.fingerprints,
      });
      await host.syncApply(result.snapshot);
      await host.syncSaveBase(peerId, result.fingerprints);

      return SyncSummary(
        peerName: peerName,
        stats: result.stats,
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
      await res.drain<void>();
      throw SyncException('Erreur ${res.statusCode} de l’autre appareil.');
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
