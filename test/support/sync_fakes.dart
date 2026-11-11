import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:petitpas/services/icloud_sync.dart';
import 'package:petitpas/services/sync_service.dart';

/// Faux appareil et instantanes pour les tests de synchronisation
/// (Wi-Fi et iCloud).
Map<String, dynamic> snap(List<Map<String, dynamic>> children,
        {Map<String, dynamic>? sons}) =>
    {
      'children': children,
      'activities': [],
      'spaces': [],
      'activity_types': [],
      'evaluation_statuses': [],
      'referentials': [],
      'class_settings': {'name': 'A'},
      'sections': ['PS'],
      'sons_progress': sons ?? {},
      'referential_status': {},
    };

class FakeHost implements SyncHost {
  FakeHost(this.id, this.data);
  final String id;
  Map<String, dynamic> data;
  final media = <String, Uint8List>{};
  final bases = <String, Map<String, String>>{};

  @override
  Future<String> syncDeviceId() async => id;
  @override
  Future<String> syncDeviceName() async => 'appareil-$id';
  @override
  Future<Map<String, dynamic>> syncSnapshot() async =>
      Map<String, dynamic>.from(json.decode(json.encode(data)) as Map);
  /// Mettre a vrai pour simuler une sauvegarde impossible (disque plein…).
  bool backupFails = false;
  int backups = 0;
  @override
  Future<void> syncBackup() async {
    if (backupFails) throw StateError('disque plein');
    backups++;
  }
  @override
  Future<void> syncApply(Map<String, dynamic> s) async => data = Map<String, dynamic>.from(s);
  @override
  Future<List<String>> syncMediaList() async => media.keys.toList();
  @override
  Future<Uint8List?> syncReadMedia(String p) async => media[p];
  @override
  Future<void> syncWriteMedia(String p, Uint8List b) async => media[p] = b;
  @override
  Future<Map<String, String>?> syncLoadBase(String p) async => bases[p];
  @override
  Future<void> syncSaveBase(String p, Map<String, String> f) async => bases[p] = f;
}

/// iCloud simule en memoire : un seul dossier partage par tous les appareils.
class FakeCloud implements CloudFolder {
  final files = <String, Uint8List>{};
  bool available = true;

  /// Appele juste avant chaque lecture : permet de simuler un autre appareil
  /// qui ecrit pendant une synchronisation.
  void Function()? beforeRead;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> exists(String rel) async => files.containsKey(rel);
  @override
  Future<List<String>> list(String relDir) async => [
        for (final k in files.keys)
          if (k.startsWith('$relDir/')) k.substring(relDir.length + 1),
      ];
  @override
  Future<bool> ensureDownloaded(String rel) async => files.containsKey(rel);
  @override
  Future<Uint8List?> read(String rel) async {
    beforeRead?.call();
    return files[rel];
  }

  @override
  Future<void> write(String rel, Uint8List bytes) async => files[rel] = bytes;
  @override
  Future<List<Uint8List>> conflictVersions(String rel) async => const [];
  @override
  Future<void> resolveConflicts(String rel) async {}

  final changesController = StreamController<void>.broadcast();
  @override
  Stream<void> changes(String rel) => changesController.stream;
}
