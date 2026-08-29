import 'package:flutter/material.dart';
import '../models/school_year_archive.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';

/// Carte « Année scolaire » : archive l'année écoulée puis repart à vide.
///
/// Doublonne volontairement la RAZ selective voisine : celle-ci efface sans
/// filet, alors que le passage a l'annee suivante garantit qu'une archive
/// complete existe sur le disque avant que quoi que ce soit ne disparaisse.
class SchoolYearCard extends StatefulWidget {
  const SchoolYearCard({super.key, required this.provider});

  final AppStateProvider provider;

  @override
  State<SchoolYearCard> createState() => _SchoolYearCardState();
}

class _SchoolYearCardState extends State<SchoolYearCard> {
  List<SchoolYearArchive> _archives = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final archives = await widget.provider.listArchives();
    if (!mounted) return;
    setState(() => _archives = archives);
  }

  void _toast(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF4E9F3D) : Colors.red,
      ),
    );
  }

  static String _anneeSuivante(String annee) {
    // « 2026-2027 » -> « 2027-2028 ». Toute autre forme est laissee a
    // l'enseignante : mieux vaut un champ a corriger qu'une annee fausse.
    final match = RegExp(r'^(\d{4})\s*[-/]\s*(\d{4})$').firstMatch(annee.trim());
    if (match == null) return '';
    return '${int.parse(match.group(1)!) + 1}-${int.parse(match.group(2)!) + 1}';
  }

  Future<void> _confirmerNouvelleAnnee() async {
    final provider = widget.provider;
    final anneeActuelle = provider.classSettings.schoolYear;
    final controller =
        TextEditingController(text: _anneeSuivante(anneeActuelle));
    final childCount = provider.children.length;
    final activityCount = provider.activities.length;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passer à l\'année suivante ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$childCount élève${childCount > 1 ? 's' : ''} et $activityCount '
              'observation${activityCount > 1 ? 's' : ''} de $anneeActuelle vont '
              'être archivés dans un fichier ZIP, puis effacés de la classe.\n\n'
              'Vos espaces, ateliers, niveaux d\'évaluation et groupes sont '
              'conservés. Si l\'archive ne peut pas être écrite, rien ne sera '
              'effacé.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nouvelle année scolaire',
                hintText: '2027-2028',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Archiver et vider'),
          ),
        ],
      ),
    );

    final nouvelleAnnee = controller.text.trim();
    controller.dispose();
    if (confirme != true) return;
    if (nouvelleAnnee.isEmpty) {
      _toast('Indiquez la nouvelle année scolaire.', success: false);
      return;
    }

    setState(() => _busy = true);
    final archive = await provider.startNewSchoolYear(nouvelleAnnee: nouvelleAnnee);
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
    _toast(
      archive == null
          ? 'Archivage impossible : aucune donnée n\'a été effacée.'
          : 'Année $anneeActuelle archivée. Bonne rentrée !',
      success: archive != null,
    );
  }

  Future<void> _partager(SchoolYearArchive archive) async {
    final ok = await widget.provider.shareArchive(archive);
    if (!ok) _toast('Fichier d\'archive introuvable sur l\'appareil.', success: false);
  }

  Future<void> _supprimer(SchoolYearArchive archive) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette archive ?'),
        content: Text(
          'L\'archive de ${archive.schoolYear} sera définitivement supprimée de '
          'l\'appareil. Si vous ne l\'avez pas partagée ailleurs, ces données '
          'seront perdues.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await widget.provider.deleteArchive(archive);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final annee = widget.provider.classSettings.schoolYear;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school_outlined, color: Color(0xFF4E9F3D)),
                SizedBox(width: 8),
                Text('Année scolaire',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Année en cours : $annee. À la rentrée, archivez l\'année écoulée '
              '(données et photos) puis repartez sur une classe vide en '
              'conservant vos espaces et ateliers.',
              style: const TextStyle(fontSize: 12, color: kMutedTextColor),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _confirmerNouvelleAnnee,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Passer à l\'année suivante'),
            ),
            if (_archives.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Années archivées',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ..._archives.map((archive) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_zip_outlined),
                    title: Text(archive.schoolYear,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${archive.childCount} élèves · ${archive.activityCount} '
                      'observations · ${(archive.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Partager',
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => _partager(archive),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _supprimer(archive),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
