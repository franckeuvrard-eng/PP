import 'dart:convert';
import 'dart:typed_data';

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

