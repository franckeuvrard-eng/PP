import 'undefined.dart';

/// Groupe de besoin : quelques eleves reunis pour retravailler la meme
/// chose (une etape de parcours, un atelier en cours...). Cree a la main ou
/// depuis une suggestion ; sert a la saisie groupee, aux rapports et au
/// planning.
class NeedGroup {
  final String id;
  final String name;
  final String colorHex;
  final List<String> childIds;

  /// D'ou vient le groupe (« Découpage · étape 2 »), ou une consigne libre.
  final String? note;
  final DateTime createdAt;

  NeedGroup({
    required this.id,
    required this.name,
    this.colorHex = '#7E57C2',
    this.childIds = const [],
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  NeedGroup copyWith({
    String? name,
    String? colorHex,
    List<String>? childIds,
    Object? note = kUndefined,
  }) =>
      NeedGroup(
        id: id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        childIds: childIds ?? this.childIds,
        note: note == kUndefined ? this.note : note as String?,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'childIds': childIds,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NeedGroup.fromMap(Map<String, dynamic> map) => NeedGroup(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        colorHex: map['colorHex'] ?? '#7E57C2',
        childIds: List<String>.from(map['childIds'] ?? const []),
        note: map['note'],
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      );
}
