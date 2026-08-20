#!/bin/bash
# Builds an unsigned .ipa for AltStore/SideStore sideloading — no Apple
# Developer account or signing certificate required. AltServer/SideServer
# performs the actual signing on-device using a free Apple ID at install time.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf build ipa_build Dash.ipa

XCODEBUILD_ARGS=(
  clean build
  -project Dash.xcodeproj
  -scheme Dash
  -configuration Release
  -sdk iphoneos
  -destination "generic/platform=iOS"
  -derivedDataPath build
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""
  CODE_SIGN_ENTITLEMENTS=""
  DEVELOPMENT_TEAM=""
  PROVISIONING_PROFILE_SPECIFIER=""
)

if [[ -n "${VERSION:-}" ]]; then
  XCODEBUILD_ARGS+=(MARKETING_VERSION="$VERSION")
fi

xcodebuild "${XCODEBUILD_ARGS[@]}"

APP_PATH="build/Build/Products/Release-iphoneos/Dash.app"
mkdir -p ipa_build/Payload
cp -R "$APP_PATH" ipa_build/Payload/
(cd ipa_build && zip -rq ../Dash.ipa Payload)
rm -rf ipa_build build

echo "Built Dash.ipa ($(du -h Dash.ipa | cut -f1))"
