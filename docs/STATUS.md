# Estado do projeto — 12/09/2026

Sessões: https://claude.ai/code/session_0153A2Tu3tz7zphMYzUt9NQP (Fase 0),
https://claude.ai/code/session_01WvfqNJWEFnjbtQFmfWf4dC (Fases 3 a 5) e
https://claude.ai/code/session_01MMnUxFEgepmGDGBTpAMtyy (Fase 6).

A Fase 6 foi feita direto em `main` (o worktree `worktree-biometria-swiftui` em
`.claude/worktrees/biometria-swiftui` ficou parado no commit da Fase 5 e pode ser apagado:
`git worktree remove .claude/worktrees/biometria-swiftui && git branch -d worktree-biometria-swiftui`).

## Feito
- App híbrido iOS/macOS em `~/Developer/IOLCalc` (Xcode 26.6).
- **Fase 0:** leitura por IA direto no app. Chave da API da Anthropic no Keychain (`Auth.swift`,
  `APIKeyStore`), chamada em Swift (`AIReader.swift`), bridge `aiRead` no `WKWebView`. Login por
  e-mail/senha e plugin WordPress v2.2 abandonados; `server/` é obsoleto.
- **Fase 3:** seções 1 a 3 nativas em `IOLCalc/Native/` (biometria OD/OE com CCT e TK, método de
  biometria com ΔA, LIO/constante A/alvo, sugestão "primeira lente sem hipermetropia", tabela por
  fórmula, alertas). `IOLCore/Planning.swift` com paridade 1e-9 contra o JavaScript.
- **Fase 4:** seção 5 nativa (curva de defocus em Swift Charts, régua de residual, astigmatismo,
  métricas longe/66 cm/40 cm/estereopsia) e gaveta "Comparar 2 lentes no mesmo olho".
- **Fase 5:** "Ler laudo com IA" na tela nativa (`BiometryReader.swift`, `AIReadControls.swift`):
  Mac escolhe arquivos/PDF; iPhone digitaliza com a câmera (VisionKit), Fotos ou Arquivos.
- **Fase 6:** seção 7 (tórica) e seção 6 (simulação visual) nativas.
  - `IOLCore/Toric.swift`: `AstigmatismVector` (duplo-ângulo), `CornealAstigmatismModel` (K anterior,
    Abulafia-Koch, Næser-Savini, TK total), `ToricPlatform` (6 plataformas), `ToricPlanner.plan`
    (astig. total + SIA, LIO no plano corneano, residual, desalinhamento), `suggestion` e
    `toricityRatio` (ELP do olho via SRK/T). `IOLCore/Simulation.swift`: constantes e escalas dos quadros.
  - `ToricSection.swift`: cartões OD/OE com os campos da web (os que seguem a biometria usam
    "overrides" em `ToricForm`, o equivalente do `dataset.touched`), plataforma/razão em "avançado",
    "sugerir ideal", "alinhar ao astig.", copiar OD↔OE, diagrama em `Canvas` com arrasto do eixo da
    LIO e da incisão, métricas e nota de desalinhamento.
  - `SimulationSection.swift`: quatro quadros em `Canvas` (celular 40 cm, notebook 70 cm, GPS 75 cm,
    rua 50 m) em tamanho físico, desfoque pela AV binocular, arrasto do astigmatismo (olho de menor
    cilindro), contraste das difrativas, dia/noite e halos com 3 modos de variação individual.
  - `ToricTests` (362 casos + razões + Abulafia-Koch, gerados por `docs/toric-generator.js` no jsc)
    e `SimulationTests`. `IOLCore`: 21 testes passando (`cd IOLCore && swift test`).
- Seletor "Página web / Nativo · beta" no topo (`RootView`); a página web continua completa.
- Roadmap de saída do WordPress em `docs/ROADMAP.md`; canvas de design:
  https://claude.ai/code/artifact/53b9c69e-7379-446f-951d-d1488f7621e4

## Pendências do usuário
1. Abrir o app, colar a chave da API (console.anthropic.com) e ler um laudo real na tela nativa.
2. Testar a seção 7 num caso real com TK (deve mudar sozinha para "Total") e o arrasto no iPhone
   (o gesto começa sem distância mínima; se atrapalhar a rolagem, aumentar `minimumDistance`).
3. Fase 1 do roadmap: revogar a chave que estava no WordPress, desativar o plugin, avisar em /calculo.
4. Apple ID no Xcode + Team no target para rodar no iPhone.
5. Opcional: renomear `Auth.swift` → `APIKeyStore.swift` e `LoginView.swift` → `APIKeyView.swift`;
   apagar o worktree antigo (comando acima).

## Próximos passos sugeridos
- Fase 7 (relatório nativo com `ImageRenderer`: já há tudo no `CalculatorModel`, inclusive o bloco
  tórico por olho como no `torBlock` da web) e Fase 2 (origem própria) antes de remover o `index.html`.
- Seção 4 (calculadoras oficiais) na tela nativa: reaproveitar `CalculatorFillSheet` com os
  dados do `CalculatorModel`.
- Ergonomia da seção 6 no iPhone: os quadros ficam em coluna única (300 pt mínimos); avaliar
  se vale um carrossel.

## Como testar sem abrir o app
- Página web: `Tools/webtest.swift` (WKWebView headless com bridge `aiRead` falso). Compilar com
  `swiftc -O Tools/webtest.swift -o /tmp/webtest` e rodar `/tmp/webtest`.
- Tela nativa (DEBUG/macOS): sempre com `-iol_no_keychain YES` quando rodar do terminal (o binário
  recém-compilado faz o Keychain pedir confirmação e a captura trava).
  `-iol_sample YES -iol_native_ui YES -iol_snapshot <png>` grava a janela em PNG dentro de
  `~/Library/Containers/br.com.drhallim.IOLCalc/Data/`; `-iol_snapshot_bottom YES` rola até o fim.
  `-iol_chart_snapshot <png>` renderiza só o gráfico; `-iol_toric_snapshot <png>` a seção 7;
  `-iol_sim_snapshot <png>` a seção 6 (`-iol_sim_night YES`, `-iol_sim_astig YES`). No `ImageRenderer`
  os controles AppKit (campos, seletores, links) saem como retângulos amarelos — é limitação da
  captura, não do app; use `-iol_snapshot` para vê-los.
  `-iol_ai_fake_file <txt>` aplica um JSON como se viesse da IA; `-iol_prep_test <imagem>` grava
  `<imagem>.txt` com o resultado do preparo de upload.
- Valores dourados: `jsc docs/toric-generator.js > IOLCore/Tests/IOLCoreTests/Resources/toric.json`
  (jsc em `/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc`).
