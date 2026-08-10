import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/services/icloud_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ICloudBackup.fromMap', () {
    test('lit une entree renvoyee par le canal natif', () {
      // Le canal livre des Map<Object?, Object?> et des num : le decodage doit
      // s'en accommoder sans cast direct vers Map<String, dynamic>.
      final backup = ICloudBackup.fromMap(<Object?, Object?>{
        'name': 'auto_2026-08-10T09-30-00.json',
        'size': 4096,
        'modified': 1786000000000,
        'downloaded': true,
      });

      expect(backup.name, 'auto_2026-08-10T09-30-00.json');
      expect(backup.sizeBytes, 4096);
      expect(backup.downloaded, isTrue);
      expect(backup.modified, DateTime.fromMillisecondsSinceEpoch(1786000000000));
    });

    test('tolere une entree incomplete plutot que de lever', () {
      final backup = ICloudBackup.fromMap(const <Object?, Object?>{});

      expect(backup.name, '');
      expect(backup.sizeBytes, 0);
      expect(backup.downloaded, isFalse);
    });

    test('rend le nom de fichier lisible', () {
      final backup = ICloudBackup.fromMap(<Object?, Object?>{
        'name': 'auto_2026-08-10T09-30-00.json',
      });

      expect(backup.label, '2026/08/10 à 09/30/00');
    });
  });

  group('ICloudBackupService hors iOS', () {
    // La cible de test n'est pas iOS : le canal natif n'existe pas. Le service
    // doit rendre des valeurs neutres sans jamais appeler la plateforme, sans
    // quoi l'apercu Windows et le CI planteraient sur MissingPluginException.
    final appels = <String>[];

    setUp(() {
      appels.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('petitpas/icloud'),
        (call) async {
          appels.add(call.method);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('petitpas/icloud'), null);
    });

    test('isAvailable rend false sans appeler la plateforme', () async {
      expect(await ICloudBackupService.isAvailable(), isFalse);
      expect(appels, isEmpty);
    });

    test('push rend 0 et list une liste vide', () async {
      expect(await ICloudBackupService.push(const ['/tmp/a.json'], keep: 5), 0);
      expect(await ICloudBackupService.list(), isEmpty);
      expect(appels, isEmpty);
    });

    test('pull rend null', () async {
      expect(await ICloudBackupService.pull('a.json', '/tmp/a.json'), isNull);
      expect(appels, isEmpty);
    });
  });
}
