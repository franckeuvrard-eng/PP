import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/icloud_sync.dart';
import '../services/sync_merge.dart';
import '../services/sync_service.dart';
import 'app_provider.dart';
import 'provider_sync_host.dart';

/// Synchronisation iCloud automatique (iPhone, iPad, Mac).
///
/// Se declenche a l'ouverture, au retour au premier plan, quelques secondes
/// apres chaque modification, des qu'iCloud signale une version deposee par un
/// autre appareil, regulierement, et a la demande (tirer pour actualiser). Toute situation delicate
/// (conflit, suppressions nombreuses) est mise en attente sans rien ecrire :
/// [lastOutcome] la signale et l'ecran de synchronisation propose de la
/// trancher avec [syncInteractive].
class CloudSyncController extends ChangeNotifier with WidgetsBindingObserver {
  CloudSyncController(this.app, {CloudFolder? folder})
      : _sync = CloudSync(ProviderSyncHost(app), folder ?? ICloudFolder()) {
    if (!isSupported) return;
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_onAppChanged);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _autoSync());
  }

  final AppStateProvider app;
  final CloudSync _sync;
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<void>? _watch;
  bool _syncing = false;
  bool _disposed = false;

  /// Synchronisation en cours, a attendre avant d'en lancer une autre.
  Future<CloudSyncOutcome>? _current;
  bool _startedOnce = false;

  CloudSyncOutcome? lastOutcome;

  /// Dernier compte rendu avec des changements (pour l'afficher).
  SyncSummary? lastChanges;
  DateTime? lastChangesAt;

  /// iCloud n'existe que sur les appareils Apple.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get syncing => _syncing;

  /// Vrai si une decision de l'utilisateur est attendue.
  bool get needsAttention =>
      lastOutcome?.status == CloudSyncStatus.needsConfirmation ||
      lastOutcome?.status == CloudSyncStatus.needsResolution;

  bool get _canRun => isSupported && app.isLoaded && !app.loadFailed && app.iCloudSyncEnabled;

  void _onAppChanged() {
    if (_syncing || !_canRun) return;
    if (!_startedOnce) {
      _startedOnce = true;
      unawaited(_autoSync());
      return;
    }
    // Les modifications arrivent par rafales (saisie) : on attend le calme.
    _schedule(const Duration(seconds: 3));
  }

  void _schedule(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, _autoSync);
  }

  /// Ecoute les nouvelles versions deposees par les autres appareils (une
  /// fois iCloud confirme disponible, sinon l'ecoute native echouerait).
  void _ensureWatching() {
    if (_watch != null) return;
    _watch = _sync.folder.changes(CloudSync.classFile).listen(
      (_) => _schedule(const Duration(milliseconds: 1500)),
      onError: (Object _) => _watch = null, // nouvel essai a la prochaine synchro
      cancelOnError: true,
    );
  }

  /// Tirer pour actualiser : synchronise tout de suite. Ne repose pas une
  /// question en attente (conflit, suppressions) : elle se traite depuis
  /// l'ecran de synchronisation.
  Future<CloudSyncOutcome?> refreshNow() async {
    if (!_canRun) return null;
    // Une synchro automatique est peut-etre en cours : on l'attend, puis on
    // en relance une pour etre sur d'avoir le dernier etat d'iCloud.
    final running = _current;
    if (running != null) {
      // Pas d'attente sans fin si iCloud traine (telechargement lent).
      await running.timeout(const Duration(seconds: 15),
          onTimeout: () => CloudSyncOutcome(CloudSyncStatus.retryLater));
      if (_syncing) {
        return CloudSyncOutcome(CloudSyncStatus.retryLater,
            message: 'Une synchronisation est déjà en cours.');
      }
    }
    if (needsAttention) return lastOutcome;
    return _run(() => _sync.sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_autoSync());
  }

  Future<void> _autoSync() async {
    if (!_canRun || _syncing) return;
    // Une decision est attendue : on ne repose pas la question en boucle.
    if (needsAttention) return;
    await _run(() => _sync.sync());
  }

  /// Synchronisation lancee par l'utilisateur, avec choix et confirmation.
  Future<CloudSyncOutcome?> syncInteractive({
    required Future<Map<String, Object?>?> Function(
            List<MergeConflict>, String, Map<String, dynamic>)
        resolveConflicts,
    required Future<bool> Function(SyncSummary) confirmChanges,
  }) async {
    if (!isSupported || !app.isLoaded || app.loadFailed || _syncing) return null;
    return _run(() => _sync.sync(
          resolveConflicts: resolveConflicts,
          confirmChanges: confirmChanges,
        ));
  }

  Future<CloudSyncOutcome> _run(Future<CloudSyncOutcome> Function() action) {
    final future = _runOnce(action);
    _current = future;
    return future.whenComplete(() {
      if (identical(_current, future)) _current = null;
    });
  }

  Future<CloudSyncOutcome> _runOnce(Future<CloudSyncOutcome> Function() action) async {
    _syncing = true;
    notifyListeners();
    try {
      final outcome = await action();
      lastOutcome = outcome;
      if (outcome.status != CloudSyncStatus.unavailable &&
          outcome.status != CloudSyncStatus.error) {
        _ensureWatching();
      }
      if (outcome.status == CloudSyncStatus.synced && outcome.summary != null) {
        lastChanges = outcome.summary;
        lastChangesAt = outcome.at;
      }
      if (outcome.status == CloudSyncStatus.retryLater) {
        _schedule(const Duration(seconds: 20));
      }
      return outcome;
    } finally {
      _syncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    _watch?.cancel();
    if (isSupported) {
      WidgetsBinding.instance.removeObserver(this);
      app.removeListener(_onAppChanged);
    }
    super.dispose();
  }
}
