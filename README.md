# Calculadora de LIO — app nativo (iOS + macOS)

Sucessor da versão web publicada em drhallim.com.br/calculo (que será descontinuada).

## Estrutura

| Pasta | O que é |
|---|---|
| `IOLCalc.xcodeproj` | Projeto Xcode. Um único target `IOLCalc` para iPhone, iPad e Mac. |
| `IOLCalc/` | App SwiftUI. A calculadora inteira é nativa (`IOLCalc/Native/`: seções 1 a 7, relatório, casos salvos); `CalculatorFillSheet` abre as calculadoras oficiais (sites de terceiros) em `WKWebView` e preenche a biometria. |
| `IOLCore/` | Pacote Swift com o motor nativo: fórmulas (SRK/T, T2, Holladay 1 ± Wang-Koch, Hoffer Q, Haigis, Castrop), catálogo de lentes, curva de defocus, visão binocular, estereopsia, planejamento tórico (vetores de duplo-ângulo, Abulafia-Koch, Næser-Savini, razão de toricidade) e constantes da simulação visual. |
| `IOLCore/Tests` | Testes contra valores gerados pelo JavaScript original (`docs/golden-generator.js`, `docs/toric-generator.js`). |
| `Web/` | Snapshot da versão web (index.html, service worker, plugin PHP). Referência histórica: o app não usa mais nenhuma página embutida. |
| `server/` | **Obsoleto.** Plugin WordPress v2.2 que nunca foi instalado; a leitura por IA agora é feita no app. Mantido só como referência. |
| `design/` | Pranchas do layout desktop (canvas do Claude Design) usadas como referência da interface. |
| `docs/` | `ROADMAP.md` (migração, concluída), `STATUS.md`, `DISTRIBUICAO.md` (TestFlight, Developer ID, iCloud), artigo da regressão tórica, geradores de valores de referência e prompts das cenas. |

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
console.anthropic.com). Ela é conferida com `GET /v1/models`, guardada no Keychain (sincronizada
pelo iCloud Keychain para os outros aparelhos, protegida por Face ID / Touch ID ao abrir o app) e
nunca sai dele: o laudo vai direto do app para `api.anthropic.com` (`IOLCalc/AIReader.swift`), sem
servidor intermediário. "Trocar chave da API" fica em
Biometria › Leitura por IA · avançado. O WordPress não é mais usado para nada.

## Calculadoras oficiais

Em **4 · Calculadoras oficiais**, cada botão abre a calculadora (Barrett, Kane, ESCRS, Hill-RBF,
Lucena) numa sheet e injeta a biometria nos campos reconhecidos por rótulo (heurística em
`CalculatorFill.script`, a mesma do antigo bookmarklet). "Copiar biometria" põe o resumo em texto na
área de transferência. Links externos abrem no navegador do sistema.

## Plano de migração para nativo

Ver `docs/ROADMAP.md`. Resumo: fórmulas (feito) → IA no app (feito) → desligar o site → origem
biometria e cálculo em SwiftUI (feito) → Swift Charts (feito) → IA com câmera (feito) → tórica e
simulação (feito) → relatório nativo (feito) → remover o `index.html` (feito). O app é 100 % nativo.

## Tela nativa

A tela (`IOLCalc/Native/`) tem as seções 1 a 3 (biometria, lentes e alvo, poder da LIO), a seção 5 (curva de
defocus, binocular, métricas), a gaveta de comparação, a seção 6 (simulação visual em `Canvas`) e a
seção 7 (planejamento tórico com diagrama arrastável), todas calculando com o `IOLCore`:

- `CalculatorModel` guarda os campos como texto (aceita vírgula ou ponto) e persiste método de
  biometria e ΔA nas mesmas chaves da web (`iol_method`, `iol_dA2_*`).
- `IOLCore/Planning.swift` porta o `recalc()` da web: mediana das fórmulas recomendadas, candidatos
  em passos de 0,5 D, "primeira lente que não deixa hipermetropia", alternativa e alertas. O teste
  `PlanningTests` confere paridade 1e-9 com o JavaScript (`Resources/planning.json`, gerado com o
  motor do `index.html` no JavaScriptCore).
- Argumentos de execução úteis em DEBUG/macOS: `-iol_sample YES` preenche o caso da prancha de
  design (`-iol_native_ui` não é mais necessário); `-iol_snapshot <png>` (com `-iol_snapshot_height`, `-iol_snapshot_scroll` ou
  `-iol_snapshot_bottom YES`) grava a janela em PNG dentro do container do app;
  `-iol_chart_snapshot <png>` renderiza só o gráfico de defocus; `-iol_toric_snapshot <png>` e
  `-iol_sim_snapshot <png>` (com `-iol_sim_night YES`, `-iol_sim_astig YES`) renderizam as seções 7 e 6;
  `-iol_report_snapshot <png>` e `-iol_report_pdf <pdf>` renderizam o relatório;
  `-iol_phone_snapshot <png>` com `-iol_force_compact YES` renderiza a página inteira na largura de
  iPhone (390 pt) para conferir o layout compacto no Mac; `-iol_cases_test <txt>`
  faz um ciclo salvar/atualizar/recarregar/apagar num JSON temporário e grava "OK" no fim;
  `-iol_no_keychain YES` pula o Keychain (um binário recém-compilado faria o sistema pedir confirmação
  e travaria a captura). Se o app já estiver aberto pelo Xcode, o macOS não abre a janela de uma
  segunda instância: compile a cópia de captura com outro bundle id
  (`xcodebuild … -derivedDataPath DerivedData/Snap build PRODUCT_BUNDLE_IDENTIFIER=br.com.drhallim.IOLCalcSnap
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS= DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=`,
  assinatura ad hoc sem o entitlement do iCloud, que exigiria perfil;
  o container passa a ser `~/Library/Containers/br.com.drhallim.IOLCalcSnap/Data`).
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
- `SimulationSection` mostra duas cenas com as três distâncias em camadas, geradas por IA
  (Gemini `gemini-3-pro-image`, prompts em `docs/simulacao-prompts.md`) a partir da descrição do
  usuário. Dia: cafeteria (celular na mão a 40 cm, notebook a 66 cm, cardápio, quadros, rua pela
  janela). Noite: dirigindo (celular na mão, GPS no painel a 66 cm, carro à frente com placa,
  semáforo, placas, luzes). As telas das fotos são geradas em branco e o app desenha por cima a
  mensagem, o e-mail e o GPS (`SimulationScene.Quad`, transformação afim pelos cantos). Cada camada
  (`farPolygons`, foto inteira, `nearPolygons`) é desfocada pela AV da sua distância (gaussiano a
  2 px/′; a ampliação das fotos é menor que a real), astigmatismo por média aditiva de 8 cópias,
  perda de contraste das difrativas e halos/anéis/starburst nas luzes marcadas em
  `SimulationScene.night.lights`. Para trocar uma foto: gerar em 3:2, recortar para 14:9 (1680 × 1080),
  substituir em `Assets.xcassets` e ajustar polígonos, quadriláteros e luzes (o processo com as
  ferramentas de grade/máscara está descrito no STATUS).