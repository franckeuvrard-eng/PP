import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

/// Politique de confidentialité (RGPD) de l'application.
///
/// Les donnees sont stockees sur les appareils de l'enseignant et, s'il
/// l'active, dans son propre iCloud ; l'editeur n'exploite aucun serveur et
/// n'a acces a aucune donnee. Le responsable du traitement est donc
/// l'etablissement / l'enseignant. Texte a garder aligne avec la page
/// publique docs/confidentialite.html (exigee par l'App Store).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppStateProvider>(context, listen: false).classSettings;
    final responsable = [settings.schoolName, settings.teacher]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' — ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Politique de confidentialité'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vos données restent chez vous',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'A petits pas est un outil de suivi pédagogique utilisé en classe. '
                    'Les données restent sur vos appareils et, si vous l\'activez, dans '
                    'votre propre iCloud. L\'éditeur n\'exploite aucun serveur et n\'a '
                    'accès à aucune des données saisies.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PolicySection(
            icon: Icons.badge,
            title: 'Responsable du traitement',
            paragraphs: [
              if (responsable.isNotEmpty)
                'Les données sont sous la responsabilité de : $responsable, '
                    'seul(e) à disposer de l\'appareil et des données qu\'il contient.'
              else
                'Les données sont sous la responsabilité de l\'établissement / '
                    'l\'enseignant qui utilise l\'application (renseignez le nom de '
                    'l\'école et de l\'enseignant dans Paramètres > Ma classe).',
              'L\'éditeur de l\'application n\'intervient pas dans ce traitement : '
                  'il ne collecte, n\'héberge ni ne transmet aucune donnée.',
            ],
          ),
          const _PolicySection(
            icon: Icons.folder_shared,
            title: 'Données collectées',
            paragraphs: [
              'Élève : prénom, nom, date de naissance, section, photo de profil, '
                  'email de contact, notes libres.',
              'Suivi pédagogique : observations d\'ateliers (texte, photos, '
                  'niveau d\'évaluation) et suivi de l\'acquisition des sons.',
              'Classe : nom de l\'enseignant et de l\'ATSEM, nom et niveau de la classe.',
            ],
          ),
          const _PolicySection(
            icon: Icons.flag,
            title: 'Finalités et base légale',
            paragraphs: [
              'Ces données servent exclusivement au suivi pédagogique individualisé '
                  'des élèves dans le cadre de la mission éducative de la classe.',
            ],
          ),
          const _PolicySection(
            icon: Icons.storage,
            title: 'Stockage',
            paragraphs: [
              'Les données sont stockées sur l\'appareil, dans une base de données '
                  'locale. Aucun serveur de l\'éditeur n\'est utilisé.',
              'Synchronisation iCloud (iPhone, iPad, Mac), si elle est activée : les '
                  'données et photos sont copiées dans l\'espace iCloud Drive privé de '
                  'l\'application, sur le compte iCloud personnel de l\'enseignant. Apple '
                  'les héberge (chiffrées en transit et au repos) ; ni l\'éditeur ni les '
                  'autres utilisateurs n\'y ont accès. Elle se désactive dans '
                  'Paramètres > Sauvegarde & Sécurité > Synchroniser avec un autre appareil.',
              'Synchronisation Wi-Fi (par exemple avec un PC Windows) : les données '
                  'passent directement d\'un appareil à l\'autre sur le réseau local, '
                  'sans internet, et seulement après accord explicite sur l\'appareil '
                  'qui les reçoit.',
            ],
          ),
          const _PolicySection(
            icon: Icons.ios_share,
            title: 'Sauvegardes et exports',
            paragraphs: [
              'Des sauvegardes automatiques locales sont créées régulièrement '
                  '(voir Paramètres > Sauvegarde & Sécurité).',
              'Les exports (sauvegarde complète, archive de fin d\'année, PDF, '
                  'Excel) ne sont générés qu\'à la demande explicite de l\'enseignant, '
                  'qui choisit ensuite où les envoyer via le partage natif de l\'appareil.',
              'Si la sauvegarde iCloud/iTunes de l\'appareil est activée dans les '
                  'réglages du système iOS, elle peut inclure ces fichiers comme '
                  'pour toute autre application : ce comportement est géré par iOS, '
                  'pas par A petits pas.',
            ],
          ),
          const _PolicySection(
            icon: Icons.schedule,
            title: 'Durée de conservation',
            paragraphs: [
              'Les données sont conservées le temps de l\'année scolaire. '
                  'L\'enseignant peut les archiver (fonction « Nouvelle année '
                  'scolaire ») ou les supprimer manuellement à tout moment.',
            ],
          ),
          const _PolicySection(
            icon: Icons.lock,
            title: 'Sécurité',
            paragraphs: [
              'Un verrou Face ID / code peut être activé pour protéger l\'accès à '
                  'l\'application (Paramètres > Sauvegarde & Sécurité).',
            ],
          ),
          const _PolicySection(
            icon: Icons.groups,
            title: 'Destinataires',
            paragraphs: [
              'Aucun tiers n\'a accès aux données, sauf action volontaire de '
                  'l\'enseignant (par exemple le partage d\'un export avec une famille). '
                  'Apple n\'intervient que comme hébergeur de l\'iCloud de l\'enseignant, '
                  'si la synchronisation iCloud est activée.',
              'L\'application ne contient ni publicité, ni outil de mesure '
                  'd\'audience, ni traceur.',
            ],
          ),
          const _PolicySection(
            icon: Icons.gavel,
            title: 'Droits des personnes concernées',
            paragraphs: [
              'Conformément au RGPD, toute personne concernée dispose d\'un droit '
                  'd\'accès, de rectification, d\'effacement, de portabilité et '
                  'd\'opposition sur les données la concernant (ou concernant son enfant).',
              'Ces droits s\'exercent directement auprès de l\'établissement / '
                  'l\'enseignant identifié plus haut, seul détenteur des données.',
            ],
          ),
          const _PolicySection(
            icon: Icons.mail_outline,
            title: 'Contact de l\'éditeur',
            paragraphs: [
              'Franck Euvrard — franck.euvrard71@gmail.com',
              'Version en ligne : https://franckeuvrard-eng.github.io/PP/confidentialite.html',
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> paragraphs;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.paragraphs,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4E9F3D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p, style: const TextStyle(fontSize: 13, height: 1.35)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
