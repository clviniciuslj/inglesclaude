#!/usr/bin/env bash
# Gera a chave de assinatura estável DENTRO do runner do GitHub e grava nos secrets do ambiente.
# A chave nunca é impressa, nunca vai para o repositório e nunca passa pelo chat.
#
# Variáveis de entrada:
#   GH_TOKEN  token pessoal temporário (secret BOOTSTRAP_TOKEN) com permissão de Secrets e Variables
#   REPO      dono/repositório (ex.: clviniciuslj/inglesclaude)
#   ENV_NAME  ambiente do GitHub (padrão: release-signing)
#   ROTATE    "true" para substituir uma chave já existente (padrão: false)
#
# Veja docs/ASSINATURA.md.
set -euo pipefail

ENV_NAME="${ENV_NAME:-release-signing}"
ROTATE="${ROTATE:-false}"
KEY_ALIAS="englishlab"

if [ -z "${GH_TOKEN:-}" ]; then
  echo "::error title=Token ausente::O secret BOOTSTRAP_TOKEN não está disponível neste ambiente. Siga o passo a passo de docs/ASSINATURA.md."
  exit 1
fi
if [ -z "${REPO:-}" ]; then
  echo "REPO não definido" >&2
  exit 2
fi

# Se o ambiente não existir (ou o token não tiver permissão), a listagem falha.
if ! existing="$(gh secret list --env "$ENV_NAME" --repo "$REPO" 2>&1)"; then
  echo "::error title=Ambiente inacessível::Não consegui listar os secrets do ambiente '$ENV_NAME'. Confirme que o ambiente existe e que o token tem permissão de Secrets (leitura e escrita)."
  echo "Resposta do gh: $existing" >&2
  exit 1
fi

# KEYSTORE_BASE64 é gravado por último: sua presença indica que a configuração terminou.
if awk '{print $1}' <<<"$existing" | grep -qx 'KEYSTORE_BASE64' && [ "$ROTATE" != "true" ]; then
  echo "A chave de assinatura já existe no ambiente '$ENV_NAME'. Nada foi alterado."
  echo "Para substituí-la (o app instalado deixará de poder ser atualizado por cima), rode de novo com rotate=true."
  exit 0
fi

umask 077
work="$(mktemp -d)"
trap 'rm -rf "$work"; unset KS_PASSWORD' EXIT

# 192 bits de entropia; uma única senha serve para o keystore e para a chave (exigência do PKCS12).
KS_PASSWORD="$(openssl rand -hex 24)"
export KS_PASSWORD

keytool -genkeypair \
  -keystore "$work/englishlab.p12" -storetype PKCS12 \
  -alias "$KEY_ALIAS" -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass:env KS_PASSWORD -keypass:env KS_PASSWORD \
  -dname "CN=English Lab, OU=Uso pessoal, O=clviniciuslj, C=BR" >/dev/null

listing="$(keytool -list -v -keystore "$work/englishlab.p12" -storetype PKCS12 -alias "$KEY_ALIAS" -storepass:env KS_PASSWORD 2>/dev/null)"
fingerprint="$(awk '/SHA256:/ {print $2; exit}' <<<"$listing")"
if [ -z "$fingerprint" ]; then
  echo "::error title=Falha ao ler o certificado::Não consegui obter o SHA-256 do certificado gerado."
  exit 1
fi

set_secret() { # $1 = nome; o valor vem pela entrada padrão (nunca pela linha de comando)
  if ! gh secret set "$1" --env "$ENV_NAME" --repo "$REPO"; then
    echo "::error title=Falha ao gravar o secret::Não foi possível gravar $1 no ambiente '$ENV_NAME'. Verifique a permissão 'Secrets: Read and write' do token."
    exit 1
  fi
}

printf '%s' "$KEY_ALIAS" | set_secret KEY_ALIAS
printf '%s' "$KS_PASSWORD" | set_secret KEY_PASSWORD
printf '%s' "$KS_PASSWORD" | set_secret KEYSTORE_PASSWORD

if ! gh variable set SIGNING_CERT_SHA256 --env "$ENV_NAME" --repo "$REPO" --body "$fingerprint"; then
  echo "::error title=Falha ao gravar a variável::Não foi possível gravar SIGNING_CERT_SHA256. Verifique a permissão 'Variables: Read and write' do token."
  exit 1
fi

base64 -w0 "$work/englishlab.p12" | set_secret KEYSTORE_BASE64

echo "Chave de assinatura criada e gravada nos secrets do ambiente '$ENV_NAME'."
echo "SHA-256 do certificado (público): $fingerprint"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Chave de assinatura configurada"
    echo ""
    echo "- Ambiente: \`$ENV_NAME\`"
    echo "- SHA-256 do certificado: \`$fingerprint\`"
    echo ""
    echo "Próximo passo: **apague o secret \`BOOTSTRAP_TOKEN\` e revogue o token pessoal** (veja docs/ASSINATURA.md)."
  } >> "$GITHUB_STEP_SUMMARY"
fi
