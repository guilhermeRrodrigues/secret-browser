# PROMPT DE CONSTRUÇÃO — Secret Browser

> Cole este arquivo inteiro como instrução inicial para uma sessão do **Claude Code**
> dentro deste repositório. Ele é a especificação completa do produto. Execute-o de
> ponta a ponta, criando todos os arquivos, e faça commits incrementais a cada etapa.

---

## 1. Objetivo

Construir um **navegador privado multiplataforma** chamado **Secret Browser**, com um
único código-base cobrindo **Android, iOS, macOS e Windows**.

Três pilares:

1. **Navegação anônima local** — nenhum rastro de navegação é gravado no dispositivo
   (sem histórico, sem cookies persistentes, sem cache em disco).
2. **Botão de pânico** — um "X" flutuante sempre visível no canto da tela.
3. **Wipe + fechar** — ao tocar no "X" **ou** usar um atalho de teclado, todo o conteúdo
   navegado é apagado imediatamente e o app é fechado.

---

## 2. Stack e decisões técnicas (não negociáveis)

- **Framework:** Flutter (canal `stable`), Dart null-safety.
- **WebView:** pacote [`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview)
  (^6.x) — é o único que suporta as 4 plataformas-alvo com controle fino de cookies/cache
  e modo incógnito.
- **Estado:** `provider` ou `riverpod` (escolha `riverpod`, mais testável). Sem estado global mutável solto.
- **Sem dependências de analytics, telemetria ou crash-reporting.** Este é um app de privacidade:
  zero chamadas de rede que não sejam a navegação do próprio usuário.
- **Sem persistência em disco de qualquer dado de navegação.** Cookies e storage devem viver
  apenas em memória e ser destruídos no wipe.

### Matriz de plataformas

| Plataforma | WebView backend             | Fechar app no wipe?                          |
|-----------|------------------------------|----------------------------------------------|
| Android   | Chromium (system WebView)    | Sim — `SystemNavigator.pop()` + `exit(0)`    |
| Windows   | WebView2 (Edge Chromium)     | Sim — `exit(0)`                              |
| macOS     | WKWebView                     | Sim — `exit(0)`                              |
| iOS       | WKWebView                     | **NÃO PODE** — ver secção 4.3               |

---

## 3. Arquitetura e estrutura de arquivos

Crie a estrutura abaixo. Cada arquivo tem responsabilidade única.

```
lib/
  main.dart                     # bootstrap do app + ProviderScope
  app.dart                      # MaterialApp, tema escuro, rotas
  core/
    privacy_config.dart         # configs de WebView anônima (cookies em memória, incognito)
    panic_service.dart          # a lógica central do wipe + fechar (o coração do app)
    keyboard_shortcuts.dart     # registro do atalho global de pânico
    platform_exit.dart          # abstração de "fechar app" por plataforma (+ stub iOS)
  features/
    browser/
      browser_screen.dart       # tela principal: WebView + barra de endereço
      address_bar.dart          # input de URL, botão go, indicador de segurança
      tab_manager.dart          # abas em memória (lista de InAppWebViewController)
    panic/
      panic_button.dart         # o "X" flutuante (Positioned/Overlay), arrastável
      panic_overlay.dart        # controla posição e visibilidade do botão
  widgets/
    ...                         # componentes reutilizáveis
test/
  panic_service_test.dart       # testes do wipe (crítico)
  privacy_config_test.dart
```

---

## 4. Especificação detalhada das funcionalidades

### 4.1 Navegação anônima (core/privacy_config.dart)

Configure toda `InAppWebView` com:

- `InAppWebViewSettings(incognito: true, cacheEnabled: false, clearCache: true)`.
- `CookieManager` operando apenas em memória; nunca chamar APIs que persistam cookies.
- Desabilitar `databaseEnabled`, `domStorageEnabled` **persistente** (DOM storage pode ficar
  ligado em runtime, mas é limpo no wipe e nunca escrito em disco).
- Nenhum uso de `WebStorageManager` persistente.
- Header opcional de `DNT: 1` (Do Not Track).
- Ao iniciar o app, executar um wipe silencioso preventivo (garante estado limpo mesmo após crash).

> **Limite honesto a documentar no README:** isto garante anonimato **local** (no aparelho).
> **Não** esconde o IP do usuário de sites nem do provedor. Anonimato de rede exigiria roteamento
> por Tor/VPN — deixe isso como um TODO/roadmap explícito, não implemente agora.

### 4.2 Botão de pânico (features/panic/panic_button.dart)

- Um widget flutuante com um "X", posicionado por cima de tudo via `Overlay`/`Stack`+`Positioned`.
- Sempre visível, inclusive com a WebView em foco.
- Arrastável (o usuário pode reposicionar); posição default = canto inferior direito.
- Semi-transparente em repouso, sólido ao toque.
- **Um único toque** dispara `PanicService.trigger()` — sem diálogo de confirmação (é pânico).

### 4.3 Wipe + fechar (core/panic_service.dart) — O CORAÇÃO DO APP

`PanicService.trigger()` deve, **nesta ordem e de forma síncrona/rápida**:

1. Parar o carregamento de todas as WebViews.
2. Para cada aba: `webView.clearHistory()`, limpar cookies (`CookieManager.deleteAllCookies()`),
   limpar cache (`InAppWebViewController.clearAllCache()`), limpar DOM storage
   (`WebStorageManager` / `evaluateJavascript('localStorage.clear();sessionStorage.clear();')`).
3. Descartar/nullificar todos os controllers e a lista de abas (esvaziar memória).
4. Limpar qualquer estado do app (URL atual, título, favicon).
5. **Fechar o app** via `PlatformExit.closeApp()`.

`core/platform_exit.dart`:

- Android/Windows/macOS → `SystemNavigator.pop()` seguido de `exit(0)`.
- **iOS → NÃO chamar `exit(0)`** (a Apple rejeita apps que se auto-encerram; é motivo de rejeição
  na App Store e parece um crash ao usuário). Em vez disso, no iOS o `closeApp()` deve:
  navegar para uma **tela de decoy inócua** (ex: uma calculadora simples) e mandar o app para
  background via nada (apenas mostra o decoy). Implemente `DecoyScreen` como fallback só-iOS.
- Use `Platform.isIOS` / detecção de plataforma para escolher o caminho.

> Como o usuário pediu **"apagar tudo e fechar"**: fecha de verdade em Android/Windows/macOS;
> no iOS, por restrição da plataforma, o equivalente é wipe + tela decoy. Documente isso no README.

### 4.4 Atalho de teclado (core/keyboard_shortcuts.dart)

- Registrar um listener global (`HardwareKeyboard.instance` / `Shortcuts`+`Actions` no nível raiz).
- Atalho default de pânico: **`Ctrl/Cmd + Shift + X`** (configurável em constante).
- Também aceitar a tecla **`Esc` pressionada 2x rápido** como gatilho alternativo (opcional).
- O atalho chama exatamente o mesmo `PanicService.trigger()`.
- Funciona em desktop nativamente; em mobile funciona com teclado físico conectado.

---

## 5. UI / UX

- Tema **escuro** por padrão, minimalista.
- Barra de endereço no topo: campo de URL, botão go/reload, ícone de cadeado (http vs https),
  botão de nova aba, contador de abas.
- Suporte a múltiplas abas **em memória** (nunca serializadas em disco).
- Ao abrir o app: uma "nova aba" em branco com um campo de busca central.
- Indicador visual discreto de "modo anônimo ativo".
- O botão de pânico nunca é coberto por nenhum outro elemento.

---

## 6. Passo a passo de execução (siga em ordem, commit a cada passo)

1. `flutter create . --org com.secretbrowser --platforms=android,ios,macos,windows`
   dentro deste repo (preserve o `.git` e este PROMPT.md). Commit: `chore: scaffold flutter`.
2. Adicionar dependências (`flutter_inappwebview`, `riverpod`) ao `pubspec.yaml`. Commit.
3. Implementar `core/privacy_config.dart` + testes. Commit.
4. Implementar `core/platform_exit.dart` (com stub iOS/DecoyScreen). Commit.
5. Implementar `core/panic_service.dart` + testes (é o mais crítico — cobrir bem). Commit.
6. Implementar `core/keyboard_shortcuts.dart`. Commit.
7. Implementar `features/browser/*` (WebView, address bar, tabs). Commit.
8. Implementar `features/panic/*` (botão flutuante arrastável). Commit.
9. Montar `app.dart` + `main.dart` ligando tudo. Commit.
10. Ajustar permissões nativas por plataforma (INTERNET no Android, entitlements de rede no
    macOS/iOS, capability de WebView2 no Windows). Commit.
11. Escrever `README.md` (setup, build por plataforma, limites de privacidade honestos). Commit.
12. Rodar `flutter analyze` e `flutter test` — tudo deve passar. Commit final.

---

## 7. Critérios de aceitação (o app está "pronto" quando…)

- [ ] `flutter analyze` sem erros/warnings; `flutter test` 100% verde.
- [ ] Navegar em qualquer site funciona nas 4 plataformas alvo (testar ao menos em 1 desktop).
- [ ] Fechar e reabrir o app: **nenhum** histórico, cookie ou cache do que foi navegado persiste.
- [ ] Tocar no "X" → tela apaga tudo e o app fecha (Android/Windows/macOS) ou vai pro decoy (iOS).
- [ ] `Ctrl/Cmd+Shift+X` dispara exatamente o mesmo comportamento.
- [ ] O botão "X" está sempre visível e é arrastável.
- [ ] Inspecionar o diretório de dados do app após um wipe: **vazio** de dados de navegação.
- [ ] README documenta claramente que o anonimato é **local**, não de rede (sem Tor/VPN ainda).

---

## 8. Fora de escopo agora (roadmap / TODO no README)

- Integração com Tor/VPN para anonimato de **rede** (esconder IP).
- Sincronização, favoritos, extensões.
- Bloqueador de anúncios/rastreadores (pode ser fase 2).
- Publicação nas lojas (App Store / Play / Microsoft Store) — exige contas de dev e assinatura.

---

## 9. Requisitos de build do ambiente (o humano precisa ter instalado)

- **Flutter SDK** (stable) + `flutter doctor` sem erros.
- **Android:** Android Studio + SDK + um emulador ou aparelho.
- **iOS/macOS:** um **Mac** com **Xcode** + conta Apple Developer (para rodar em device/publicar).
- **Windows:** Visual Studio com workload "Desktop C++" (necessário para o backend WebView2).

> O Claude Code escreve **todo o código**. Compilar, assinar e publicar depende dessas ferramentas
> instaladas na máquina do desenvolvedor — o Claude guia, mas não instala SDKs por você.

---

## 10. Princípios inegociáveis

- **Privacidade acima de conveniência.** Na dúvida, não persista nada.
- **O wipe nunca pode falhar silenciosamente.** Se um passo do wipe der erro, continue os demais
  e só então feche — nunca aborte o wipe pela metade.
- **Zero telemetria.** Nenhuma lib que "liga pra casa".
- **Honestidade no README.** Não prometa anonimato de rede que o app ainda não entrega.
