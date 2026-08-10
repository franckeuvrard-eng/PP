import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Une sauvegarde deposee dans le conteneur iCloud de l'application.
@immutable
class ICloudBackup {
  const ICloudBackup({
    required this.name,
    required this.sizeBytes,
    required this.modified,
    required this.downloaded,
  });

  /// Nom de fichier, au format `auto_<horodatage>.json`.
  final String name;
  final int sizeBytes;
  final DateTime modified;

  /// Faux tant que le fichier n'existe sur cet appareil que sous forme de
  /// marqueur : la sauvegarde vient d'un autre appareil et devra etre
  /// telechargee avant restauration.
  final bool downloaded;

  /// Horodatage lisible extrait du nom, la date de modification du fichier
  /// etant celle du televersement et non celle de la sauvegarde.
  String get label => name
      .replaceFirst('auto_', '')
      .replaceFirst('.json', '')
      .replaceAll('T', ' à ')
      .replaceAll('-', '/');

  static ICloudBackup fromMap(Map<Object?, Object?> map) => ICloudBackup(
        name: map['name'] as String? ?? '',
        sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(
            (map['modified'] as num?)?.toInt() ?? 0),
        downloaded: map['downloaded'] as bool? ?? false,
      );
}

/// Copie les sauvegardes automatiques dans le conteneur iCloud Drive de
/// l'application, via le canal natif declare dans ios/Runner/AppDelegate.swift.
///
/// iCloud est une copie hors appareil, jamais la source de verite : chaque
/// appel echoue en silence et rend une valeur neutre. Une panne reseau, un
/// compte iCloud absent ou un stockage plein ne doivent ni interrompre la
/// sauvegarde locale, ni remonter une erreur a l'enseignant en pleine classe.
class ICloudBackupService {
  const ICloudBackupService._();

  static const MethodChannel _channel = MethodChannel('petitpas/icloud');

  /// Le canal n'est enregistre que par l'AppDelegate iOS. Ailleurs — apercu
  /// Windows, tests, CI — tout appel leverait MissingPluginException.
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Vrai si l'appareil dispose d'un conteneur iCloud utilisable.
  static Future<bool> isAvailable() async {
    if (!_supported) return false;
    return await _invoke<bool>('available') ?? false;
  }

  /// Televerse les sauvegardes absentes du conteneur et n'y conserve que les
  /// [keep] plus recentes. Rend le nombre de fichiers effectivement envoyes.
  static Future<int> push(List<String> paths, {required int keep}) async {
    if (!_supported || paths.isEmpty) return 0;
    return await _invoke<int>('push', {'paths': paths, 'keep': keep}) ?? 0;
  }

  /// Sauvegardes presentes sur iCloud, de la plus recente a la plus ancienne.
  static Future<List<ICloudBackup>> list() async {
    if (!_supported) return const [];
    final raw = await _invoke<List<Object?>>('list');
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(ICloudBackup.fromMap)
        .toList();
  }

  /// Rapatrie [name] vers [destination], en declenchant si besoin son
  /// telechargement. Rend le chemin local, ou null en cas d'echec.
  static Future<String?> pull(String name, String destination) async {
    if (!_supported) return null;
    return _invoke<String>('pull', {'name': name, 'destination': destination});
  }

  static Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('iCloud : $method a echoue (${e.code}) ${e.message}');
      return null;
    } on MissingPluginException {
      // Build iOS sans le canal natif : l'application doit rester utilisable.
      debugPrint('iCloud : canal natif absent, synchronisation ignoree.');
      return null;
    }
  }
}
