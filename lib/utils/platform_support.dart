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

/// Vrai sur macOS, Windows et Linux (hors web).
///
/// Sert a choisir la mise en page ordinateur (barre laterale, raccourcis
/// clavier, defilement a la souris) et a masquer ce qui exige une camera ou
/// une biometrie mobile.
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Vrai sur macOS : c'est la seule plateforme qui possede une barre de menus
/// systeme geree par Flutter (`PlatformMenuBar`).
bool get isMacOSPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
