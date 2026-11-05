#!/usr/bin/env bash
# Testes dos scripts de CI: geração da chave de assinatura, verificação de APK e higiene do repositório.
# Usam um "gh" falso e ferramentas do Android falsas: sem rede e sem nenhum segredo real.
# Requer: bash, openssl, keytool (JDK), git.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

ok() { passed=$((passed + 1)); echo "  ok    $1"; }
bad() { failed=$((failed + 1)); echo "  FALHA $1"; }

expect_ok() { # expect_ok "descrição" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}
expect_fail() { # expect_fail "descrição" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}

# ======================================================================================
echo "== bootstrap-signing.sh =="
fakebin="$work/fakebin"
mkdir -p "$fakebin"
cat > "$fakebin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
# "gh" falso: guarda secrets e variáveis em arquivos do diretório FAKE_GH_STATE.
state="${FAKE_GH_STATE:?}"
mkdir -p "$state"
case "$1 $2" in
  "secret list")
    if [ -f "$state/fail_list" ]; then
      echo "HTTP 404: Not Found" >&2
      exit 1
    fi
    for f in "$state"/secret_*; do
      [ -e "$f" ] || continue
      printf '%s\t%s\n' "${f##*/secret_}" "less than a minute ago"
    done
    ;;
  "secret set")
    name="$3"
    cat > "$state/secret_$name"
    echo "$name" >> "$state/set_order.txt"
    ;;
  "variable set")
    name="$3"
    shift 3
    while [ $# -gt 0 ]; do
      if [ "$1" = "--body" ]; then printf '%s' "$2" > "$state/var_$name"; fi
      shift
    done
    ;;
  *)
    echo "gh falso: comando inesperado: $*" >&2
    exit 1
    ;;
esac
FAKE_GH
chmod +x "$fakebin/gh"

state="$work/gh-state"
run_bootstrap() { # $1 = ROTATE
  FAKE_GH_STATE="$state" PATH="$fakebin:$PATH" GH_TOKEN=token-falso REPO=dono/repo \
    ENV_NAME=release-signing ROTATE="${1:-false}" "$root/scripts/bootstrap-signing.sh"
}

run_bootstrap false > "$work/boot1.log" 2>&1 || true
expect_ok "cria os 4 secrets e a variável" test -f "$state/secret_KEYSTORE_BASE64" -a -f "$state/secret_KEYSTORE_PASSWORD" \
  -a -f "$state/secret_KEY_ALIAS" -a -f "$state/secret_KEY_PASSWORD" -a -f "$state/var_SIGNING_CERT_SHA256"
if [ "$(tail -n 1 "$state/set_order.txt" 2>/dev/null)" = "KEYSTORE_BASE64" ]; then
  ok "KEYSTORE_BASE64 é gravado por último (marca de conclusão)"
else
  bad "KEYSTORE_BASE64 é gravado por último (marca de conclusão)"
fi

password="$(cat "$state/secret_KEYSTORE_PASSWORD" 2>/dev/null || true)"
base64 -d "$state/secret_KEYSTORE_BASE64" > "$work/decoded.p12" 2>/dev/null || true
expect_ok "o keystore gravado abre com a senha gravada" \
  keytool -list -keystore "$work/decoded.p12" -storetype PKCS12 -storepass "$password" -alias englishlab
listing="$(keytool -list -v -keystore "$work/decoded.p12" -storetype PKCS12 -storepass "$password" -alias englishlab 2>/dev/null || true)"
fingerprint="$(awk '/SHA256:/ {print $2; exit}' <<<"$listing")"
if [ -n "$fingerprint" ] && [ "$fingerprint" = "$(cat "$state/var_SIGNING_CERT_SHA256" 2>/dev/null || true)" ]; then
  ok "a variável SIGNING_CERT_SHA256 é o SHA-256 real do certificado"
else
  bad "a variável SIGNING_CERT_SHA256 é o SHA-256 real do certificado"
fi
if [ "$(cat "$state/secret_KEY_PASSWORD")" = "$password" ] && [ "$(cat "$state/secret_KEY_ALIAS")" = "englishlab" ]; then
  ok "senha da chave = senha do keystore (exigência do PKCS12) e alias correto"
else
  bad "senha da chave = senha do keystore (exigência do PKCS12) e alias correto"
fi
if [ -n "$password" ] && ! grep -qF "$password" "$work/boot1.log"; then
  ok "a senha nunca aparece na saída do script"
else
  bad "a senha nunca aparece na saída do script"
fi
if ! grep -qF "$(cat "$state/secret_KEYSTORE_BASE64")" "$work/boot1.log"; then
  ok "o keystore (base64) nunca aparece na saída do script"
else
  bad "o keystore (base64) nunca aparece na saída do script"
fi

before="$(cat "$state"/secret_* "$state"/var_* | sha256sum)"
expect_ok "sem rotate, uma chave existente é preservada (sai com sucesso)" run_bootstrap false
after="$(cat "$state"/secret_* "$state"/var_* | sha256sum)"
if [ "$before" = "$after" ]; then ok "sem rotate, nada é alterado"; else bad "sem rotate, nada é alterado"; fi

expect_ok "com rotate=true a chave é substituída" run_bootstrap true
rotated="$(cat "$state"/secret_* "$state"/var_* | sha256sum)"
if [ "$before" != "$rotated" ]; then ok "com rotate=true os secrets mudam"; else bad "com rotate=true os secrets mudam"; fi

expect_fail "sem token falha com erro" env -u GH_TOKEN FAKE_GH_STATE="$state" PATH="$fakebin:$PATH" REPO=dono/repo "$root/scripts/bootstrap-signing.sh"

rm -rf "$state" && mkdir -p "$state" && touch "$state/fail_list"
expect_fail "ambiente inexistente (listagem falha) aborta sem gravar nada" run_bootstrap false
if ! ls "$state"/secret_* >/dev/null 2>&1; then ok "nada foi gravado quando o ambiente é inacessível"; else bad "nada foi gravado quando o ambiente é inacessível"; fi

# ======================================================================================
echo "== verify-apk.sh =="
sdk="$work/sdk"
tools="$sdk/build-tools/36.0.0"
mkdir -p "$tools"
cat > "$tools/aapt2" <<'FAKE_AAPT2'
#!/usr/bin/env bash
case "$1 $2" in
  "dump permissions")
    echo "package: io.github.clviniciuslj.englishlab"
    [ -n "${FAKE_PERMS:-}" ] && echo "uses-permission: name='${FAKE_PERMS}'"
    exit 0 ;;
  "dump badging")
    echo "package: name='io.github.clviniciuslj.englishlab' versionCode='123' versionName='0.1.0' compileSdkVersion='37'"
    echo "sdkVersion:'26'"
    exit 0 ;;
esac
exit 1
FAKE_AAPT2
cat > "$tools/apksigner" <<'FAKE_APKSIGNER'
#!/usr/bin/env bash
echo "Verifies"
echo "Verified using v2 scheme (APK Signature Scheme v2): true"
echo "Number of signers: 1"
echo "Signer #1 certificate DN: ${FAKE_DN:-CN=English Lab, OU=Uso pessoal, O=clviniciuslj, C=BR}"
echo "Signer #1 certificate SHA-256 digest: ${FAKE_SHA:-aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899}"
echo "Signer #1 certificate SHA-1 digest: 0123456789abcdef0123456789abcdef01234567"
FAKE_APKSIGNER
chmod +x "$tools/aapt2" "$tools/apksigner"
echo "apk de mentira" > "$work/app.apk"

verify() { ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/app.apk" "$@"; }

expect_ok "APK sem INTERNET passa" verify
expect_fail "APK com INTERNET é reprovado" env FAKE_PERMS=android.permission.INTERNET ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/app.apk"
expect_ok "outras permissões não reprovam" env FAKE_PERMS=android.permission.RECORD_AUDIO ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/app.apk"
expect_fail "--stable-signature rejeita a chave de debug padrão" \
  env FAKE_DN="C=US, O=Android, CN=Android Debug" ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/app.apk" --stable-signature
expect_ok "--stable-signature aceita chave própria quando não há certificado de referência" verify --stable-signature
expect_ok "certificado esperado (formato do keytool, com dois-pontos e maiúsculas) confere" \
  env EXPECTED_CERT_SHA256="AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99" \
  ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/app.apk" --stable-signature
expect_fail "certificado diferente do esperado é reprovado" \
  env EXPECTED_CERT_SHA256="00:11:22" ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/app.apk" --stable-signature
expect_fail "arquivo inexistente é erro de uso" env ANDROID_HOME="$sdk" "$root/scripts/verify-apk.sh" "$work/nao-existe.apk"

# ======================================================================================
echo "== check-repo-hygiene.sh =="
new_repo() { # cria um repositório git limpo com o script de higiene
  local dir="$work/repo-$1"
  mkdir -p "$dir/scripts"
  cp "$root/scripts/check-repo-hygiene.sh" "$dir/scripts/"
  git -C "$dir" init -q
  echo "$dir"
}
run_hygiene() { (cd "$1" && git add -A && ./scripts/check-repo-hygiene.sh); }

clean="$(new_repo limpo)"
echo "texto qualquer" > "$clean/README.md"
expect_ok "repositório limpo passa" run_hygiene "$clean"

with_keystore="$(new_repo keystore)"
echo "x" > "$with_keystore/segredo.jks"
expect_fail "keystore versionado é reprovado" run_hygiene "$with_keystore"

with_key_block="$(new_repo bloco)"
printf '%s\n' "-----BEGIN $(printf 'PRIVATE')  KEY-----" | sed 's/  / /' > "$with_key_block/chave.txt"
expect_fail "bloco de chave privada em texto é reprovado" run_hygiene "$with_key_block"

with_password="$(new_repo senha)"
printf 'storePassword = "abc123"\n' > "$with_password/build.gradle.kts"
expect_fail "senha fixa no Gradle é reprovada" run_hygiene "$with_password"

with_env_password="$(new_repo senha-env)"
printf 'storePassword = providers.environmentVariable("X").get()\n' > "$with_env_password/build.gradle.kts"
expect_ok "senha lida de variável de ambiente é aceita" run_hygiene "$with_env_password"

# ======================================================================================
echo "== setup-android-sdk.sh =="
sdk2="$work/sdk2"
mkdir -p "$sdk2/cmdline-tools/latest/bin" "$sdk2/platforms"
cat > "$sdk2/cmdline-tools/latest/bin/sdkmanager" <<'FAKE_SDKMANAGER'
#!/usr/bin/env bash
# sdkmanager falso: reproduz o comportamento real de recusar pacotes que não existem.
case " $* " in
  *" --licenses "*)
    head -n 1 > /dev/null   # o sdkmanager real também encerra depois das respostas
    exit 0 ;;
  *" --list_installed "*)
    echo "Installed packages:"
    exit 0 ;;
  *" --list "*)
    echo "Installed packages:"
    echo "  Path | Version | Description | Location"
    echo "  ------- | ------- | ------- | -------"
    for p in ${FAKE_PLATFORMS:-}; do printf '  %s | 1 | Android SDK Platform | platforms/x\n' "$p"; done
    echo "Available Packages:"
    echo "  platforms;android-37.0-ext99 | 1 | extensão | platforms/y"
    exit 0 ;;
  *" --install "*)
    for arg in "$@"; do
      case "$arg" in
        platforms\;*)
          found=0
          for p in ${FAKE_PLATFORMS:-}; do [ "$p" = "$arg" ] && found=1; done
          if [ "$found" -eq 0 ]; then
            echo "Warning: Failed to find package '$arg'" >&2
            exit 1
          fi ;;
      esac
    done
    echo "$*" >> "${FAKE_INSTALL_LOG:?}"
    exit 0 ;;
esac
exit 1
FAKE_SDKMANAGER
chmod +x "$sdk2/cmdline-tools/latest/bin/sdkmanager"

sdk_setup() { # $1 = plataformas disponíveis (ids separados por espaço)
  rm -f "$work/install.log"
  env ANDROID_HOME="$sdk2" PATH="$sdk2/cmdline-tools/latest/bin:$PATH" \
    FAKE_PLATFORMS="$1" FAKE_INSTALL_LOG="$work/install.log" "$root/scripts/setup-android-sdk.sh"
}

expect_ok "API 37 com nome 'android-37.0' (o caso real do runner) é instalada" sdk_setup "platforms;android-36 platforms;android-37.0"
if grep -q 'platforms;android-37\.0' "$work/install.log" 2>/dev/null; then
  ok "o sdkmanager recebe exatamente platforms;android-37.0"
else
  bad "o sdkmanager recebe exatamente platforms;android-37.0"
fi
expect_ok "API 37 com nome antigo 'android-37' também funciona" sdk_setup "platforms;android-37"
if grep -q 'platforms;android-37 \|platforms;android-37$' "$work/install.log" 2>/dev/null; then
  ok "o sdkmanager recebe platforms;android-37 quando é o nome existente"
else
  bad "o sdkmanager recebe platforms;android-37 quando é o nome existente"
fi
expect_fail "sem a plataforma pedida, falha com erro claro" sdk_setup "platforms;android-36"
expect_fail "variante -ext não é aceita no lugar da plataforma" sdk_setup ""

echo ""
echo "Resultado: ${passed} ok, ${failed} falha(s)."
[ "$failed" -eq 0 ]
