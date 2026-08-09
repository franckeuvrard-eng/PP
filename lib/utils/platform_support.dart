import 'package:flutter/foundation.dart';

/// Vrai uniquement sur iOS et Android.
///
/// Les plugins `local_auth` (verrouillage FaceID) et `mobile_scanner` (scan des
/// QR Codes) n'ont aucune implementation Windows ni web. Sans ce garde-fou,
/// l'application ne demarre pas hors mobile, ce qui empeche de previsualiser
/// l'interface sur poste de travail (`flutter run -d windows`).
bool get isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
