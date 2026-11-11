import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';
import 'progressions_screen.dart';
import 'planning_screen.dart';
import 'spaces_workshops_tab.dart';

/// Onglet « Ateliers » de la barre du bas sur iPhone : l'entree vers les
/// Espaces & Ateliers, les Parcours et le Planning, qui ont chacun leur page
/// de la barre laterale sur Mac et iPad.
class AteliersHubScreen extends StatelessWidget {
  const AteliersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final ateliers = provider.activityTypes.where((a) => !a.inProgression).length;

    Widget entry({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required WidgetBuilder page,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          subtitle: Text(subtitle, style: const TextStyle(color: kMutedTextColor)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: page)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        entry(
          icon: Icons.space_dashboard,
          color: const Color(0xFF4E9F3D),
          title: 'Espaces & Ateliers',
          subtitle: '${provider.spaces.length} espace(s), $ateliers atelier(s)',
          page: (_) => const SpacesWorkshopsScreen(),
        ),
        entry(
          icon: Icons.timeline,
          color: const Color(0xFF42A5F5),
          title: 'Parcours',
          subtitle: provider.progressions.isEmpty
              ? 'Des étapes à faire dans l’ordre, comme un chemin.'
              : '${provider.progressions.length} parcours : suivi, étapes, frise et QR codes',
          page: (_) => const ProgressionsScreen(),
        ),
        entry(
          icon: Icons.calendar_view_week,
          color: const Color(0xFFE8833A),
          title: 'Planning',
          subtitle: 'Qui fait quel atelier, jour par jour',
          page: (_) => const PlanningScreen(),
        ),
      ],
    );
  }
}
