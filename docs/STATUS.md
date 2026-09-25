# Estado do projeto — 17/09/2026

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

## Rodada de refinamento (14/09)
- Simulação: cantos das telas do celular (dia) e do notebook remedidos com o novo ajuste por retas
  do `Tools/scene-tools.swift screen` (linha "fit"): a tela desenhada vai até a borda física, sem
  a faixa cinza que sobrava à direita e em cima; a mensagem do celular em 3 linhas cabe inteira.
  Máscaras "longe"/"perto" com borda suave (`clipToLayer` + blur de 6 px da foto). A tela do GPS
  (noite) fica com os cantos manuais: a mão cobre parte dela e o ajuste automático erra.
- iPhone (conferido no simulador iPhone 17 com `-iol_scroll_section <n>`): o seletor do método de
  biometria virou `Menu` com rótulo curto (`BiometryMethod.compactTitle`) — o `Picker` de menu
  quebrava o título longo em 3 linhas sobre o texto vizinho; `FlowLayout` dá a largura do contêiner a
  um item mais largo que ele (o botão do ESCRS estourava o cartão); faixa translúcida atrás da barra
  de status (`safeAreaInset` com fundo `ultraThinMaterial`).
- iPad na vertical (834 pt): a página de duas colunas estourava dos dois lados. `CompactWidthProvider`
  agora mede a largura (`GeometryReader`) e usa o layout de coluna única abaixo de 1000 pt, além do
  size class. iPad na horizontal e Mac seguem com duas colunas.
- Relatório em PDF: paginado bloco a bloco (`ReportView.blocks`, `ReportPDF.make`): cada seção é
  medida e desenhada em separado e vai inteira para a próxima página quando não cabe; só um bloco
  mais alto que a página é partido. Conferido com `-iol_report_pdf` (2 páginas, rasterizadas com
  PDFKit).
- Depuração: `-iol_snapshot_width <pt>` no `-iol_phone_snapshot` renderiza a página em qualquer
  largura (1100 = Mac). A captura da janela (`-iol_snapshot`) saiu em branco nesta rodada (causa não
  investigada; o render por `ImageRenderer` e o simulador cobriram a revisão).
- Ficou de fora: força do desfoque/arrasto (subjetivo, o usuário não pediu mudança) e regenerar as
  fotos com telas mais frontais.

## Rodada de 17/09 (cinco pedidos do usuário)
1. **Conferir o laudo no próprio app.** `LaudoInspector.swift`: os arquivos lidos (fotos/PDF) viram
   um `PDFDocument` (imagens → `PDFPage(image:)`) mostrado num `PDFView` (zoom, páginas) dentro de
   `.inspector` — coluna à direita no Mac/iPad, folha no iPhone. Abre sozinho depois da leitura
   quando há largura; botões "Ver laudo" (na mensagem de estado) e "Laudo" (barra do paciente);
   "Abrir arquivo…" no painel para conferir um laudo sem IA. O `CompactWidthProvider` passou para
   DENTRO do inspector (`NativeCalculatorView`): com o laudo aberto a coluna encolhe e a página vai
   para uma coluna (antes estourava e era cortada). O laudo fica só na sessão (não é salvo no caso).
   Depuração: `-iol_laudo_file <caminho dentro do container>` abre o arquivo como se lido.
2. **Catálogo de lentes e favoritas.** `LensCatalog` passou de 20 para 59 lentes (Alcon, J&J, Zeiss,
   HOYA, Rayner, BVI/PhysIOL, Bausch + Lomb, Hanita, Mediphacos, Medicontur, Teleon, Ophtec, Aurolab,
   Biotech), com `notes` (origem da constante: fabricante/IOLcon, ULIB SRK/T otimizada, rótulo;
   registro Anvisa quando encontrado) e `curveEstimated` (curva de lente parecida/média da classe).
   Os 20 ids originais não mudaram (casos salvos). Fontes: ULIB (ocusoft.de/ulib), iolreference.com,
   site da Mediphacos (MFR2, UnA, BIOS com registro Anvisa). O portal da Anvisa bloqueia consulta
   automatizada: a lista é a das marcas comercializadas no Brasil, não "todas com registro".
   `LensPreferences` (UserDefaults `iol_fav_lenses`, padrão = as 20 originais) → `LensPicker`
   mostra só favoritas + a lente em uso + "Outra LIO…" → `LensChooserSheet` (catálogo completo com
   estrela, ou nome/classe/constante à mão → `CustomLens` em `EyeForm.custom`, `lensID = "custom"`,
   curva média da classe por `LensCatalog.referenceCurve`). Comparador também tem "Outra…" (só
   catálogo). Configurações › Lentes lista tudo por fabricante.
3. **Explicações.** `HelpTopics.swift`: 12 tópicos (`HelpTopic`) com botão "?" (`HelpButton`,
   popover também no iPhone) ao lado de: método/ΔA, constante A, LIO, TK, seção 3, seção 4,
   seção 5, seção 6, base do astigmatismo, plataforma/razão, leitura por IA; e reunidos em
   Configurações › Ajuda (`SettingsSheet.swift`, engrenagem na barra do paciente).
4. **Modelo fixo.** `AIReader.defaultModel = claude-sonnet-5` (título em `defaultModelTitle`);
   seletor e chave `iol_model` removidos; o fallback do Opus saiu. Configurações › Leitura por IA
   mostra o modelo, chave (trocar/remover) e a caixa do Face ID.
5. **Preenchimento das calculadoras.** Causa do "não colou o eixo" na Kane: (a) o JSON não tinha
   eixos; (b) o preenchimento rodava 0,8/2,5/5 s após o load, antes de o usuário aceitar "I Agree"
   (a Kane só monta o formulário depois); (c) `\b` não separa `_`, então `k1_right_t_axis` caía em
   K1. Agora: JSON v2 com `K1_axis`/`K2_axis` (K1 = K2 + 90°), `TK1/2_axis` e `NAME`; rótulos
   normalizados (`_`/`-` → espaço); regras de eixo/TK/CCT antes das de K; "Axis" solto herda o K
   anterior (Lucena); label sem `for` no contêiner (Vue/React); célula rotulada mais próxima na
   tabela (Barrett); `_1`/`_2` → OD/OE (Kane); campos escondidos só com olho explícito; campos já
   preenchidos marcados (`data-iol-filled`). O script é injetado como `WKUserScript` em todos os
   frames (Hill-RBF fica num iframe de outra origem) e repete a cada 1,5 s por ≈5 min, avisando o app
   por `webkit.messageHandlers.iolFill`. "Copiar biometria" inclui eixos, TK e a LIO.
   Conferido com `Tools/filltest.swift` (WKWebView sem janela) nos 5 sites: Kane 33 campos (com a
   aba tórica), Barrett 18, ESCRS 29, Lucena 25 (com eixos), RBF 5 + 6 no iframe (AL/K ficam
   desabilitados até o usuário escolher no site; o polling preenche quando liberarem).

### Complementos (17/09, tarde)
- **Favoritas pelo iCloud.** `LensPreferences` grava no UserDefaults e no
  `NSUbiquitousKeyValueStore` (chave `iol_fav_lenses`); ao iniciar, o valor do iCloud vence; mudanças
  externas chegam por `didChangeExternallyNotification`. Entitlement novo em `IOLCalc.entitlements`:
  `com.apple.developer.ubiquity-kvstore-identifier = $(TeamIdentifierPrefix)$(CFBundleIdentifier)`.
  **No Xcode**, se a assinatura reclamar: Signing & Capabilities › iCloud › marcar "Key-value storage"
  (o perfil precisa incluir o KVS). Sem o entitlement o app não quebra: as favoritas ficam locais.
- **Laudo guardado com o caso.** `SavedCase.laudo: [LaudoPage]?` (nome do arquivo + UTType) no
  `cases.json`; os bytes ficam em `laudos/<id do caso>/paginaN.(jpg|pdf)` ao lado do `cases.json`,
  no espelho local e no iCloud Drive (`Documents/laudos/…`, `NSFileCoordinator`). Imagens são
  reamostradas ao guardar (`UploadPrep.storageCopy`: máx. 2000 px, JPEG 0,75); PDFs seguem inteiros.
  "Salvar caso" leva o laudo da sessão; "Atualizar" só troca o laudo quando a sessão leu um novo
  (`AIReaderState.laudoCaseID` marca de qual caso o laudo atual veio; nunca apaga por omissão).
  Abrir um caso carrega o laudo (`CaseStore.loadLaudo`: local, senão pede o download do iCloud e
  espera até ≈60 s por página; a barra mostra "Laudo · baixando…"). Apagar o caso apaga a pasta;
  `pruneLocalLaudos` limpa pastas de casos apagados noutro aparelho. Exportar embute as páginas em
  base64 no `.iolcase.json` (`LaudoPage.base64`) e importar grava os arquivos de volta (bytes
  intactos). Lista de casos mostra o chip "laudo". `-iol_cases_test` cobre tudo isso (OK).

### Publicação (17/09, 11:50 e 14:00)
Commit `5610040` enviado ao GitHub; builds de iOS (.ipa) e Mac (.pkg) enviados ao App Store Connect
pelo terminal (comandos em `docs/DISTRIBUICAO.md`), ambos "Upload succeeded". Falta, no
appstoreconnect.apple.com › TestFlight, criar o grupo de teste interno com o Apple ID do usuário e
instalar pelo app TestFlight.

## Rodada de 25/09 (correções e ajustes pedidos pelo usuário)
- **Diagrama tórico "fixo"** (`ToricSection.swift`): cadeado sobre cada diagrama, fechado por padrão —
  o `Canvas` não recebe gesto (`.gesture(_, including: .subviews)`), então rolar a tela no iPhone não
  mexe nos eixos. Aberto, só as alças respondem (marca da incisão ou as duas pontas do eixo da LIO,
  raio 32 pt) e o arrasto exige 6 pt de deslocamento. Tocar fora das alças não faz nada.
- **Configurações › Padrões** (`PlanningDefaults.swift`, `SettingsSheet.PlanningSettings`): SIA, eixo
  da incisão OD/OE, miopia da monovisão, monofocal e multifocal de referência. UserDefaults + iCloud
  KVS (`iol_planning_defaults`). Aplicados no `init` do modelo e em "Limpar"
  (`CalculatorModel.applyPlanningDefaults`); um caso aberto mantém o que foi gravado.
- **Olho dominante e monovisão** (seção 2, `dominanceRow`): segmentado OD/OE/— e "Monovisão" com o
  campo de miopia; ligar põe alvo 0,00 no dominante e −miopia no outro (`setMonovision`,
  `applyMonovisionTargets`; sem dominante marcado assume OD). No `CaseSnapshot` entram
  `dominantEye`, `monovisionOn`, `monovisionAmount`, `altScenarioOn`, `altLensID` (opcionais, para
  abrir casos antigos). Bug encontrado no caminho: `Num.fmt` gera o menos tipográfico (U+2212) e
  `Num.parse` não o lia — agora lê; os alvos usam "-" ASCII.
- **Cenário alternativo** (seções 5 e 6): "comparar com monovisão monofocal" (plano multifocal) ou
  "comparar com multifocal bilateral" (plano monovisão). Curva binocular tracejada laranja
  (`Theme.alt`), linha com as AV das três distâncias dos dois cenários, e na seção 6 o segmentado
  "plano / alternativa" troca as cenas. Residuais do cenário calculados com a constante A da lente
  alternativa e a mesma biometria (`altResidual`, `altBinocularVA`, `altSimulationAcuity`).
- **Simulação ampliável** (`SceneViewer`): toque na cena ou no botão de ampliar → tela inteira
  (iOS) / folha grande (Mac) com pinça e toque duplo (zoom até 4×, o `Canvas` é redesenhado no
  tamanho ampliado, sem perder nitidez), AV das três distâncias no topo.
- **Cena noturna nova** (Gemini, prompt em `docs/simulacao-prompts.md`): mão esquerda com o celular
  em primeiro plano, direita no volante, sem a terceira mão. Telas medidas com `scene-tools screen`
  (celular por preenchimento, GPS com o ajuste "fit"), silhueta da mão/celular/manga traçada com 22
  vértices na grade, luzes marcadas à mão (semáforos, lanternas, faróis, postes).
- **iPhone**: `CompactMenuPicker` (Theme) para seletores de menu com títulos longos (quebravam em
  várias linhas); usado na lente alternativa. Conferido no simulador iPhone 17 (seções 2, 5, 6, 7).
- **Depuração**: `-iol_monovision YES` e `-iol_alt YES` ligam monovisão e comparação no caso de
  exemplo; os testes sem janela (`-iol_cases_test`, renders por `ImageRenderer`) agora rodam no
  `init` do app (`DebugSnapshot.runHeadlessIfRequested`) — no macOS 27, em sessão em segundo plano,
  a janela não aparece e o `onAppear` não disparava. Passe caminho absoluto dentro do container.
  `sips -c` deixou de recortar nesta máquina; usar o `crop.swift` (CGImage) da sessão.
- **Enviado ao TestFlight** em 25/09 às 10:43 (iOS) e 10:44 (Mac), versão 1.1, build gerenciado pelo
  Xcode (`manageAppVersionAndBuildNumber`). Os archives antigos em `~/Library/Developer/Xcode/Archives` (24 do MeuOrcamento,
  16–18/09; nenhum do IOLCalc) ficaram para o usuário apagar (Xcode › Organizer › Archives, ou a pasta).

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
- Roadmap de migração e rodada de refinamento concluídos. Próximo: uso real por algumas semanas
  (TestFlight), política de privacidade, capturas e ficha da App Store; versão em inglês como 1.1
  (plano combinado em 14/09, ver conversa).
- Casos salvos: iCloud feito em 13/09. Se um dia houver conflito de versões do iCloud
  (`NSFileVersion`), o app ignora; o arquivo é pequeno e de um único usuário.
- TestFlight: agora possível (`docs/DISTRIBUICAO.md`), para instalar no iPhone sem cabo e sem o
  limite de 7 dias.
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
- Preenchimento das calculadoras oficiais: `swiftc -O Tools/filltest.swift -o /tmp/filltest` e
  `/tmp/filltest <url> [segundos]`; `PRE_JS="…"` executa um JS antes (aceitar termos), `USERSCRIPT=1`
  usa o mesmo script de todos os frames do app, `DEBUG_FILL=1` lista rótulo → olho → grandeza,
  `DUMP=1` imprime o texto/botões da página (`DUMP_JS=<arquivo>` um JS próprio).
- Valores dourados: `jsc docs/toric-generator.js > IOLCore/Tests/IOLCoreTests/Resources/toric.json`
  (jsc em `/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc`).
