/// Conversion des anciens espaces « mode progression » (versions <= 1.4) en
/// progressions, sur des donnees au format « sauvegarde » (cle -> liste de
/// Map). Fonction pure : la meme sert a la base locale, aux sauvegardes
/// restaurees, a l'ancien fichier iCloud et aux donnees recues en Wi-Fi.
///
/// Deterministe : la progression reprend l'identifiant de l'espace qu'elle
/// remplace. Deux appareils qui migrent chacun de leur cote produisent donc
/// exactement les memes donnees, et la synchronisation les fusionne sans
/// conflit.
///
/// Pour chaque espace en mode progression :
///  - une progression du meme nom, couleur, icone, description et seuil ;
///  - ses ateliers deviennent les jalons (progressionId), sans espace, dans
///    l'ordre deja regle (position) ;
///  - l'espace est retire.
/// Observations, photos et historique ne bougent pas (memes ateliers).
Map<String, dynamic> migrateSpaceProgressions(Map<String, dynamic> data) {
  final spaces = (data['spaces'] as List?) ?? const [];
  final legacy = [
    for (final s in spaces)
      if (s is Map && s['isProgression'] == true) s,
  ];
  if (legacy.isEmpty) return data;

  final ids = {for (final s in legacy) s['id'] as String};
  final existing = [
    for (final p in (data['progressions'] as List?) ?? const [])
      if (p is Map) p,
  ];
  final existingIds = {for (final p in existing) p['id']};

  final types = (data['activity_types'] as List?) ?? const [];
  return {
    ...data,
    'spaces': [
      for (final s in spaces)
        if (!(s is Map && ids.contains(s['id']))) s,
    ],
    'progressions': [
      ...existing,
      for (final s in legacy)
        if (!existingIds.contains(s['id']))
          <String, dynamic>{
            'id': s['id'],
            'name': s['name'] ?? '',
            'colorHex': s['colorHex'] ?? '#4E9F3D',
            'iconName': s['iconName'],
            'description': s['description'],
            'minStatusId': s['progressionMinStatusId'],
          },
    ],
    'activity_types': [
      for (final t in types)
        if (t is Map && ids.contains(t['spaceId']))
          <String, dynamic>{...t, 'progressionId': t['spaceId'], 'spaceId': ''}
        else
          t,
    ],
  };
}

/// Vrai si [data] contient encore des espaces en mode progression.
bool needsProgressionMigration(Map<String, dynamic> data) =>
    ((data['spaces'] as List?) ?? const []).any((s) => s is Map && s['isProgression'] == true);
