# Estado do projeto — 11/09/2026

Sessão anterior: https://claude.ai/code/session_0153A2Tu3tz7zphMYzUt9NQP

## Feito
- App híbrido iOS/macOS em `~/Developer/IOLCalc` (Xcode 26.6).
- **11/09:** leitura por IA direto no app. Chave da API da Anthropic no Keychain (`Auth.swift`,
  `APIKeyStore`), chamada em Swift (`AIReader.swift`), bridge `aiRead` no `WKWebView`. Login por
  e-mail/senha e plugin WordPress v2.2 abandonados; `server/` é obsoleto.
- CCT, método de biometria com ΔA automático, sugestão "primeira lente sem hipermetropia",
  calculadoras oficiais preenchidas dentro do app, comparador em gaveta, tórica com
  plataforma/razão em "avançado", simulação em quadros ampliados, barra lateral no desktop.
- `IOLCore` (Swift): fórmulas + CCT, 8 testes passando (`cd IOLCore && swift test`).
- Roadmap de saída do WordPress em `docs/ROADMAP.md`.
- Canvas de design: https://claude.ai/code/artifact/53b9c69e-7379-446f-951d-d1488f7621e4

## Pendências do usuário
1. Abrir o app, colar a chave da API (console.anthropic.com) e ler um laudo real.
2. Fase 1 do roadmap: revogar a chave que estava no WordPress, desativar o plugin, avisar em /calculo.
3. Apple ID no Xcode + Team no target para rodar no iPhone.
4. Opcional: renomear `Auth.swift` → `APIKeyStore.swift` e `LoginView.swift` → `APIKeyView.swift`
   no Xcode (os arquivos já têm o conteúdo novo; só o nome ficou antigo).

## Próximos passos sugeridos
- Fase 2 do roadmap (origem própria + migrar localStorage), depois fase 3 (biometria em SwiftUI).

## Como testar a página sem abrir o app
`Tools/webtest.swift` carrega `IOLCalc/index.html` num WKWebView headless com um
bridge `aiRead` falso e confere que a leitura preenche os campos. Compilar com
`swiftc -O Tools/webtest.swift -o /tmp/webtest` e rodar `/tmp/webtest`.
