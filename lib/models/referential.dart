import 'dart:convert';

import '../data/sons_data.dart' show SonStatut;

/// Un item individuel d'un referentiel personnalise (ex: une couleur de
/// ceinture, un materiel Montessori).
class ReferentialItem {
  final String id;
  final String label;

  const ReferentialItem({required this.id, required this.label});

  Map<String, dynamic> toMap() => {'id': id, 'label': label};

  factory ReferentialItem.fromMap(Map<String, dynamic> map) => ReferentialItem(
        id: map['id'] ?? '',
        label: map['label'] ?? '',
      );
}

/// Un regroupement d'items au sein d'un referentiel (ex: "Vie pratique" pour
/// une base Montessori).
class ReferentialGroup {
  final String id;
  final String title;
  final List<ReferentialItem> items;

  const ReferentialGroup({
    required this.id,
    required this.title,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory ReferentialGroup.fromMap(Map<String, dynamic> map) => ReferentialGroup(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        items: (map['items'] as List? ?? [])
            .map((e) => ReferentialItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Un referentiel de suivi defini par l'enseignant (ceintures de couleur,
/// base Montessori, ou tout autre systeme propre a la classe).
///
/// Suit le meme principe a 3 etats que l'analyse des sons (non acquis / en
/// cours / acquis), mais le contenu (groupes et items) est entierement saisi
/// par l'enseignant : aucun referentiel pedagogique n'est fourni par defaut.
class Referential {
  final String id;
  final String name;
  final List<ReferentialGroup> groups;

  const Referential({
    required this.id,
    required this.name,
    this.groups = const [],
  });

  List<ReferentialItem> get allItems => groups.expand((g) => g.items).toList();

  Referential copyWith({String? id, String? name, List<ReferentialGroup>? groups}) {
    return Referential(
      id: id ?? this.id,
      name: name ?? this.name,
      groups: groups ?? this.groups,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'groups': groups.map((g) => g.toMap()).toList(),
      };

  factory Referential.fromMap(Map<String, dynamic> map) => Referential(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        groups: (map['groups'] as List? ?? [])
            .map((e) => ReferentialGroup.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  String toJson() => json.encode(toMap());
  factory Referential.fromJson(String source) => Referential.fromMap(json.decode(source));
}

/// Un point de l'historique d'un item de referentiel pour un eleve : son
/// statut a un instant donne. Sert au graphique de progression, comme
/// [SonHistoryEntry] pour les sons.
class ReferentialHistoryEntry {
  final String itemId;
  final SonStatut statut;
  final DateTime changedAt;

  const ReferentialHistoryEntry({
    required this.itemId,
    required this.statut,
    required this.changedAt,
  });
}
