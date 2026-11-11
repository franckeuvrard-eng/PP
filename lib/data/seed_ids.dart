/// Identifiants des eleves et observations d'exemple crees a l'installation
/// (AppStateProvider, valeurs initiales). Doivent rester alignes : verifie
/// par test/cloud_sync_controller_test.dart.
///
/// Sert a reconnaitre un appareil neuf, qui n'a rien saisi lui-meme : a sa
/// premiere synchronisation iCloud, ses exemples ne doivent pas entrer en
/// conflit avec les vraies donnees deja dans iCloud.
const kSeedChildIds = {'child_1', 'child_2', 'child_3', 'child_4'};
const kSeedActivityIds = {'log_1', 'log_2'};
