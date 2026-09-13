# Distribuição — do Xcode ao TestFlight

Atualizado em 13/09/2026.

## Hoje (Apple ID gratuito, Personal Team)

- Mac: rodar pelo Xcode (▶ com "My Mac") — o app fica em `DerivedData` e abre normalmente depois.
- iPhone/iPad: ▶ com o aparelho no cabo. O perfil expira em **7 dias**; depois é só apertar ▶ de novo.
- Limites do Personal Team: 3 apps por aparelho, sem iCloud, sem TestFlight, sem notarização.

## Apple Developer Program (US$ 99/ano) — o que muda

1. developer.apple.com/programs › inscrever-se com o mesmo Apple ID do Xcode (pessoa física basta).
2. No Xcode: Settings › Accounts › a conta passa a mostrar o Team pago; em Signing & Capabilities
   escolha esse Team no target `IOLCalc` (troca o `DEVELOPMENT_TEAM` no projeto).
3. **iCloud para os casos** (opcional): Signing & Capabilities › "+ Capability" › iCloud › iCloud
   Documents, container `iCloud.br.com.drhallim.IOLCalc`. Depois, no `CaseStore`, trocar
   `defaultURL` pelo container ubíquo (`FileManager.default.url(forUbiquityContainerIdentifier:)`
   + `Documents/cases.json`) e observar mudanças com `NSMetadataQuery` — meia sessão.

## TestFlight (iPhone e iPad sem cabo, build válido por 90 dias)

1. Xcode › Product › Archive (destino "Any iOS Device"). Aguarde o Organizer abrir.
2. Distribute App › **TestFlight & App Store** › Upload (deixe o Xcode gerenciar assinatura).
3. Em appstoreconnect.apple.com › Apps › "+" › New App: plataforma iOS, nome "Calculadora de LIO",
   bundle id `br.com.drhallim.IOLCalc`, SKU qualquer, idioma pt-BR.
4. Depois do processamento (5–20 min), aba TestFlight › Internal Testing › crie um grupo e adicione
   o seu Apple ID como testador. No iPhone/iPad instale o app **TestFlight** e aceite o convite.
5. Cada nova versão: aumente `CURRENT_PROJECT_VERSION` (build) — a `MARKETING_VERSION` só quando
   quiser — e repita Archive › Upload. O TestFlight avisa nos aparelhos.

Já preparado no projeto: `ITSAppUsesNonExemptEncryption = NO` (só HTTPS; evita a pergunta de
criptografia a cada build), `PrivacyInfo.xcprivacy` (sem rastreamento; UserDefaults declarado),
descrição de uso da câmera, categoria "Medical", sandbox com rede de saída e leitura de arquivos
escolhidos pelo usuário.

## Mac fora do Xcode (Developer ID)

Product › Archive (destino "My Mac") › Distribute App › **Direct Distribution** (assina com Developer
ID e notariza automaticamente) › Export. O `.app` resultante pode ser copiado para `/Applications` e
enviado por AirDrop para outro Mac.

## App Store (só se for distribuir para outros oftalmologistas)

Além do acima: política de privacidade publicada numa URL, capturas de tela (iPhone 6,7", iPad 13",
Mac), descrição, e a tela de chave da API já existente (cada usuário usa a própria chave). Revisão da
Apple costuma pedir uma conta/chave de teste: prepare uma chave da Anthropic só para a revisão.
