# English Lab

Aplicativo Android para aprender inglês (uso individual): currículo por competências, revisão espaçada, escuta e pronúncia. Funciona **offline**, sem anúncios, sem conta e sem IA. Interface em português do Brasil.

**Status:** entrega 1 da Etapa 2, “APK base instalável”. O app mostra o Início de estado do aplicativo (versão, dados locais, funcionamento offline). As funções de estudo chegam nas próximas entregas, uma por vez, cada uma validada antes da seguinte.

## Documentação

- [`docs/PLANO-ARQUITETURA.md`](docs/PLANO-ARQUITETURA.md): arquitetura, modelo de dados, progressão pedagógica, limites de voz, plano de entregas e decisões aprovadas.
- [`docs/ASSINATURA.md`](docs/ASSINATURA.md): assinatura estável do APK com GitHub Secrets (nenhuma chave no repositório).
- [`docs/INSTALACAO.md`](docs/INSTALACAO.md): como baixar e instalar o APK e como validar a entrega.

## Estrutura

```text
core/   lógica pura em Kotlin/JVM (sem Android), testada com JUnit
app/    aplicativo Android (Jetpack Compose, Material 3, Room)
docs/   documentação
scripts/  verificações usadas pelo CI (e seus testes)
.github/workflows/  build (PR sem segredos; APK assinado só na main) e configuração da assinatura
```

## Como compilar

O APK é gerado pelo GitHub Actions (`.github/workflows/build.yml`). Localmente:

```bash
./gradlew :core:test          # lógica pura (precisa só de JDK 17+)
./gradlew :app:assembleDebug  # precisa do Android SDK
scripts/tests/run-all.sh      # testes dos scripts de CI
```

Versões do Gradle, Kotlin e bibliotecas ficam em `gradle/libs.versions.toml`.
