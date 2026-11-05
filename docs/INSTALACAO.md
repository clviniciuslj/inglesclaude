# Instalação do APK no Android

Guia para o Samsung Galaxy S25 Ultra (SM-S938B, Android 17). Os nomes de menu do One UI podem variar um pouco.

## 1. Baixar o APK

1. No navegador do celular, abra o repositório no GitHub → aba **Actions** → workflow **Build** → a execução mais recente na branch `main` com o job **APK assinado** verde.
2. Role até **Artifacts** e toque em `english-lab-apk-buildN` (o artefato baixa como `.zip`; é necessário estar logado no GitHub).
3. Abra **Meus Arquivos → Downloads**, toque no `.zip` e escolha **Extrair**.

> Pull requests **não** publicam APK de propósito: o APK de um PR usa uma chave descartável e, se fosse instalado, impediria as atualizações seguintes. Instale apenas APKs vindos da `main`.

## 2. Instalar

1. Toque no arquivo `.apk` extraído.
2. Se o Android pedir, permita **instalar apps desconhecidos** para o app que abriu o arquivo (por exemplo, Meus Arquivos) e volte.
3. Toque em **Instalar**. Se o Play Protect avisar sobre app não verificado, escolha **Instalar mesmo assim**.
4. Se a instalação for bloqueada, desative temporariamente o **Auto Blocker** (**Configurações → Segurança e privacidade → Auto Blocker**), que impede instalar apps de fontes não autorizadas.

## 3. Verificação de desenvolvedor do Android (Brasil)

Desde 30/09/2026, o Android exige verificação de desenvolvedor no Brasil, na Indonésia, em Singapura e na Tailândia. A documentação oficial do Google, hoje, diz:

- A exigência de 30/09/2026 vale para instalações vindas de **lojas participantes** (Google Play, Galaxy Store e outras). Uma das respostas da FAQ (atualizada em julho de 2026) afirma que, para quem instala o APK direto (*sideload*), a exigência **ainda não se aplica**.
- Outras páginas da mesma documentação dizem que apps de desenvolvedores não registrados só podem ser instalados ou atualizados com o **fluxo avançado** ligado, ou por ADB.
- A documentação **não esclarece qual das duas vale na prática** para um APK baixado e instalado direto num Samsung. Por isso, estes são os caminhos, do mais simples ao mais robusto:

**Caminho 1: tentar instalar normalmente.** Se instalar sem aviso de “desenvolvedor não verificado”, não há nada a fazer.

**Caminho 2: fluxo avançado (uma vez só).** Segundo o Google:

1. Ative o modo desenvolvedor (**Configurações → Sobre o telefone → Informações do software →** toque 7 vezes em **Número da versão**).
2. Em **Opções do desenvolvedor**, procure a opção para permitir apps de desenvolvedores não verificados e confirme que ninguém está pressionando você a desligar a segurança.
3. Reinicie e autentique-se de novo.
4. **Espere 24 horas** (espera única de segurança).
5. Volte, confirme com biometria ou PIN e escolha liberar por **7 dias** ou **indefinidamente**.
6. Ao instalar, toque em **Instalar mesmo assim**.

Atenção: se você desligar essa opção depois, as **atualizações** de apps não registrados falham. E como há espera de 24 horas, **comece por aqui se o Caminho 1 for bloqueado**.

**Caminho 3: registro gratuito do app (conta de distribuição limitada).** Para estudantes e hobbistas: sem custo, sem documento de identidade, para poucos dispositivos (a documentação cita 20 e, em outro ponto, 50). Pede conta Google com verificação em duas etapas e perfil de pagamentos. Você registra o pacote `io.github.clviniciuslj.englishlab` provando a posse com um APK assinado com a chave privada: o APK assinado desta pipeline serve, porque a chave é sempre a mesma. O passo a passo exato do Console não está na documentação que consegui ler; seguimos juntos se for preciso.

**Caminho 4: ADB** (precisa de um computador): `adb install -r english-lab-….apk`. Instalações por ADB não passam pela verificação.

Fontes oficiais: [visão geral](https://developer.android.com/developer-verification), [guias](https://developer.android.com/developer-verification/guides), [conta de distribuição limitada](https://developer.android.com/developer-verification/guides/limited-distribution) e [perguntas frequentes](https://developer.android.com/developer-verification/guides/faq).

## 4. O que você deve ver ao abrir

Tela **Início** com dois cartões:

- **Versão de teste da estrutura**, explicando o que esta versão valida.
- **Estado do aplicativo**: versão e build, data de criação dos dados locais, dia de estudo, meta diária (45 minutos), versão do esquema do banco (1) e “O aplicativo não tem permissão de internet: funciona 100% offline.”

O tema acompanha o modo claro/escuro do sistema.

## 5. Como validar a entrega 1

| # | Teste | Resultado esperado |
|---|---|---|
| 1 | Instalar o APK e abrir | O Início aparece com os dois cartões |
| 2 | Anotar “Versão instalada” e “Dados locais criados em”. Fechar o app por completo e reabrir | A data de criação **não muda** |
| 3 | Ativar o modo avião e abrir o app | Mesmo conteúdo, sem erro |
| 4 | Alternar o modo escuro do sistema | O app troca de tema |
| 5 | Pedir uma nova build (**Actions → Build → Run workflow** na `main`) e instalar **por cima**, sem desinstalar | Instala sem erro, o número do **build** aumenta e a data de criação dos dados **continua a mesma** |

## 6. Se aparecer “App não instalado”

- **Assinatura diferente:** você instalou antes um APK de outra origem (por exemplo, de um PR). Desinstalar resolve, mas **apaga os dados locais**. Nesta fase eles são só de teste.
- **Versão menor:** o Android não permite voltar para um build mais antigo por cima. Instale sempre o mais recente.
- **Verificação de desenvolvedor:** veja a seção 3.
