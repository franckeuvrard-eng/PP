import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/class_settings.dart';
import 'package:petitpas/models/space.dart';

void main() {
  group('copyWith', () {
    final child = Child(
      id: 'c1',
      firstname: 'Léo',
      lastname: 'Martin',
      group: 'PS',
      notes: 'Allergie',
      colorHex: '#4E9F3D',
      avatarText: 'LM',
      email: 'p@example.com',
      imagePath: 'profiles/leo.jpg',
    );

    test('ne touche pas aux champs non fournis', () {
      final copie = child.copyWith(group: 'MS');

      expect(copie.group, 'MS');
      // Le motif qui effacait l'illustration d'un atelier : un champ oublie
      // lors d'une recopie manuelle.
      expect(copie.imagePath, 'profiles/leo.jpg');
      expect(copie.notes, 'Allergie');
      expect(copie.email, 'p@example.com');
      expect(copie.lastname, 'Martin');
    });

    test('un null explicite vide bien le champ', () {
      final copie = child.copyWith(imagePath: null, notes: null);

      expect(copie.imagePath, isNull);
      expect(copie.notes, isNull);
      expect(copie.firstname, 'Léo');
    });

    test('sur ActivityType, preserve photos et legendes', () {
      final atelier = ActivityType(
        id: 'a1',
        name: 'Peinture',
        spaceId: 's1',
        colorHex: '#FF7043',
        imagePath: 'ateliers/couv.jpg',
        photoPaths: const ['ateliers/1.jpg'],
        photoCaptions: const {'ateliers/1.jpg': 'Le geste'},
        obligatoryGroups: const ['PS'],
      );

      final copie = atelier.copyWith(name: 'Peinture libre');

      expect(copie.name, 'Peinture libre');
      expect(copie.imagePath, 'ateliers/couv.jpg');
      expect(copie.photoPaths, ['ateliers/1.jpg']);
      expect(copie.photoCaptions['ateliers/1.jpg'], 'Le geste');
      expect(copie.obligatoryGroups, ['PS']);
    });
  });

  group('sérialisation', () {
    test('Child survit à un aller-retour', () {
      final child = Child(
        id: 'c1',
        firstname: 'Chloé',
        lastname: 'Dubois',
        birthdate: '2023-09-05',
        group: 'Groupe Jaune',
        colorHex: '#FFA726',
        avatarText: 'CD',
      );

      final relu = Child.fromMap(child.toMap());

      expect(relu.firstname, 'Chloé');
      expect(relu.birthdate, '2023-09-05');
      expect(relu.group, 'Groupe Jaune');
      expect(relu.lastname, 'Dubois');
    });

    test('ActivityType survit à un aller-retour, champs récents compris', () {
      final atelier = ActivityType(
        id: 'a1',
        name: 'Tri',
        spaceId: 's4',
        colorHex: '#00BCD4',
        domaine: 'Acquérir les premiers outils mathématiques',
        domaineId: 'maths',
        iconName: 'calcul',
        photoPaths: const ['ateliers/2.jpg'],
        photoCaptions: const {'ateliers/2.jpg': 'Collections'},
        isObligatory: true,
        obligatoryGroups: const ['MS', 'GS'],
      );

      final relu = ActivityType.fromMap(atelier.toMap());

      expect(relu.domaineId, 'maths');
      expect(relu.iconName, 'calcul');
      expect(relu.photoCaptions['ateliers/2.jpg'], 'Collections');
      expect(relu.obligatoryGroups, ['MS', 'GS']);
      expect(relu.isObligatory, isTrue);
    });

    test('ActivityLog conserve identifiant de niveau et légendes', () {
      final log = ActivityLog(
        id: 'l1',
        childId: 'c1',
        activityTypeId: 'a1',
        timestamp: DateTime(2026, 3, 14, 10, 30),
        note: 'A réussi seul',
        photoPaths: const ['activities/1.jpg'],
        photoCaptions: const {'activities/1.jpg': 'Le résultat'},
        evaluationStatusId: 'acquis',
      );

      final relu = ActivityLog.fromMap(log.toMap());

      expect(relu.evaluationStatusId, 'acquis');
      expect(relu.captionFor('activities/1.jpg'), 'Le résultat');
      expect(relu.timestamp, DateTime(2026, 3, 14, 10, 30));
    });

    test('une ancienne observation expose son libellé hérité', () {
      final relu = ActivityLog.fromMap({
        'id': 'l1',
        'childId': 'c1',
        'activityTypeId': 'a1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'evaluationStatus': 'Acquis 🟢',
      });

      expect(relu.evaluationStatusId, isNull);
      expect(relu.legacyStatusLabel, 'Acquis 🟢');
    });

    test('Space et ClassSettings survivent à un aller-retour', () {
      final space = Space(id: 's1', name: 'Coin lecture', colorHex: '#7E57C2', iconName: 'livre');
      expect(Space.fromMap(space.toMap()).iconName, 'livre');

      final settings = ClassSettings(
        name: 'PS A',
        teacher: 'Mme Dupont',
        level: 'PS',
        schoolYear: '2026-2027',
        atsem: 'M. Bernard',
      );
      expect(ClassSettings.fromMap(settings.toMap()).atsem, 'M. Bernard');
    });
  });

  group('ateliers obligatoires', () {
    ActivityType atelier({required bool obligatoire, List<String> groupes = const []}) =>
        ActivityType(
          id: 'a1',
          name: 'Parcours',
          spaceId: 's1',
          colorHex: '#4E9F3D',
          isObligatory: obligatoire,
          obligatoryGroups: groupes,
        );

    test('non obligatoire ne concerne personne', () {
      expect(atelier(obligatoire: false).isObligatoryForGroup('PS'), isFalse);
    });

    test('sans ciblage, concerne toute la classe', () {
      final a = atelier(obligatoire: true);
      expect(a.isObligatoryForGroup('PS'), isTrue);
      expect(a.isObligatoryForGroup(null), isTrue);
    });

    test('avec ciblage, ne concerne que les sections listées', () {
      final a = atelier(obligatoire: true, groupes: ['MS', 'GS']);
      expect(a.isObligatoryForGroup('MS'), isTrue);
      expect(a.isObligatoryForGroup('PS'), isFalse);
      expect(a.isObligatoryForGroup(null), isFalse);
    });
  });

  test('allPhotoPaths place l\'illustration en tête', () {
    final a = ActivityType(
      id: 'a1',
      name: 'Peinture',
      spaceId: 's1',
      colorHex: '#FF7043',
      imagePath: 'ateliers/couv.jpg',
      photoPaths: const ['ateliers/1.jpg', 'ateliers/2.jpg'],
    );

    expect(a.allPhotoPaths, ['ateliers/couv.jpg', 'ateliers/1.jpg', 'ateliers/2.jpg']);
  });

  test('une légende vide est traitée comme absente', () {
    final a = ActivityType(
      id: 'a1',
      name: 'Peinture',
      spaceId: 's1',
      colorHex: '#FF7043',
      photoCaptions: const {'p.jpg': '   '},
    );

    expect(a.captionFor('p.jpg'), isNull);
  });
}
