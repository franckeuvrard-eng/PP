import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/services/sync_merge.dart';
import 'package:petitpas/services/sync_report.dart';
import 'package:petitpas/services/sync_service.dart';

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

void main() {
  const alice = {'id': 'a', 'name': 'Alice'};
  const bob = {'id': 'b', 'name': 'Bob'};

  group('lanAddressScore', () {
    test('le Wi-Fi passe devant les interfaces virtuelles', () {
      final wifi = lanAddressScore('Wi-Fi', '192.168.1.20');
      expect(wifi, greaterThan(lanAddressScore('vEthernet (WSL)', '172.24.16.1')));
      expect(wifi, greaterThan(lanAddressScore('VirtualBox Host-Only Network', '192.168.56.1')));
      expect(wifi, greaterThan(lanAddressScore('Connexion au réseau local* 2', '192.168.137.1')));
      expect(wifi, greaterThan(lanAddressScore('Tailscale', '100.64.0.3')));
    });

    test('sur iPhone, en0 passe devant les donnees mobiles et le VPN', () {
      final en0 = lanAddressScore('en0', '10.0.0.42');
      expect(en0, greaterThan(lanAddressScore('pdp_ip0', '10.120.4.7')));
      expect(en0, greaterThan(lanAddressScore('utun3', '10.8.0.2')));
      expect(en0, greaterThan(lanAddressScore('bridge100', '192.168.2.1')));
    });
  });

  group('SyncMerge', () {
    test('premiere synchronisation : union, rien n\'est perdu', () {
      final r = SyncMerge.merge(local: snap([alice]), remote: snap([bob]));
      expect((r.snapshot['children'] as List).length, 2);
      expect(r.stats.addedLocally, 1);
      expect(r.stats.addedRemotely, 1);
    });

    test('une suppression d\'un seul cote se propage', () {
      final base = SyncMerge.merge(local: snap([alice, bob]), remote: snap([alice, bob])).fingerprints;
      final r = SyncMerge.merge(local: snap([bob]), remote: snap([alice, bob]), base: base);
      expect((r.snapshot['children'] as List).map((c) => c['id']), ['b']);
      expect(r.stats.deletedRemotely, 1);
    });

    test('une modification distante seule est reprise', () {
      final base = SyncMerge.merge(local: snap([alice]), remote: snap([alice])).fingerprints;
      final r = SyncMerge.merge(
        local: snap([alice]),
        remote: snap([{'id': 'a', 'name': 'Alicia'}]),
        base: base,
      );
      expect((r.snapshot['children'] as List).first['name'], 'Alicia');
    });

    test('conflit : la version locale gagne, comptee', () {
      final base = SyncMerge.merge(local: snap([alice]), remote: snap([alice])).fingerprints;
      final r = SyncMerge.merge(
        local: snap([{'id': 'a', 'name': 'L'}]),
        remote: snap([{'id': 'a', 'name': 'R'}]),
        base: base,
      );
      expect((r.snapshot['children'] as List).first['name'], 'L');
      expect(r.stats.conflicts, 1);
    });

    test('une suppression ne l\'emporte jamais sur une modification', () {
      final base = SyncMerge.merge(local: snap([alice]), remote: snap([alice])).fingerprints;
      final r = SyncMerge.merge(
        local: snap([]),
        remote: snap([{'id': 'a', 'name': 'R'}]),
        base: base,
      );
      expect((r.snapshot['children'] as List).length, 1);
    });

    test('progression des sons fusionnee par son', () {
      final r = SyncMerge.merge(
        local: snap([alice], sons: {'a': {'s': 2}}),
        remote: snap([alice], sons: {'a': {'t': 1}}),
      );
      expect((r.snapshot['sons_progress'] as Map)['a'], {'s': 2, 't': 1});
    });

    test('idempotente : une 2e fusion ne change rien', () {
      final r = SyncMerge.merge(local: snap([alice]), remote: snap([bob]));
      final again = SyncMerge.merge(
          local: r.snapshot, remote: r.snapshot, base: r.fingerprints);
      expect(again.stats.changesLocally + again.stats.changesRemotely, 0);
    });
  });

  group('SyncServer / SyncClient', () {
    test('synchronisation complete sur le reseau local', () async {
      final mac = FakeHost('mac', snap([alice]));
      final phone = FakeHost('phone', snap([bob]));
      phone.media['profiles/b.jpg'] = Uint8List.fromList([1, 2, 3]);
      mac.media['audio/x.m4a'] = Uint8List.fromList([9]);

      final server = SyncServer(mac);
      final started = await server.start();
      addTearDown(server.stop);
      final pairing = SyncPairing(
          hosts: const ['127.0.0.1'], port: started.port, token: started.token, name: 'mac');

      final summary = await SyncClient(phone).sync(pairing);
      expect((mac.data['children'] as List).length, 2);
      expect((phone.data['children'] as List).length, 2);
      expect(mac.media.keys, contains('profiles/b.jpg'));
      expect(phone.media.keys, contains('audio/x.m4a'));
      expect(summary.mediaDownloaded, 1);
      expect(summary.mediaUploaded, 1);

      // Le Mac supprime Alice, l'iPhone renomme Bob : les deux se propagent.
      mac.data = snap([bob]);
      phone.data = snap([alice, {'id': 'b', 'name': 'Robert'}]);
      await SyncClient(phone).sync(pairing);
      expect((mac.data['children'] as List).map((c) => c['name']), ['Robert']);
      expect((phone.data['children'] as List).map((c) => c['name']), ['Robert']);
    });

    test('conflit : choix champ par champ, ou annulation sans rien modifier', () async {
      const lea = {'id': 'l', 'firstname': 'Léa', 'birthdate': '2021-03-12', 'notes': ''};
      final mac = FakeHost('mac', snap([lea]));
      final phone = FakeHost('phone', snap([lea]));
      final server = SyncServer(mac);
      final started = await server.start();
      addTearDown(server.stop);
      final pairing = SyncPairing(
          hosts: const ['127.0.0.1'], port: started.port, token: started.token, name: 'mac');
      await SyncClient(phone).sync(pairing); // etablit la base commune

      // Meme fiche modifiee des deux cotes, sur des champs differents.
      phone.data = snap([{...lea, 'birthdate': '2021-03-15'}]);
      mac.data = snap([{...lea, 'notes': 'Allergie'}]);

      List<MergeConflict>? seen;
      // Annulation : aucun des deux appareils ne change.
      await expectLater(
        SyncClient(phone).sync(pairing, resolveConflicts: (c, _, __) async {
          seen = c;
          return null;
        }),
        throwsA(isA<SyncException>()),
      );
      expect(seen!.single.differingFields.toSet(), {'birthdate', 'notes'});
      expect((mac.data['children'] as List).single['notes'], 'Allergie');
      expect((phone.data['children'] as List).single['birthdate'], '2021-03-15');

      // Date de naissance de l'iPhone, notes du Mac : les deux sont gardees.
      final summary = await SyncClient(phone).sync(pairing,
          resolveConflicts: (c, _, __) async => {c.single.id: c.single.combine({'notes'})});
      for (final host in [mac, phone]) {
        final child = (host.data['children'] as List).single as Map;
        expect(child['birthdate'], '2021-03-15');
        expect(child['notes'], 'Allergie');
      }
      expect(summary.conflicts, 1);
    });

    test('accord de l\'appareil qui recoit : refus, puis acceptation memorisee', () async {
      final mac = FakeHost('mac', snap([alice]));
      final phone = FakeHost('phone', snap([bob]));
      final asked = <String>[];
      var answer = false;
      final server = SyncServer(mac)
        ..onConsentRequest = (name) async {
          asked.add(name);
          return answer;
        };
      final started = await server.start();
      addTearDown(server.stop);
      final pairing = SyncPairing(
          hosts: const ['127.0.0.1'], port: started.port, token: started.token, name: 'mac');

      await expectLater(SyncClient(phone).sync(pairing), throwsA(isA<SyncException>()));
      expect(asked, ['appareil-phone']);
      expect((mac.data['children'] as List).length, 1);
      expect((phone.data['children'] as List).length, 1);

      answer = true;
      await SyncClient(phone).sync(pairing);
      await SyncClient(phone).sync(pairing); // deja accepte : pas de nouvelle question
      expect(asked.length, 2);
      expect((mac.data['children'] as List).length, 2);
    });

    test('sans accord, les donnees ne sont pas lisibles meme avec le jeton', () async {
      final mac = FakeHost('mac', snap([alice]));
      final server = SyncServer(mac);
      final started = await server.start();
      addTearDown(server.stop);
      final c = HttpClient();
      addTearDown(() => c.close(force: true));
      final req = await c.getUrl(Uri.parse('http://127.0.0.1:${started.port}/snapshot'));
      req.headers.set('authorization', 'Bearer ${started.token}');
      final res = await req.close();
      await res.drain<void>();
      expect(res.statusCode, 403);
    });

    test('sauvegarde impossible d\'un cote ou de l\'autre : rien n\'est modifie', () async {
      final mac = FakeHost('mac', snap([alice]));
      final phone = FakeHost('phone', snap([bob]));
      final server = SyncServer(mac);
      final started = await server.start();
      addTearDown(server.stop);
      final pairing = SyncPairing(
          hosts: const ['127.0.0.1'], port: started.port, token: started.token, name: 'mac');

      for (final failing in [phone, mac]) {
        failing.backupFails = true;
        await expectLater(SyncClient(phone).sync(pairing), throwsA(isA<SyncException>()));
        failing.backupFails = false;
        expect((mac.data['children'] as List).map((c) => c['id']), ['a']);
        expect((phone.data['children'] as List).map((c) => c['id']), ['b']);
      }

      await SyncClient(phone).sync(pairing);
      expect(mac.backups, 1);
      expect(phone.backups, 2); // une par tentative arrivee jusqu'a l'echec du Mac, puis la bonne
    });

    test('compte rendu detaille sur les deux appareils', () async {
      const lea = {'id': 'l', 'firstname': 'Léa', 'lastname': 'Martin'};
      const tom = {'id': 't', 'firstname': 'Tom', 'lastname': 'Petit'};
      final mac = FakeHost('mac', snap([lea]));
      final phone = FakeHost('phone', snap([tom]));
      SyncSummary? received;
      final server = SyncServer(mac)..onSynced = (s) => received = s;
      final started = await server.start();
      addTearDown(server.stop);

      final summary = await SyncClient(phone).sync(SyncPairing(
          hosts: const ['127.0.0.1'], port: started.port, token: started.token, name: 'mac'));

      List<String> labels(SyncSummary s, {required bool here}) => [
            for (final g in SyncReport.build(s.changes, onLocal: here, snapshot: s.snapshot))
              for (final l in g.lines) '${g.title}:${l.kind.name}:${l.label}',
          ];
      // L'iPhone recoit Lea, le Mac recoit Tom ; chacun le voit de son cote.
      expect(labels(summary, here: true), ['Élèves:added:Léa Martin']);
      expect(labels(summary, here: false), ['Élèves:added:Tom Petit']);
      expect(received, isNotNull);
      expect(received!.peerName, 'appareil-phone');
      expect(labels(received!, here: true), ['Élèves:added:Tom Petit']);
      expect(labels(received!, here: false), ['Élèves:added:Léa Martin']);
    });

    test('jeton invalide refuse, serveur arrete injoignable', () async {
      final mac = FakeHost('mac', snap([alice]));
      final phone = FakeHost('phone', snap([bob]));
      final server = SyncServer(mac);
      final started = await server.start();

      await expectLater(
        SyncClient(phone).sync(SyncPairing(
            hosts: const ['127.0.0.1'], port: started.port, token: 'faux', name: '')),
        throwsA(isA<SyncException>()),
      );
      expect((mac.data['children'] as List).length, 1);

      await server.stop();
      await expectLater(
        SyncClient(phone).sync(SyncPairing(
            hosts: const ['127.0.0.1'], port: started.port, token: started.token, name: '')),
        throwsA(isA<SyncException>()),
      );
    });

    test('chemins de medias : seuls dossier/fichier autorises', () {
      expect(isSafeMediaPath('profiles/a.jpg'), isTrue);
      expect(isSafeMediaPath('../a.jpg'), isFalse);
      expect(isSafeMediaPath('profiles/../a'), isFalse);
      expect(isSafeMediaPath('etc/passwd'), isFalse);
      expect(isSafeMediaPath('profiles/..'), isFalse);
    });

    test('code d\'appairage : aller-retour et rejet des QR etrangers', () {
      const p = SyncPairing(hosts: ['10.0.0.2'], port: 1234, token: 'abc', name: 'Mac');
      final back = SyncPairing.decode(p.encode())!;
      expect(back.hosts, ['10.0.0.2']);
      expect(back.port, 1234);
      expect(SyncPairing.decode('PETITPAS:CHILD:1'), isNull);
    });
  });
}
