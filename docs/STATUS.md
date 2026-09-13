# Estado do projeto — 13/09/2026

Sessões: https://claude.ai/code/session_0153A2Tu3tz7zphMYzUt9NQP (Fase 0),
https://claude.ai/code/session_01WvfqNJWEFnjbtQFmfWf4dC (Fases 3 a 5) e
https://claude.ai/code/session_01MMnUxFEgepmGDGBTpAMtyy (Fases 6 e 7).

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
  - `SimulationSection.swift` (refeita duas vezes em 12/09 a pedido do usuário; versão final à
    noite): cenas geradas com o Gemini (chave da API em `~/.config/iolcalc/gemini.key`, projeto com
    cobrança ativada; script `docs/gen-cena.py`, prompts em `docs/simulacao-prompts.md`). Dia:
    cafeteria; noite: direção em 1ª pessoa — exatamente os elementos que o usuário pediu. Camadas:
    foto inteira (66 cm) → polígonos "longe" → polígonos "perto" (mão com celular); telas em branco
    na foto preenchidas pelo app com transformação afim (`Quad`); a tela a 66 cm é desenhada antes
    do celular e recortada fora da região "perto". Astigmatismo por média aditiva; halos só nas luzes
    marcadas. Telas: os quatro cantos são medidos com `Tools/scene-tools.swift screen` (preenchimento por
    cor a partir de um ponto dentro da tela em branco) e o conteúdo é projetado por homografia
    (`GraphicsContext.Filter.projectionTransform`), que respeita a perspectiva — a versão afim de
    três cantos ficava desalinhada, como o usuário apontou. Máscaras "longe"/"perto" conferidas com
    `scene-tools mask`; luzes com `scene-tools blobs`.
  - `ToricTests` (362 casos + razões + Abulafia-Koch, gerados por `docs/toric-generator.js` no jsc)
    e `SimulationTests`. `IOLCore`: 21 testes passando (`cd IOLCore && swift test`).
- **Fase 7:** relatório nativo e casos salvos.
  - `ReportView.swift`: relatório em SwiftUI com o conteúdo do `generateReport()` da web; `ReportPDF`
    gera PDF A4 paginado via `ImageRenderer.render` (uma passagem por página, com recorte e
    deslocamento); impressão por PDFKit (Mac) / `UIPrintInteractionController` (iOS); `ShareLink`.
    Rodapé agora diz "Calculadora de LIO" (sem o site, já antecipando a Fase 2).
  - `CaseStore.swift` + `CasesSheet.swift`: `CaseSnapshot` (Codable) com biometria, lentes, alvos,
    régua, astigmatismo, tórica, simulação e comparador; JSON em `Application Support/IOLCalc/`.
    Botões "Relatório" e "Casos" na barra do paciente (`NativeCalculatorView.topBar`).
  - Verificado por `-iol_report_pdf` (2 páginas A4 no caso de exemplo) e `-iol_cases_test` (OK).
  - Ajustes pedidos depois: sem linhas de assinatura; só entram os olhos com LIO escolhida; a seção
    tórica só aparece quando há cilindro > 0 em algum olho.
- **Fase 8 (12/09, noite):** `index.html`, `ContentView`, `CalculatorWebView` (bridge), `ReportSheet`
  (relatório web) e `Tools/webtest.swift` removidos; `RootView` mostra só a tela nativa. Seção 4
  nativa (`CalculatorsSection.swift`): botões das calculadoras oficiais → `CalculatorFillSheet` com
  `CalculatorFill.script` (heurística de rótulos portada do JS) e `CalculatorModel.biometryJSON()`
  no formato do antigo `bioJSON()`; "Copiar biometria" (texto). `FlowLayout` para os botões
  quebrarem linha no iPhone. Fase 2 ficou desnecessária.
- Roadmap de saída do WordPress em `docs/ROADMAP.md`; canvas de design:
  https://claude.ai/code/artifact/53b9c69e-7379-446f-951d-d1488f7621e4

## Incidente resolvido em 12/09 (noite): "não consigo escolher a lente"
Causa: o Mac do usuário está em modo escuro. A tela nativa tem paleta clara fixa (`Theme`), mas os
controles AppKit (menus `Picker`, caixas `Toggle`, setas de `DisclosureGroup`) e o texto padrão
seguiam o esquema escuro do sistema: brancos sobre fundo claro, invisíveis. O seletor sempre
funcionou (provado por `-iol_popup_test`). Correção: `.preferredColorScheme(.light)` em `RootView`.
Diagnóstico feito com capturas da janela ao vivo (`screencapture -l <CGWindowID>`; as capturas por
`cacheDisplay` não mostravam o problema porque desenham por outro caminho). Se um dia quiser modo
escuro de verdade, é preciso uma paleta escura no `Theme`, não só tirar essa linha.

## Layout de iPhone (12/09, noite)
O usuário rodou no iPhone e a tela só cabia na horizontal. Causa: cabeçalhos com controles de largura
fixa (`fixedSize`), linhas de botões em `HStack` e margens de 32 pt. Correção: ambiente
`isCompactWidth` (`CompactWidthProvider` no `RootView`, lê o size class do iOS; `-iol_force_compact`
no Mac), `SectionCard` põe o "trailing" abaixo do título, `FlowLayout` para linhas de botões/toggles,
`AdaptiveHStack` e `.compactFixedSize()` nos seletores, tabela da seção 3 rolável na horizontal,
margens de 12 pt. `EyePair`/`EyePairLike` passaram a usar o mesmo ambiente. Conferido no simulador
(iPhone 17) e no render `-iol_phone_snapshot`.

## Itens 3 e 4 (13/09)
- Casos: exportar/importar como arquivo (`CaseExport`, `CaseFile`, `CaseStore.importCases`), para
  levar casos entre Mac e iPhone por AirDrop/Arquivos. iCloud fica para depois do Developer Program
  (Personal Team não tem a capacidade iCloud) — passos em `docs/DISTRIBUICAO.md`.
- Distribuição: `ITSAppUsesNonExemptEncryption = NO`, `PrivacyInfo.xcprivacy`, entitlements conferidos
  (sandbox, rede de saída, arquivos escolhidos). Guia completo em `docs/DISTRIBUICAO.md`.

## iCloud, Face ID e chave sincronizada (13/09, depois do Developer Program)
Pedido do usuário: no iPhone não conseguia "cadastrar" a chave; queria um acesso único na primeira
vez e depois entrada automática por Face ID.
- **Chave sincronizada** (`Auth.swift`): o item do Keychain agora é `kSecAttrSynchronizable` (iCloud
  Keychain). Digitada uma vez no Mac, aparece no iPhone/iPad do mesmo Apple ID sem digitar de novo.
  O item local antigo é promovido a sincronizado na primeira leitura; `clear()` apaga os dois.
- **Bloqueio por Face ID / Touch ID** (`AppLock.swift`, `RootView.LockScreen`): ao abrir, se há chave e
  a preferência `iol_lock_enabled` (padrão ligada; caixa na tela da chave) está ativa, a tela de
  bloqueio pede `LAContext.deviceOwnerAuthentication` (biometria com senha como alternativa). "Usar sem
  leitura por IA" deixa entrar; a leitura por IA chama `ensureKeyAccess()` e pede a biometria antes de
  usar a chave. Volta do segundo plano depois de 5 min pede de novo. `NSFaceIDUsageDescription` no
  Info.plist. Sem biometria nem senha no aparelho, não trava. É uma trava de uso do app: o item do
  Keychain em si é protegido pelo desbloqueio do aparelho (itens sincronizados não aceitam
  `SecAccessControl`).
- **Casos no iCloud Drive** (`CaseStore.swift`): `useCloud: true` no app (os testes usam arquivo
  temporário sem iCloud). O container `iCloud.br.com.drhallim.IOLCalc` é descoberto fora da thread
  principal; `Documents/cases.json` lá é a verdade e `Application Support/IOLCalc/cases.json` continua
  como espelho local. Primeira vez em cada aparelho: união dos casos locais com os do iCloud (o
  `updatedAt` mais novo vence por id; flag `iol_cloud_migrated`); depois, o iCloud manda, então apagar
  num aparelho apaga nos outros. `NSMetadataQuery` observa o arquivo e recarrega quando outro
  aparelho grava (eco da própria gravação ignorado por comparação de bytes); leitura/gravação com
  `NSFileCoordinator`. A `CasesSheet` mostra "iCloud ativo" / "iCloud indisponível".
- **Projeto:** `IOLCalc/IOLCalc.entitlements` (iCloud Documents + container) em
  `CODE_SIGN_ENTITLEMENTS`; a assinatura ad hoc do Mac (`CODE_SIGN_IDENTITY[sdk=macosx*] = -`) saiu,
  porque o iCloud exige assinatura com o Team nas duas plataformas. As compilações de captura pelo
  terminal passam `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS= DEVELOPMENT_TEAM=`
  (ver README). Conferido: build macOS e iOS Simulator, `-iol_cases_test` OK, `-iol_phone_snapshot`.
- **O que o usuário ainda precisa fazer no Xcode** (não dá para fazer pelo terminal): Settings ›
  Accounts › conferir que a conta mostra o Team pago (se o Team ID for outro que `VFK4JUPXJF`,
  trocar em Signing & Capabilities); na primeira compilação o Xcode registra a capacidade iCloud e o
  container no portal — se reclamar do perfil, "+ Capability › iCloud › iCloud Documents" com o
  container acima. iCloud Drive e iCloud Keychain precisam estar ligados no Mac e no iPhone.

## Pendências do usuário
1. Abrir o app no Mac, colar a chave da API (console.anthropic.com) e ler um laudo real; no iPhone a
   chave chega pelo iCloud Keychain (nada a digitar) e o app pede Face ID ao abrir.
2. Testar no iPhone (instruções na conversa: simulador sem Apple ID; aparelho físico com Apple ID +
   Team + Modo Desenvolvedor). Conferir o arrasto da seção 7 e o botão Imprimir do relatório.
2b. Salvar um caso real, fechar e reabrir o app, abrir o caso pela lista "Casos".
3. ~~Fase 1 do roadmap~~ feita em 13/09 (chave revogada, página apagada).
4. ~~Apple ID no Xcode + Team no target~~ feito em 13/09; ~~Developer Program~~ assinado em 13/09.
   Falta conferir o Team pago no Xcode e compilar uma vez para registrar o iCloud (seção acima).
5. Opcional: renomear `Auth.swift` → `APIKeyStore.swift` e `LoginView.swift` → `APIKeyView.swift`;
   apagar o worktree antigo (comando acima).

## Próximos passos sugeridos
- Roadmap de migração concluído. Próximo: a rodada de refinamento combinada (ver memória
  "iolcalc-refinamento-final": alinhamento das telas na simulação, revisão geral da tela e do
  relatório, iPhone), depois distribuição (Apple ID/TestFlight).
- Casos salvos: iCloud feito em 13/09. Se um dia houver conflito de versões do iCloud
  (`NSFileVersion`), o app ignora; o arquivo é pequeno e de um único usuário.
- TestFlight: agora possível (`docs/DISTRIBUICAO.md`), para instalar no iPhone sem cabo e sem o
  limite de 7 dias.
- Relatório: no PDF, o corte de página pode cair no meio de um bloco (é o `ImageRenderer` deslocado
  por página). Se incomodar, renderizar as seções separadamente e paginar por bloco.
- Seção 4 (calculadoras oficiais) na tela nativa: reaproveitar `CalculatorFillSheet` com os
  dados do `CalculatorModel`.
- Ergonomia da seção 6 no iPhone: os quadros ficam em coluna única (300 pt mínimos); avaliar
  se vale um carrossel.

## Como testar sem abrir o app
- Página web: `Tools/webtest.swift` (WKWebView headless com bridge `aiRead` falso). Compilar com
  `swiftc -O Tools/webtest.swift -o /tmp/webtest` e rodar `/tmp/webtest`.
- Tela nativa (DEBUG/macOS): sempre com `-iol_no_keychain YES` quando rodar do terminal (o binário
  recém-compilado faz o Keychain pedir confirmação e a captura trava). Se o usuário estiver com o
  app aberto no Xcode, a segunda instância fica sem janela: compilar a cópia de captura com
  `PRODUCT_BUNDLE_IDENTIFIER=br.com.drhallim.IOLCalcSnap` em `DerivedData/Snap` (ver README).
  `-iol_sample YES -iol_snapshot <png>` grava a janela em PNG dentro de
  `~/Library/Containers/br.com.drhallim.IOLCalc/Data/`; `-iol_snapshot_bottom YES` rola até o fim.
  `-iol_chart_snapshot <png>` renderiza só o gráfico; `-iol_toric_snapshot <png>` a seção 7;
  `-iol_sim_snapshot <png>` a seção 6 (dia e noite; `-iol_sim_astig YES` liga o astigmatismo). No `ImageRenderer`
  os controles AppKit (campos, seletores, links) saem como retângulos amarelos — é limitação da
  captura, não do app; use `-iol_snapshot` para vê-los.
  `-iol_popup_test <txt>` escolhe a 4ª lente no seletor do OD pelo caminho de um clique (menu →
  ação) e registra o antes/depois — serve para provar que o seletor funciona sem tocar na interface;
  `-iol_ai_fake_file <txt>` aplica um JSON como se viesse da IA; `-iol_prep_test <imagem>` grava
  `<imagem>.txt` com o resultado do preparo de upload.
- Valores dourados: `jsc docs/toric-generator.js > IOLCore/Tests/IOLCoreTests/Resources/toric.json`
  (jsc em `/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc`).
