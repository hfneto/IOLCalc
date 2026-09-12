# Estado do projeto — 11/09/2026 (noite)

Sessões: https://claude.ai/code/session_0153A2Tu3tz7zphMYzUt9NQP (Fase 0) e
https://claude.ai/code/session_01WvfqNJWEFnjbtQFmfWf4dC (Fases 3 e 4).

Todo o trabalho está no branch `worktree-biometria-swiftui` (worktree em
`.claude/worktrees/biometria-swiftui`). `main` parou em `9a96f17` e o checkout principal
tem cópias sem commit dos arquivos da Fase 0 (já commitados no branch). Para trazer tudo
para `main`:

```bash
cd ~/Developer/IOLCalc
git restore . && git clean -f IOLCalc/AIReader.swift docs/ROADMAP.md && git clean -fd Tools
git merge --ff-only worktree-biometria-swiftui
```

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
  Mac escolhe arquivos/PDF; iPhone digitaliza com a câmera (VisionKit), Fotos ou Arquivos. Imagens
  são redimensionadas/recomprimidas como na web, vários laudos são mesclados, valores fora da faixa
  geram aviso. Gaveta "Leitura por IA · avançado" com modelo e chave da API.
- Seletor "Página web / Nativo · beta" no topo (`RootView`); a página web continua completa.
- `IOLCore`: 16 testes passando (`cd IOLCore && swift test`).
- Roadmap de saída do WordPress em `docs/ROADMAP.md`; canvas de design:
  https://claude.ai/code/artifact/53b9c69e-7379-446f-951d-d1488f7621e4

## Pendências do usuário
1. Rodar os comandos acima para levar o branch a `main`.
2. Abrir o app, colar a chave da API (console.anthropic.com) e ler um laudo real (página web).
3. Fase 1 do roadmap: revogar a chave que estava no WordPress, desativar o plugin, avisar em /calculo.
4. Apple ID no Xcode + Team no target para rodar no iPhone.
5. Opcional: renomear `Auth.swift` → `APIKeyStore.swift` e `LoginView.swift` → `APIKeyView.swift`.

## Próximos passos sugeridos
- Fase 6 (tórica + simulação em `Canvas`), Fase 7 (relatório nativo) e Fase 2 (origem própria)
  antes de remover o `index.html`. Testar a leitura por IA nativa com um laudo real.
- Seção 4 (calculadoras oficiais) na tela nativa: reaproveitar `CalculatorFillSheet` com os
  dados do `CalculatorModel`.

## Como testar sem abrir o app
- Página web: `Tools/webtest.swift` (WKWebView headless com bridge `aiRead` falso). Compilar com
  `swiftc -O Tools/webtest.swift -o /tmp/webtest` e rodar `/tmp/webtest`.
- Tela nativa (DEBUG/macOS): `-iol_sample YES -iol_native_ui YES -iol_snapshot <png>` grava a
  janela em PNG dentro de `~/Library/Containers/br.com.drhallim.IOLCalc/Data/`; a captura não
  redesenha controles AppKit/eixos do Charts após rolagem, por isso `-iol_chart_snapshot <png>`
  renderiza só o gráfico com `ImageRenderer`. `-iol_ai_fake_file <txt>` aplica um JSON como se
  viesse da IA; `-iol_prep_test <imagem>` grava `<imagem>.txt` com o resultado do preparo de upload.
