import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/activity.dart';
import '../models/space.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import '../data/sons_data.dart';
import '../models/referential.dart';
import '../services/child_data_export_service.dart';
import 'atelier_history_screen.dart';
import 'ateliers_progress_screen.dart';
import 'children_manager_screen.dart' show ChildFormDialog;
import 'referential_progress_screen.dart';
import 'sons_progress_screen.dart';
import '../widgets/voice_note_play_button.dart';

class ChildProfileScreen extends StatelessWidget {
  final Child child;

  const ChildProfileScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    // Refresh child data from provider in case it was updated
    final currentChild = provider.childById(child.id) ?? child;
    final childLogs = provider.activitiesForChild(currentChild.id).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${currentChild.firstname} ${currentChild.lastname ?? ""}'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Profil'),
              Tab(icon: Icon(Icons.history), text: 'Activités'),
              Tab(icon: Icon(Icons.checklist), text: 'Acquis'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.privacy_tip_outlined),
              tooltip: 'Exporter les données (RGPD)',
              onPressed: () => ChildDataExportService.exportChild(
                context: context,
                provider: provider,
                child: currentChild,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier cet élève',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ChildFormDialog(provider: provider, child: currentChild),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Supprimer cet élève',
              onPressed: () => _confirmDelete(context, provider, currentChild),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(context, provider, currentChild, isDark),
            _buildActivitiesTab(context, provider, currentChild, childLogs, isDark),
            _buildAcquisTab(context, provider, currentChild),
          ],
        ),
      ),
    );
  }

  // ────────────── PROFILE TAB ──────────────
  Widget _buildProfileTab(BuildContext context, AppStateProvider provider, Child child, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          _buildLargeAvatar(child, provider),
          const SizedBox(height: 16),

          // Name
          Text(
            '${child.firstname} ${child.lastname ?? ""}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (child.group != null && child.group!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Chip(
                avatar: const Icon(Icons.group, size: 16),
                label: Text(child.group!),
              ),
            ),

          const SizedBox(height: 24),

          // Info Cards
          _buildInfoCard(
            context,
            icon: Icons.cake,
            label: 'Date de naissance',
            value: _formatBirthdate(child.birthdate),
            isDark: isDark,
          ),
          _buildInfoCard(
            context,
            icon: Icons.email,
            label: 'Email des parents',
            value: child.email ?? 'Non renseigné',
            isDark: isDark,
          ),
          _buildInfoCard(
            context,
            icon: Icons.notes,
            label: 'Notes',
            value: (child.notes != null && child.notes!.isNotEmpty) ? child.notes! : 'Aucune note',
            isDark: isDark,
          ),
          _buildInfoCard(
            context,
            icon: child.imageAuthorized ? Icons.image : Icons.no_photography,
            label: 'Autorisation droit à l\'image',
            value: child.imageAuthorized ? 'Accordée' : 'Non accordée — modifiable via le crayon',
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  context,
                  icon: Icons.assignment,
                  value: '${provider.activityCountForChild(child.id)}',
                  label: 'Observations totales',
                  color: const Color(0xFF4E9F3D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  context,
                  icon: Icons.today,
                  value: '${provider.activityCountForChildOn(child.id, DateTime.now())}',
                  label: "Aujourd'hui",
                  color: const Color(0xFFFF7043),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Date stockee au format ISO (aaaa-mm-jj) affichee en jj/mm/aaaa. Une
  /// valeur illisible est affichee telle quelle plutot que masquee.
  String _formatBirthdate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Non renseignée';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Widget _buildLargeAvatar(Child child, AppStateProvider provider) {
    final absolutePath = provider.getAbsolutePath(child.imagePath);
    final avatar = (absolutePath != null && File(absolutePath).existsSync())
        ? CircleAvatar(
            radius: 56,
            backgroundImage: FileImage(File(absolutePath)),
          )
        : CircleAvatar(
            radius: 56,
            backgroundColor: hexToColor(child.colorHex),
            child: Text(
              child.avatarText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
            ),
          );
    if (child.imageAuthorized) return avatar;
    return Stack(
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: Tooltip(
            message: 'Autorisation photo non accordée',
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.no_photography, size: 18, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String label, required String value, required bool isDark}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4E9F3D)),
        title: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildStatBox(BuildContext context, {required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  // ─────────────────── ACQUIS : ANALYSE DES SONS ───────────────────

  static Color _sonColor(SonStatut statut) => switch (statut) {
        SonStatut.nonAcquis => const Color(0xFFD32F2F),
        SonStatut.enCours => const Color(0xFFF9A825),
        SonStatut.acquis => const Color(0xFF388E3C),
      };

  Widget _buildAcquisTab(BuildContext context, AppStateProvider provider, Child child) {
    final tous = SonsData.tous;
    final acquis = tous.where((s) => provider.sonStatut(child.id, s) == SonStatut.acquis).length;
    final enCours = tous.where((s) => provider.sonStatut(child.id, s) == SonStatut.enCours).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Ateliers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Ateliers de la section de l\'élève, acquis / en cours / non acquis / non faits',
            style: TextStyle(fontSize: 12, color: kMutedTextColor)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AteliersProgressScreen(child: child)),
            ),
            icon: const Icon(Icons.show_chart, size: 18),
            label: const Text('Voir le suivi des ateliers'),
          ),
        ),
        const Divider(height: 32),

        const Text('Analyse des sons',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Langage · conscience phonémique & signes graphiques',
            style: TextStyle(fontSize: 12, color: kMutedTextColor)),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _sonLegende(SonStatut.acquis, '$acquis acquis'),
            _sonLegende(SonStatut.enCours, '$enCours en cours'),
            _sonLegende(SonStatut.nonAcquis, '${tous.length - acquis - enCours} non acquis'),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SonsProgressScreen(child: child)),
            ),
            icon: const Icon(Icons.show_chart, size: 18),
            label: const Text('Voir la progression dans le temps'),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Appuyez sur un son pour le faire progresser : non acquis → en cours → acquis. '
          'Appui long pour revenir en arrière.',
          style: TextStyle(fontSize: 12, color: kMutedTextColor),
        ),
        const SizedBox(height: 16),

        ...SonsData.groupes.map((groupe) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupe.titre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: groupe.sons.map((son) {
                      final statut = provider.sonStatut(child.id, son);
                      final couleur = _sonColor(statut);
                      return InkWell(
                        onTap: () => provider.cycleSonStatut(child.id, son),
                        onLongPress: () {
                          HapticFeedback.selectionClick();
                          provider.reculeSonStatut(child.id, son);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Tooltip(
                          // Sans « manual », le Tooltip enregistre son propre
                          // LongPressGestureRecognizer ; imbrique dans l'InkWell
                          // il remporte l'arene de gestes et l'appui long de
                          // retour en arriere n'etait jamais declenche. Le
                          // survol reste gere a part, donc actif sur ordinateur.
                          triggerMode: TooltipTriggerMode.manual,
                          message: '$son — ${statut.libelle}',
                          child: Container(
                            // Taille minimale plutot que fixe : a 54x54 stricts,
                            // le libelle debordait des que l'utilisateur
                            // agrandissait la police dans les reglages iOS.
                            constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: couleur.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: couleur, width: 2),
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                son,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: couleur,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            )),

        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final confirme = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Réinitialiser l\'analyse des sons ?'),
                content: Text(
                    'Tous les sons de ${child.firstname} repasseront à « non acquis ».'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
            );
            if (confirme == true) provider.resetSons(child.id);
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Tout remettre à non acquis'),
        ),

        for (final referential in provider.referentials) ...[
          const Divider(height: 40),
          _buildReferentialSection(context, provider, child, referential),
        ],
      ],
    );
  }

  // ────────────── REFERENTIELS PERSONNALISES ──────────────

  Widget _buildReferentialSection(
    BuildContext context,
    AppStateProvider provider,
    Child child,
    Referential referential,
  ) {
    final allItems = referential.allItems;
    final acquis = allItems
        .where((i) => provider.referentialItemStatut(referential.id, child.id, i.id) == SonStatut.acquis)
        .length;
    final enCours = allItems
        .where((i) => provider.referentialItemStatut(referential.id, child.id, i.id) == SonStatut.enCours)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(referential.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _sonLegende(SonStatut.acquis, '$acquis acquis'),
            _sonLegende(SonStatut.enCours, '$enCours en cours'),
            _sonLegende(SonStatut.nonAcquis, '${allItems.length - acquis - enCours} non acquis'),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReferentialProgressScreen(child: child, referential: referential),
              ),
            ),
            icon: const Icon(Icons.show_chart, size: 18),
            label: const Text('Voir la progression dans le temps'),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Appuyez sur un item pour le faire progresser. Appui long pour revenir en arrière.',
          style: TextStyle(fontSize: 12, color: kMutedTextColor),
        ),
        const SizedBox(height: 16),
        if (referential.groups.isEmpty)
          const Text('Aucun groupe défini pour ce référentiel.', style: TextStyle(fontSize: 13, color: kMutedTextColor))
        else
          ...referential.groups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: group.items.map((item) {
                        final statut = provider.referentialItemStatut(referential.id, child.id, item.id);
                        final couleur = _sonColor(statut);
                        return InkWell(
                          onTap: () => provider.cycleReferentialItemStatut(referential.id, child.id, item.id),
                          onLongPress: () {
                            HapticFeedback.selectionClick();
                            provider.reculeReferentialItemStatut(referential.id, child.id, item.id);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: couleur.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: couleur, width: 2),
                            ),
                            child: Text(
                              item.label,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: couleur),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )),
        OutlinedButton.icon(
          onPressed: allItems.isEmpty
              ? null
              : () async {
                  final confirme = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Réinitialiser "${referential.name}" ?'),
                      content: Text(
                          'Tous les items repasseront à « non acquis » pour ${child.firstname}.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text('Réinitialiser'),
                        ),
                      ],
                    ),
                  );
                  if (confirme == true) provider.resetReferentialStatus(referential.id, child.id);
                },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Tout remettre à non acquis'),
        ),
      ],
    );
  }

  Widget _sonLegende(SonStatut statut, String label) {
    final couleur = _sonColor(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: couleur)),
        ],
      ),
    );
  }

  // ────────────── ACTIVITIES TAB ──────────────
  Widget _buildActivitiesTab(BuildContext context, AppStateProvider provider, Child child, List<ActivityLog> childLogs, bool isDark) {
    if (childLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text("Aucune activité enregistrée pour cet élève.", textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Regroupe par atelier plutot que par date : un eleve qui refait un
    // atelier plusieurs fois n'apparait qu'une fois dans ce fil, avec son
    // dernier statut ; l'historique complet (dates, notes, photos de chaque
    // occurrence) reste accessible en detail via AtelierHistoryScreen.
    final Map<String, List<ActivityLog>> byAtelier = {};
    for (final log in childLogs) {
      (byAtelier[log.activityTypeId] ??= []).add(log);
    }
    // childLogs est deja trie du plus recent au plus ancien : l'ordre des
    // groupes (et le "premier" de chaque groupe) en herite naturellement.
    final atelierIds = byAtelier.keys.toList()
      ..sort((a, b) => byAtelier[b]!.first.timestamp.compareTo(byAtelier[a]!.first.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: atelierIds.length,
      itemBuilder: (context, index) {
        final logs = byAtelier[atelierIds[index]]!;
        final log = logs.first; // occurrence la plus recente
        final actType = provider.activityTypes.firstWhere(
          (a) => a.id == log.activityTypeId,
          orElse: () => ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: '#718096'),
        );
        final space = provider.spaces.firstWhere(
          (s) => s.id == actType.spaceId,
          orElse: () => Space(id: '', name: 'Espace inconnu', colorHex: '#718096'),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AtelierHistoryScreen(child: child, atelier: actType)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: hexToColor(actType.colorHex),
                              child: Icon(iconForName(actType.iconName, fallback: Icons.palette),
                                  size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                actType.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4E9F3D).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📍 ${space.name}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ),
                      if (actType.isObligatoryForGroup(child.group))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '⭐ Obligatoire',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ),
                      if (logs.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${logs.length} observations',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey.shade700),
                          ),
                        ),
                      Text(
                        '• ${DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFFA0AEC0)),
                      ),
                    ],
                  ),
                  if (actType.domaine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '📚 Domaine : ${actType.domaine}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.indigo.shade800),
                    ),
                  ],
                  if (actType.objectifs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '🏁 Objectifs : ${actType.objectifs.join(' • ')}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade700),
                    ),
                  ],
                  if (provider.statusLabel(log) != null) ...[
                    const SizedBox(height: 6),
                    Builder(builder: (context) {
                      final status = provider.statusById(log.evaluationStatusId);
                      final couleur = status == null ? null : hexToColor(status.colorHex);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: couleur?.withOpacity(0.15) ??
                              (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          provider.statusLabel(log)!,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: couleur),
                        ),
                      );
                    }),
                  ],
                  if (log.note != null && log.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '📝 ${log.note!}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (log.audioPath != null && log.audioPath!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    VoiceNotePlayButton(provider: provider, audioPath: log.audioPath!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────── DELETE CONFIRMATION ──────────────
  void _confirmDelete(BuildContext context, AppStateProvider provider, Child child) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Supprimer cet élève ?'),
            ],
          ),
          content: Text(
            'Voulez-vous vraiment supprimer ${child.firstname} ${child.lastname ?? ""} ?\n\n'
            'Vous pourrez annuler juste après la suppression.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final deleted = provider.deleteChild(child.id);
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back to list
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('${child.firstname} a été supprimé(e)'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 8),
                    action: SnackBarAction(
                      label: 'Annuler',
                      textColor: Colors.white,
                      onPressed: () => provider.restoreChild(deleted),
                    ),
                  ),
                );
              },
              label: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
}
