# Calculadora de LIO — app nativo (iOS + macOS)

Sucessor da versão web publicada em drhallim.com.br/calculo (que será descontinuada).

## Estrutura

| Pasta | O que é |
|---|---|
| `IOLCalc.xcodeproj` | Projeto Xcode. Um único target `IOLCalc` para iPhone, iPad e Mac. |
| `IOLCalc/` | App SwiftUI. Hoje exibe a calculadora web embutida (`index.html`) em um `WKWebView`. |
| `IOLCore/` | Pacote Swift com o motor nativo: fórmulas (SRK/T, T2, Holladay 1 ± Wang-Koch, Hoffer Q, Haigis, Castrop), catálogo de lentes, curva de defocus, visão binocular e estereopsia. |
| `IOLCore/Tests` | Testes contra valores gerados pelo JavaScript original (`docs/golden-generator.js`). |
| `Web/` | Snapshot da versão web (index.html, service worker, plugin PHP do proxy de IA). Referência histórica. |
| `server/` | Plugin WordPress `iol-calc-proxy.php` v2.2 (login por e-mail/senha + token, CCT na leitura por IA). Precisa ser instalado no site. |
| `design/` | Pranchas do layout desktop (canvas do Claude Design) usadas como referência da interface. |
| `docs/` | Artigo da fórmula de regressão tórica e o gerador de valores de referência. |

## Como rodar

1. Abra `IOLCalc.xcodeproj` no Xcode.
2. Escolha o destino (My Mac, um simulador de iPhone ou seu iPhone) e aperte ▶.
3. Para rodar no iPhone físico: Xcode > Settings > Accounts, entre com seu Apple ID e, em
   Signing & Capabilities do target, selecione o Team.

Pela linha de comando:

```bash
xcodebuild -scheme IOLCalc -destination 'platform=macOS' build
cd IOLCore && swift test
```

## Login e leitura por IA

Na primeira abertura o app pede e-mail e senha da conta do WordPress (drhallim.com.br). Com o plugin
v2.2 instalado, o servidor devolve um token de 180 dias que fica no Keychain; a página recebe
`window.IOL_NATIVE.auth` e nunca mais mostra senha. Enquanto o plugin antigo estiver no ar, o app usa
a senha digitada como senha de acesso compartilhada (modo legado). "Sair da conta" fica em
Biometria › Leitura por IA · avançado.

## Como o híbrido funciona

- `IOLCalc/index.html` é uma cópia da versão web (sem o registro do service worker).
- A página é carregada com a origem `https://drhallim.com.br/calculo/`. Assim a leitura de laudos
  por IA continua chamando `/wp-json/iol/v1/read` como mesma origem (sem CORS) e o `localStorage`
  (senha da IA, método de cálculo) tem um domínio estável.
- Links externos (Barrett, Kane, ESCRS…) abrem no navegador do sistema.
- O botão **Relatório** abre uma sheet com o relatório, com impressão e exportação em PDF.
- Em **Calculadoras oficiais**, cada botão abre a calculadora (Barrett, Kane, ESCRS, Hill-RBF, Lucena) numa
  sheet e injeta a biometria nos campos reconhecidos por rótulo (mesma heurística do antigo bookmarklet).

## Plano de migração para nativo

1. **Fórmulas** — feito em `IOLCore` (paridade 1e-9 D com o JS).
2. Tela de biometria + cálculo do poder em SwiftUI, usando `IOLCore`.
3. Curva de defocus em Swift Charts.
4. Leitura de laudo por IA nativa (câmera + URLSession), dispensando o WKWebView para essa etapa.
5. Planejamento tórico e simulação visual.
6. Remover o `index.html` quando todos os módulos estiverem nativos.
