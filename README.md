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
| `server/` | **Obsoleto.** Plugin WordPress v2.2 que nunca foi instalado; a leitura por IA agora é feita no app. Mantido só como referência. |
| `design/` | Pranchas do layout desktop (canvas do Claude Design) usadas como referência da interface. |
| `docs/` | `ROADMAP.md` (saída do WordPress), `STATUS.md`, artigo da regressão tórica e o gerador de valores de referência. |

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

## Leitura por IA

Na primeira abertura o app pede a **chave da API da Anthropic** (`sk-ant-…`, criada em
console.anthropic.com). Ela é conferida com `GET /v1/models`, guardada no Keychain do aparelho e
nunca sai dele: o laudo vai direto do app para `api.anthropic.com` (`IOLCalc/AIReader.swift`), sem
servidor intermediário. A página injeta `window.IOL_NATIVE.ai` e chama
`webkit.messageHandlers.aiRead` para ler o laudo. "Trocar chave da API" fica em
Biometria › Leitura por IA · avançado. O WordPress não é mais usado para nada.

## Como o híbrido funciona

- `IOLCalc/index.html` é uma cópia da versão web (sem o registro do service worker).
- A página é carregada com a origem `https://drhallim.com.br/calculo/` apenas para que o
  `localStorage` (modelo de IA, método de cálculo) tenha um domínio estável; nenhuma chamada de rede
  vai para o site (ver fase 2 do `docs/ROADMAP.md`).
- Links externos (Barrett, Kane, ESCRS…) abrem no navegador do sistema.
- O botão **Relatório** abre uma sheet com o relatório, com impressão e exportação em PDF.
- Em **Calculadoras oficiais**, cada botão abre a calculadora (Barrett, Kane, ESCRS, Hill-RBF, Lucena) numa
  sheet e injeta a biometria nos campos reconhecidos por rótulo (mesma heurística do antigo bookmarklet).

## Plano de migração para nativo

Ver `docs/ROADMAP.md`. Resumo: fórmulas (feito) → IA no app (feito) → desligar o site → origem
própria → biometria e cálculo em SwiftUI → Swift Charts → IA com câmera → tórica e simulação →
relatório nativo → remover o `index.html`.
