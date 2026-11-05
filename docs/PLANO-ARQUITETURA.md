# English Lab — Plano de arquitetura (Etapa 1)

**Status:** proposta aguardando aprovação · **Data:** 05/11/2026 · **Escopo:** planejamento. Nenhum código do aplicativo foi escrito.

Convenções propostas: interface e explicações em pt-BR; identificadores de código em inglês; comentários, KDoc e documentação em pt-BR. Este documento é atualizado a cada etapa; decisões arquiteturais importantes ficam registradas na seção 2.6.

**Sumário:** [0. Resumo](#0-resumo) · [1. Análise crítica](#1-análise-crítica) · [2. Arquitetura](#2-arquitetura) · [3. Pastas](#3-estrutura-de-pastas) · [4. Modelo de dados](#4-modelo-de-dados-room) · [5. Progressão](#5-progressão-pedagógica) · [6. Voz](#6-reconhecimento-de-voz-limites-reais) · [7. Plano](#7-plano-de-desenvolvimento) · [8. Decisões](#8-decisões-pendentes) · [Anexos](#anexo-a--esboço-do-workflow)

---

## 0. Resumo

- **Viável como especificado:** currículo por competências, revisão espaçada, persistência offline em Room, TTS, reconhecimento de voz com comparação de transcrições, avaliações por habilidade, relatórios e APK gerado no GitHub Actions.
- **Não funciona como escrito** (seção 1.2): corrigir qualquer frase digitada sem IA; “avaliar pronúncia” com o `SpeechRecognizer`; e “conseguir conversar” usando só o app. Para cada ponto há uma alternativa honesta.
- **Arquitetura:** Kotlin + Compose + Material 3 + Room. Dois módulos Gradle (`:core` em Kotlin puro, `:app` Android). MVVM com fluxo unidirecional. DI manual. Conteúdo em JSON validado no CI e semeado no Room com IDs estáveis. Tentativas imutáveis e estado derivado recalculável.
- **Pedagogia:** competências medidas por acerto **e retenção**; revisão espaçada (SM-2 adaptado); avaliação de 4 semanas por habilidade com limiares configuráveis; sessão diária de 45 min que se adapta ao que você precisa reforçar.
- **Ambiente:** o sandbox desta sessão não alcança `dl.google.com`, então o app Android só compila no GitHub Actions (a lógica pura compila e testa aqui). O repositório remoto está vazio e o **push foi recusado (403)**: o app Claude do GitHub ainda não tem acesso de escrita. Isso precisa ser resolvido antes da Etapa 2 (decisão 1).
- **Próximo passo:** sua aprovação (seção 8): seis decisões, cada uma com um padrão recomendado.

---

## 1. Análise crítica

### 1.1 Fatos verificados no ambiente (05/11/2026)

| Item | Resultado | Consequência |
|---|---|---|
| Repositório remoto | Vazio, sem nenhuma branch | O primeiro push define a branch padrão. O gatilho “push em `main`” só funciona depois que `main` existir (decisão 1). |
| Push para o GitHub | **Recusado (403):** o app Claude do GitHub não tem acesso de escrita a `clviniciuslj/inglesclaude` | Nada foi enviado: este documento está commitado só dentro do container da sessão. Sem escrita não há CI nem APK (decisão 1). |
| Android SDK no sandbox | Ausente. `dl.google.com` (AGP, AndroidX, Compose, Room e SDK) é bloqueado pela rede da sessão | `:app` só compila no Actions, a menos que você libere o host (decisão 5). |
| JDK e Gradle no sandbox | JDK 21; Gradle 9.8.2 baixa normalmente pelo wrapper | A lógica pura (`:core`) compila e testa localmente. |
| Maven Central no sandbox | Responde `429` (limite por IP). O espelho do Google funciona | Uso um *init script* só do sandbox, fora do repositório. Não afeta o CI. |
| Teste de viabilidade | Gradle 9.8.2 + Kotlin 2.4.21 + JDK 21: um módulo Kotlin puro compilou e passou 4 testes, incluindo `I work every day` × `I works every day` | Valida a estratégia de `:core` testável localmente. Código descartável, fora do repositório. |
| Leitura do CI | As ferramentas GitHub da sessão listam execuções e logs do Actions | Posso diagnosticar falhas de build sem depender de você. |

Versões estáveis lidas hoje (a Etapa 2 fixa tudo em `gradle/libs.versions.toml` e o CI confirma a compatibilidade):

| Componente | Versão | Observação |
|---|---|---|
| Gradle | 9.8.2 | `services.gradle.org/versions/current` |
| Kotlin | 2.4.21 | O compilador do Compose vem como plugin do próprio Kotlin |
| KSP | 2.3.13 | Para o Room |
| Coroutines | 1.11.0 | |
| AGP | série 9.x | 9.0 exige Gradle ≥ 9.1, traz Kotlin embutido (sem plugin `kotlin-android`) e DSL nova. Tutoriais de AGP 8 não servem. Número exato fixado na Etapa 2 (o Google Maven não é acessível daqui). Plano B: última 8.x |
| Compose / Material 3 | Compose 1.12.x; Material 3 1.4.0 (1.5 em beta) | BOM fixado na Etapa 2 |
| Room | 2.8.x (2.8.4 foi a última estável que encontrei) | Room 3.0 ainda em RC: não usar |
| Navigation | Navigation 3 estável (1.2.0); Navigation Compose 2.x estável | Ver ADR-10 |
| JUnit | 4.13.2 | Robolectric exige JUnit 4 |

### 1.2 Requisitos que não funcionam como escritos

1. **Corrigir qualquer frase digitada** (exemplo “She work every day.”). Sem IA não existe corretor gramatical geral, offline e gratuito, de boa qualidade.
   **Decisão:** exercícios de resposta fechada ou semifechada (múltipla escolha, lacuna, ordenar palavras, digitar com respostas aceitas) e **detectores por regras** para padrões previstos (terceira pessoa com -s, *to be*, auxiliar *do/does*, ordem das perguntas, *a/an*, plural, passado regular/irregular). Texto livre sem gabarito vira **autoavaliação** contra uma resposta-modelo e **não conta** como evidência de domínio. Erro fora do catálogo é registrado como “não classificado”, mostrando a diferença para a resposta aceita mais próxima.

2. **Avaliar pronúncia.** O `SpeechRecognizer` devolve texto, não qualidade fonética, e ainda “corrige” a fala com um modelo de linguagem (pode devolver *I work* quando você disse *I works*).
   **Decisão:** mostrar apenas **o que o reconhecedor entendeu**, palavra a palavra; **sem nota de 0 a 100**; um erro só vira “problema persistente” depois de se repetir; o tipo de dados do resultado nem tem campo de nota (seções 2.5 e 6).

3. **Reconhecimento de voz offline.** Por padrão o Android pode enviar o áudio a servidores do Google. Offline exige pacote de idioma baixado e depende do aparelho (seção 6).

4. **TTS offline e “sotaques”.** A voz inglesa offline precisa estar instalada (aparelho em pt-BR nem sempre tem). A voz é sintética, com poucos sotaques; heterônimos (*read*, *live*) podem sair errados. O Ciclo 5 (“diferentes velocidades e sotaques”) fica **aproximado**: vozes en-US/en-GB/en-AU/en-IN quando instaladas, mais velocidades. Áudio humano gravado fica como extensão futura (peso do APK e licenças).

5. **“Conseguir conversar”.** Sem IA nem outra pessoa, o app não cria conversa real.
   **Decisão:** treinar o que sustenta a conversa (compreensão, vocabulário, blocos prontos de frases, pronúncia, produção oral guiada) e usar **diálogos roteirizados** nos Ciclos 4–6: o app fala a fala do interlocutor (TTS) e você responde dentro de variantes aceitas. É determinístico, rotulado como simulação e não é chatbot. Recomendo complementar com conversa real fora do app (troca de idiomas ou tutor).

6. **24 semanas × 45 min.** São cerca de 126 h se você estudar os 7 dias (cerca de 90 h em 5 dias). Para ir de A2 a B1 costuma-se citar algo na casa de 150–200 h (as fontes variam muito). Já está previsto como “referência”: o app mostra a **posição no currículo** e uma **faixa CEFR aproximada, rotulada como estimativa**. Além disso, a prova de retenção estica os ciclos: o conteúdo da última semana só pode ser “consolidado” alguns dias depois de aprendido.

7. **Produção oral nas avaliações.** Mede, no máximo, repetição/leitura **reconhecida**. Rótulo explícito, limiar menor e, sem reconhecedor disponível, “não avaliado” (não bloqueia o avanço).

8. **Volume e confiabilidade do conteúdo.** Seis ciclos com rotina completa são milhares de itens, todos escritos por mim, e em A1/A2 você não consegue revisá-los bem.
   **Decisão:** motor + **Ciclo 1 completo** primeiro; Ciclos 2–6 em pacotes entregues antes de você chegar neles; validações automáticas no CI (gabaritos consistentes, referências íntegras, **vocabulário controlado por ciclo**: nenhuma palavra “fora do nível” nos exemplos); conteúdo autoral (sem problema de licença); revisão por amostragem com você.

9. **APK de debug do Actions e perda de progresso.** O runner cria uma chave de debug nova a cada execução. O Android recusa instalar por cima (conflito de assinatura) e você teria de desinstalar, **apagando o banco com todo o progresso**.
   **Decisão:** assinatura estável (decisão 2) + exportar/importar progresso como rede de segurança.

10. **APK de debug é mais lento** (sem R8, Compose em modo debug). Para uso diário o ideal é um release assinado; entra documentado na Etapa 6.

11. **Entrega do APK.** O artefato do Actions baixa como `.zip`, exige login e expira (padrão de 90 dias). Opcional futuro: publicar também numa Release “latest”.

12. **Gatilhos do CI.** O botão manual (`workflow_dispatch`) só aparece com o arquivo na branch padrão, e “push em `main`” não roda sem `main`. Proponho acrescentar `pull_request` → `main` para validar antes do merge (decisão 5).

13. **“Palavras desconhecidas”.** Só dá para traduzir palavras dos textos que escrevemos (glossário por texto + catálogo). Não existe dicionário offline geral. O toque na palavra mostra o glossário do conteúdo.

14. **Nível “A1/A2, ainda não avaliado”.** Precisa de um **teste de nivelamento** (usa o mesmo motor das avaliações). Competências puladas ficam *provisórias* até serem confirmadas por revisões espaçadas.

15. **Notificações.** Nenhuma no MVP. Um lembrete diário só se você quiser: opt-in e desligado por padrão.

### 1.3 Funciona offline?

| Recurso | Sem internet? | Observação / alternativa |
|---|---|---|
| Lições, exercícios, vocabulário, revisões, avaliações, relatórios, progresso | Sim, 100% local | O manifesto não declara `INTERNET` (o CI verifica) |
| Voz do app (TTS) | Sim, se a voz inglesa offline estiver instalada | Instalar exige internet uma vez; o diagnóstico de voz guia |
| Reconhecimento de voz | Depende | Pacote offline instalado → funciona. Senão → modo de autoavaliação (seção 6) |
| Backup e restauração | Sim (arquivo local) | Sem nuvem |
| Baixar o APK | Não | Via GitHub |

### 1.4 Riscos principais (por ordem de impacto)

1. **Acesso de escrita ao GitHub não concedido** (hoje recusado, 403). Bloqueia push, CI e APK. Mitigação: decisão 1.
2. **Reconhecimento de voz varia entre aparelhos.** Mitigação: spike de voz já na Etapa 2 (entrega 2.4), contratos por interface, modo de autoavaliação.
3. **Qualidade e volume do conteúdo.** Mitigação: fatiar por ciclo, validadores no CI, revisão por amostragem.
4. **Ciclo de build lento** (sem SDK local). Mitigação: `:core` testado localmente; CI com leitura de logs; liberar `dl.google.com` (decisão 5).
5. **Perda de progresso** (assinatura, migração, troca de aparelho). Mitigação: assinatura estável, migrações testadas, exportar/importar.
6. **Limiares pedagógicos não calibrados.** Mitigação: tudo em `ProgressionPolicy`; calibrar com dados reais no primeiro checkpoint.
7. **Compatibilidade de plugins com AGP 9** (KSP, Compose). Mitigação: fixar versões e validar no CI já na entrega 2.1; plano B: AGP 8.x.
8. **Escopo.** Mitigação: regra “sem tela sem funcionalidade real”; cada aba só entra na barra quando funciona.

---

## 2. Arquitetura

### 2.1 Princípios

- Offline-first, sem backend, sem permissão `INTERNET`.
- Lógica pedagógica em Kotlin puro (`:core`), testável sem Android.
- Fonte única de verdade: tentativas imutáveis. O estado derivado (revisão espaçada, maestria) é projeção recalculável.
- Conteúdo é separado de progresso: IDs estáveis; atualizar conteúdo nunca apaga progresso.
- Serviços da plataforma (voz, relógio) atrás de interfaces.
- Honestidade de medição: os tipos impedem exibir nota onde não há medição.
- Simplicidade: sem injeção de dependência por framework, sem multi-módulo por feature.
- Fora de escopo por decisão: chatbot/IA, backend, contas, anúncios, gamificação além de sequência e progresso.

### 2.2 Stack

| Camada | Escolha |
|---|---|
| Linguagem | Kotlin 2.4.x (plugin do Compose do próprio Kotlin) |
| Build | Gradle 9.8.x (wrapper), AGP 9.x, KSP 2.3.x, catálogo de versões, JDK 21 (mínimo 17) |
| Interface | Jetpack Compose + Material 3, paleta fixa sóbria (claro/escuro/sistema), sem cores dinâmicas |
| Navegação | Navigation Compose, rotas tipadas |
| Estado | ViewModel + `StateFlow` |
| Persistência | Room 2.8.x (KSP) |
| Serialização | kotlinx.serialization (conteúdo e exportação) |
| Assíncrono | Coroutines/Flow |
| Injeção | Manual (`AppContainer`) |
| Voz | `TextToSpeech` e `SpeechRecognizer` do Android |
| Testes | JUnit 4 + `kotlin.test`; Robolectric para Room no `:app` |
| SDK | `minSdk 26` (Android 8.0); compile/target = último estável disponível no runner |

Todas as bibliotecas são de código aberto (Apache-2.0, MIT ou BSD) e gratuitas. Sem Firebase, sem Play Services, sem analytics.

### 2.3 Camadas e módulos

```text
┌──────────────────────────── :app (Android) ────────────────────────────┐
│ ui/        Compose + ViewModels (StateFlow<UiState>)                    │
│ data/      Room (entidades, DAOs), repositórios, semeadura, backup      │
│ platform/  TTS, STT, relógio, tempo ativo  (implementam contratos)      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ depende de (nunca o contrário)
┌───────────────────────────────▼─────────────────────────────────────────┐
│ :core  (Kotlin/JVM puro, sem Android)                                    │
│ srs · progress · planner · assessment · text · speech · content          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Fluxo central: da tentativa ao aprendizado

```text
Exercício exibido ──► resposta do aluno ──► AnswerChecker / TranscriptComparator (:core)
                                                   │ resultado + padrões de erro detectados
                                                   ▼
                          AttemptRecorder (:app) grava, numa transação:
                          attempt (+ error_event, pronunciation_attempt, listening_attempt)
                                                   │
                recalcula as projeções (:core): review_state (SRS) ·
                competency_progress (maestria) · estado dos padrões de erro
                                                   │
        SessionPlanner · UnlockEvaluator · ReportBuilder leem as projeções
                                                   ▼
                 próxima sessão, Início, desbloqueios, avaliações e relatórios
```

O mesmo `ExerciseHost` renderiza exercícios na sessão diária, na prática livre e nas avaliações (nas avaliações o feedback é adiado para o fim).

### 2.5 Contratos de voz e avaliação (em `:core`, sem tipos do Android)

```kotlin
interface SpeechSynthesizer {
    suspend fun availability(): TtsAvailability       // voz inglesa offline instalada? precisa baixar?
    suspend fun speak(text: String, rate: Float = 1f, accent: Accent = Accent.US): SpeakResult
    fun stop()
}

interface SpeechRecognitionEngine {
    suspend fun availability(): SttAvailability       // permissão, serviço, offline, idioma
    fun listen(language: String = "en-US", preferOffline: Boolean = true): Flow<RecognitionEvent>
}

sealed interface RecognitionEvent {
    data object Ready : RecognitionEvent
    data class Partial(val text: String) : RecognitionEvent
    data class Final(val hypotheses: List<Hypothesis>) : RecognitionEvent  // texto + confiança opcional
    data class Failed(val reason: SttFailure) : RecognitionEvent
}

interface PronunciationEvaluator {
    fun evaluate(expected: String, heard: RecognitionResult): PronunciationFeedback
}

sealed interface PronunciationFeedback {
    /** Hoje: só comparação de transcrições. Este tipo não tem campo de nota. */
    data class Transcript(val words: List<WordFeedback>) : PronunciationFeedback
    /** Reservado para o futuro: só um avaliador acústico real pode produzir pontuações. */
    data class Acoustic(val words: List<WordFeedback>, val phonemeScores: List<PhonemeScore>) : PronunciationFeedback
}

enum class WordStatus { CORRECT, OMITTED, SUBSTITUTED, EXTRA, HOMOPHONE_AMBIGUOUS }
```

A interface só mostra pontuação para `Acoustic`. Incorporar um avaliador fonético no futuro é trocar a implementação de `PronunciationEvaluator`, sem tocar no resto e sem custo agora.

### 2.6 Decisões arquiteturais (ADR curtos)

- **ADR-1 · Dois módulos.** `:core` (Kotlin/JVM) + `:app`. Toda a lógica pedagógica testável em segundos, local e no CI; a fronteira impede que regras dependam de Android. Descartados: módulo único (testes só com SDK); um módulo por feature (excesso para app solo).
- **ADR-2 · MVVM com fluxo unidirecional e DI manual.** Descartados: Hilt/Koin (build mais lento e mais dependências sem ganho neste tamanho).
- **ADR-3 · Conteúdo em JSON no repositório, semeado no Room.** IDs estáveis; semeadura idempotente com `@Upsert`; validador no CI. Descartados: conteúdo em código Kotlin (difícil de validar e revisar); banco pré-populado (opaco, sem diff).
- **ADR-4 · Log imutável + projeções.** `attempt` é append-only; `review_state` e `competency_progress` são derivados e reconstruíveis. Permite mudar algoritmos e limiares sem perder histórico.
- **ADR-5 · Voz atrás de interfaces; resultado sem nota** (seção 2.5).
- **ADR-6 · SM-2 adaptado, não FSRS.** Mais simples de testar e explicar; `SrsScheduler` é uma interface. FSRS pode ser avaliado depois com dados reais.
- **ADR-7 · Política de progressão configurável.** Todos os limiares em `ProgressionPolicy`; testes fixam o comportamento.
- **ADR-8 · Esquema evolutivo, nunca destrutivo.** Esquemas exportados e versionados; migrações testadas; sem `fallbackToDestructiveMigration`; progresso exportável.
- **ADR-9 · Preferências no Room (linha única).** Um só caminho de backup. Descartado: DataStore (segundo armazenamento).
- **ADR-10 · Navigation Compose com rotas tipadas.** Maduro e suficiente para 5 abas + fluxos em tela cheia. Navigation 3 também é estável; aqui o ganho é pequeno e errar a API custa caro com feedback de compilação lento. Revisável.
- **ADR-11 · Sem `INTERNET`.** O app não acessa a rede; só o serviço de voz do sistema pode. Verificação automática do manifesto mesclado no CI.

### 2.7 Navegação e interface

- **Barra inferior (M3) com 5 abas:** Início · Aprender · Vocabulário · Escutar · Pronúncia. Cada aba só aparece quando tem funcionalidade real.
- **Telas cheias (sem barra):** Sessão diária, Lição, Prática, Avaliação, Relatório, Configurações (engrenagem no Início), Diagnóstico de voz, Backup.
- **Início (no máximo 5 cartões):** Sessão de hoje · Posição no currículo e nível · Sequência e tempo de estudo · Revisões pendentes · Próxima lição e desempenho recente.
  - *Sequência:* dias consecutivos com pelo menos 10 min de estudo ativo (configurável), mais a melhor sequência. Sem “perder vidas”.
  - *Tempo de estudo:* tempo **ativo** (pausa em segundo plano e após 60 s sem interação).
  - *Desempenho recente:* acerto por habilidade nos últimos 7 dias, sempre com o número de itens.
  - *Nível:* posição no currículo (ciclo, unidade, % de competências consolidadas) + faixa CEFR aproximada, rotulada como estimativa.
- **Acessibilidade:** alvos de toque ≥ 56 dp, texto em `sp` respeitando a escala do sistema, contraste AA, status nunca só por cor (ícone + texto), `contentDescription` nos botões de áudio e microfone.

### 2.8 Estratégia de testes

- **`:core` (JUnit 4):** revisão espaçada, maestria e desbloqueio, planejador, pontuação e relatório de avaliações, normalizador, alinhador, verificador de respostas, regras de erro, validador de conteúdo. Inclui simulações determinísticas (por exemplo, 30 dias de estudo) e propriedades (intervalos nunca menores que 1 dia; `ease` dentro dos limites).
- **`:app` (JVM + Robolectric):** DAOs e consultas críticas, semeadura idempotente, migrações, exportação/importação, `AttemptRecorder`.
- **Conteúdo:** todos os JSON validados a cada execução do CI.
- **Aparelho (manual, com protocolo escrito):** voz (TTS/STT), modo avião, acessibilidade, desempenho.

---

## 3. Estrutura de pastas

```text
inglesclaude/
├── .github/workflows/build.yml
├── .gitignore · README.md
├── settings.gradle.kts · build.gradle.kts · gradle.properties
├── gradle/            libs.versions.toml · wrapper/
├── gradlew · gradlew.bat
├── docs/
│   ├── PLANO-ARQUITETURA.md     este documento
│   ├── CURRICULO.md             mapa ciclo → unidade → competência
│   ├── FORMATO-CONTEUDO.md      esquema do JSON + regras do validador
│   └── RELEASE.md               release assinado sem segredos no repositório
├── core/                        Kotlin/JVM puro (testes rodam sem Android)
│   ├── build.gradle.kts
│   └── src/
│       ├── main/kotlin/io/github/clviniciuslj/englishlab/core/
│       │   ├── model/        Skill, Grade, ExerciseType, identificadores
│       │   ├── srs/          SrsScheduler, SrsState, SrsConfig
│       │   ├── progress/     ProgressionPolicy, MasteryEvaluator, UnlockEvaluator
│       │   ├── planner/      SessionPlanner, TimeBudget, PriorityScorer
│       │   ├── assessment/   AssessmentBuilder, AssessmentScorer, ReportBuilder
│       │   ├── text/         TextNormalizer, WordAligner, AnswerChecker, ErrorRules
│       │   ├── speech/       contratos (2.5) + TranscriptComparator
│       │   └── content/      DTOs do JSON + ContentValidator
│       └── test/kotlin/…     espelha main/
└── app/
    ├── build.gradle.kts
    ├── schemas/                 esquemas do Room exportados (versionados)
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml
        │   ├── assets/content/  JSON do currículo (c1/, c2/, … e error_patterns.json)
        │   ├── res/             strings pt-BR, tema, ícone
        │   └── kotlin/io/github/clviniciuslj/englishlab/
        │       ├── EnglishLabApp.kt · MainActivity.kt · AppContainer.kt
        │       ├── data/
        │       │   ├── db/          EnglishLabDatabase, entity/, dao/, converter/, migration/
        │       │   ├── content/     ContentSeeder
        │       │   ├── repository/  catálogo, progresso, sessões, avaliações
        │       │   └── backup/      ProgressExporter, ProgressImporter
        │       ├── platform/        tts/ · stt/ · clock/ · activetime/
        │       └── ui/
        │           ├── theme/ · navigation/ · components/
        │           ├── exercise/    ExerciseHost + renderizadores por tipo
        │           └── home/ learn/ vocab/ listen/ pronounce/ session/ assessment/ settings/
        ├── test/                JVM + Robolectric
        └── androidTest/         opcional (execução manual em aparelho)
```

O identificador `io.github.clviniciuslj.englishlab` é a proposta da decisão 3.

---

## 4. Modelo de dados (Room)

### 4.1 Princípios do esquema

- **Dois grupos de tabelas:** *catálogo* (somente leitura, semeado do JSON) e *estado do aluno* (a semeadura nunca toca nele).
- **IDs de conteúdo são strings estáveis** (`c1.tobe.aff`, `w.apple`), não autoincremento.
- **Sem chave estrangeira do estado para o catálogo** (referência por ID). Motivo: `REPLACE` + `ON DELETE CASCADE` apagaria progresso. A semeadura usa `@Upsert`. Chaves estrangeiras só dentro de cada grupo.
- **Tempos** em epoch ms (UTC) mais `localDate` (`yyyy-MM-dd`) gravado na hora, para sequência e relatórios não quebrarem com fuso ou horário de verão. O “dia de estudo” vira às 04:00.
- **JSON em colunas `TEXT`** só para conteúdo lido por inteiro (corpo da lição, payload do exercício). O que se consulta é relacional.
- **`attempt` é append-only.** `review_state` e `competency_progress` são projeções reconstruíveis (“Recalcular progresso”).
- **Evolução:** `exportSchema = true`, `AutoMigration`/`Migration` testadas, nunca destrutivo.

### 4.2 Relacionamentos

```text
CATÁLOGO
cycle 1─* unit 1─* competency ┬─1─* lesson
                              ├─1─* exercise ··(opcional)··> listening_item / reading_passage / phrase
                              ├─1─* phrase
                              └─1─* word            (introduzida na competência)
listening_item 1─* listening_segment        error_pattern *─0..1 competency

ESTADO DO ALUNO                (·· = referência por ID ao catálogo, sem FK)
study_session 1─* session_block
study_session 1─* attempt *─0..1 assessment 1─* assessment_skill_result
attempt 1─* error_event
attempt 1─0..1 pronunciation_attempt        attempt 1─0..1 listening_attempt
review_state (itemType,itemId)··>  word / phrase / error_pattern / listening_item
competency_progress ··> competency          lesson_progress ··> lesson
lookup_event ··> word                       user_settings (linha única)
```

### 4.3 Tabelas do catálogo

- `cycle`: `id` PK, `ordinal`, `title`, `summaryPt`, `targetWeeks`, `cefrBand`.
- `unit`: `id` PK, `cycleId` FK, `ordinal`, `title`, `summaryPt`. Índice `(cycleId, ordinal)`.
- `competency`: `id` PK, `unitId` FK, `ordinal`, `title`, `canDoPt` (“Consigo…”), `required`, `primarySkill`. Índice `(unitId, ordinal)`.
- `lesson`: `id` PK, `competencyId` FK, `ordinal`, `title`, `estimatedMin`, `bodyJson`. Índice `(competencyId, ordinal)`.
- `word`: `id` PK, `lemma`, `pos`, `translationPt`, `ipa?`, `respellingPt?` (pronúncia aproximada, só apoio), `exampleEn`, `examplePt`, `category`, `cefr`, `introducedIn` (competência), `formsJson`. Índices em `category`, `introducedIn`, `lemma`.
- `phrase`: `id` PK, `textEn`, `translationPt`, `notePt?`, `competencyId`, `difficulty`, `kind`, `glossJson?`. Índice `(competencyId, difficulty)`.
- `exercise`: `id` PK, `competencyId`, `type`, `skill`, `difficulty`, `pool` (`PRACTICE` ou `ASSESSMENT`: itens de avaliação nunca aparecem na prática), `primaryPatternId?`, `refType?`, `refId?`, `payloadJson`. Índices `(competencyId, type)`, `(skill, difficulty)`, `(primaryPatternId)`.
- `listening_item`: `id` PK, `kind` (`WORD`, `SENTENCE`, `DIALOGUE`, `SCENARIO`), `title`, `competencyId?`, `difficulty`, `rateHint`, `accentHint`.
- `listening_segment`: `itemId` FK, `ordinal`, `speaker`, `textEn`, `translationPt`. PK `(itemId, ordinal)`. Palavra e frase têm 1 segmento; diálogo tem N falas.
- `reading_passage`: `id` PK, `title`, `textEn`, `translationPt`, `competencyId`, `difficulty`, `glossJson`.
- `error_pattern`: `id` PK (ex.: `gram.simple_present.third_person_s`), `category`, `topic` (ex.: “Simple Present”), `titlePt`, `explanationPt`, `competencyId?`, `wrongExample`, `rightExample`.
- `content_meta`: `key` PK, `value` (`contentVersion`, `seededAt`).

### 4.4 Tabelas do estado do aluno

- `user_settings` (linha única, `id = 1`): `dailyMinutes` (45), `blockWeightsJson`, `theme`, `speechRate`, `ttsVoice?`, `preferOfflineStt`, `dayRolloverHour` (4), `onboardingDone`, `placementDone`, `createdAt`.
- `study_session`: `id` PK, `startedAt`, `endedAt?`, `localDate`, `mode` (`DAILY`, `FREE`, `ASSESSMENT`), `plannedMin`, `activeMs`, `planJson`. Índice `(localDate)`.
- `session_block`: `sessionId` FK, `ordinal`, `type` (`REVIEW`, `NEW`, `GRAMMAR`, `LISTENING`, `PRONUNCIATION`), `plannedSec`, `activeMs`, `status` (`PLANNED`, `DONE`, `SKIPPED`), `items`. PK `(sessionId, ordinal)`.
- **`attempt` (tabela de fatos):** `id` PK, `sessionId?`, `assessmentId?`, `at`, `localDate`, `source` (`DAILY`, `FREE`, `ASSESSMENT`, `PLACEMENT`), `exerciseId?`, `exerciseType`, `skill`, `competencyId`, `targetType?`, `targetId?`, `correct`, `grade` (`AGAIN`, `HARD`, `GOOD`, `EASY`), `responseMs`, `hintUsed`, `userAnswer?`, `expectedAnswer?`. Índices `(competencyId, at)`, `(targetType, targetId, at)`, `(localDate)`, `(skill, at)`, `(assessmentId)`.
- `error_event`: `id` PK, `attemptId` FK (CASCADE), `at`, `category` (`GRAMMAR`, `VOCABULARY`, `LISTENING`, `SENTENCE`, `PRONUNCIATION`, `SPELLING`), `patternId?`, `competencyId`, `userAnswer`, `correctAnswer`, `detailJson?`. Índices `(patternId, at)`, `(competencyId, at)`.
- `pronunciation_attempt`: `attemptId` PK/FK, `phraseId`, `expectedText`, `recognizedText?`, `alternativesJson?`, `wordResultsJson`, `engineId`, `onDevice?`, `evidenceKind`. O `engineId` impede misturar resultados de motores diferentes no futuro.
- `listening_attempt`: `attemptId` PK/FK, `listeningItemId`, `plays`, `slowPlays`, `transcriptViewed`, `transcriptBeforeAnswer`, `translationViewed`, `translationBeforeAnswer`. Pedir a tradução antes de tentar é registrado como sinal de dificuldade.
- `lookup_event`: `id` PK, `at`, `token`, `wordId?`, `contextType`, `contextId`. Toque em palavra desconhecida; alimenta o vocabulário.
- `review_state`: `itemType` (`WORD`, `PHRASE`, `PATTERN`, `LISTENING`), `itemId`, `status` (`NEW`, `LEARNING`, `REVIEW`, `RELEARNING`), `ease`, `intervalDays`, `dueAt`, `repetitions`, `lapses`, `correctCount`, `wrongCount`, `consecutiveCorrect`, `lastReviewedAt?`, `firstSeenAt`, `lastGrade?`, `leech`. PK `(itemType, itemId)`; índice `(dueAt)`.
- `competency_progress`: `competencyId` PK, `status` (`NOT_STARTED`, `LEARNING`, `PRACTICING`, `CONSOLIDATED`, `MASTERED`), `recentAccuracy`, `delayedRecallRate`, `attemptsTotal`, `provisional`, `updatedAt`, `firstConsolidatedAt?`.
- `lesson_progress`: `lessonId` PK, `status`, `lastStep`, `completedAt?`.
- `assessment`: `id` PK, `kind` (`PLACEMENT`, `CHECKPOINT`, `FINAL`), `cycleId`, `status`, `seed`, `startedAt`, `finishedAt?`, `planJson` (itens sorteados, para retomar), `reportJson?` (relatório congelado, não muda se os limiares mudarem depois).
- `assessment_skill_result`: `assessmentId` FK, `skill`, `total`, `correct`, `percent`, `thresholdPercent`, `outcome` (`ATTAINED`, `REINFORCE`, `NOT_ASSESSED`). PK `(assessmentId, skill)`.

### 4.5 Do requisito à tabela

| O app precisa registrar | Onde |
|---|---|
| Erros gramaticais | `error_event` (`GRAMMAR`) + `error_pattern` |
| Palavras desconhecidas | `lookup_event`, `review_state` (`WORD`), tentativas erradas |
| Dificuldades de compreensão | `listening_attempt` (repetições, lenta, transcrição/tradução antes da resposta) |
| Erros de construção de frases | `error_event` (`SENTENCE`) |
| Exercícios realizados, taxa de acerto, tempo de resposta | `attempt` (derivados por consulta; `responseMs`) |
| Evolução por competência | `competency_progress` + série semanal calculada de `attempt` |
| Lições concluídas | `lesson_progress` |
| Palavras aprendidas e revisões pendentes | `review_state` (`dueAt`) |
| Resultados de avaliações | `assessment` + `assessment_skill_result` |
| Preferências | `user_settings` |

**Exemplo do enunciado.** O aluno escreve “She work every day.”: grava-se um `attempt` incorreto e um `error_event` com `category = GRAMMAR`, `patternId = gram.simple_present.third_person_s` (cujo `topic` é “Simple Present”), `userAnswer = "She work every day."` e `correctAnswer = "She works every day."`. A “frequência de repetição do erro” é derivada (contagem por padrão numa janela de tempo) e alimenta `review_state` (`PATTERN`), que influencia os próximos exercícios.

Volume esperado: centenas de tentativas por dia, bem abaixo de dezenas de MB mesmo após anos.

### 4.6 Backup e exportação

JSON apenas com o **estado do aluno** (o catálogo é reconstruído a partir do app), com `schemaVersion` e `contentVersion`. Usa o seletor de arquivos do sistema (`CreateDocument`/`OpenDocument`), sem permissão de armazenamento. A importação valida e pede confirmação. O backup automático do Android (`allowBackup`) é só complemento, não garantia para APKs instalados fora da Play Store.

### 4.7 Formato do conteúdo (JSON) — exemplo mínimo

```json
{
  "competency": {
    "id": "c1.tobe.aff", "unitId": "c1.u03", "ordinal": 1, "required": true,
    "title": "To be — afirmativa", "canDoPt": "Consigo dizer quem sou e como estou.",
    "primarySkill": "GRAMMAR"
  },
  "exercises": [
    {
      "id": "c1.tobe.aff.cloze.001", "type": "CLOZE", "skill": "GRAMMAR",
      "difficulty": 1, "pool": "PRACTICE",
      "prompt": { "textEn": "She ___ a teacher.", "hintPt": "Ela é professora." },
      "accepted": ["is"],
      "distractors": [
        { "text": "are", "patternId": "gram.tobe.agreement" },
        { "text": "am",  "patternId": "gram.tobe.agreement" }
      ],
      "explanationPt": "Com he/she/it usamos is."
    },
    {
      "id": "c1.simplepres.typed.014", "type": "TYPED", "skill": "SENTENCE_BUILDING",
      "difficulty": 2, "pool": "PRACTICE",
      "prompt": { "textPt": "Ela trabalha todos os dias." },
      "accepted": ["She works every day."],
      "ruleIds": ["gram.simple_present.third_person_s"]
    }
  ]
}
```

O **validador** (roda no CI) garante: IDs únicos; referências existentes; todo exercício com gabarito; cada resposta aceita passa no próprio `AnswerChecker`; distratores diferentes do gabarito; `patternId` existente; **vocabulário controlado** (toda palavra de exemplo pertence ao catálogo dos ciclos até o atual ou à lista de palavras funcionais); tamanho mínimo do banco por competência.

---

## 5. Progressão pedagógica

### 5.1 Hierarquia

**Ciclo** (≈ 4 semanas) → **Unidade** (módulo/tópico, ex.: “Verbo to be”) → **Competência** (habilidade mensurável, “Consigo…”) → itens (palavras, frases, exercícios, escutas).
Uma **lição ensina**; uma **competência é medida**. A sessão diária é montada a partir das competências e das revisões, não de um calendário fixo.

Ciclo 1 (meta de conteúdo, não promessa): 6 unidades (uma por tópico do enunciado), cerca de 20 competências, ~200 palavras, ~250 frases, ~400 exercícios de prática, ~60 itens de escuta e um banco de avaliação separado, com pelo menos 3× os itens que cada avaliação usa.

### 5.2 Revisão espaçada (SM-2 adaptado)

**Notas** (derivadas automaticamente nos exercícios corrigidos pelo app; escolhidas por você nos cartões):

| Nota | Quando |
|---|---|
| `AGAIN` | resposta errada |
| `HARD` | acertou, mas com dica, na segunda tentativa, ou demorou mais de 2× a sua mediana para aquele tipo de exercício |
| `GOOD` | acertou no tempo normal |
| `EASY` | acertou rápido (≤ 0,5× a mediana) após ≥ 3 acertos seguidos, ou “Fácil” no cartão |

**Valores iniciais** (a calibrar com uso real; todos em `SrsConfig`):

| Situação | Regra |
|---|---|
| Item novo | Passos dentro da sessão: reaparece após ~10 itens; ao acertar de novo, “gradua” com intervalo de 1 dia (3 dias se `EASY`) |
| `AGAIN` | `lapses + 1`; `ease − 0,20`; `intervalo = max(1, 0,25 × intervalo)`; reaparece na mesma sessão (após ~5 itens e ao fim) |
| `HARD` | `ease − 0,15`; `intervalo = max(intervalo + 1, 1,2 × intervalo)` |
| `GOOD` | `intervalo = max(intervalo + 1, intervalo × ease)` |
| `EASY` | `ease + 0,10`; `intervalo = intervalo × ease × 1,3` |
| Limites | `ease` entre 1,3 e 3,0 (inicia em 2,5); intervalo máximo de 180 dias; variação determinística de ±5% a partir de 7 dias |
| Atraso | O próximo intervalo usa os dias realmente decorridos (bônus limitado a 1,5×) |
| *Leech* | `lapses ≥ 5`: troca o formato do exercício, mostra dica/nota, limita a 1 aparição por dia e lista em “Dificuldades” |
| Modo recuperação | Se os atrasos passam de 2× a capacidade diária: prioriza por risco (menor `ease`, mais lapsos, mais atraso), limita o total por dia e suspende conteúdo novo |

**Resultado esperado:** o que você erra muito tem `ease` baixo e volta com frequência; o que você domina cresce de 1 dia para meses. O formato do exercício também escala com os acertos (reconhecer → completar → produzir → falar).

**Por que não FSRS:** exige mais parâmetros e dados para calibrar e é mais difícil de explicar e testar. Como `SrsScheduler` é uma interface e `attempt` guarda tudo o que o FSRS precisaria, dá para trocar depois. O relógio é injetável (testes determinísticos; saltos para trás no relógio são limitados a zero dias).

### 5.3 Maestria da competência (retenção, não só acerto imediato)

“Itens-núcleo” são as palavras, frases e padrões marcados como centrais para a competência.

| Estado | Critério inicial |
|---|---|
| Não iniciada | Lição não concluída |
| Em aprendizado | Lição concluída; menos de 8 tentativas ou acerto recente < 75% |
| Em prática | ≥ 8 tentativas em ≥ 2 formatos e acerto nas últimas 10 ≥ 75% (ainda **sem** prova de retenção) |
| **Consolidada** | Prática + **retenção**: ≥ 70% dos itens-núcleo acertados ao menos uma vez **após intervalo ≥ 3 dias**; acerto nas últimas 15 ≥ 80%; nenhum erro nas 2 últimas revisões espaçadas |
| Dominada | ≥ 80% dos itens-núcleo com intervalo de revisão ≥ 21 dias e no máximo 1 lapso recente |

- Se o desempenho cair, o estado é **rebaixado** e gera reforço. O que já foi desbloqueado **não é bloqueado de novo**.
- *Provisória:* competências marcadas pelo teste de nivelamento valem para pular conteúdo, mas só viram “Consolidada” com a prova de retenção.

### 5.4 Desbloqueio e avaliações

- **Próxima unidade:** libera quando ≥ 80% das competências **obrigatórias** da unidade estão “Consolidadas”.
- **Avaliação de 4 semanas (checkpoint):** fica disponível aos 28 dias do início do ciclo (ponto de controle) **ou antes**, quando as competências obrigatórias estiverem consolidadas.
  - *Composição:* 60% do ciclo atual, 25% de ciclos anteriores (retenção), 15% dos padrões de erro mais frequentes; itens da prática recente são evitados; a semente do sorteio é gravada (a avaliação pode ser retomada).
  - *Seis habilidades, avaliadas separadamente,* com limiares iniciais: Vocabulário 75%, Gramática 75%, Leitura 75%, Escuta 70%, Construção de frases 70%, **Produção oral 60%** (mais baixo por causa do ruído do reconhecedor; informativa se não houver reconhecimento de voz).
  - *Resultado por habilidade:* “Atingiu”, “Reforçar” ou “Não avaliado” (este último nunca bloqueia).
- **Aprovação do ciclo:** todas as habilidades avaliadas acima do limiar **e** ≥ 80% das competências obrigatórias do ciclo consolidadas. Concluir as lições não basta.
- **Se não aprovar:** reforço dirigido nas habilidades e competências reprovadas; reteste **só dessas habilidades**, após ≥ 3 dias, com itens diferentes.
- **Teste de nivelamento** (início): mesmo motor, itens em ordem de dificuldade, ~25 itens; marca competências como provisórias.
- **Relatório** (determinístico, em pt-BR, sempre com o número de itens para evitar falsa precisão):
  - *O que foi aprendido:* competências consolidadas e dominadas.
  - *O que ainda é difícil:* habilidades abaixo do limiar, padrões de erro ativos, *leeches*.
  - *O que revisar:* competências rebaixadas ou com revisões atrasadas.
  - *Próxima etapa:* liberar o próximo ciclo, reforço dirigido ou reteste em N dias.

### 5.5 Sessão diária adaptativa

1. **Base:** minutos por bloco = tempo disponível × proporção padrão (5/10/8/10/12 de 45 min: revisão 11%, conteúdo novo 22%, gramática aplicada 18%, escuta 22%, pronúncia e construção oral 27%). O tempo disponível é ajustável (15 a 90 min).
2. **Necessidade:** cada bloco recebe um fator entre 0,5× e 2×: revisão sobe com atrasos acumulados; gramática, com padrões de erro ativos; escuta, com acerto baixo; pronúncia, com divergências repetidas; conteúdo novo **desce** quando há muito atraso.
3. **Normalização:** os minutos são reequilibrados para o total; bloco com menos de 3 min é realocado.
4. **Itens:** minutos viram número de itens pela **sua** mediana de tempo por tipo de exercício (valores padrão no começo).
5. **Seleção:** por prioridade (5.6).
6. **Nada é obrigatório:** você pode pular, reordenar, estender ou encerrar; o tempo ativo real fica registrado por bloco.
7. **Sem reconhecimento de voz:** o bloco de pronúncia vira repetição guiada com autoavaliação e escuta ativa.

### 5.6 Memória de erros e reforço

- **Registro:** cada erro grava `error_event` (categoria, assunto, padrão, resposta dada e correta) e atualiza o `review_state` do padrão.
- **Prioridade de um item na seleção:** atraso + taxa de erro recente do padrão/competência + lapsos do item + “próximo no caminho” − visto há pouco (pesos iniciais em `ProgressionPolicy`).
- **Padrão resolvido:** ≥ 5 acertos seguidos **em pelo menos 2 dias diferentes**; a frequência cai e os intervalos crescem.
- **Voz:** divergências de pronúncia só viram “problema persistente” depois de repetidas (ex.: ≥ 2 em 3 tentativas), pois uma única divergência é evidência fraca.

### 5.7 Política configurável

Todos os limiares e pesos desta seção ficam em `ProgressionPolicy`/`SrsConfig`, com testes que fixam o comportamento. Eles são **valores iniciais razoáveis, não verdade pedagógica**: revisamos juntos após o primeiro checkpoint com dados reais.

---

## 6. Reconhecimento de voz: limites reais

### 6.1 O que o `SpeechRecognizer` é (e não é)

- É um cliente do **serviço de reconhecimento padrão do sistema** (em geral o do Google). Devolve **texto** (lista de hipóteses; confiança por hipótese, às vezes). Não devolve fonemas nem qualidade acústica.
- O texto sai de um **modelo de linguagem**: o reconhecedor tende a “consertar” o que ouviu para a frase mais provável. Um erro seu pode **desaparecer** na transcrição (falso “correto”), e uma pronúncia aceitável pode sair errada (falso “incorreto”).

### 6.2 Online × offline

- Por padrão o áudio pode ir aos servidores do Google. O app não precisa de `INTERNET`: quem usa a rede é o serviço do sistema.
- Offline exige **pacote de idioma baixado** nesse serviço. `EXTRA_PREFER_OFFLINE` é só uma **preferência**; o serviço pode ignorá-la. Sem pacote e sem rede: erro (`ERROR_NETWORK`, `ERROR_SERVER`, `ERROR_LANGUAGE_*`).
- **A partir do Android 13 (API 33)** existem APIs para saber se há reconhecedor *somente no aparelho*, criar um e consultar/baixar pacotes de idioma (`isOnDeviceRecognitionAvailable`, `createOnDeviceSpeechRecognizer`, `checkRecognitionSupport`, `triggerModelDownload`). **Antes disso não há como verificar o pacote offline de antemão:** só tentando e tratando o erro. As versões exatas de cada API serão confirmadas no diagnóstico (entrega 2.4).
- A qualidade offline costuma ser inferior à online, principalmente com sotaque.

### 6.3 Variação por aparelho e armadilhas

- Aparelhos **sem Google Play Services** podem não ter reconhecedor (`isRecognitionAvailable() == false`).
- **Android 11+** exige declarar `<queries>` para `android.speech.RecognitionService` (e para `TTS_SERVICE`); sem isso a detecção pode falhar.
- O `SpeechRecognizer` só funciona na **thread principal**, toca **bipes** de início/fim e corta por silêncio (1–2 s) de um jeito nem sempre configurável: quem hesita pode ser interrompido.
- Em muitos aparelhos não dá para **gravar o áudio e reconhecer ao mesmo tempo** (o microfone tem um consumidor por vez). Por isso o modo de autoavaliação **não** grava; só orienta.
- Erros a tratar: sem fala, sem correspondência, ocupado, sem permissão, rede, servidor, idioma indisponível, muitos pedidos.

### 6.4 Como o design lida com isso

- Resultado **por palavra**: correta, omitida, trocada, extra, ou *homófono ambíguo* (*to/too/two* não podem ser distinguidos só pelo áudio).
- **Sem nota numérica.** A mensagem é “o reconhecedor entendeu X”, nunca “você pronunciou errado”.
- **Normalização** antes de comparar: minúsculas, pontuação, contrações (*I'm* ↔ *I am*), números (*2* ↔ *two*), variantes (*color/colour*).
- **Hipótese principal** como padrão; usar as alternativas (modo “tolerante”) é opção, porque pode esconder erros.
- **Evidência acumulada:** uma divergência isolada não vira erro persistente.
- **Dicas para falantes de português** (final -s/-ed, “th”, “h” inicial, vogal extra no fim) aparecem como *hipóteses*, não como diagnóstico.
- **Explicação por regra** nos casos previstos. Exemplo do enunciado: esperado “I work every day.” e reconhecido “I works every day.” → *I* ✓, *works* ✗ (trocada), *every* ✓, *day* ✓; explicação: “Com I/you/we/they o verbo não leva -s: *I work*”.

### 6.5 Cenários e comportamento

| Cenário | Comportamento do app |
|---|---|
| A. Android 13+, pacote offline en-US instalado | Reconhecimento no aparelho (preferido), sem rede |
| B. Android 8–12, pacote offline instalado | `EXTRA_PREFER_OFFLINE`; sem verificação prévia; erros tratados |
| C. Sem pacote e sem internet | Guia “baixar o pacote offline” (abre as configurações de voz) + modo de autoavaliação |
| D. Com internet, sem pacote | Funciona; avisa uma vez que o áudio é enviado ao Google |
| E. Sem serviço de reconhecimento | Recurso desativado; autoavaliação; futuro: motor offline próprio |
| F. Permissão negada | Explica e oferece abrir os ajustes do app |
| G. Ocupado, sem fala, ruído | Mensagem clara e nova tentativa; após 2 falhas, sugere checar microfone e ambiente |

**Modo de autoavaliação:** ouvir, repetir em voz alta, marcar “Consegui / Quase / Preciso repetir”. Alimenta a revisão espaçada, mas vale como evidência **fraca**.

### 6.6 Evolução futura (opcional, sem custo)

- `SpeechRecognitionEngine` permite outros motores: **Vosk** (Apache-2.0; modelo pequeno em inglês ≈ 40 MB; funciona offline sempre; devolve palavra, tempo e confiança) ou **whisper.cpp** (MIT; ≈ 75 MB no modelo tiny.en; mais pesado e também “conserta” a gramática). Ambos aumentam o APK e exigem testes próprios.
- **Avaliação fonética real** exige modelo acústico de fonemas (pontuação por fonema), maior e mais complexo. O tipo `PronunciationFeedback.Acoustic` já está reservado; nada disso é necessário agora.

### 6.7 TTS

- Verifica-se a voz com `TextToSpeech.setLanguage` (`LANG_MISSING_DATA`/`LANG_NOT_SUPPORTED`) e com `Voice.isNetworkConnectionRequired()`; instalar dados de voz abre o instalador do sistema (precisa de internet uma vez).
- Velocidade reduzida via `setSpeechRate`; vozes e sotaques dependem do que o motor tiver instalado; a voz soa diferente entre aparelhos (Google, Samsung).
- Sem controle fino de prosódia ou fonemas; heterônimos podem sair errados. O conteúdo evita ambiguidades ou as anota.

### 6.8 Spike de voz (entrega 2.4)

A tela **Diagnóstico de voz** (em Configurações) faz: verificação de TTS (voz en-US offline?), fala de uma frase; verificação de STT (permissão, serviço, offline); um reconhecimento de teste com transcrição bruta, alternativas, tempo e se foi no aparelho ou online. Você roda no seu aparelho e me envia o resultado. Com isso fechamos o desenho da Etapa 4 com dados reais, antes de investir em conteúdo.

---

## 7. Plano de desenvolvimento

### 7.1 Ajustes na ordem das etapas (pedem sua aprovação)

1. **Spike de voz já na Etapa 2** (era da Etapa 4): é o maior risco técnico; melhor descobrir cedo.
2. **Núcleo de revisão espaçada e maestria na Etapa 3** (era da Etapa 5): a progressão por retenção e o bloco de revisão da sessão dependem dele. A Etapa 5 fica com erros, adaptação e relatórios.
3. **TTS básico antes das lições** (Etapa 3): os exemplos já tocam desde a primeira lição.

### 7.2 Entregas

**Verificação:** *CI* = GitHub Actions (build, testes, lint). *Local* = `:core` neste sandbox. *Você* = teste no seu celular. Cada entrega é um PR pequeno; **definição de pronto** = testes verdes, APK compilando, critérios de aceite atendidos, documentação atualizada, nenhuma tela sem função real.

**Etapa 2 — Estrutura inicial**

| ID | Entrega | Critério de aceite | Verificação |
|---|---|---|---|
| 2.0 | Branch `main` e convenções (README curto, `.gitignore`) | `main` existe; PRs apontam para ela | Você (decisão 1) |
| 2.1 | Projeto Gradle (`:core`, `:app`), catálogo de versões, wrapper, tema M3 claro/escuro, navegação base | `./gradlew :core:test :app:assembleDebug` verde no Actions; APK instala e abre; Início lê dados reais do Room; o CI **falha** se `INTERNET` aparecer no manifesto mesclado | CI + Você |
| 2.2 | Workflow `build.yml` + assinatura estável (decisão 2) | Execução por push, PR e manual; artefato `.apk` baixável; uma 2ª build instala **por cima** da 1ª sem perder dados | CI + Você |
| 2.3 | Room v1, formato de conteúdo, validador, semeadura idempotente (com uma unidade real do Ciclo 1) | Semear 2× não duplica; atualizar conteúdo preserva progresso; app abre em modo avião e lista a unidade | CI + Você |
| 2.4 | Diagnóstico de voz (spike, seção 6.8) | Você roda no aparelho e me envia o resultado | Você |

**Etapa 3 — Motor pedagógico**

| ID | Entrega | Critério de aceite | Verificação |
|---|---|---|---|
| 3.1 | `:core`: normalização, `AnswerChecker`, revisão espaçada, maestria e desbloqueio, relógio injetável | Suíte de testes verde (acertos seguidos aumentam o intervalo; erro reduz; *leech* aos 5 lapsos; “Consolidada” só com recordação após ≥ 3 dias) | CI + Local |
| 3.2 | Renderizadores de exercício (múltipla escolha, lacuna, ordenar, digitar, cartão), `AttemptRecorder`, botão “ouvir” (TTS) | Uma competência-piloto jogável; tentativas gravadas; projeções atualizam | CI + Você |
| 3.3 | Currículo do Ciclo 1 (semanas 1–4): unidades, competências, lições, exercícios, vocabulário, frases | Validador verde; cobertura mínima por competência; relatório de conteúdo; você revisa uma amostra | CI + Você |
| 3.4 | Aba Aprender (mapa, lição, desbloqueio por maestria) + Início real | Desbloqueio só pela regra; Início bate com o banco | CI + Você |
| 3.5 | Sessão diária v1 (revisão, conteúdo novo, gramática), tempo ajustável, pular/estender | Planejador testado; sessão completa no celular | CI + Você |
| 3.6 | Nivelamento + avaliação de 4 semanas v1 (vocabulário, gramática, leitura, construção de frases) + relatório | Pontuação e relatório testados; reprovação gera reforço dirigido | CI + Você |

**Etapa 4 — Áudio e pronúncia**

| ID | Entrega | Critério de aceite | Verificação |
|---|---|---|---|
| 4.1 | TTS e STT do Android completos (estados, permissões, `<queries>`, erros, fallback) | Cenários A–G tratados; sem falha ao negar permissão | Você + testes com *fakes* no CI |
| 4.2 | `TranscriptComparator` (normalização, alinhamento, estados, explicações por regra) | Testes incluem “I works every day”, contrações, números, homófonos | CI + Local |
| 4.3 | Aba Pronúncia (fluxo de 8 passos) + histórico + autoavaliação | Fluxo completo; “tentar novamente”; **sem nota numérica**; mensagens de indisponibilidade | Você |
| 4.4 | Aba Escutar (palavras a conversas, repetir, lenta, perguntas, transcrição e tradução sob demanda, ditado) + escuta do Ciclo 1 | Tradução oculta até a tentativa; dificuldades registradas | CI + Você |
| 4.5 | Aba Vocabulário (categorias, áudio, histórico de acertos e erros, revisão visível) | Busca e filtro; histórico por palavra | CI + Você |
| 4.6 | Sessão diária v2 (5 blocos) + avaliação v2 (6 habilidades) | Habilidade avaliada ou “não avaliado” | CI + Você |

**Etapa 5 — Memória e adaptação**

| ID | Entrega | Critério de aceite | Verificação |
|---|---|---|---|
| 5.1 | Catálogo `error_pattern` e detectores por regras (Ciclos 1–2) | “She work every day.” registra categoria, assunto, erro, resposta dada e correta, frequência | CI |
| 5.2 | Reforço adaptativo (prioridade, *leeches*, modo recuperação) | Testes de prioridade; simulação de 30 dias | CI + Local |
| 5.3 | Planejador adaptativo (reponderação dos blocos) | Testes com limites | CI |
| 5.4 | Relatórios (4 semanas e visão geral) e “desempenho recente” no Início | Relatório determinístico, com nº de itens | CI + Você |
| 5.5 | Exportar/importar progresso + “recalcular projeções” | Exportar → reinstalar → importar restaura tudo | CI + Você |

**Etapa 6 — Testes e entrega**

| ID | Entrega | Critério de aceite | Verificação |
|---|---|---|---|
| 6.1 | Protocolo offline (modo avião) | Passos documentados, executados e registrados | Você |
| 6.2 | Persistência: matar o processo no meio da sessão, atualizar o APK (mesma assinatura), migração de esquema | Nada se perde | CI + Você |
| 6.3 | Dispositivos: seu aparelho e, se viável, emuladores no CI | Lista de aparelhos testados | Você |
| 6.4 | Acessibilidade e desempenho; release assinado documentado | Fonte grande, TalkBack, contraste; `docs/RELEASE.md` | Você |
| 6.5 | Documentação final e correções | README e docs atualizados | CI |

**Contínuo — Pacotes de conteúdo CP2…CP6:** cada ciclo é entregue com validador verde **antes** de você concluir o ciclo anterior (cerca de 4 semanas de uso por ciclo). O uso real do Ciclo 1 também calibra limiares e conteúdo.

---

## 8. Decisões pendentes

A decisão 1 exige uma ação sua. Nas demais, responda “aprovado” para aceitar os padrões recomendados, ou indique o número da que quer mudar.

1. **Acesso ao GitHub e branch principal (pré-requisito).** O push desta sessão foi recusado (403): o app Claude do GitHub não tem acesso de escrita a `clviniciuslj/inglesclaude`. **Ação sua:** conectar ou reconectar o GitHub em <https://claude.ai/connect-github> e instalar o app Claude no repositório (ou pedir a um dono da organização). Se a sessão atual não enxergar o acesso novo, abra uma nova sessão com este repositório selecionado. Com o acesso resolvido, **recomendo:** eu enviar a branch `claude/english-lab-architecture-x02jkx` e criar `main` a partir dela (o remoto está vazio; assim o histórico fica compatível), você marcar `main` como padrão em *Configurações → Branches*, e todo trabalho seguir em branches `claude/*` com PR para `main`. Só abro PR quando você pedir.
2. **Assinatura estável do APK** (para atualizar sem perder dados). **A)** keystore de *debug dedicado* versionado em `app/`: zero configuração; é chave pública por natureza, mas **contraria a sua regra de não versionar chaves**. **B)** Secrets do GitHub: mais limpo, mas exige gerar o keystore e cadastrar 4 secrets (difícil só pelo celular). **Recomendo A para o debug** e B (já documentada, Anexo B) para o release.
3. **Identificador do app:** `io.github.clviniciuslj.englishlab`. Não dá para mudar depois sem reinstalar (apaga os dados).
4. **Escopo e ordem.** Aprovar: (a) os três ajustes da seção 7.1; (b) conteúdo em fatias, com o Ciclo 1 completo primeiro; (c) três adições mínimas que a especificação implica: **teste de nivelamento**, **exportar/importar progresso** e **diagnóstico de voz**.
5. **CI e ambiente.** (a) Gatilhos: push em `main` + manual (como você pediu) **+ `pull_request` → `main`**. (b) Liberar `dl.google.com` na rede da sessão para eu compilar o `:app` localmente: peço na Etapa 2, com um cartão de aprovação.
6. **Seu aparelho.** Modelo, versão do Android e idioma do sistema (definem `minSdk`, a prioridade do spike de voz e os cenários de teste).

---

## Anexo A — Esboço do workflow

Rascunho; o arquivo final e as versões das *actions* são fixados na Etapa 2 (o CI acusa na hora se uma versão não existir).

```yaml
name: build
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true
jobs:
  apk:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4          # Temurin 21
      - uses: android-actions/setup-android@v3
      - uses: gradle/actions/setup-gradle@v4 # cache do Gradle
      - run: ./gradlew :core:test :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
      - uses: actions/upload-artifact@v4     # app/build/outputs/apk/debug/*.apk
```

## Anexo B — Release assinado sem segredos no repositório

Será detalhado em `docs/RELEASE.md` na Etapa 6. Resumo:

1. Gerar o keystore **fora do repositório** (`keytool -genkeypair …`) e guardar uma cópia de segurança offline. Perder a chave significa não poder atualizar o app instalado.
2. Cadastrar em *GitHub → Settings → Secrets and variables → Actions*: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
3. Um workflow `release.yml` (manual ou por tag) decodifica o keystore para um arquivo temporário do runner, passa caminho e senhas ao Gradle por **variáveis de ambiente** (o `signingConfig` lê `System.getenv`), roda `assembleRelease`, apaga o arquivo e publica o APK.
4. `.gitignore` bloqueia `*.jks`, `*.keystore` e `keystore.properties` (exceto o keystore de debug dedicado, se a decisão 2 for A).
5. Segredos nunca aparecem em logs (o Actions os mascara) nem em código.

## Anexo C — Fontes consultadas (05/11/2026)

- [Android Gradle plugin 9.0 — notas de versão](https://developer.android.com/build/releases/agp-9-0-0-release-notes) e [página de versões do AGP](https://developer.android.com/studio/releases/gradle-plugin.html)
- [Jetpack Compose — versões](https://developer.android.com/jetpack/androidx/releases/compose)
- [AndroidX — canal estável (Room)](https://developer.android.com/jetpack/androidx/versions/stable-channel)
- [Navigation 3 — versões](https://developer.android.com/jetpack/androidx/releases/navigation3)
- [Gradle — versão atual](https://services.gradle.org/versions/current)
- Maven Central (metadados): [Kotlin Gradle plugin](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml), [KSP](https://repo.maven.apache.org/maven2/com/google/devtools/ksp/symbol-processing-gradle-plugin/maven-metadata.xml), [Coroutines](https://repo.maven.apache.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core/maven-metadata.xml), [JUnit 4](https://repo.maven.apache.org/maven2/junit/junit/maven-metadata.xml)
