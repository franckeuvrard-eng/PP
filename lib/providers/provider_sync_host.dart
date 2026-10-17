import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../services/sync_service.dart';
import 'app_provider.dart';

/// Branche la synchronisation locale sur l'etat de l'application.
class ProviderSyncHost implements SyncHost {
  ProviderSyncHost(this._provider);

  final AppStateProvider _provider;

  @override
  Future<String> syncDeviceId() => _provider.syncDeviceId();

  @override
  Future<String> syncDeviceName() async {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Appareil';
    }
  }

  /// Passe par une serialisation JSON complete : on compare et on transmet
  /// exactement ce qui sera relu de l'autre cote, pas des objets Dart.
  @override
  Future<Map<String, dynamic>> syncSnapshot() async =>
      Map<String, dynamic>.from(json.decode(json.encode(_provider.buildSyncSnapshot())) as Map);

  @override
  Future<void> syncBackup() => _provider.backupBeforeSync();

  @override
  Future<void> syncApply(Map<String, dynamic> snapshot) =>
      _provider.applySyncSnapshot(snapshot);

  @override
  Future<List<String>> syncMediaList() => _provider.listSyncMedia();

  @override
  Future<Uint8List?> syncReadMedia(String relativePath) =>
      _provider.readSyncMedia(relativePath);

  @override
  Future<void> syncWriteMedia(String relativePath, Uint8List bytes) =>
      _provider.writeSyncMedia(relativePath, bytes);

  @override
  Future<Map<String, String>?> syncLoadBase(String peerId) =>
      _provider.loadSyncBase(peerId);

  @override
  Future<void> syncSaveBase(String peerId, Map<String, String> fingerprints) =>
      _provider.saveSyncBase(peerId, fingerprints);
}
