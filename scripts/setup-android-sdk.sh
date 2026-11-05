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

# O nome do pacote da plataforma mudou: até a API 36 era "platforms;android-36"; a partir da 37 é
# "platforms;android-37.0". Em vez de supor, procura o nome real na lista do sdkmanager.
available="$("$sdkmanager" --sdk_root="$sdk_root" --list 2>/dev/null || true)"
platform_pkg="$(awk -v re="^platforms;android-${COMPILE_SDK}([.]0)?\$" '$1 ~ re { print $1; exit }' <<<"$available")"
if [ -z "$platform_pkg" ]; then
  echo "::error title=Plataforma do Android::Não encontrei platforms;android-${COMPILE_SDK} (nem ${COMPILE_SDK}.0) na lista do sdkmanager. Plataformas conhecidas:"
  awk '$1 ~ /^platforms;android-[0-9.]+$/ { print "  " $1 }' <<<"$available" >&2
  exit 1
fi
echo "Plataforma escolhida: $platform_pkg"

"$sdkmanager" --sdk_root="$sdk_root" --install "platform-tools" "$platform_pkg" "build-tools;${BUILD_TOOLS}"

echo "== Plataformas em $sdk_root/platforms =="
ls -1 "$sdk_root/platforms"
echo "== Componentes instalados (primeiras linhas) =="
"$sdkmanager" --sdk_root="$sdk_root" --list_installed | sed -n '1,40p'
