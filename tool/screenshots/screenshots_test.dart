// Generateur des captures d'ecran App Store, avec une classe FICTIVE.
//
//   flutter test tool/screenshots/screenshots_test.dart
//
// Ecrit store/captures/<appareil>/NN_<ecran>.png aux tailles exigees par
// Apple. Hors du dossier test/ : ne tourne jamais dans le CI. Polices : celles
// de Windows (Segoe UI) a la place de la police systeme Apple, et les icones
// Material du SDK Flutter.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/main.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Device {
  const Device(this.folder, this.physical, this.ratio, this.platform);
  final String folder;
  final Size physical;
  final double ratio;
  final TargetPlatform platform;
}

const devices = [
  Device('iphone_6.9', Size(1320, 2868), 3, TargetPlatform.iOS),
  Device('ipad_13', Size(2064, 2752), 2, TargetPlatform.iOS),
  Device('mac', Size(2880, 1800), 2, TargetPlatform.macOS),
];

const _prenoms = [
  ('Léa', 'Martin'), ('Noah', 'Bernard'), ('Jade', 'Petit'), ('Louis', 'Durand'),
  ('Emma', 'Leroy'), ('Gabriel', 'Moreau'), ('Alice', 'Simon'), ('Raphaël', 'Laurent'),
  ('Rose', 'Michel'), ('Arthur', 'Garcia'), ('Chloé', 'David'), ('Hugo', 'Bertrand'),
  ('Lina', 'Roux'), ('Jules', 'Vincent'), ('Mila', 'Fournier'), ('Adam', 'Morel'),
];
const _couleurs = ['#4E9F3D', '#E67E22', '#3498DB', '#9B59B6', '#E74C3C', '#16A085'];

const _notes = [
  'A reconnu toutes les couleurs sans aide.',
  'Très concentré, a terminé l\'atelier seul.',
  'Besoin d\'un appui sur la tenue du crayon.',
  'A expliqué sa démarche à un camarade.',
  'Progrès nets depuis la semaine dernière.',
];

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  const win = r'C:\Windows\Fonts';
  final segoe = ['$win\\segoeui.ttf', '$win\\seguisb.ttf', '$win\\segoeuib.ttf'];
  // Emojis des ateliers : repli du theme active seulement pour les captures.
  await _font('Segoe UI Emoji', ['$win\\seguiemj.ttf']);
  // ignore: invalid_use_of_visible_for_testing_member (outil hors de test/)
  debugThemeFontFallback = const ['Segoe UI Emoji'];
  // L'app demande « Outfit » (police systeme en pratique) ; certains
  // composants utilisent les polices systeme Apple : Segoe UI s'en approche.
  for (final family in [
    'Outfit',
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF UI Text',
    '.SF UI Display',
    '.SF Pro Text',
    '.SF Pro Display',
    '.AppleSystemUIFont',
  ]) {
    await _font(family, segoe);
  }
  await _font('MaterialIcons', [
    '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter'}'
        r'\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ]);
}

/// Classe fictive : 16 eleves, quelques semaines d'observations.
Future<void> _demoClass(AppStateProvider app) async {
  app.updateClassSettings(app.classSettings.copyWith(
    name: 'Classe des Lucioles',
    teacher: 'Mme Dupont',
    atsem: 'Mme Rivière',
    schoolName: 'École des Tilleuls',
  ));
  final sections = app.sections.isEmpty ? ['MS'] : app.sections;
  final rnd = Random(7);
  for (var i = 0; i < _prenoms.length; i++) {
    final (prenom, nom) = _prenoms[i];
    app.addOrUpdateChild(Child(
      id: 'demo_$i',
      firstname: prenom,
      lastname: nom,
      birthdate: '2021-0${1 + i % 9}-1${i % 9}',
      group: sections[i % sections.length],
      colorHex: _couleurs[i % _couleurs.length],
      avatarText: '${prenom[0]}${nom[0]}',
      imageAuthorized: true,
    ));
  }
  final types = app.activityTypes;
  final statuses = app.evaluationStatuses;
  final now = DateTime.now();
  var n = 0;
  for (var day = 0; day < 20; day++) {
    for (var k = 0; k < 6; k++) {
      final child = rnd.nextInt(_prenoms.length);
      app.logActivity(ActivityLog(
        id: 'demo_log_${n++}',
        childId: 'demo_$child',
        activityTypeId: types[rnd.nextInt(types.length)].id,
        timestamp: now.subtract(Duration(days: day, hours: rnd.nextInt(5))),
        evaluationStatusId: statuses.isEmpty ? null : statuses[rnd.nextInt(statuses.length)].id,
        note: rnd.nextInt(3) == 0 ? _notes[rnd.nextInt(_notes.length)] : null,
      ));
    }
  }
  app.setBiometricLockEnabled(false);
}

/// PNG sans canal alpha (l'App Store refuse la transparence) a partir de
/// pixels RGBA ; le fond de l'app est opaque, l'alpha est simplement retire.
Uint8List _pngRgb(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < height; y++) {
    final line = Uint8List(1 + width * 3); // filtre 0 puis R, V, B
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      line.setRange(1 + x * 3, 4 + x * 3, rgba, i);
    }
    raw.add(line);
  }
  Uint8List chunk(String type, List<int> data) {
    final body = Uint8List.fromList([...type.codeUnits, ...data]);
    final out = BytesBuilder()
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc32(body)));
    return out.toBytes();
  }

  final header = BytesBuilder()
    ..add(_u32(width))
    ..add(_u32(height))
    ..add([8, 2, 0, 0, 0]); // 8 bits, RVB, compression/filtre/entrelacement standard
  return (BytesBuilder()
        ..add([137, 80, 78, 71, 13, 10, 26, 10])
        ..add(chunk('IHDR', header.toBytes()))
        ..add(chunk('IDAT', ZLibEncoder(level: 6).convert(raw.toBytes())))
        ..add(chunk('IEND', const [])))
      .toBytes();
}

List<int> _u32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _loadFonts();
  });

  for (final device in devices) {
    testWidgets('captures ${device.folder}', (tester) async {
      // ignore: invalid_use_of_visible_for_testing_member (outil hors de test/)
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = device.platform;
      // Les tests remplacent les ombres par des traits noirs : vraies ombres ici.
      debugDisableShadows = false;
      tester.view.physicalSize = device.physical;
      tester.view.devicePixelRatio = device.ratio;
      addTearDown(tester.view.reset);

      final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('captures_'));
      final app = AppStateProvider(
        database: AppDatabase(fileName: 'captures_${device.folder}_${DateTime.now().microsecondsSinceEpoch}.db'),
        documentsPath: dir!.path,
        autoLoad: false,
      );
      await tester.runAsync(() async {
        await app.initialize();
        await _demoClass(app);
        await Future<void>.delayed(const Duration(milliseconds: 300)); // ecritures en base
      });

      // Lecteur des notes vocales (fiche eleve) : pas de plugin audio en test.
      // Chaque lecteur cree a son propre canal d'evenements, simule a la volee.
      final messenger = tester.binding.defaultBinaryMessenger;
      void silentEvents(String channel) => messenger.setMockStreamHandler(
          EventChannel(channel), MockStreamHandler.inline(onListen: (_, __) {}));
      silentEvents('xyz.luan/audioplayers.global/events');
      // Enregistreur des notes vocales (fiche eleve).
      messenger.setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'), (_) async => null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
      messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'),
          (call) async {
        if (call.method == 'create') {
          silentEvents('xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}');
        }
        return null;
      });

      const root = Key('captures');
      await tester.pumpWidget(RepaintBoundary(
        key: root,
        child: ChangeNotifierProvider<AppStateProvider>.value(
          value: app,
          child: const PetitPasApp(),
        ),
      ));
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      }

      var index = 0;
      // Capture a la densite de l'appareil (matchesGoldenFile ecrit en
      // pixels logiques, trop petit pour l'App Store).
      Future<void> shot(String name) async {
        await settle();
        index++;
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(root));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: device.ratio);
          final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final file = File(
              'store/captures/${device.folder}/${index.toString().padLeft(2, '0')}_$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(_pngRgb(rgba!.buffer.asUint8List(), image.width, image.height));
        });
      }

      Future<void> open(String label) async {
        await tester.tap(find.text(label).last);
        await settle();
      }

      await shot('accueil');
      await open('Élèves');
      await shot('eleves');
      await tester.tap(find.textContaining('Léa').first);
      await shot('fiche_eleve');
      // Retour : bouton Material ou Cupertino selon la plateforme simulee.
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await settle();
      await open('Badges QR');
      await shot('badges_qr');
      await open('Accueil');
      await tester.tap(find.text('Statistiques').first);
      await shot('statistiques');

      // A remettre avant la fin du test (verifie par le framework).
      debugDefaultTargetPlatformOverride = null;
      debugDisableShadows = true;
    });
  }
}
