# Assinatura estável do APK (GitHub Secrets)

**Em resumo:** o APK que você instala precisa ser assinado **sempre com a mesma chave**. Se a chave mudar, o Android recusa atualizar por cima e você teria de desinstalar o app, o que **apaga todo o progresso**. A chave fica guardada só nos *secrets* do GitHub (ambiente `release-signing`): nunca no repositório, nunca no chat, nunca nos logs.

## Como o CI trata a assinatura

| Situação | O que acontece |
|---|---|
| Pull request (qualquer branch) | O job `verify` compila e testa **sem acesso a segredos**. O APK é verificado, mas **não é publicado**: ele é assinado com uma chave de debug descartável, que não serve para instalar. |
| Push na `main` ou execução manual na `main` | O job `signed-apk` entra no ambiente `release-signing`, assina com a chave estável e publica o APK como artefato. |
| Qualquer outra branch | O ambiente `release-signing` é restrito à `main`: o GitHub bloqueia o acesso aos segredos, mesmo que alguém altere o workflow. |

Nomes usados: ambiente `release-signing`; secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`; variável `SIGNING_CERT_SHA256` (impressão digital **pública** do certificado). Toda build assinada é comparada com essa variável e **falha** se o certificado for diferente.

## Configuração única (cerca de 15 minutos, pelo navegador do celular)

> Dica: no Chrome do celular, ative **Site para computador** para ver os menus completos do GitHub.
> Os workflows só aparecem na aba **Actions** depois de estarem na branch `main`.

### Passo 1. Criar o ambiente protegido

1. No repositório: **Settings → Environments → New environment**.
2. Nome: `release-signing` → **Configure environment**.
3. Em **Deployment branches and tags**, escolha **Selected branches and tags** → **Add deployment branch or tag rule** → tipo *Branch*, padrão `main` → **Add rule**.

Faça isso **antes** de adicionar qualquer secret.

### Passo 2. Criar um token pessoal temporário

1. Foto de perfil → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. *Token name:* `englishlab-bootstrap`. *Expiration:* **7 days**.
3. *Repository access:* **Only select repositories** → `inglesclaude`.
4. *Permissions → Repository permissions:* **Secrets: Read and write** e **Variables: Read and write**. Nada além disso.
5. **Generate token** e copie o valor (ele só aparece uma vez).

### Passo 3. Guardar o token no ambiente

Repositório → **Settings → Environments → release-signing → Add environment secret**: nome `BOOTSTRAP_TOKEN`, valor = o token copiado.

### Passo 4. Gerar a chave

**Actions → Configurar assinatura (uma vez) → Run workflow**, na branch `main`, com `rotate` **desmarcado**. Se preferir, peça no chat que eu dispare o workflow e acompanhe a execução.

O workflow cria o keystore **dentro do runner**, grava os 4 secrets e a variável no ambiente e imprime só o SHA-256 do certificado (informação pública). A senha e o keystore não aparecem nos logs. Se a chave já existir, ela **não** é sobrescrita.

### Passo 5. Limpar

1. Apague o secret `BOOTSTRAP_TOKEN` do ambiente.
2. Apague o token pessoal (**Developer settings → Fine-grained tokens → Delete**).

### Passo 6. Gerar o primeiro APK assinado

**Actions → Build → Run workflow** na `main` (ou faça um merge na `main`). Ao terminar, o resumo da execução mostra o SHA-256 do certificado e o APK fica em **Artifacts**. Depois, siga `docs/INSTALACAO.md`.

## Como conferir que a assinatura é estável

- O resumo de cada execução do `signed-apk` mostra o **SHA-256 do certificado**. Tem de ser **o mesmo** em todas as builds.
- Esse valor também está na variável `SIGNING_CERT_SHA256` do ambiente. Se uma build sair com outro certificado, ela **falha** antes de publicar o APK.
- No celular: depois de instalar uma build, instale a seguinte **por cima**, sem desinstalar. Se o Android aceitar, a assinatura está estável.

## Alternativa, se você tiver um computador

Gere o keystore com o `keytool` (fora do repositório) e cadastre os secrets à mão no ambiente:

```bash
keytool -genkeypair -keystore englishlab.p12 -storetype PKCS12 -alias englishlab \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 englishlab.p12        # no macOS: base64 -i englishlab.p12
keytool -list -v -keystore englishlab.p12 -alias englishlab | grep SHA256
```

Secrets: `KEYSTORE_BASE64` (saída do `base64`), `KEYSTORE_PASSWORD`, `KEY_ALIAS` (`englishlab`) e `KEY_PASSWORD` (a mesma senha: o formato PKCS12 exige). Variável: `SIGNING_CERT_SHA256` (o valor do SHA256 impresso). Guarde uma cópia do `.p12` e da senha em local seguro **fora** do repositório.

## Se a chave se perder ou for trocada

Não há como ler os secrets de volta. Se o ambiente ou o repositório forem apagados, a chave some. Trocar a chave (`rotate = true`) tem o mesmo efeito: o app instalado **não** poderá ser atualizado por cima. Será preciso desinstalar (isso apaga os dados locais) e instalar a nova build.

Por isso a exportação/importação de progresso (entrega 5.5) é importante. Até lá, os dados do app são só de teste.

Se você registrar o app no Google (veja `docs/INSTALACAO.md`), perder a chave também afeta o registro.

## O que nunca fazer

- Commitar `.p12`, `.jks`, `.keystore` ou senhas. O `.gitignore` bloqueia, e o CI (`scripts/check-repo-hygiene.sh`) **reprova** o push.
- Colar senha, keystore ou token em chat, issue ou comentário de PR.
- Deixar o `BOOTSTRAP_TOKEN` guardado depois do passo 4.
