#!/usr/bin/env bash
# Confere um APK gerado pelo Gradle.
#   - Falha se o APK declarar android.permission.INTERNET (o app deve funcionar 100% offline).
#   - Com --stable-signature: exige uma assinatura que NÃO seja a chave de debug padrão do Android
#     e, se EXPECTED_CERT_SHA256 estiver definida, exige exatamente esse certificado.
# Uso: scripts/verify-apk.sh <apk> [--stable-signature]
set -euo pipefail

apk="${1:-}"
mode="${2:-}"
if [ -z "$apk" ] || [ ! -f "$apk" ]; then
  echo "uso: scripts/verify-apk.sh <apk> [--stable-signature]" >&2
  exit 2
fi

sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$sdk_root" ]; then
  echo "ANDROID_HOME/ANDROID_SDK_ROOT não está definido" >&2
  exit 2
fi

# Usa a build-tools mais recente que tenha a ferramenta pedida.
find_tool() {
  local tool="$1" dir
  for dir in $(ls -d "$sdk_root"/build-tools/*/ 2>/dev/null | sort -rV); do
    if [ -x "${dir}${tool}" ]; then
      echo "${dir}${tool}"
      return 0
    fi
  done
  return 1
}
aapt2="$(find_tool aapt2)" || { echo "aapt2 não encontrado em $sdk_root/build-tools" >&2; exit 2; }
apksigner="$(find_tool apksigner)" || { echo "apksigner não encontrado em $sdk_root/build-tools" >&2; exit 2; }

summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

echo "== Permissões declaradas =="
permissions="$("$aapt2" dump permissions "$apk")"
echo "$permissions"
if grep -q 'android.permission.INTERNET' <<<"$permissions"; then
  echo "::error title=Permissão proibida::O APK declara android.permission.INTERNET. O app deve funcionar 100% offline."
  exit 1
fi
echo "OK: o APK não declara a permissão INTERNET."

badging="$("$aapt2" dump badging "$apk" | head -n 1)"
version_name="$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badging")"
version_code="$(sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" <<<"$badging")"

echo "== Assinatura =="
cert_info="$("$apksigner" verify --verbose --print-certs "$apk")"
sed -n '1,12p' <<<"$cert_info"
cert_dn="$(awk -F': ' '/certificate DN/ {print $2; exit}' <<<"$cert_info")"
cert_sha256="$(awk -F': ' '/certificate SHA-256 digest/ {print tolower($2); exit}' <<<"$cert_info")"
apk_sha256="$(sha256sum "$apk" | cut -d' ' -f1)"
apk_size="$(du -h "$apk" | cut -f1)"

signature_note="chave de debug efêmera (somente verificação)"
if [ "$mode" = "--stable-signature" ]; then
  if grep -qi 'CN=Android Debug' <<<"$cert_dn"; then
    echo "::error title=Assinatura de debug::O APK foi assinado com a chave de debug padrão. Isso impediria atualizar o app por cima do instalado."
    exit 1
  fi
  if [ -n "${EXPECTED_CERT_SHA256:-}" ]; then
    expected="$(tr -d ':[:space:]' <<<"$EXPECTED_CERT_SHA256" | tr 'A-F' 'a-f')"
    if [ "$cert_sha256" != "$expected" ]; then
      echo "::error title=Certificado diferente::O certificado do APK (${cert_sha256}) não é o registrado (${expected}). Atualizar por cima falharia."
      exit 1
    fi
    echo "OK: certificado idêntico ao registrado."
    signature_note="chave estável (idêntica à registrada)"
  else
    echo "::warning title=Certificado não registrado::A variável SIGNING_CERT_SHA256 não existe; não foi possível comparar com o certificado esperado."
    signature_note="chave estável (sem certificado de referência para comparar)"
  fi
fi

summary "### APK verificado"
summary ""
summary "| Item | Valor |"
summary "|---|---|"
summary "| Versão | ${version_name} (código ${version_code}) |"
summary "| Tamanho | ${apk_size} |"
summary "| SHA-256 do APK | \`${apk_sha256}\` |"
summary "| SHA-256 do certificado | \`${cert_sha256}\` |"
summary "| Assinatura | ${signature_note} |"
summary "| Permissão INTERNET | ausente |"

echo "Versão: ${version_name} (código ${version_code}) · ${apk_size} · certificado ${cert_sha256}"
