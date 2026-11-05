#!/usr/bin/env bash
# Falha se os esquemas exportados do Room (app/schemas) não forem os que estão commitados.
# A comparação é semântica (JSON normalizado): diferenças só de espaço ou de quebra de linha
# final não reprovam. Quando reprova, imprime o arquivo gerado para ser commitado.
# Requer: git e jq.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
dir="app/schemas"

if [ ! -d "$dir" ]; then
  echo "::error title=Esquemas do Room ausentes::$dir não existe: o build não exportou o esquema (exportSchema = true e room.schemaLocation)."
  exit 1
fi

status=0
while IFS= read -r -d '' file; do
  if ! git cat-file -e "HEAD:${file}" 2>/dev/null; then
    echo "::error title=Esquema do Room não commitado::${file}"
    echo "----- ${file}"
    cat "$file"
    echo
    status=1
    continue
  fi
  if ! diff -q <(git show "HEAD:${file}" | jq -S .) <(jq -S . "$file") >/dev/null; then
    echo "::error title=Esquema do Room diferente do commitado::${file}"
    echo "----- ${file}"
    cat "$file"
    echo
    status=1
  fi
done < <(find "$dir" -type f -name '*.json' -print0 | sort -z)

if [ "$status" -eq 0 ]; then
  echo "OK: os esquemas do Room em $dir estão em dia."
fi
exit "$status"
