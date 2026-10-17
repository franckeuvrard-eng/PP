import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Rappel local « élèves non évalués aujourd'hui ».
///
/// Purement local : aucun serveur, comme le reste de l'application. La
/// notification est reconstruite (annulée puis reprogrammée) à chaque appel
/// plutôt que répétée telle quelle, pour que son contenu reflète le nombre
/// d'élèves réellement en attente au moment du dernier calcul — au prix
/// d'un léger décalage si l'app n'est pas rouverte entre deux calculs.
class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _notificationId = 1001;
  static bool _initialized = false;

  /// Les rappels n'existent que sur iOS et macOS : le plugin de notifications
  /// n'a pas d'implementation Windows/Linux dans la version utilisee.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Application francophone, usage en classe en France : pas besoin de
    // detection dynamique du fuseau, qui demanderait un plugin natif de plus.
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(iOS: iosSettings, macOS: iosSettings),
    );
    _initialized = true;
  }

  /// Demande l'autorisation d'envoyer des notifications. À appeler quand
  /// l'enseignant active le rappel dans les réglages, pas au démarrage.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    // Sur Mac, c'est l'implementation macOS qui repond : sans elle le rappel
    // restait silencieusement desactive.
    final mac = await _plugin
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return ios ?? mac ?? false;
  }

  /// (Re)programme le rappel du jour à [hour]:[minute] avec le nombre actuel
  /// d'élèves non évalués. Annule silencieusement si l'heure est déjà
  /// passée ou s'il n'y a plus personne en attente.
  static Future<void> scheduleTodayReminder({
    required int hour,
    required int minute,
    required int pendingCount,
  }) async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
    if (pendingCount <= 0) return;

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) return;

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Élèves non évalués',
      body: pendingCount > 1
          ? '$pendingCount élèves n\'ont pas encore d\'observation aujourd\'hui.'
          : '1 élève n\'a pas encore d\'observation aujourd\'hui.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        macOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      // Sans effet sur iOS/macOS (seules plateformes du rappel), mais requis.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminder() async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
  }
}
