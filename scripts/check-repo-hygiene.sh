#!/usr/bin/env bash
# Falha se o repositório contiver keystores, chaves privadas ou senhas de assinatura fixas.
# Regra do projeto: nenhuma chave nem senha é versionada (veja docs/ASSINATURA.md).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
status=0

# 1) Arquivos de keystore ou chave
if git ls-files | grep -Ei '\.(jks|keystore|p12|pfx|pem|key)$'; then
  echo "::error title=Chave versionada::Há arquivo de keystore/chave no repositório (listado acima)."
  status=1
fi

# 2) Bloco de chave privada dentro de arquivos de texto
if git grep -nIE -e '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' -- . ':(exclude)scripts/check-repo-hygiene.sh'; then
  echo "::error title=Chave privada no texto::Há bloco de chave privada em algum arquivo (listado acima)."
  status=1
fi

# 3) Senhas de assinatura escritas direto nos scripts do Gradle
if git grep -nIE -e '(storePassword|keyPassword)[[:space:]]*(=|\()[[:space:]]*"[^"]+"' -- '*.gradle' '*.gradle.kts'; then
  echo "::error title=Senha no build::storePassword/keyPassword com valor fixo em arquivo Gradle (listado acima)."
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "OK: nenhuma chave, keystore ou senha de assinatura versionada."
fi
exit "$status"
