# Référentiel Éduscol

`lib/data/eduscol_data.dart` est généré à partir du programme officiel.

Source actuelle (cycle 1) : « Programme d'enseignement - École maternelle »,
Éduscol, d'après le BO n° 41 du 31 octobre 2024 et le BO n° 19 du 7 mai 2026 :
https://eduscol.education.gouv.fr/sites/default/files/document/programme-cycle-1-consolide-127565.pdf

Régénérer (Python 3 + `pip install pymupdf`) :

    python tool/eduscol/parse_programme_c1.py programme-cycle-1-consolide.pdf c1.json
    python tool/eduscol/gen_eduscol_data.py c1.json lib/data/eduscol_data.dart

Relire ensuite l'arborescence affichée par le premier script et lancer
`flutter test test/eduscol_data_test.dart`. Ne jamais renommer ni retirer un
identifiant de domaine : ils sont enregistrés sur les ateliers (voir l'en-tête
du fichier généré).
