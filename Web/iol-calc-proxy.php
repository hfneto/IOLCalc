<?php
/**
 * Plugin Name: IOL Calc Proxy
 * Description: Proxy seguro para leitura de laudos de biometria por IA (Anthropic). A chave da API fica no servidor; o app usa apenas uma senha de acesso. Endpoint: /wp-json/iol/v1/read
 * Version: 2.1.0
 * Author: Dr. Hallim / Calculadora de LIO
 */

if (!defined('ABSPATH')) exit;

/* ============================================================
 * CONFIGURAÇÕES (Configurações > IOL Proxy)
 * ============================================================ */
add_action('admin_menu', function () {
    add_options_page('IOL Proxy', 'IOL Proxy', 'manage_options', 'iol-proxy', 'iolp_settings_page');
});

add_action('admin_init', function () {
    register_setting('iolp_group', 'iolp_api_key');
    register_setting('iolp_group', 'iolp_access_pw');
    register_setting('iolp_group', 'iolp_allowed_models');
});

function iolp_settings_page() {
    if (!current_user_can('manage_options')) return;
    $default_models = "claude-sonnet-5\nclaude-opus-5\nclaude-haiku-4-5-20251001";
    ?>
    <div class="wrap">
        <h1>IOL Calc Proxy</h1>
        <p>A chave da API Anthropic fica guardada aqui no servidor e nunca é enviada ao navegador. O app (calculadora) usa somente a <strong>senha de acesso</strong> definida abaixo.</p>
        <form method="post" action="options.php">
            <?php settings_fields('iolp_group'); ?>
            <table class="form-table" role="presentation">
                <tr>
                    <th scope="row"><label for="iolp_api_key">Chave da API Anthropic</label></th>
                    <td>
                        <input type="password" id="iolp_api_key" name="iolp_api_key"
                               value="<?php echo esc_attr(get_option('iolp_api_key')); ?>"
                               class="regular-text" autocomplete="off" placeholder="sk-ant-...">
                        <p class="description">Obtida em console.anthropic.com. Fica só no servidor.</p>
                    </td>
                </tr>
                <tr>
                    <th scope="row"><label for="iolp_access_pw">Senha de acesso (usada no app)</label></th>
                    <td>
                        <input type="text" id="iolp_access_pw" name="iolp_access_pw"
                               value="<?php echo esc_attr(get_option('iolp_access_pw')); ?>"
                               class="regular-text" autocomplete="off">
                        <p class="description">Digite essa mesma senha no campo "Senha de acesso" da calculadora.</p>
                    </td>
                </tr>
                <tr>
                    <th scope="row"><label for="iolp_allowed_models">Modelos permitidos</label></th>
                    <td>
                        <textarea id="iolp_allowed_models" name="iolp_allowed_models" rows="4" class="regular-text"><?php
                            echo esc_textarea(get_option('iolp_allowed_models', $default_models));
                        ?></textarea>
                        <p class="description">Um por linha. Somente estes IDs de modelo são aceitos pelo endpoint (evita abuso). Deixe em branco para aceitar qualquer modelo.</p>
                    </td>
                </tr>
            </table>
            <?php submit_button(); ?>
        </form>
        <hr>
        <p><strong>Endpoint:</strong> <code><?php echo esc_html(get_rest_url(null, 'iol/v1/read')); ?></code></p>
    </div>
    <?php
}

/* ============================================================
 * PROMPT DE EXTRAÇÃO (multi-aparelho)
 * ============================================================ */
function iolp_system_prompt() {
    return <<<PROMPT
Você é um extrator de dados de laudos de BIOMETRIA OCULAR para cálculo de lente intraocular (catarata). Recebe uma imagem ou PDF de um laudo e devolve APENAS um objeto JSON, sem texto antes ou depois, sem markdown, sem ```.

APARELHOS SUPORTADOS (o layout varia muito entre eles — reconheça o formato):
- Zeiss IOLMaster 500 e IOLMaster 700 (SWEPT Source; costuma trazer "SE", TK/K, AL, ACD, LT, WTW/CCT)
- Alcon Argos (usa "AL", "K1/K2", "ACD", "LT", "WTW"; pode mostrar índice sumado)
- Haag-Streit Lenstar LS900 e Eyestar 900
- Oculus Pentacam AXL / Pentacam AXL Wave
- Heidelberg Anterion
- Tomey OA-2000
- Nidek AL-Scan
- Topcon Aladdin / Aladdin HW
- Ziemer Galilei G6
- Biômetros ultrassônicos (podem trazer só AL e ACD)

REGRAS DE LEITURA:
1. Sempre separe por olho: "OD" (olho direito / OD / R / right) e "OE" (olho esquerdo / OS / OE / L / left). NÃO troque os lados. Em laudos de dois olhos lado a lado, o OD normalmente está à esquerda da página e o OE à direita — mas confirme pelos rótulos.
2. Se o laudo tiver só um olho, preencha só esse olho e deixe o outro com todos os campos null.
3. Campos a extrair por olho (todos numéricos, em milímetros ou dioptrias):
   - AL  = comprimento axial (mm), tipicamente 20–30
   - K1  = ceratometria plana (D), tipicamente 38–48
   - K2  = ceratometria curva/íngreme (D), tipicamente 38–48 (K2 >= K1)
   - ACD = profundidade da câmara anterior (mm), tipicamente 2–4 (do epitélio ou do endotélio; use o valor rotulado ACD)
   - LT  = espessura do cristalino (mm), tipicamente 3.5–5.5
   - WTW = branco-a-branco / diâmetro corneano horizontal (mm), tipicamente 11–13 (também chamado CD, corneal diameter, W-W)
   - TK1/TK2 = ceratometria TOTAL (Total Keratometry, "TK" do IOLMaster 700 e equivalentes), quando o laudo trouxer; TK2 >= TK1. NÃO confundir com o K padrão: preencha TK1/TK2 SOMENTE se o laudo tiver medida total/posterior explícita (rótulos TK, Total K, TCP, Total Corneal Power). Se houver, inclua também "TK2_axis" (eixo do meridiano curvo total, 0–180).
4. CONVERSÃO DE UNIDADES:
   - Se a ceratometria vier como RAIO em mm (ex. "r1 7.80 mm"), converta para dioptrias: K(D) = 337.5 / raio(mm).
   - Se houver "TK" (total keratometry, IOLMaster 700) E "K" padrão: K1/K2 recebem o K padrão E TK1/TK2 recebem o TK (os dois conjuntos são extraídos). Se só existir TK, use-o em K1/K2 e também em TK1/TK2.
   - Se aparecer "SE"/"Km"/"Kmean" mas também K1 e K2, use K1 e K2.
   - Decimais com vírgula (23,45) devem virar ponto (23.45).
5. Extraia também o NOME DO PACIENTE como aparece no laudo (campo "name", string; null se ausente/ilegível). Ignore: data de nascimento, sexo, olhos dominantes, valores de refração alvo, poder de LIO já calculado, constantes A, fórmulas. NÃO invente valores. Se um campo não estiver legível ou não existir, use null.
6. Se houver múltiplas medidas/repetições, use o valor médio ou o marcado como selecionado/usado pelo aparelho.
7. Opcionalmente, se o laudo trouxer o EIXO do meridiano curvo (steep axis, eixo de K2), inclua "K2_axis" em graus (0–180).

FORMATO DE SAÍDA (exatamente esta estrutura, com números ou null):
{"name":null,"OD":{"AL":null,"K1":null,"K2":null,"ACD":null,"LT":null,"WTW":null,"K2_axis":null,"TK1":null,"TK2":null,"TK2_axis":null},"OE":{"AL":null,"K1":null,"K2":null,"ACD":null,"LT":null,"WTW":null,"K2_axis":null,"TK1":null,"TK2":null,"TK2_axis":null}}

Responda SOMENTE com o JSON.
PROMPT;
}

/* ============================================================
 * REST ENDPOINT
 * ============================================================ */
add_action('rest_api_init', function () {
    register_rest_route('iol/v1', '/read', array(
        'methods'  => 'POST',
        'callback' => 'iolp_read',
        'permission_callback' => '__return_true',
    ));
});

function iolp_read(WP_REST_Request $req) {
    $body = $req->get_json_params();
    if (!is_array($body)) {
        return new WP_REST_Response(array('error' => 'Requisição inválida.'), 400);
    }

    // senha de acesso
    $pw_sent  = isset($body['password']) ? (string) $body['password'] : '';
    $pw_saved = (string) get_option('iolp_access_pw', '');
    if ($pw_saved === '' ) {
        return new WP_REST_Response(array('error' => 'Servidor sem senha configurada (Configurações > IOL Proxy).'), 500);
    }
    if (!hash_equals($pw_saved, $pw_sent)) {
        return new WP_REST_Response(array('error' => 'Senha de acesso incorreta.'), 401);
    }

    $api_key = (string) get_option('iolp_api_key', '');
    if ($api_key === '') {
        return new WP_REST_Response(array('error' => 'Servidor sem chave da API configurada.'), 500);
    }

    // modelo
    $model = isset($body['model']) ? (string) $body['model'] : 'claude-sonnet-5';
    $allowed_raw = trim((string) get_option('iolp_allowed_models', ''));
    if ($allowed_raw !== '') {
        $allowed = array_filter(array_map('trim', preg_split('/\r\n|\r|\n/', $allowed_raw)));
        if (!empty($allowed) && !in_array($model, $allowed, true)) {
            return new WP_REST_Response(array('error' => 'Modelo não permitido.'), 400);
        }
    }

    // dados do arquivo
    $data = isset($body['data']) ? (string) $body['data'] : '';
    if ($data === '') {
        return new WP_REST_Response(array('error' => 'Arquivo ausente.'), 400);
    }
    $is_pdf = !empty($body['is_pdf']);
    $media_type = isset($body['media_type']) ? (string) $body['media_type'] : 'image/jpeg';
    $allowed_img = array('image/jpeg','image/png','image/gif','image/webp');
    if (!$is_pdf && !in_array($media_type, $allowed_img, true)) {
        $media_type = 'image/jpeg';
    }

    // limite de tamanho (~10 MB de base64 ≈ 7,5 MB de arquivo)
    if (strlen($data) > 14000000) {
        return new WP_REST_Response(array('error' => 'Arquivo muito grande (máx. ~10 MB).'), 413);
    }

    // bloco de conteúdo (imagem ou PDF)
    if ($is_pdf) {
        $source_block = array(
            'type' => 'document',
            'source' => array('type' => 'base64', 'media_type' => 'application/pdf', 'data' => $data),
        );
    } else {
        $source_block = array(
            'type' => 'image',
            'source' => array('type' => 'base64', 'media_type' => $media_type, 'data' => $data),
        );
    }

    $payload = array(
        'model'      => $model,
        // 3000: nos modelos da geração 5 o "adaptive thinking" consome tokens DENTRO
        // do max_tokens; 1024 poderia truncar o JSON. O texto de saída segue ~120 tokens.
        'max_tokens' => 3000,
        'system'     => iolp_system_prompt(),
        'messages'   => array(
            array(
                'role' => 'user',
                'content' => array(
                    $source_block,
                    array('type' => 'text', 'text' => 'Extraia a biometria deste laudo e responda apenas com o JSON no formato especificado.'),
                ),
            ),
        ),
    );

    $resp = wp_remote_post('https://api.anthropic.com/v1/messages', array(
        'timeout' => 60,
        'headers' => array(
            'content-type'      => 'application/json',
            'x-api-key'         => $api_key,
            'anthropic-version' => '2023-06-01',
        ),
        'body' => wp_json_encode($payload),
    ));

    if (is_wp_error($resp)) {
        return new WP_REST_Response(array('error' => 'Falha ao contatar a API: ' . $resp->get_error_message()), 502);
    }

    $code = wp_remote_retrieve_response_code($resp);
    $raw  = wp_remote_retrieve_body($resp);
    $json = json_decode($raw, true);

    if ($code !== 200) {
        $msg = 'Erro da API (HTTP ' . $code . ')';
        if (is_array($json) && isset($json['error']['message'])) {
            $msg = $json['error']['message'];
        }
        return new WP_REST_Response(array('error' => $msg), 502);
    }

    // extrai o texto do primeiro bloco de conteúdo
    $text = '';
    if (is_array($json) && isset($json['content']) && is_array($json['content'])) {
        foreach ($json['content'] as $block) {
            if (isset($block['type']) && $block['type'] === 'text' && isset($block['text'])) {
                $text .= $block['text'];
            }
        }
    }
    if ($text === '') {
        return new WP_REST_Response(array('error' => 'Resposta vazia da IA.'), 502);
    }

    return new WP_REST_Response(array('text' => $text), 200);
}
