#!/usr/bin/env bash
# Prepare le projet macOS pour un build CI (test non signe ou TestFlight).
#
# Usage : scripts/prepare_macos.sh [--icloud]
#
# Le dossier macos/ n'est pas versionne : on le regenere puis on applique la
# configuration de l'application. --icloud ajoute les droits iCloud : a
# reserver aux builds signes par Apple, sinon l'app refuse de demarrer.
set -euo pipefail
ICLOUD=0
[ "${1:-}" = "--icloud" ] && ICLOUD=1
CONTAINER=iCloud.fr.franckeuvrard.apetitspas

flutter config --enable-macos-desktop
flutter create --project-name=petitpas --platforms=macos .
rm -f test/widget_test.dart

cp macos_config/DebugProfile.entitlements macos/Runner/DebugProfile.entitlements
cp macos_config/Release.entitlements macos/Runner/Release.entitlements

# Identifiant definitif de l'app (le meme que sur iOS).
sed -i '' 's/^PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = fr.franckeuvrard.apetitspas/' macos/Runner/Configs/AppInfo.xcconfig
sed -i '' 's/^PRODUCT_NAME = .*/PRODUCT_NAME = A petits pas/' macos/Runner/Configs/AppInfo.xcconfig
grep -n 'PRODUCT_' macos/Runner/Configs/AppInfo.xcconfig

# Taille minimale de fenetre : en dessous, la barre laterale ecrase le contenu.
perl -0pi -e 's/super\.awakeFromNib\(\)/self.minSize = NSSize(width: 900, height: 640)\n    super.awakeFromNib()/' macos/Runner/MainFlutterWindow.swift
grep -n "minSize" macos/Runner/MainFlutterWindow.swift

PLIST=macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'Notes vocales sur les observations.'" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string 'Dictee des observations en texte.'" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSLocalNetworkUsageDescription string 'Synchronisation avec l application sur iPhone/iPad.'" "$PLIST"
# Service Bonjour de decouverte automatique (cf. sync_discovery.dart).
/usr/libexec/PlistBuddy -c "Add :NSBonjourServices array" -c "Add :NSBonjourServices:0 string '_petitpas._tcp'" "$PLIST"
# Mac App Store : categorie obligatoire, pas de chiffrement soumis a declaration.
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.education" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"

if [ "$ICLOUD" = 1 ]; then
  for E in macos/Runner/Release.entitlements macos/Runner/DebugProfile.entitlements; do
    /usr/libexec/PlistBuddy \
      -c "Add :com.apple.developer.icloud-container-identifiers array" \
      -c "Add :com.apple.developer.icloud-container-identifiers:0 string $CONTAINER" \
      -c "Add :com.apple.developer.icloud-services array" \
      -c "Add :com.apple.developer.icloud-services:0 string CloudDocuments" \
      -c "Add :com.apple.developer.ubiquity-container-identifiers array" \
      -c "Add :com.apple.developer.ubiquity-container-identifiers:0 string $CONTAINER" \
      "$E"
  done
  echo "Droits iCloud ajoutes."
fi

# Icone de l'app (la meme que sur iPhone), au lieu de l'icone Flutter.
flutter pub get
dart run flutter_launcher_icons -f flutter_launcher_icons_macos.yaml

# Cible macOS : celle du template Flutter (12.0), au-dessus du minimum du
# plugin record (10.15).
grep -m1 'MACOSX_DEPLOYMENT_TARGET' macos/Runner.xcodeproj/project.pbxproj
