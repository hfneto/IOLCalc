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

## Como o híbrido funciona

- `IOLCalc/index.html` é uma cópia da versão web (sem o registro do service worker).
- A página é carregada com a origem `https://drhallim.com.br/calculo/`. Assim a leitura de laudos
  por IA continua chamando `/wp-json/iol/v1/read` como mesma origem (sem CORS) e o `localStorage`
  (senha da IA, método de cálculo) tem um domínio estável.
- Links externos (Barrett, Kane, ESCRS…) abrem no navegador do sistema.
- O botão **Relatório** abre uma sheet com o relatório, com impressão e exportação em PDF.

## Plano de migração para nativo

1. **Fórmulas** — feito em `IOLCore` (paridade 1e-9 D com o JS).
2. Tela de biometria + cálculo do poder em SwiftUI, usando `IOLCore`.
3. Curva de defocus em Swift Charts.
4. Leitura de laudo por IA nativa (câmera + URLSession), dispensando o WKWebView para essa etapa.
5. Planejamento tórico e simulação visual.
6. Remover o `index.html` quando todos os módulos estiverem nativos.
