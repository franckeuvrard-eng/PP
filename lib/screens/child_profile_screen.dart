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
import '../data/sons_data.dart';
import 'children_manager_screen.dart' show ChildFormDialog;
import 'edit_activity_log_screen.dart';

class ChildProfileScreen extends StatelessWidget {
  final Child child;

  const ChildProfileScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    // Refresh child data from provider in case it was updated
    final currentChild = provider.children.firstWhere(
      (c) => c.id == child.id,
      orElse: () => child,
    );
    final childLogs = provider.activities
        .where((log) => log.childId == currentChild.id)
        .toList()
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
            value: child.birthdate ?? 'Non renseignée',
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

          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  context,
                  icon: Icons.assignment,
                  value: '${provider.activities.where((a) => a.childId == child.id).length}',
                  label: 'Observations totales',
                  color: const Color(0xFF4E9F3D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  context,
                  icon: Icons.today,
                  value: '${provider.activities.where((a) => a.childId == child.id && _isSameDay(a.timestamp, DateTime.now())).length}',
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

  Widget _buildLargeAvatar(Child child, AppStateProvider provider) {
    final absolutePath = provider.getAbsolutePath(child.imagePath);
    if (absolutePath != null && File(absolutePath).existsSync()) {
      return CircleAvatar(
        radius: 56,
        backgroundImage: FileImage(File(absolutePath)),
      );
    }
    return CircleAvatar(
      radius: 56,
      backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
      child: Text(
        child.avatarText,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
      ),
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
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
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
        const Text('Analyse des sons',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Langage · conscience phonémique & signes graphiques',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
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
        const SizedBox(height: 4),
        const Text(
          'Appuyez sur un son pour le faire progresser : non acquis → en cours → acquis. '
          'Appui long pour revenir en arrière.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: couleur.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: couleur, width: 2),
                            ),
                            child: Center(
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

    // Group activities by date
    final Map<String, List<ActivityLog>> groupedLogs = {};
    for (final log in childLogs) {
      final dateKey = DateFormat('dd/MM/yyyy').format(log.timestamp);
      groupedLogs.putIfAbsent(dateKey, () => []);
      groupedLogs[dateKey]!.add(log);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: groupedLogs.length,
      itemBuilder: (context, index) {
        final dateKey = groupedLogs.keys.elementAt(index);
        final logs = groupedLogs[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF718096),
                ),
              ),
            ),
            ...logs.map((log) {
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
                                  backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
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
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Éditer l\'observation',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditActivityLogScreen(
                                    activityLog: log,
                                    actType: actType,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                          ),
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
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
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
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                          Text(
                            '• ${DateFormat('HH:mm').format(log.timestamp)}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFFA0AEC0)),
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
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade700),
                        ),
                      ],
                      if (provider.statusLabel(log) != null) ...[
                        const SizedBox(height: 6),
                        Builder(builder: (context) {
                          final status = provider.statusById(log.evaluationStatusId);
                          final couleur = status == null
                              ? null
                              : Color(int.parse(status.colorHex.replaceFirst('#', '0xff')));
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
                    ],
                  ),
                ),
              );
            }),
            const Divider(),
          ],
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
