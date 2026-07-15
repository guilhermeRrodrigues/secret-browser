# Instalar o Secret Browser

Baixe o arquivo da sua plataforma nos **assets** abaixo e siga as instruções.

> Navegação anônima **local**: nada da sua navegação é gravado no aparelho. Isto
> **não** esconde seu IP dos sites nem do provedor (não é Tor/VPN).

| Plataforma | Arquivo | Requisito |
|---|---|---|
| Android | `SecretBrowser-<versão>-android.apk` | Android 5.0+ (permitir "fontes desconhecidas") |
| Windows | `SecretBrowser-<versão>-windows-x64.zip` | Windows 10/11 + Edge WebView2 Runtime |
| macOS | `SecretBrowser-<versão>-macos.zip` | macOS 10.15+ |
| iPhone | `SecretBrowser-<versão>-ios-unsigned.ipa` | iOS 13+ e sideload (AltStore/Sideloadly) |

---

## 🤖 Android (.apk)

1. Baixe o `.apk`.
2. Abra o arquivo. Se pedir, permita **instalar apps de fontes desconhecidas**
   para o seu navegador/gerenciador de arquivos.
3. Confirme a instalação e abra o **Secret Browser**.

## 🪟 Windows (.zip)

1. **Antes de extrair**: clique com o botão direito no `.zip` baixado →
   **Propriedades** → marque **Desbloquear** → **OK**. Isso remove a "marca da web"
   que faz o Windows desconfiar do arquivo.
2. **Extraia** o `.zip` em uma pasta.
3. Execute **`secret_browser.exe`**.
4. Se a área de navegação ficar **em branco**, instale o
   **[Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)**
   (Evergreen Standalone) e abra novamente. O Windows 11 já vem com ele.

> O runtime do Visual C++ já vai **empacotado** junto do `.exe`, então você não
> precisa instalar nada para isso.

### ⚠️ Erro "Imagem Incorreta / 0xC0E90002"

Esse erro **não** é bug do app: é o **Smart App Control (SAC)** do Windows 11
bloqueando um programa **não assinado** (o app não tem certificado de editor
comercial). O diálogo só tem "OK", sem "Executar assim mesmo" — porque o SAC é mais
rígido que o SmartScreen.

Como o app é gratuito/open-source e não assinado, para rodar você precisa **desativar
o Smart App Control**:

1. **Ajustes** → **Privacidade e segurança** → **Segurança do Windows**
2. **Controle de aplicativo e navegador** → **Configurações do Smart App Control**
3. Mude para **Desativado**.

> ⚠️ Desativar o Smart App Control é **irreversível** sem reinstalar/resetar o Windows
> — decida com consciência. Alternativa: se você tiver o SmartScreen (e não o SAC),
> o aviso azul terá **Mais informações → Executar assim mesmo**.
>
> A solução "de verdade" (sem mexer no SAC) exige **assinatura digital paga** do
> executável ou publicação na **Microsoft Store** — está no roadmap, fora do escopo
> gratuito atual.

## 🍎 macOS (.zip)

O app **não é assinado/notarizado**, então o Gatekeeper bloqueia o duplo-clique.
Faça assim:

1. Baixe e **descompacte** o `.zip` (vai gerar `Secret Browser.app`).
2. **Clique com o botão direito** no app → **Abrir** → **Abrir** de novo no aviso.

Se ainda assim recusar ("está danificado"), rode uma vez no Terminal:

```bash
xattr -dr com.apple.quarantine "Secret Browser.app"
```

## 📱 iPhone (.ipa — não assinado)

O iOS **não permite** instalar por download direto como o Android — é restrição
da Apple. O `.ipa` publicado é **não assinado**: você o instala assinando com a
**sua própria Apple ID** (grátis) por uma ferramenta de sideload:

- **[Sideloadly](https://sideloadly.io/)** (Windows/macOS) — conecte o iPhone,
  arraste o `.ipa`, entre com sua Apple ID e instale.
- **[AltStore](https://altstore.io/)** — instala e mantém o app assinado.

Depois de instalar, confie no perfil em **Ajustes → Geral → Gerenciamento de VPN
e Dispositivo**.

> Com Apple ID **gratuita**, o app expira em **7 dias** e precisa ser
> reinstalado/reassinado (limitação da Apple, não do app). Uma conta paga do
> Apple Developer Program permite validade maior / TestFlight.

---

## Compilar você mesmo

Todo o código está neste repositório. Com o **Flutter** (stable) instalado:

```bash
flutter pub get
flutter build apk --release        # Android
flutter build windows --release    # Windows (rodar no Windows)
flutter build macos --release      # macOS
flutter build ios --release --no-codesign   # iOS (sideload)
```
