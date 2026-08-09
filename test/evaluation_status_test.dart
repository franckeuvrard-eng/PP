import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/models/evaluation_status.dart';

void main() {
  group('normalizeLabel', () {
    test('ignore emojis, casse et accents', () {
      expect(EvaluationStatus.normalizeLabel('Acquis 🟢'), 'acquis');
      expect(EvaluationStatus.normalizeLabel('acquis'), 'acquis');
      expect(EvaluationStatus.normalizeLabel('ACQUIS'), 'acquis');
      expect(EvaluationStatus.normalizeLabel('En cours 🟡'), 'en cours');
      expect(EvaluationStatus.normalizeLabel('À revoir'), 'a revoir');
    });

    test('ne confond pas « acquis » et « non acquis »', () {
      expect(
        EvaluationStatus.normalizeLabel('Non acquis 🔴'),
        isNot(EvaluationStatus.normalizeLabel('Acquis 🟢')),
      );
    });
  });

  group('fromLegacyLabel', () {
    test('rattache un libellé connu à l\'identifiant par défaut', () {
      final s = EvaluationStatus.fromLegacyLabel('Acquis 🟢', 0);

      expect(s.id, 'acquis');
      expect(s.colorHex, '#388E3C');
      // Le texte de l'enseignant est conserve tel quel.
      expect(s.label, 'Acquis 🟢');
    });

    test('rattache « Non acquis » au bon identifiant, pas à « acquis »', () {
      expect(EvaluationStatus.fromLegacyLabel('Non acquis 🔴', 0).id, 'non_acquis');
      expect(EvaluationStatus.fromLegacyLabel('En cours 🟡', 1).id, 'en_cours');
    });

    test('crée un niveau dédié pour un libellé inconnu', () {
      final s = EvaluationStatus.fromLegacyLabel('À consolider', 3);

      expect(s.id, isNot(anyOf('acquis', 'en_cours', 'non_acquis')));
      expect(s.label, 'À consolider');
      expect(s.id, contains('consolider'));
    });

    test('deux libellés inconnus ne partagent pas le même identifiant', () {
      final a = EvaluationStatus.fromLegacyLabel('Découverte', 0);
      final b = EvaluationStatus.fromLegacyLabel('Maîtrisé', 1);

      expect(a.id, isNot(b.id));
    });
  });

  test('copyWith conserve l\'identifiant, c\'est tout le principe', () {
    const s = EvaluationStatus(id: 'acquis', label: 'Acquis', colorHex: '#388E3C');
    final renomme = s.copyWith(label: 'Maîtrisé');

    // Renommer ne doit pas orpheliner les observations deja enregistrees.
    expect(renomme.id, 'acquis');
    expect(renomme.label, 'Maîtrisé');
  });

  test('sérialisation aller-retour', () {
    const s = EvaluationStatus(id: 'en_cours', label: 'En cours', colorHex: '#F9A825');
    final relu = EvaluationStatus.fromMap(s.toMap());

    expect(relu.id, 'en_cours');
    expect(relu.label, 'En cours');
    expect(relu.colorHex, '#F9A825');
  });
}
