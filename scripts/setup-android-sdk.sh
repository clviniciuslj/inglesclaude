#!/usr/bin/env bash
# Prepara o Android SDK: aceita as licenças e garante a plataforma e as build-tools do projeto.
# Nos runners do GitHub o SDK já vem instalado; o script é idempotente e só baixa o que faltar.
set -euo pipefail

sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$sdk_root" ]; then
  echo "::error title=Android SDK::ANDROID_HOME/ANDROID_SDK_ROOT não está definido."
  exit 1
fi

sdkmanager="$(command -v sdkmanager || true)"
if [ -z "$sdkmanager" ]; then
  sdkmanager="$(ls -d "$sdk_root"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [ -z "$sdkmanager" ] || [ ! -x "$sdkmanager" ]; then
  echo "::error title=sdkmanager::sdkmanager não encontrado em $sdk_root/cmdline-tools."
  exit 1
fi

COMPILE_SDK="${COMPILE_SDK:-37}"
BUILD_TOOLS="${BUILD_TOOLS:-36.0.0}"

echo "SDK: $sdk_root"
echo "sdkmanager: $sdkmanager"

# O 'yes' recebe SIGPIPE quando o sdkmanager termina; isso não é um erro.
yes 2>/dev/null | "$sdkmanager" --sdk_root="$sdk_root" --licenses >/dev/null || true

"$sdkmanager" --sdk_root="$sdk_root" --install \
  "platform-tools" "platforms;android-${COMPILE_SDK}" "build-tools;${BUILD_TOOLS}"

echo "== Componentes instalados (primeiras linhas) =="
"$sdkmanager" --sdk_root="$sdk_root" --list_installed | sed -n '1,40p'
