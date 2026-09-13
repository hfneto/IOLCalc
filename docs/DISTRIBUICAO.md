# Distribuição — do Xcode ao TestFlight

Atualizado em 13/09/2026.

## Hoje (Apple Developer Program assinado em 13/09/2026)

- Mac: rodar pelo Xcode (▶ com "My Mac") — o app fica em `DerivedData` e abre normalmente depois.
- iPhone/iPad: ▶ com o aparelho no cabo (perfil de desenvolvimento, agora válido por 1 ano) ou, sem
  cabo, pelo TestFlight (abaixo).

## Depois de assinar o Developer Program — conferir no Xcode

1. Settings › Accounts › a conta deve mostrar o Team pago. Se o Team ID for diferente de
   `VFK4JUPXJF` (Personal Team), escolha o novo em Signing & Capabilities do target `IOLCalc`.
2. **iCloud para os casos** já está no projeto: `IOLCalc/IOLCalc.entitlements` (iCloud Documents,
   container `iCloud.br.com.drhallim.IOLCalc`) e o `CaseStore` grava em
   `iCloud Drive/IOLCalc/Documents/cases.json`. Na primeira compilação com o Team pago o Xcode
   registra a capacidade e o container no portal; se ele reclamar do perfil, use
   "+ Capability › iCloud › iCloud Documents" e marque o container.
3. **Chave da API pelo iCloud Keychain**: a chave é sincronizada entre os aparelhos do mesmo Apple ID
   (ligue "Senhas e Keychain" no iCloud do Mac e do iPhone). O app pede Face ID / Touch ID ao abrir.

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
