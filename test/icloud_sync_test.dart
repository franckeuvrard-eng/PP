import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/services/icloud_sync.dart';
import 'package:petitpas/services/sync_merge.dart';
import 'package:petitpas/services/sync_service.dart';

import 'support/sync_fakes.dart';

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
}

List<String> ids(FakeHost h) => [for (final c in h.data['children'] as List) c['id'] as String];

Map<String, dynamic> child(String id, [String name = '']) =>
    {'id': id, 'firstname': name.isEmpty ? id : name};

void main() {
  late FakeCloud cloud;
  late FakeHost mac;
  late FakeHost phone;
  CloudSync on(FakeHost h) => CloudSync(h, cloud);

  setUp(() {
    cloud = FakeCloud();
    mac = FakeHost('mac', snap([child('a')]));
    phone = FakeHost('phone', snap([child('b')]));
  });

  test('deux appareils se retrouvent via iCloud', () async {
    expect((await on(mac).sync()).status, CloudSyncStatus.synced);
    expect((await on(phone).sync()).status, CloudSyncStatus.synced);
    expect(ids(phone), unorderedEquals(['a', 'b']));
    expect((await on(mac).sync()).status, CloudSyncStatus.synced);
    expect(ids(mac), unorderedEquals(['a', 'b']));
    expect((await on(mac).sync()).status, CloudSyncStatus.upToDate);
  });

  test('iCloud indisponible : rien n\'est touche', () async {
    cloud.available = false;
    expect((await on(mac).sync()).status, CloudSyncStatus.unavailable);
    expect(cloud.files, isEmpty);
    expect(ids(mac), ['a']);
  });

  test('une suppression isolee se propage, une suppression massive attend un accord', () async {
    mac.data = snap([for (var i = 0; i < 10; i++) child('e$i')]);
    await on(mac).sync();
    await on(phone).sync();

    phone.data = snap([for (final c in phone.data['children'] as List) if (c['id'] != 'e0') c]);
    await on(phone).sync();
    await on(mac).sync();
    expect(ids(mac), isNot(contains('e0')));

    // L'iPhone vide tout (sans remise a zero) : rien ne part sans accord.
    phone.data = snap([]);
    final auto = await on(phone).sync();
    expect(auto.status, CloudSyncStatus.needsConfirmation);
    await on(mac).sync();
    expect(ids(mac), hasLength(10), reason: 'le Mac ne doit rien perdre sans accord');

    // Refus explicite : toujours rien.
    final refused = await on(phone).sync(confirmChanges: (_) async => false);
    expect(refused.status, CloudSyncStatus.error);
    await on(mac).sync();
    expect(ids(mac), hasLength(10));
  });

  test('appareil remis a zero : re-rempli depuis iCloud, les autres intacts', () async {
    await on(mac).sync();
    await on(phone).sync();
    await on(mac).sync();

    phone.data = snap([]);
    phone.bases.clear(); // ce que fait la remise a zero de l'app
    expect((await on(phone).sync()).status, CloudSyncStatus.synced);
    expect(ids(phone), unorderedEquals(['a', 'b']));
    await on(mac).sync();
    expect(ids(mac), unorderedEquals(['a', 'b']));
  });

  test('meme champ modifie des deux cotes : choix demande, rien ecrit en automatique', () async {
    await on(mac).sync();
    await on(phone).sync();
    mac.data = snap([child('a', 'Alice'), child('b')]);
    phone.data = snap([child('a', 'Alicia'), child('b')]);
    await on(mac).sync();

    final auto = await on(phone).sync();
    expect(auto.status, CloudSyncStatus.needsResolution);
    expect((phone.data['children'] as List).first['firstname'], 'Alicia');

    final chosen = await on(phone).sync(
        resolveConflicts: (c, _, __) async => {c.single.id: c.single.combine({'firstname'})});
    expect(chosen.status, CloudSyncStatus.synced);
    expect((phone.data['children'] as List).first['firstname'], 'Alice');
  });

  test('photos : envoyees puis recuperees, seules celles utilisees voyagent', () async {
    mac.data = snap([{...child('a'), 'imagePath': 'profiles/a.jpg'}]);
    mac.media['profiles/a.jpg'] = Uint8List.fromList([1, 2, 3]);
    mac.media['profiles/orpheline.jpg'] = Uint8List.fromList([9]);
    await on(mac).sync();
    expect(cloud.files.keys, contains('medias/profiles/a.jpg'));
    expect(cloud.files.keys, isNot(contains('medias/profiles/orpheline.jpg')));

    final r = await on(phone).sync();
    expect(r.summary!.mediaDownloaded, 1);
    expect(phone.media['profiles/a.jpg'], [1, 2, 3]);
  });

  test('sauvegarde avant de modifier l\'appareil ; echec = rien d\'ecrit', () async {
    await on(mac).sync();
    phone.backupFails = true;
    final r = await on(phone).sync();
    expect(r.status, CloudSyncStatus.error);
    expect(ids(phone), ['b']);
    phone.backupFails = false;
    await on(phone).sync();
    expect(phone.backups, 1);
  });

  test('ecriture d\'un autre appareil pendant la synchro : on recommence plus tard', () async {
    await on(mac).sync();
    var reads = 0;
    cloud.beforeRead = () {
      // 2e lecture du fichier de classe = verification juste avant d'ecrire.
      if (++reads == 2) cloud.files[CloudSync.classFile] = Uint8List.fromList([123, 125]);
    };
    final r = await on(phone).sync();
    expect(r.status, CloudSyncStatus.retryLater);
    expect(ids(phone), ['b'], reason: 'rien applique localement');
  });

  test('le compte rendu indique le detail des changements', () async {
    await on(mac).sync();
    final r = await on(phone).sync();
    final here = r.summary!.changes.where((c) => c.onLocal && c.kind == ChangeKind.added);
    expect(here.map((c) => c.key), contains('a'));
    expect(r.summary!.peerName, 'iCloud');
    expect(kSyncGenerationKey, isNotEmpty);
  });
}
