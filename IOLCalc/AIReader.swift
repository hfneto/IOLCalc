import Foundation

/// Pedido de leitura de um laudo (arquivo já preparado pelo `UploadPrep`).
struct AIReadRequest {
    var model: String
    var isPDF: Bool
    var mediaType: String
    /// Conteúdo do arquivo em base64, sem quebras de linha.
    var data: String
}

enum AIReadError: LocalizedError {
    case noKey
    case tooLarge
    case network(String)
    case api(status: Int, message: String)
    case refused(String?)
    case empty

    var errorDescription: String? {
        switch self {
        case .noKey: return "Configure a chave da API da Anthropic no app (Configurações › Leitura por IA)."
        case .tooLarge: return "Arquivo muito grande (máx. ~10 MB)."
        case .network(let m): return "Sem conexão com a API: \(m)"
        case .api(let status, let message):
            switch status {
            case 401: return "Chave da API inválida ou revogada. Troque a chave no app."
            case 403: return "Esta chave não tem permissão para usar o modelo \(AIReader.defaultModel)."
            case 429: return "Limite de uso da API atingido. Aguarde um instante e tente de novo."
            case 529: return "API sobrecarregada no momento. Tente de novo em alguns segundos."
            default: return "Erro da API (HTTP \(status)): \(message)"
            }
        case .refused(let why): return "A IA recusou processar este arquivo" + (why.map { ": \($0)" } ?? ".")
        case .empty: return "Resposta vazia da IA."
        }
    }
}

/// Leitura de laudos de biometria chamando a API da Anthropic diretamente do app.
/// Reproduz o que o plugin WordPress fazia: mesmo prompt, mesmo payload, mesma resposta (`text`).
enum AIReader {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let modelsEndpoint = URL(string: "https://api.anthropic.com/v1/models")!
    /// Modelo fixo (não há mais escolha na interface): bom equilíbrio entre precisão na leitura de
    /// laudos e velocidade/custo. Mostrado em Configurações › Leitura por IA.
    static let defaultModel = "claude-sonnet-5"
    static let defaultModelTitle = "Claude Sonnet 5"
    static let allowedImageTypes: Set<String> = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    /// ~10 MB de base64 ≈ 7,5 MB de arquivo.
    static let maxBase64Length = 14_000_000

    static func read(_ req: AIReadRequest, apiKey: String) async throws -> String {
        guard req.data.count <= maxBase64Length else { throw AIReadError.tooLarge }

        let source: [String: Any]
        if req.isPDF {
            source = ["type": "document", "source": ["type": "base64", "media_type": "application/pdf", "data": req.data]]
        } else {
            let mt = allowedImageTypes.contains(req.mediaType) ? req.mediaType : "image/jpeg"
            source = ["type": "image", "source": ["type": "base64", "media_type": mt, "data": req.data]]
        }

        let payload: [String: Any] = [
            "model": req.model,
            // 3000: nos modelos da geração 5 o "adaptive thinking" consome tokens DENTRO
            // do max_tokens; 1024 poderia truncar o JSON. O texto de saída segue ~120 tokens.
            "max_tokens": 3000,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": [source, ["type": "text", "text": "Extraia a biometria deste laudo e responda apenas com o JSON no formato especificado."]],
            ]],
        ]

        var http = URLRequest(url: endpoint)
        http.httpMethod = "POST"
        http.timeoutInterval = 90
        http.setValue("application/json", forHTTPHeaderField: "content-type")
        http.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        http.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        http.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: http) }
        catch { throw AIReadError.network(error.localizedDescription) }

        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200 else {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? String(decoding: data.prefix(300), as: UTF8.self)
            throw AIReadError.api(status: status, message: msg)
        }
        if (json?["stop_reason"] as? String) == "refusal" {
            let details = json?["stop_details"] as? [String: Any]
            throw AIReadError.refused(details?["explanation"] as? String)
        }
        let text = ((json?["content"] as? [[String: Any]]) ?? [])
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw AIReadError.empty }
        return text
    }

    /// Confere a chave com `GET /v1/models` (não consome tokens).
    static func validate(apiKey: String) async throws {
        var http = URLRequest(url: modelsEndpoint)
        http.timeoutInterval = 20
        http.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        http.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: http) }
        catch { throw AIReadError.network(error.localizedDescription) }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "resposta inesperada"
            throw AIReadError.api(status: status, message: msg)
        }
    }

    static let systemPrompt = """
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
   - CCT = paquimetria / espessura corneana central (µm), tipicamente 450–650 (rótulos: CCT, Pachy, Pachymetry, espessura corneana). Se vier em mm (ex. 0.541), converta para µm (541)
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
{"name":null,"OD":{"AL":null,"K1":null,"K2":null,"ACD":null,"LT":null,"WTW":null,"CCT":null,"K2_axis":null,"TK1":null,"TK2":null,"TK2_axis":null},"OE":{"AL":null,"K1":null,"K2":null,"ACD":null,"LT":null,"WTW":null,"CCT":null,"K2_axis":null,"TK1":null,"TK2":null,"TK2_axis":null}}

Responda SOMENTE com o JSON.
"""
}
