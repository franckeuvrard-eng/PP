import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:petitpas_icloud/petitpas_icloud.dart';

import '../data/seed_ids.dart';

import 'sync_merge.dart';
import 'sync_service.dart';

/// Conteneur iCloud de l'application. Ne jamais changer : les donnees deja
/// dans iCloud y sont attachees.
const kICloudContainerId = 'iCloud.fr.franckeuvrard.apetitspas';

/// Dossier partage, vu par chemins relatifs. Interface pour pouvoir tester
/// toute la synchronisation sans iCloud.
abstract class CloudFolder {
  /// False si iCloud est inaccessible (pas de compte, app non signee…).
  Future<bool> isAvailable();
  Future<bool> exists(String rel);
  Future<List<String>> list(String relDir);
  Future<bool> ensureDownloaded(String rel);
  Future<Uint8List?> read(String rel);
  Future<void> write(String rel, Uint8List bytes);
  Future<List<Uint8List>> conflictVersions(String rel);
  Future<void> resolveConflicts(String rel);

  /// Signale qu'un autre appareil a depose une nouvelle version de [rel]
  /// (pour synchroniser aussitot). Peut ne jamais rien emettre.
  Stream<void> changes(String rel);
}

/// Le vrai conteneur iCloud Drive (iOS et macOS).
class ICloudFolder implements CloudFolder {
  ICloudFolder({this.plugin = const PetitpasIcloud()});

  final PetitpasIcloud plugin;
  String? _root;

  Future<String?> _rootPath() async {
    if (_root != null) return _root;
    if (!await plugin.isAvailable()) return null;
    return _root = await plugin.containerDocuments(kICloudContainerId);
  }

  Future<String> _abs(String rel) async {
    final root = await _rootPath();
    if (root == null) throw StateError('iCloud indisponible');
    return '$root/$rel';
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _rootPath() != null;
    } catch (_) {
      return false; // pas d'implementation native (Windows, tests) ou refus
    }
  }

  @override
  Future<bool> exists(String rel) async => plugin.exists(await _abs(rel));
  @override
  Future<List<String>> list(String relDir) async => plugin.list(await _abs(relDir));
  @override
  Future<bool> ensureDownloaded(String rel) async => plugin.ensureDownloaded(await _abs(rel));
  @override
  Future<Uint8List?> read(String rel) async => plugin.read(await _abs(rel));
  @override
  Future<void> write(String rel, Uint8List bytes) async => plugin.write(await _abs(rel), bytes);
  @override
  Future<List<Uint8List>> conflictVersions(String rel) async =>
      plugin.conflictVersions(await _abs(rel));
  @override
  Future<void> resolveConflicts(String rel) async => plugin.resolveConflicts(await _abs(rel));
  @override
  Stream<void> changes(String rel) => plugin.changes(rel.split('/').last);
}

enum CloudSyncStatus {
  /// iCloud inaccessible : rien n'a ete fait.
  unavailable,

  /// Deja identique : rien a ecrire.
  upToDate,

  /// Changements appliques ici et/ou envoyes dans iCloud.
  synced,

  /// Beaucoup de suppressions en jeu : rien n'est fait sans accord.
  needsConfirmation,

  /// Elements modifies des deux cotes : choix de l'utilisateur requis.
  needsResolution,

  /// iCloud a change pendant la synchro : a refaire un peu plus tard.
  retryLater,

  error,
}

class CloudSyncOutcome {
  CloudSyncOutcome(this.status, {this.summary, this.message}) : at = DateTime.now();

  final CloudSyncStatus status;

  /// Changements prevus (needsConfirmation/needsResolution) ou faits (synced).
  final SyncSummary? summary;
  final String? message;
  final DateTime at;
}

/// Synchronisation via un fichier de classe unique dans iCloud.
///
/// Meme fusion a trois voies que la synchro Wi-Fi, iCloud tenant le role de
/// « l'autre appareil » : chaque appareil memorise l'etat commun de sa
/// derniere synchro (sa « base ») et fusionne ses changements avec ceux deposes
/// par les autres. Les filets de securite sont les memes : sauvegarde avant
/// d'appliquer, accord avant des suppressions massives, appareil remis a zero
/// re-rempli (sa base oubliee ne correspond plus a la lignee du fichier).
class CloudSync {
  CloudSync(this.host, this.folder);

  final SyncHost host;
  final CloudFolder folder;

  static const classFile = 'classe.json';
  static const mediaDir = 'medias';

  /// Cle de la base dans [SyncHost.syncLoadBase] (distincte des bases Wi-Fi).
  static const baseKey = 'icloud';

  /// Au-dela, des suppressions demandent un accord : plus de [_maxSilentDeletes]
  /// elements, ou plus de [_maxSilentShare] des elements de ce cote.
  static const _maxSilentDeletes = 5;
  static const _maxSilentShare = 0.2;

  bool _running = false;

  /// [interactive] : appel depuis l'ecran de synchronisation, ou les choix
  /// et confirmations sont possibles. En automatique ([resolveConflicts] et
  /// [confirmChanges] absents), toute situation delicate est rendue sans
  /// rien ecrire, pour que l'utilisateur la tranche plus tard.
  Future<CloudSyncOutcome> sync({
    Future<Map<String, Object?>?> Function(
            List<MergeConflict> conflicts, String peerName, Map<String, dynamic> merged)?
        resolveConflicts,
    Future<bool> Function(SyncSummary preview)? confirmChanges,
  }) async {
    if (_running) return CloudSyncOutcome(CloudSyncStatus.retryLater, message: 'Déjà en cours');
    _running = true;
    try {
      return await _sync(resolveConflicts, confirmChanges);
    } on SyncException catch (e) {
      return CloudSyncOutcome(CloudSyncStatus.error, message: e.message);
    } catch (e) {
      return CloudSyncOutcome(CloudSyncStatus.error, message: '$e');
    } finally {
      _running = false;
    }
  }

  Future<CloudSyncOutcome> _sync(
    Future<Map<String, Object?>?> Function(List<MergeConflict>, String, Map<String, dynamic>)?
        resolveConflicts,
    Future<bool> Function(SyncSummary)? confirmChanges,
  ) async {
    if (!await folder.isAvailable()) {
      return CloudSyncOutcome(CloudSyncStatus.unavailable,
          message: 'iCloud n’est pas disponible sur cet appareil.');
    }

    // 1. Etat dans iCloud, versions en conflit comprises.
    final cloudRaw = await _readClassFile();
    final cloud = cloudRaw == null ? null : _decode(cloudRaw);
    var lineage = cloud?['lineage'] as String? ?? _randomId();
    var remoteData = cloud == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(cloud['data'] as Map? ?? const {});
    final conflictVersions = cloudRaw == null ? const <Uint8List>[] : await folder.conflictVersions(classFile);
    for (final v in conflictVersions) {
      // Ecritures simultanees : union prudente, rien n'est supprime.
      final other = _decode(v);
      if (other == null) continue;
      remoteData = SyncMerge.merge(
        local: remoteData,
        remote: Map<String, dynamic>.from(other['data'] as Map? ?? const {}),
      ).snapshot;
    }

    // 2. Fusion avec cet appareil, depuis la derniere base commune.
    final local = await host.syncSnapshot();
    var base = await host.syncLoadBase(baseKey);
    if (base == null || base[kSyncGenerationKey] != lineage) base = null;
    var result = SyncMerge.merge(local: local, remote: remoteData, base: base);

    // Appareil neuf (jamais synchronise, ni eleve ni observation) : ses
    // differences ne sont que les exemples crees a l'installation. iCloud fait
    // foi, sans poser de question qui bloquerait la premiere synchro.
    var resolved = false;
    if (result.conflicts.isNotEmpty && base == null && cloud != null && _isFreshInstall(local)) {
      result = SyncMerge.merge(local: local, remote: remoteData, base: base, resolutions: {
        for (final c in result.conflicts) c.id: c.remote,
      });
      resolved = true;
    }

    if (result.conflicts.isNotEmpty && !resolved) {
      final summary = _summary(result, 0, 0);
      if (resolveConflicts == null) {
        return CloudSyncOutcome(CloudSyncStatus.needsResolution, summary: summary,
            message: '${result.conflicts.length} élément(s) modifié(s) des deux côtés.');
      }
      final choices = await resolveConflicts(result.conflicts, 'iCloud', result.snapshot);
      if (choices == null) throw SyncException('Synchronisation annulée : rien n’a été modifié.');
      result = SyncMerge.merge(local: local, remote: remoteData, base: base, resolutions: choices);
    }

    // 3. Medias : ceux utilises par la fusion, a echanger avec la reserve.
    final needed = referencedMedia(result.snapshot);
    final localMedia = (await host.syncMediaList()).toSet();
    final cloudMedia = (await folder.list(mediaDir)).toSet();
    final toUpload = needed.intersection(localMedia).difference(cloudMedia);
    final toDownload = needed.intersection(cloudMedia).difference(localMedia);

    final changesHere = result.stats.changes.where((c) => c.onLocal).toList();
    final changesThere = result.stats.changes.where((c) => !c.onLocal).toList();
    if (changesHere.isEmpty && changesThere.isEmpty && toUpload.isEmpty &&
        toDownload.isEmpty && cloud != null && conflictVersions.isEmpty) {
      await host.syncSaveBase(baseKey, _base(result, lineage));
      return CloudSyncOutcome(CloudSyncStatus.upToDate);
    }

    // 4. Suppressions massives : jamais sans accord.
    final summary = _summary(result, toDownload.length, toUpload.length);
    if (_massive(changesHere, local) || _massive(changesThere, remoteData)) {
      if (confirmChanges == null) {
        return CloudSyncOutcome(CloudSyncStatus.needsConfirmation, summary: summary,
            message: 'Beaucoup de suppressions en attente : vérifiez avant de synchroniser.');
      }
      if (!await confirmChanges(summary)) {
        throw SyncException('Synchronisation annulée : rien n’a été modifié.');
      }
    }

    // 5. Sauvegarde avant de modifier cet appareil.
    if (changesHere.isNotEmpty) {
      try {
        await host.syncBackup();
      } catch (e) {
        throw SyncException('La sauvegarde de sécurité a échoué ($e) : rien n’a été modifié.');
      }
    }

    // 6. Medias d'abord (les donnees y font reference).
    for (final rel in toUpload) {
      final bytes = await host.syncReadMedia(rel);
      if (bytes != null) await folder.write('$mediaDir/$rel', bytes);
    }
    var downloaded = 0;
    for (final rel in toDownload) {
      // Photo pas encore arrivee d'iCloud : elle sera reprise a la prochaine synchro.
      if (!await folder.ensureDownloaded('$mediaDir/$rel')) continue;
      final bytes = await folder.read('$mediaDir/$rel');
      if (bytes == null) continue;
      await host.syncWriteMedia(rel, bytes);
      downloaded++;
    }

    // 7. Fichier de classe, si iCloud a quelque chose de nouveau a recevoir.
    if (changesThere.isNotEmpty || cloud == null || conflictVersions.isNotEmpty) {
      // Un autre appareil a-t-il ecrit pendant ce temps ? Alors on recommence.
      final now = await _readClassFile();
      if (!_sameBytes(now, cloudRaw)) {
        return CloudSyncOutcome(CloudSyncStatus.retryLater,
            message: 'iCloud a changé pendant la synchronisation.');
      }
      await folder.write(classFile, _encode(lineage, result.snapshot, await host.syncDeviceName()));
      if (conflictVersions.isNotEmpty) await folder.resolveConflicts(classFile);
    }

    // 8. Cet appareil, puis la nouvelle base commune.
    if (changesHere.isNotEmpty) await host.syncApply(result.snapshot);
    await host.syncSaveBase(baseKey, _base(result, lineage));

    return CloudSyncOutcome(CloudSyncStatus.synced,
        summary: _summary(result, downloaded, toUpload.length));
  }

  Future<Uint8List?> _readClassFile() async {
    if (!await folder.exists(classFile)) return null;
    if (!await folder.ensureDownloaded(classFile)) {
      throw SyncException('Le fichier iCloud n’a pas pu être téléchargé : réessayez plus tard.');
    }
    return folder.read(classFile);
  }

  static Map<String, dynamic>? _decode(Uint8List bytes) {
    try {
      final v = json.decode(utf8.decode(bytes));
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  static Uint8List _encode(String lineage, Map<String, dynamic> data, String by) =>
      Uint8List.fromList(utf8.encode(json.encode({
        'format': 1,
        'lineage': lineage,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': by,
        'data': data,
      })));

  /// Rien de saisi sur cet appareil : ses eleves et observations sont tous
  /// des exemples de l'installation (ou il n'y en a aucun).
  static bool _isFreshInstall(Map<String, dynamic> local) {
    bool onlySeeds(String key, Set<String> seeds) => (local[key] as List? ?? const [])
        .every((r) => r is Map && seeds.contains(r['id']));
    return onlySeeds('children', kSeedChildIds) && onlySeeds('activities', kSeedActivityIds);
  }

  static Map<String, String> _base(MergeResult r, String lineage) =>
      {...r.fingerprints, kSyncGenerationKey: lineage};

  static bool _massive(List<MergeChange> changes, Map<String, dynamic> side) {
    final deletes = changes.where((c) => c.kind == ChangeKind.deleted).length;
    if (deletes == 0) return false;
    final total = SyncMerge.flatten(side).values.fold<int>(0, (n, c) => n + c.length);
    return deletes > _maxSilentDeletes || deletes > total * _maxSilentShare;
  }

  static SyncSummary _summary(MergeResult r, int downloaded, int uploaded) => SyncSummary(
        peerName: 'iCloud',
        changes: r.stats.changes,
        snapshot: r.snapshot,
        mediaDownloaded: downloaded,
        mediaUploaded: uploaded,
      );

  static bool _sameBytes(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _randomId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
