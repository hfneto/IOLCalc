> **OBSOLETO (11/09/2026).** Este plugin nunca foi instalado. A leitura por IA passou a ser feita
> dentro do app (`IOLCalc/AIReader.swift`), com a chave da API no Keychain. O WordPress não é mais
> usado. Mantido só como referência histórica.

# Plugin WordPress `iol-calc-proxy.php` (v2.2)

Instale no WordPress do drhallim.com.br substituindo o plugin atual (Plugins > Adicionar novo > Enviar plugin, ou copie o arquivo para `wp-content/plugins/iol-calc-proxy/`).

Novidades da 2.2:

- `POST /wp-json/iol/v1/login` com `{email, password}` (conta do WordPress) devolve um token válido por 180 dias. O app guarda o token no Keychain e nunca mais pede senha.
- `POST /wp-json/iol/v1/read` aceita `token` (novo) ou `password` (senha de acesso compartilhada, como antes).
- A leitura por IA extrai também a paquimetria (`CCT`, em µm).

Enquanto o plugin antigo estiver no ar, o app cai no modo legado: a senha digitada no login é usada como senha de acesso compartilhada.
