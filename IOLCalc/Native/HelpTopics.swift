import SwiftUI

/// Explicações das opções avançadas do app. Aparecem no botão "?" ao lado de cada opção e reunidas
/// em Configurações › Ajuda.
enum HelpTopic: String, CaseIterable, Identifiable {
    case aiReading
    case biometryMethod
    case aConstant
    case lensChoice
    case totalKeratometry
    case powerSuggestion
    case officialCalculators
    case defocusSlider
    case simulation
    case toricBase
    case toricPlatform
    case cases
    case monovision

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiReading: return "Leitura do laudo por IA"
        case .biometryMethod: return "Tipo de biometria e ajuste ΔA"
        case .aConstant: return "Constante A por olho"
        case .lensChoice: return "Escolha da LIO, favoritas e \"Outra\""
        case .totalKeratometry: return "Ceratometria total (TK)"
        case .powerSuggestion: return "Como o app sugere o poder"
        case .officialCalculators: return "Calculadoras oficiais e preenchimento"
        case .defocusSlider: return "Régua de residual e astigmatismo (seção 5)"
        case .simulation: return "Simulação visual e halos (seção 6)"
        case .toricBase: return "Base do astigmatismo e SIA (seção 7)"
        case .toricPlatform: return "Plataforma e razão de toricidade (seção 7)"
        case .cases: return "Casos salvos e iCloud"
        case .monovision: return "Olho dominante, monovisão e cenário alternativo"
        }
    }

    /// Parágrafos do texto (o primeiro é o resumo).
    var paragraphs: [String] {
        switch self {
        case .aiReading: return [
            "\"Ler laudo com IA\" envia a foto ou o PDF do laudo direto do app para a API da Anthropic (modelo Claude Sonnet 5, fixo) e preenche os campos dos dois olhos. Nada passa por servidor intermediário e nada fica guardado fora do aparelho.",
            "Sempre confira os valores: a leitura pode trocar OD/OE, confundir K com TK ou ler mal um dígito. O laudo abre ao lado (Mac/iPad) ou numa folha (iPhone) pelo botão \"Ver laudo\", para comparar linha a linha. Valores fora da faixa plausível são destacados em vermelho.",
            "A chave da API fica no Keychain, sincronizada pelo iCloud Keychain para os seus outros aparelhos, e pode ser protegida por Face ID / Touch ID ao abrir o app (Configurações › Leitura por IA).",
        ]
        case .biometryMethod: return [
            "As constantes A do catálogo valem para biometria óptica (IOLMaster, Lenstar, Argos, Pentacam AXL, Anterion…). Se o AL veio de ultrassom, a mesma constante daria um poder alto demais, porque o ultrassom mede o olho mais curto.",
            "Por isso o app soma um ΔA ao escolher o método: imersão ≈ −0,23 (Shammas, 2021) e contato/aplanação ≈ −0,50 (a sonda comprime a córnea 0,14–0,28 mm; pela relação de Hill, A óptica ≈ A contato + 3·ΔAL). O ΔA aparece na seção 2 e no cabeçalho da seção 3 (\"A → A efetiva\").",
            "Em \"Ajuste da constante A por método · avançado\" você pode trocar o ΔA de cada método, por exemplo pela constante otimizada do seu aparelho e da sua técnica. Um ΔA de 0 desliga o ajuste. A escolha fica guardada no aparelho e vale para todos os casos.",
        ]
        case .aConstant: return [
            "Ao escolher a LIO, o campo \"Constante A\" recebe o valor do catálogo (SRK/T, biometria óptica), mas pode ser editado por olho: use a constante otimizada da sua série (IOLcon, ULIB ou a sua própria) quando tiver uma.",
            "Regra de bolso: 1 unidade na constante A ≈ 1 D no poder da LIO ≈ 0,7 D na refração. Um rótulo de caixa costuma trazer a constante para ultrassom, 0,3–0,5 abaixo da óptica; o app usa a óptica.",
            "As outras fórmulas usam constantes derivadas da A pelas relações padrão (Holladay 1: sf = 0,5663·A − 65,6; Hoffer Q: pACD; Haigis: a0 calibrado no olho padrão com a1 = 0,4 e a2 = 0,1; Castrop: H calibrado), então basta ajustar a A.",
            "\"copiar OD → OE\" leva LIO, constante (mesmo editada) e alvo para o outro olho.",
        ]
        case .lensChoice: return [
            "O seletor da seção 2 mostra só as LIOs favoritas, para não poluir a lista. Em Configurações › Lentes você vê o catálogo inteiro (por fabricante) e marca as favoritas com a estrela; \"Restaurar padrão\" volta às 20 lentes originais.",
            "\"Outra LIO…\" no fim do seletor abre o catálogo completo (para usar uma lente sem favoritar) ou deixa digitar nome, classe e constante A de uma lente que não está no catálogo. A classe define a curva de defocus (média das lentes publicadas da classe) e o grau de halos usados nas seções 5 e 6.",
            "Lentes marcadas \"curva estimada\" não têm curva de defocus publicada no catálogo: a curva é a de uma lente parecida ou a média da classe. Poder e residual (seção 3) não dependem da curva, só da constante A.",
            "O catálogo traz constantes do fabricante/IOLcon para lentes recentes e a SRK/T otimizada do ULIB para as mais antigas; a origem de cada uma está na nota da lente. Confira sempre o registro Anvisa e a disponibilidade com o distribuidor.",
        ]
        case .totalKeratometry: return [
            "TK (Total Keratometry, IOLMaster 700 e equivalentes) mede a córnea anterior e posterior. Os campos TK1/TK2 aparecem ao tocar \"ceratometria total (TK)\" ou quando a IA os lê do laudo.",
            "Nas seções 2 e 3 o cálculo do poder continua usando K1/K2 (as constantes do catálogo foram otimizadas com K padrão). O TK é usado na seção 7: com TK medido, a base do astigmatismo passa automaticamente para \"Total\" e o cilindro/eixo da LIO tórica saem do TK, sem a regressão de Abulafia-Koch.",
        ]
        case .powerSuggestion: return [
            "A seção 3 calcula o poder para emetropia e para o alvo com SRK/T, T2, Holladay 1 (com ajuste Wang-Koch em olhos longos), Hoffer Q, Haigis e Castrop. As fórmulas recomendadas dependem do AL: olho curto (< 22 mm) → Hoffer Q, Haigis e Castrop; médio → todas; longo (> 26 mm) → Holladay 1 Wang-Koch, T2, Haigis e Castrop.",
            "A sugestão é a mediana das fórmulas recomendadas, arredondada ao passo de 0,5 D, escolhendo a primeira lente que não deixa hipermetropia em relação ao alvo (residual ≤ alvo). A \"alternativa\" é o degrau logo abaixo, com residual levemente hipermetrópico. A tabela mostra o residual previsto por fórmula nos dois poderes.",
            "Os alertas em vermelho apontam olhos fora da faixa de confiança das fórmulas locais (muito curtos, muito longos, K extremos, ΔK alto, ACD atípica). Nesses casos confirme na Barrett/ESCRS/Kane (seção 4).",
        ]
        case .officialCalculators: return [
            "Cada botão da seção 4 abre a calculadora oficial dentro do app e injeta a biometria nos campos que reconhece pelo rótulo: AL, K1, K2, eixos de K1/K2, ACD, LT, WTW, CCT, TK, constante A, alvo e nome. \"Preencher de novo\" repete a injeção depois de trocar de aba no site (ex.: aba tórica da Kane).",
            "Os sites mudam sem aviso; se um campo ficar vazio, cole à mão a partir de \"Copiar biometria\", que copia um resumo em texto com todos os valores, inclusive eixos e TK. Confira sempre o que foi preenchido antes de calcular.",
            "Os campos que o app não tem (sexo, na Kane; SIA, na tórica) ficam para você preencher.",
        ]
        case .defocusSlider: return [
            "A régua de residual da seção 5 começa no alvo da seção 2. Ao arrastá-la você simula o que acontece se o olho ficar mais míope ou mais hipermétrope do que o previsto: o gráfico e as métricas (longe, 66 cm, 40 cm, estereopsia) se deslocam junto. Ela não altera o cálculo da seção 3.",
            "\"Astigmatismo\" liga um cilindro residual por olho (pré-preenchido com o ΔK da biometria; edite se pretende corrigir com tórica) que reduz a AV em todas as distâncias. O comparador (gaveta) desenha duas lentes no mesmo olho, cada uma com o poder sugerido para a sua própria constante.",
            "As curvas do catálogo são binoculares e publicadas pelos fabricantes; a AV monocular recebe a penalidade de somação e a binocular do paciente é a combinação das duas (em olhos simétricos reproduz a curva publicada). Além de −3,0 D é extrapolação (tracejado).",
        ]
        case .simulation: return [
            "Cada camada da cena é desfocada pela AV binocular prevista naquela distância (lentes + residual da régua + astigmatismo, se ligado). À noite entram a penalidade mesópica e os halos, cuja intensidade depende da classe da lente (difrativas = mais).",
            "O seletor de halos (melhor caso / mais comum / pior caso) mostra a variação individual entre pacientes com a mesma lente; use-o na conversa pré-operatória, não como previsão para aquela pessoa.",
            "A calibração está descrita no rodapé da seção: σ do desfoque proporcional ao MAR, 2 px por minuto de arco, +0,08 logMAR à noite, perda de contraste das difrativas.",
        ]
        case .monovision: return [
            "Marque o olho dominante (teste do buraco no cartão ou o olho que o paciente usa para mirar). Com \"Monovisão\" ligada, o app põe alvo 0,00 D no dominante e −miopia no outro olho (quantidade em Configurações › Padrões, ajustável por caso; 1,00–1,50 D é a faixa mais tolerada, acima de 2,00 D perde estereopsia). Desligando, os dois alvos voltam a 0,00 D.",
            "Na seção 5, \"comparar com…\" desenha uma segunda curva binocular tracejada com o cenário oposto: se o plano é multifocal, a alternativa é monovisão com uma monofocal; se o plano é monovisão, a alternativa é a multifocal bilateral escolhida. Os residuais do cenário são calculados com a constante A da lente alternativa e a mesma biometria.",
            "Na seção 6, com a comparação ligada, o seletor \"plano / alternativa\" troca as cenas entre os dois cenários para mostrar ao paciente a diferença nas três distâncias.",
        ]
        case .toricBase: return [
            "\"Base do astigmatismo\" define de onde vem o astigmatismo corneano total: K anterior puro; Abulafia-Koch (regressão que estima a córnea posterior a partir do K anterior — padrão quando não há TK); Næser-Savini (outra regressão); ou Total (TK medido, escolhido automaticamente quando há TK na biometria).",
            "SIA é o astigmatismo induzido pela incisão (vetor cujo meridiano curvo fica a 90° do eixo da incisão, que aplana o próprio meridiano). O padrão 0,10 D é o centroide típico de incisões temporais de 2,2–2,4 mm; use o seu valor se o tiver medido. O eixo da incisão pode ser arrastado no diagrama (laranja) depois de abrir o cadeado; com ele fechado, o diagrama não responde ao toque, para não mudar os eixos sem querer ao rolar a tela.",
            "O residual é a soma vetorial (duplo-ângulo) de astigmatismo total, SIA e cilindro da LIO no plano corneano. \"Sugerir ideal\" escolhe o degrau da plataforma mais próximo do necessário e alinha ao meridiano curvo total; \"alinhar ao astig.\" só corrige o eixo. A nota de desalinhamento mostra quanto se perde a cada grau de rotação.",
        ]
        case .toricPlatform: return [
            "A plataforma segue o fabricante da LIO escolhida na seção 2 (Alcon, HOYA, J&J, Zeiss, Rayner ou genérica) e define os degraus de cilindro disponíveis (T2–T9, passos de 0,5 ou 0,25 D). Troque em \"avançado\" se a lente tórica for de outra família.",
            "A razão de toricidade converte o cilindro no plano da LIO para o plano corneano (ex.: T3 = 1,50 D na LIO ≈ 1,03 D na córnea). Com biometria, o app a calcula pela ELP do olho (SRK/T com o poder sugerido), como faz a Barrett Toric; sem biometria usa o padrão da plataforma (≈1,46). Digite um valor para fixá-la (\"manual\").",
            "Olhos longos e LIOs de baixo poder têm razão maior (cada dioptria da LIO corrige menos); olhos curtos, menor. Por isso a razão fixa das tabelas dos fabricantes erra nos extremos.",
        ]
        case .cases: return [
            "\"Casos\" guarda o planejamento inteiro (biometria, lentes, alvos, régua, tórica, simulação, comparador) com o nome do paciente. Os casos ficam no iCloud Drive do seu Apple ID e aparecem no Mac, iPad e iPhone; sem iCloud, ficam só no aparelho.",
            "\"Atualizar\" regrava o caso aberto; exportar/importar gera um arquivo .iolcase.json para AirDrop, Arquivos ou e-mail. O relatório em PDF sai do botão \"Relatório\".",
        ]
        }
    }
}

/// Texto de um tópico (título + parágrafos), usado no popover e na Ajuda.
struct HelpTopicView: View {
    let topic: HelpTopic
    var showTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTitle {
                Text(topic.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            }
            ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, p in
                Text(p).font(.system(size: 12.5)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Botão "?" que abre a explicação num popover (no iPhone também, sem virar folha).
struct HelpButton: View {
    let topic: HelpTopic
    @State private var open = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.brand)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajuda: \(topic.title)")
        .help(topic.title)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ScrollView {
                HelpTopicView(topic: topic).padding(16)
            }
            .frame(width: 340)
            .frame(maxHeight: 480)
            #if os(iOS)
            .presentationCompactAdaptation(.popover)
            #endif
        }
    }
}
