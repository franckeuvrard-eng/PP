import 'dart:convert';


/// Niveau d'évaluation d'une observation.
///
/// L'identifiant est **stable** et c'est lui qui est enregistré dans les
/// observations. Auparavant le libellé lui-même était stocké : renommer un
/// niveau orphelinait tout l'historique déjà saisi, sans le moindre
/// avertissement — les statistiques cessaient de le compter et les couleurs
/// disparaissaient.
///
/// La couleur est portée ici plutôt que devinée depuis le texte. C'est ce qui
/// permet de se passer des emojis dans les libellés, lesquels finissaient dans
/// les exports PDF que les polices intégrées ne savent pas rendre.
class EvaluationStatus {
  final String id;
  final String label;
  final String colorHex;

  const EvaluationStatus({
    required this.id,
    required this.label,
    required this.colorHex,
  });

  /// Niveaux fournis par défaut, avec des identifiants connus : la migration
  /// des anciennes données s'y rattache par correspondance de libellé.
  static const List<EvaluationStatus> defaults = [
    EvaluationStatus(id: 'non_acquis', label: 'Non acquis', colorHex: '#D32F2F'),
    EvaluationStatus(id: 'en_cours', label: 'En cours', colorHex: '#F9A825'),
    EvaluationStatus(id: 'acquis', label: 'Acquis', colorHex: '#388E3C'),
  ];

  /// Compare deux intitulés sans tenir compte des emojis, de la casse ni des
  /// accents : « Acquis 🟢 » et « acquis » désignent le même niveau.
  ///
  /// Sert à rattacher les données antérieures aux identifiants stables.
  static String normalizeLabel(String label) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    var out = label.toLowerCase();
    accents.forEach((k, v) => out = out.replaceAll(k, v));
    return out.replaceAll(RegExp(r'[^a-z0-9 ]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Fabrique un niveau à partir d'un intitulé historique.
  ///
  /// Reprend l'identifiant et la couleur d'un niveau par défaut quand
  /// l'intitulé correspond, tout en conservant le texte de l'enseignant.
  /// Sinon, crée un niveau dédié : aucune évaluation ne doit être perdue.
  static EvaluationStatus fromLegacyLabel(String label, int index) {
    final normalized = normalizeLabel(label);
    for (final d in defaults) {
      if (normalizeLabel(d.label) == normalized) {
        return d.copyWith(label: label.trim());
      }
    }
    return EvaluationStatus(
      id: 'statut_${index}_${normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      label: label.trim(),
      colorHex: '#1976D2',
    );
  }

  EvaluationStatus copyWith({
    String? id,
    String? label,
    String? colorHex,
  }) {
    return EvaluationStatus(
      id: id ?? this.id,
      label: label ?? this.label,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'colorHex': colorHex,
      };

  factory EvaluationStatus.fromMap(Map<String, dynamic> map) => EvaluationStatus(
        id: map['id'] ?? '',
        label: map['label'] ?? '',
        colorHex: map['colorHex'] ?? '#1976D2',
      );

  String toJson() => json.encode(toMap());
  factory EvaluationStatus.fromJson(String source) =>
      EvaluationStatus.fromMap(json.decode(source));
}
