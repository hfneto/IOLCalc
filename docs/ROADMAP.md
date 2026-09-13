# Roadmap — Calculadora de LIO fora do WordPress

Atualizado em 12/09/2026 (noite).

## Onde o WordPress entrava

Até ontem o site drhallim.com.br fazia duas coisas pela calculadora:

1. Hospedar a PWA em `/calculo` (a versão web, que será descontinuada).
2. Servir de proxy para a leitura de laudos por IA: o plugin `iol-calc-proxy.php` guardava a chave
   da API da Anthropic e a senha de acesso compartilhada.

Depois da fase 0, **o app não faz nenhuma chamada ao drhallim.com.br**. O que sobra do site dentro
do app é só cosmético: a URL base do `WKWebView` (usada como "domínio" do `localStorage`) e o nome
do site no rodapé do relatório.

## Fase 0 — IA direto no app ✅ (11/09/2026)

- Chave da API da Anthropic digitada uma vez no app e guardada no Keychain (`APIKeyStore`).
- Leitura por IA em Swift (`AIReader`): mesmo prompt, mesmo payload e mesma resposta do plugin.
- A página chama `webkit.messageHandlers.aiRead` em vez de `fetch('/wp-json/iol/v1/read')`.
- Login por e-mail/senha e plugin v2.2 abandonados (`server/` ficou só como referência).

## Fase 1 — Desligar o lado do site (tarefa sua, 15 min)

Nada no app depende disto; é higiene e segurança.

1. Revogar no console da Anthropic a chave que estava no WordPress e criar uma nova só para o app.
2. Desativar e apagar o plugin **IOL Proxy** no WordPress.
3. Trocar a página `/calculo` por um aviso "a calculadora virou app" (ou apagar). Quem ainda tiver
   a PWA instalada continua com a versão antiga em cache, sem leitura por IA.

## Fase 2 — Cortar o último fio — desnecessária

Seria carregar a página com origem própria e migrar o `localStorage`. Com a Fase 8 a página deixou
de existir: as preferências já vivem no `UserDefaults` da tela nativa (`iol_method`, `iol_dA2_*`,
`iol_model`) e os casos salvos em `Application Support`. Nada no app cita o site.

## Fase 3 — Biometria e cálculo em SwiftUI ✅ (11/09/2026, seções 1–3 em `IOLCalc/Native/`)

O coração da migração nativa. Tela de biometria (OD/OE, CCT, TK, método com ΔA automático),
seleção de lente e alvo, e cálculo do poder usando `IOLCore`, que já tem paridade com o JS.
Sugestão "primeira lente sem hipermetropia" e refração prevista por inversão.

## Fase 4 — Defocus, binocular e comparador ✅ (11/09/2026, Swift Charts)

Curva de defocus e AV binocular em Swift Charts; comparador de lentes em gaveta, como hoje.

## Fase 5 — Leitura por IA nativa ✅ (11/09/2026: scanner VisionKit, Fotos e arquivos → `AIReader` → campos nativos)

Câmera/scanner (VisionKit), fotos e PDF direto no app, chamando `AIReader` sem passar pelo
WebView. `AIReader` já está pronto para isso; falta só a interface e o preenchimento dos campos
nativos da fase 3.

## Fase 6 — Tórica e simulação visual ✅ (12/09/2026)

Planejamento tórico (SIA vetorial, Abulafia-Koch do artigo em `docs/`, Næser-Savini, TK medido,
razão de toricidade pela ELP) em `IOLCore/Toric.swift` + `ToricSection`, com diagrama arrastável;
simulação em quadros ampliados desenhada em `Canvas` (`SimulationSection`).

## Fase 7 — Relatório nativo ✅ (12/09/2026)

Relatório em SwiftUI (`ReportView`), exportado com `ImageRenderer` para PDF A4 paginado
(`ReportPDF`), impressão (PDFKit no Mac, `UIPrintInteractionController` no iPhone) e `ShareLink`.
De quebra, **casos salvos** (`CaseStore`, `CasesSheet`): o planejamento inteiro (biometria, lentes,
alvos, tórica, comparador) fica em `Application Support/IOLCalc/cases.json`.

## Fase 8 — Remover o `index.html` ✅ (12/09/2026)

Página, `WKWebView` principal, bridge, relatório web e seletor "Página web / Nativo" removidos; a
seção 4 (calculadoras oficiais) ganhou versão nativa (`CalculatorsSection`), com a mesma heurística
de preenchimento (`CalculatorFill.script`) e "Copiar biometria". Barrett, Kane, ESCRS, Hill-RBF e
Lucena continuam abrindo em `WKWebView` (`CalculatorFillSheet`), porque são sites de terceiros.
`Web/` fica só como snapshot histórico da versão web.

## Distribuição

- **Só para você, agora:** Mac direto do Xcode; iPhone com Apple ID gratuito (o app expira em 7
  dias e precisa ser reinstalado pelo Xcode).
- **Para uso diário sem reinstalar:** Apple Developer Program (US$ 99/ano) dá TestFlight (iPhone,
  90 dias por build, renovável) e Developer ID (Mac, app assinado e notarizado).
- **App Store:** só se quiser distribuir para outros oftalmologistas; exigirá política de
  privacidade e tela para o usuário colocar a própria chave da API (já existe).
