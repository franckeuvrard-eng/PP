import 'package:flutter/services.dart';

/// Acces au conteneur iCloud Drive prive de l'application (iOS et macOS).
///
/// Simple pont vers le code natif (darwin/Classes) : la logique de
/// synchronisation est cote Dart, dans l'application.
class PetitpasIcloud {
  const PetitpasIcloud();

  static const _channel = MethodChannel('petitpas/icloud');

  /// Vrai si un compte iCloud est connecte et iCloud Drive actif.
  Future<bool> isAvailable() async => await _channel.invokeMethod<bool>('isAvailable') ?? false;

  /// Dossier `Documents` du conteneur [containerId], ou null si inaccessible
  /// (app non signee avec le droit iCloud, iCloud Drive desactive…).
  Future<String?> containerDocuments(String containerId) =>
      _channel.invokeMethod<String>('containerDocuments', {'id': containerId});

  /// Vrai si le fichier existe, telecharge ou non.
  Future<bool> exists(String path) async =>
      await _channel.invokeMethod<bool>('exists', {'path': path}) ?? false;

  /// Chemins relatifs des fichiers sous [dir], telecharges ou non.
  Future<List<String>> list(String dir) async =>
      (await _channel.invokeListMethod<String>('list', {'path': dir})) ?? const [];

  /// Telecharge le fichier si besoin ; false s'il n'existe pas ou si le
  /// delai est depasse.
  Future<bool> ensureDownloaded(String path, {Duration timeout = const Duration(seconds: 30)}) async =>
      await _channel.invokeMethod<bool>(
          'ensureDownloaded', {'path': path, 'timeoutMs': timeout.inMilliseconds}) ??
      false;

  /// Lecture coordonnee ; null si le fichier n'existe pas.
  Future<Uint8List?> read(String path) => _channel.invokeMethod<Uint8List>('read', {'path': path});

  /// Ecriture coordonnee (remplacement atomique), dossiers crees au besoin.
  Future<void> write(String path, Uint8List bytes) =>
      _channel.invokeMethod<void>('write', {'path': path, 'bytes': bytes});

  /// Contenu des versions en conflit (ecritures simultanees d'autres appareils).
  Future<List<Uint8List>> conflictVersions(String path) async =>
      (await _channel.invokeListMethod<Uint8List>('conflictVersions', {'path': path})) ?? const [];

  /// Marque les conflits comme resolus (apres les avoir fusionnes).
  Future<void> resolveConflicts(String path) =>
      _channel.invokeMethod<void>('resolveConflicts', {'path': path});
}
