#!/usr/bin/env bash
# Prepare le projet iOS pour un build CI (test non signe ou TestFlight).
#
# Usage : scripts/prepare_ios.sh <cible-ios>   (ex. 15.0)
#
# Le dossier ios/ est en partie versionne (Info.plist, projet, Podfile,
# droits iCloud) : flutter create ne fait que completer les fichiers manquants,
# puis on aligne la cible de deploiement partout (Podfile, projet, xcconfig)
# pour eviter « module has a minimum deployment target of iOS X ».
set -euo pipefail
T="${1:?cible iOS manquante}"

mv ios/Runner/Info.plist Info.plist.bak
flutter create --project-name=petitpas --platforms=ios .
mv Info.plist.bak ios/Runner/Info.plist
# flutter create regenere test/widget_test.dart (reference MyApp, absente).
rm -f test/widget_test.dart

sed -i '' "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = ${T};/g" ios/Runner.xcodeproj/project.pbxproj
sed -i '' "s|<string>12.0</string>|<string>${T}</string>|g" ios/Flutter/AppFrameworkInfo.plist
echo "IPHONEOS_DEPLOYMENT_TARGET=${T}" >> ios/Flutter/Release.xcconfig

echo "--- pbxproj ---"; grep -n 'IPHONEOS_DEPLOYMENT_TARGET\|PRODUCT_BUNDLE_IDENTIFIER' ios/Runner.xcodeproj/project.pbxproj
echo "--- Podfile ---"; grep -n 'platform :ios' ios/Podfile
