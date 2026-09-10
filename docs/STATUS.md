# Estado do projeto — 10/09/2026

Sessão anterior: https://claude.ai/code/session_0153A2Tu3tz7zphMYzUt9NQP

## Feito
- App híbrido iOS/macOS em `~/Developer/IOLCalc` (Xcode 26.6), 3 commits.
- Login nativo (Keychain) + plugin WordPress v2.2 em `server/` (ainda NÃO instalado no site → app em modo legado).
- CCT, método de biometria com ΔA automático, sugestão "primeira lente sem hipermetropia",
  calculadoras oficiais preenchidas dentro do app (Barrett verificada; ESCRS/Kane/Lucena pedem
  "Preencher de novo" depois de entrar no formulário), comparador em gaveta, tórica com
  plataforma/razão em "avançado", simulação em quadros ampliados, barra lateral no desktop.
- `IOLCore` (Swift): fórmulas + CCT, 8 testes passando (`cd IOLCore && swift test`).
- Canvas de design: https://claude.ai/code/artifact/53b9c69e-7379-446f-951d-d1488f7621e4

## Pendências do usuário
1. Instalar `server/iol-calc-proxy.php` no WordPress (Plugins > Enviar plugin).
2. Apple ID no Xcode + Team no target para rodar no iPhone.

## Próximos passos sugeridos
- Testar a leitura por IA de um laudo real no app (Mac) após instalar o plugin.
- Migração nativa: biometria + cálculo em SwiftUI usando `IOLCore`; depois Swift Charts.
- Rever curvas do catálogo (ex. ReSTOR a −1,5 D) se a experiência clínica divergir.

## Como testar a página sem abrir o app
Os testes headless (WKWebView) desta sessão eram scripts Swift ad hoc; se precisar, recriar:
carregar `IOLCalc/index.html` com base URL `https://drhallim.com.br/calculo/` e rodar `runSelfTest(true)`.
