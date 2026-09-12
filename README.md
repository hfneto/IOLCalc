# Calculadora de LIO — app nativo (iOS + macOS)

Sucessor da versão web publicada em drhallim.com.br/calculo (que será descontinuada).

## Estrutura

| Pasta | O que é |
|---|---|
| `IOLCalc.xcodeproj` | Projeto Xcode. Um único target `IOLCalc` para iPhone, iPad e Mac. |
| `IOLCalc/` | App SwiftUI. Alterna entre a calculadora web embutida (`index.html` em `WKWebView`) e a versão nativa em `IOLCalc/Native/` (seções 1 a 3 e 5 a 7, relatório e casos salvos, "Nativo · beta"). |
| `IOLCore/` | Pacote Swift com o motor nativo: fórmulas (SRK/T, T2, Holladay 1 ± Wang-Koch, Hoffer Q, Haigis, Castrop), catálogo de lentes, curva de defocus, visão binocular, estereopsia, planejamento tórico (vetores de duplo-ângulo, Abulafia-Koch, Næser-Savini, razão de toricidade) e constantes da simulação visual. |
| `IOLCore/Tests` | Testes contra valores gerados pelo JavaScript original (`docs/golden-generator.js`, `docs/toric-generator.js`). |
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
própria → biometria e cálculo em SwiftUI (feito) → Swift Charts (feito) → IA com câmera (feito) →
tórica e simulação (feito) → relatório nativo (feito) → remover o `index.html`.

## Tela nativa (Nativo · beta)

O seletor no topo do app alterna "Página web" / "Nativo · beta" (`RootView`). A tela nativa
(`IOLCalc/Native/`) tem as seções 1 a 3 (biometria, lentes e alvo, poder da LIO), a seção 5 (curva de
defocus, binocular, métricas), a gaveta de comparação, a seção 6 (simulação visual em `Canvas`) e a
seção 7 (planejamento tórico com diagrama arrastável), todas calculando com o `IOLCore`:

- `CalculatorModel` guarda os campos como texto (aceita vírgula ou ponto) e persiste método de
  biometria e ΔA nas mesmas chaves da web (`iol_method`, `iol_dA2_*`).
- `IOLCore/Planning.swift` porta o `recalc()` da web: mediana das fórmulas recomendadas, candidatos
  em passos de 0,5 D, "primeira lente que não deixa hipermetropia", alternativa e alertas. O teste
  `PlanningTests` confere paridade 1e-9 com o JavaScript (`Resources/planning.json`, gerado com o
  motor do `index.html` no JavaScriptCore).
- Argumentos de execução úteis em DEBUG/macOS: `-iol_sample YES` preenche o caso da prancha de
  design; `-iol_snapshot <png>` (com `-iol_snapshot_height`, `-iol_snapshot_scroll` ou
  `-iol_snapshot_bottom YES`) grava a janela em PNG dentro do container do app;
  `-iol_chart_snapshot <png>` renderiza só o gráfico de defocus; `-iol_toric_snapshot <png>` e
  `-iol_sim_snapshot <png>` (com `-iol_sim_night YES`, `-iol_sim_astig YES`) renderizam as seções 7 e 6;
  `-iol_report_snapshot <png>` e `-iol_report_pdf <pdf>` renderizam o relatório; `-iol_cases_test <txt>`
  faz um ciclo salvar/atualizar/recarregar/apagar num JSON temporário e grava "OK" no fim;
  `-iol_no_keychain YES` pula o Keychain (um binário recém-compilado faria o sistema pedir confirmação
  e travaria a captura).
- `IOLCore/Toric.swift` porta o módulo tórico da web (`torState`/`toricRecalc`): astigmatismo total
  por K anterior, Abulafia-Koch, Næser-Savini ou TK medido; SIA vetorial; cilindro da LIO convertido
  ao plano corneano pela razão de toricidade (calculada pela ELP do olho com o SRK/T, senão o padrão
  da plataforma); residual, desalinhamento e "sugerir ideal". `ToricTests` confere paridade 1e-9 em
  362 casos gerados pelo JavaScript (`Resources/toric.json`).
- **Relatório** (`ReportView.swift`): mesmo conteúdo do `generateReport()` da web (biometria, poder
  por olho com tabela de fórmulas, visão binocular, tórica, comparador, aviso, assinaturas), só com
  `Text`/`Grid`. `ReportPDF.make` gera PDF A4 paginado com `ImageRenderer.render`; a sheet
  (`NativeReportSheet`) mostra a prévia, imprime e compartilha o PDF.
- **Casos salvos** (`CaseStore.swift`, `CasesSheet.swift`): `CalculatorModel.snapshot()/restore()`
  serializam `EyeForm`/`ToricForm` e as escolhas; a lista fica em
  `Application Support/IOLCalc/cases.json` no container do app. "Salvar caso atual", "Atualizar" (quando
  o estado veio de um caso), "Salvar como novo", abrir, renomear e apagar. "Limpar" começa um caso novo.
- `SimulationSection` desenha os quatro quadros (celular, notebook, GPS, rua) em `Canvas`, em
  tamanho físico real, com desfoque gaussiano pela AV binocular prevista, arrasto direcional do
  astigmatismo, perda de contraste das difrativas e halos/anéis/starburst à noite.
