import SwiftUI
import STCore
import STDomain

/// Dashboard do cliente (spec §15.3): saudação + sino, KPIs, "precisa da sua
/// atenção", gráficos de gasto, carrosséis de ordens ativas e veículos,
/// atividade recente. Estados completos (§12.4).
public struct DashboardView: View {
    @State private var store: DashboardStore
    let nomeCliente: String
    let aoCadastrarVeiculo: (() -> Void)?

    @State private var confirmandoAprovacao: OrdemAtivaDashboard?
    @State private var reprovando: OrdemAtivaDashboard?

    public init(store: DashboardStore, nomeCliente: String,
                aoCadastrarVeiculo: (() -> Void)? = nil) {
        self._store = State(initialValue: store)
        self.nomeCliente = nomeCliente
        self.aoCadastrarVeiculo = aoCadastrarVeiculo
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                cabecalho

                switch store.estado.fase {
                case .carregando:
                    esqueleto.dsEntradaSuave()
                case .erro(let erro):
                    STErrorState(mensagem: erro.mensagemPadrao) {
                        store.send(.recarregar)
                    }
                    .dsEntradaSuave()
                case .vazio:
                    STEmptyState(icone: "car",
                                 titulo: "Bem-vindo à sua oficina digital",
                                 subtitulo: "Cadastre seu primeiro veículo para abrir ordens de serviço e acompanhar tudo por aqui.",
                                 tituloCTA: aoCadastrarVeiculo != nil ? "Cadastrar meu veículo" : nil,
                                 acaoCTA: aoCadastrarVeiculo)
                        .dsEntradaSuave()
                case .conteudo:
                    conteudo.dsEntradaSuave()
                }
            }
            .padding(DSSpacing.margemTela)
            .dsAnimaFase(store.estado.fase)
        }
        .background(DSColor.bgCanvas)
        .refreshable { await store.carregar() }
        .onAppear { store.send(.aparecer) }
        .confirmationDialog(tituloConfirmacao, isPresented: presenteAprovacao, titleVisibility: .visible) {
            Button("Aprovar orçamento") {
                if let os = confirmandoAprovacao {
                    store.send(.aprovarOrcamento(os.id))
                }
            }
            Button("Agora não", role: .cancel) {}
        }
        .sheet(item: $reprovando) { os in
            ReprovarSheet(os: os) { motivo in
                store.send(.reprovarOrcamento(os.id, motivo: motivo))
            }
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: store.estado.sucessoAcao) { _, novo in novo != nil }
        .sensoryFeedback(.warning, trigger: store.estado.erroAcao) { _, novo in novo != nil }
        #endif
    }

    private var presenteAprovacao: Binding<Bool> {
        Binding(get: { confirmandoAprovacao != nil },
                set: { if !$0 { confirmandoAprovacao = nil } })
    }

    private var tituloConfirmacao: String {
        if let valor = confirmandoAprovacao?.valorOrcado {
            return "Confirmar aprovação de \(valor.formatted(.currency(code: "BRL")))?"
        }
        return "Confirmar aprovação do orçamento?"
    }

    // MARK: - Header

    private var cabecalho: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Olá, \(primeiroNome)")
                    .font(DSFont.title1)
                    .foregroundStyle(DSColor.textPrimary)
                Text("Aqui está o resumo da sua oficina")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            sino
        }
    }

    private var primeiroNome: String {
        nomeCliente.split(separator: " ").first.map(String.init) ?? nomeCliente
    }

    /// Sino com contador de não lidas (central de notificações chega na Fase 4).
    private var sino: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: DSSpacing.alvoMinimo, height: DSSpacing.alvoMinimo)
                .background(DSColor.bgSurface, in: .circle)
                .overlay(Circle().strokeBorder(DSColor.borderSubtle, lineWidth: 1))

            if store.estado.naoLidas > 0 {
                Text("\(min(store.estado.naoLidas, 99))")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.onPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DSColor.danger, in: .capsule)
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Notificações: \(store.estado.naoLidas) não lidas")
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private var conteudo: some View {
        if let resumo = store.estado.dashboard?.resumo {
            kpis(resumo)
        }

        feedbackAcao

        if let pendente = store.estado.pendenteDeAprovacao {
            atencao(pendente)
        }

        if let ativas = store.estado.dashboard?.ordensAtivas, !ativas.isEmpty {
            secao("Ordens ativas") { carrosselOrdens(ativas) }
        }

        if !store.gastoPorVeiculo.isEmpty {
            secao("Gasto por veículo") {
                STCard {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        GastoPorVeiculoChart(pontos: store.gastoPorVeiculo)
                        HStack {
                            Text("Total investido")
                                .font(DSFont.footnote)
                                .foregroundStyle(DSColor.textSecondary)
                            Spacer()
                            STCurrencyText(store.totalInvestido)
                        }
                    }
                }
            }
        }

        if store.gastosPorMes.count > 1 {
            secao("Gastos por mês") {
                STCard {
                    GastosMensaisChart(pontos: store.gastosPorMes)
                }
            }
        }

        if let veiculos = store.estado.dashboard?.veiculos, !veiculos.isEmpty {
            secao("Seus veículos") { carrosselVeiculos(veiculos) }
        }

        if let recentes = store.estado.dashboard?.ordensRecentes, !recentes.isEmpty {
            secao("Atividade recente") { listaRecentes(recentes) }
        }

        if let atualizado = store.estado.dashboard?.dataAtualizacao {
            Text("Atualizado \(atualizado.formatted(.relative(presentation: .named)))")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// KPIs em grid 2×2 — números exibidos como o backend envia (§9 C7).
    private func kpis(_ resumo: ResumoDashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DSSpacing.md),
                            GridItem(.flexible())], spacing: DSSpacing.md) {
            STMetricTile(valor: "\(resumo.ordensAtivas)", rotulo: "Em andamento",
                         icone: "clock.arrow.circlepath", cor: DSColor.brandPrimary)
            STMetricTile(valor: "\(resumo.ordensConcluidas)", rotulo: "Concluídas",
                         icone: "checkmark.seal", cor: DSColor.success)
            STMetricTile(valor: "\(resumo.veiculosCadastrados)", rotulo: "Veículos",
                         icone: "car", cor: DSColor.accentSpark)
            STMetricTile(valor: "\(resumo.ordensCanceladas)", rotulo: "Canceladas",
                         icone: "xmark.circle", cor: DSColor.danger)
        }
    }

    @ViewBuilder
    private var feedbackAcao: some View {
        if let sucesso = store.estado.sucessoAcao {
            faixaFeedback(sucesso, cor: DSColor.success, icone: "checkmark.circle.fill")
        }
        if let erro = store.estado.erroAcao {
            faixaFeedback(erro, cor: DSColor.warning, icone: "exclamationmark.triangle.fill")
        }
    }

    private func faixaFeedback(_ texto: String, cor: Color, icone: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icone)
            Text(texto).font(DSFont.subhead)
        }
        .foregroundStyle(cor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .background(cor.opacity(0.12), in: .rect(cornerRadius: DSRadius.sm))
        .task {
            try? await Task.sleep(for: .seconds(5))
            store.send(.limparFeedback)
        }
    }

    /// Card destacado com a ação mais valiosa (RF07) — aprovar/reprovar direto.
    private func atencao(_ os: OrdemAtivaDashboard) -> some View {
        secao("Precisa da sua atenção") {
            STCard {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    HStack {
                        STStatusBadge(.aguardandoAprovacao, tamanho: .sm)
                        Spacer()
                        if let prazo = os.prazoConclusao {
                            Text("Prazo \(prazo.formatted(.dateTime.day().month(.abbreviated)))")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(os.motivo)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        if let modelo = os.veiculoModelo {
                            Text("\(modelo)\(os.veiculoPlaca.map { " · \($0)" } ?? "")")
                                .font(DSFont.footnote)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }

                    HStack {
                        Text("Orçamento")
                            .font(DSFont.subhead)
                            .foregroundStyle(DSColor.textSecondary)
                        Spacer()
                        STCurrencyText(os.valorOrcado, fonte: DSFont.monoDestaque)
                    }

                    HStack(spacing: DSSpacing.md) {
                        STPrimaryButton("Aprovar", carregando: store.estado.decidindo) {
                            confirmandoAprovacao = os
                        }
                        STDestructiveButton("Reprovar") {
                            reprovando = os
                        }
                        .disabled(store.estado.decidindo)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(DSColor.status(.aguardandoAprovacao).opacity(0.5), lineWidth: 1.5)
            )
        }
    }

    private func carrosselOrdens(_ ordens: [OrdemAtivaDashboard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.md) {
                ForEach(ordens) { os in
                    STCard {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            STStatusBadge(os.status, tamanho: .sm)
                            Text(os.motivo)
                                .font(DSFont.subhead)
                                .foregroundStyle(DSColor.textPrimary)
                                .lineLimit(2, reservesSpace: true)
                            if let modelo = os.veiculoModelo {
                                Text(modelo)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                            if let dias = os.diasEmAndamento {
                                Label("\(dias) dia\(dias == 1 ? "" : "s")", systemImage: "clock")
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textTertiary)
                            }
                        }
                    }
                    .frame(width: 220)
                }
            }
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func carrosselVeiculos(_ veiculos: [VeiculoDashboard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.md) {
                ForEach(veiculos) { veiculo in
                    STCard {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            imagemVeiculo(veiculo.imagemUrl)
                            Text("\(veiculo.marca) \(veiculo.modelo)")
                                .font(DSFont.subhead)
                                .foregroundStyle(DSColor.textPrimary)
                            Text(veiculo.placa)
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xxs)
                                .background(DSColor.borderSubtle.opacity(0.5), in: .capsule)
                            HStack(spacing: DSSpacing.md) {
                                if let total = veiculo.totalOrdens {
                                    Label("\(total) OS", systemImage: "wrench.adjustable")
                                }
                                if let gasto = veiculo.totalGasto {
                                    Label(gasto.formatted(.currency(code: "BRL")
                                        .precision(.fractionLength(0))), systemImage: "banknote")
                                }
                            }
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                        }
                    }
                    .frame(width: 200)
                }
            }
        }
        .scrollTargetBehavior(.viewAligned)
    }

    @ViewBuilder
    private func imagemVeiculo(_ url: URL?) -> some View {
        AsyncImage(url: url) { fase in
            switch fase {
            case .success(let imagem):
                imagem.resizable().aspectRatio(contentMode: .fill)
            default:
                ZStack {
                    DSColor.brandPrimary.opacity(0.08)
                    Image(systemName: "car.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(DSColor.brandPrimary.opacity(0.5))
                }
            }
        }
        .frame(height: 92)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .accessibilityHidden(true)
    }

    private func listaRecentes(_ recentes: [OrdemRecenteDashboard]) -> some View {
        STCard {
            VStack(spacing: DSSpacing.md) {
                ForEach(Array(recentes.prefix(5).enumerated()), id: \.element.id) { indice, os in
                    if indice > 0 { Divider() }
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: os.status.iconeSistema)
                            .foregroundStyle(DSColor.status(os.status))
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            Text(os.motivo)
                                .font(DSFont.subhead)
                                .foregroundStyle(DSColor.textPrimary)
                                .lineLimit(1)
                            Text([os.veiculoModelo,
                                  os.dataConclusao.map { $0.formatted(.dateTime.day().month(.abbreviated)) }]
                                .compactMap(\.self).joined(separator: " · "))
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textTertiary)
                        }
                        Spacer()
                        STCurrencyText(os.valorTotal)
                    }
                }
            }
        }
    }

    private var esqueleto: some View {
        VStack(spacing: DSSpacing.lg) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DSSpacing.md),
                                GridItem(.flexible())], spacing: DSSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    STSkeleton(altura: 110, raio: DSRadius.md)
                }
            }
            STSkeleton(altura: 180, raio: DSRadius.md)
            STSkeleton(altura: 140, raio: DSRadius.md)
        }
    }

    private func secao(_ titulo: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(titulo)
                .font(DSFont.title3)
                .foregroundStyle(DSColor.textPrimary)
            conteudo()
        }
    }
}

/// Sheet de reprovação — motivo obrigatório (RN-05).
private struct ReprovarSheet: View {
    let os: OrdemAtivaDashboard
    let aoConfirmar: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var motivo = ""
    @State private var erro: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("Conte para a oficina por que o orçamento não funcionou para você.")
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)

                STTextField("Motivo da reprovação", texto: $motivo, erro: erro)

                STDestructiveButton("Reprovar orçamento") {
                    let limpo = motivo.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !limpo.isEmpty else {
                        erro = "O motivo é obrigatório."
                        return
                    }
                    aoConfirmar(limpo)
                    dismiss()
                }

                Spacer()
            }
            .padding(DSSpacing.margemTela)
            .background(DSColor.bgCanvas)
            .navigationTitle("Reprovar orçamento")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium])
    }
}
