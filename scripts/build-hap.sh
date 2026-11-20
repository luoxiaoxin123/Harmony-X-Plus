#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ ! -e build-profile.json5 ]]; then
  cat > build-profile.json5 <<'PROFILE'
{
  "app": {
    "products": [{
      "name": "default",
      "compatibleSdkVersion": "6.0.2(22)",
      "targetSdkVersion": "26.0.0",
      "runtimeOS": "HarmonyOS"
    }],
    "buildModeSet": [{ "name": "debug" }, { "name": "release" }]
  },
  "modules": [{
    "name": "entry", "srcPath": "./entry",
    "targets": [{ "name": "default", "applyToProducts": ["default"] }]
  }]
}
PROFILE
fi
if [[ "${1:-}" == --prepare ]]; then
  exit 0
fi

: "${HOS_SDK_HOME:?Set HOS_SDK_HOME to the HarmonyOS API 26 SDK directory}"
if [[ ! -e .npmrc ]]; then
  printf '%s\n' '@ohos:registry=https://repo.harmonyos.com/npm/' > .npmrc
fi
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=4096}"
ohpm install --all
hvigorw --mode module -p product=default -p module=entry@default -p buildMode=release assembleHap --no-daemon --no-parallel
python3 scripts/collect-hap.py
