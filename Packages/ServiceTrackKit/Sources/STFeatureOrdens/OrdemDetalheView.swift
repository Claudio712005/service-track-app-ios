import SwiftUI
import STCore
import STDomain

/// Detalhe da OS — tela-assinatura (spec §15.6): timeline vertical, orçamento
/// com decisão (§15.7), checklist de itens, insumos agregados, cancelamento.
struct OrdemDetalheView: View {
    @Bindable var store: OrdemDetalheStore
    @State private var confirmandoAprovacao = false
    @State private var reprovando = false
    @State private var cancelando = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                switch store.estado.fase {
                case .carregando:
                    esqueleto.dsEntradaSuave()
                case .erro(let erro):
                    STErrorState(mensagem: erro.mensagemPadrao) {
                        store.send(.recarregar)
                    }
                    .dsEntradaSuave()
                case .conteudo:
                    if let ordem = store.estado.ordem {
                        conteudo(ordem).dsEntradaSuave()
                    }
                }
            }
            .padding(DSSpacing.margemTela)
            .dsAnimaFase(store.estado.fase)
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Ordem de serviço")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { store.send(.aparecer) }
        .refreshable { await store.carregar() }
        .confirmationDialog(tituloAprovacao, isPresented: $confirmandoAprovacao, titleVisibility: .visible) {
            Button("Aprovar orçamento") { store.send(.aprovar) }
            Button("Agora não", role: .cancel) {}
        }
        .sheet(isPresented: $reprovando) {
            MotivoSheet(titulo: "Reprovar orçamento",
                        descricao: "Conte para a oficina por que o orçamento não funcionou para você.",
                        motivoObrigatorio: true,
                        tituloCTA: "Reprovar orçamento") { motivo in
                store.send(.reprovar(motivo: motivo ?? ""))
            }
        }
        .sheet(isPresented: $cancelando) {
            MotivoSheet(titulo: "Cancelar ordem",
                        descricao: "Se quiser, conte o motivo do cancelamento (opcional).",
                        motivoObrigatorio: false,
                        tituloCTA: "Cancelar ordem") { motivo in
                store.send(.cancelar(motivo: motivo))
            }
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: store.estado.sucessoAcao) { _, novo in novo != nil }
        .sensoryFeedback(.warning, trigger: store.estado.erroAcao) { _, novo in novo != nil }
        #endif
    }

    private var tituloAprovacao: String {
        if let valor = store.estado.ordem?.orcamento?.valorTotal {
            return "Confirmar aprovação de \(valor.formatted(.currency(code: "BRL")))?"
        }
        return "Confirmar aprovação do orçamento?"
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private func conteudo(_ ordem: OrdemServico) -> some View {
        cabecalho(ordem)
        feedback

        secao("Acompanhamento") {
            STCard {
                STStatusTimeline(statusAtual: ordem.status,
                                 dataCriacao: ordem.dataCriacao,
                                 dataAtualizacao: ordem.dataAtualizacao)
            }
        }

        if let orcamento = ordem.orcamento {
            secao("Orçamento") { cardOrcamento(orcamento, status: ordem.status) }
        }

        if !ordem.itensServico.isEmpty {
            secao("Serviços") { checklistServicos(ordem.itensServico) }
        }

        if !store.estado.insumosAgregados.isEmpty {
            secao("Peças e insumos") { listaInsumos }
        }

        acoes(ordem)
    }

    private func cabecalho(_ ordem: OrdemServico) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            STStatusBadge(ordem.status)
            Text(ordem.motivo)
                .font(DSFont.title2)
                .foregroundStyle(DSColor.textPrimary)
            if let observacao = ordem.observacao {
                Text(observacao)
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let sucesso = store.estado.sucessoAcao {
            faixa(sucesso, cor: DSColor.success, icone: "checkmark.circle.fill")
        }
        if let erro = store.estado.erroAcao {
            faixa(erro, cor: DSColor.warning, icone: "exclamationmark.triangle.fill")
        }
    }

    private func faixa(_ texto: String, cor: Color, icone: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icone)
            Text(texto).font(DSFont.subhead)
        }
        .foregroundStyle(cor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .background(cor.opacity(0.12), in: .rect(cornerRadius: DSRadius.sm))
        .dsEntradaSuave()
        .task {
            try? await Task.sleep(for: .seconds(5))
            store.send(.limparFeedback)
        }
    }

    /// STBudgetCard (spec §14): mão de obra, insumos, total tabular; CTAs só em
    /// AGUARDANDO_APROVACAO (§5.3).
    private func cardOrcamento(_ orcamento: Orcamento, status: StatusOrdemServico) -> some View {
        STCard {
            VStack(spacing: DSSpacing.md) {
                linhaValor("Mão de obra", orcamento.custoMaoDeObra)
                linhaValor("Peças e insumos", orcamento.custoInsumos)
                Divider()
                HStack {
                    Text("Total")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    STCurrencyText(orcamento.valorTotal, fonte: DSFont.monoDestaque)
                }
                if let observacao = orcamento.observacao {
                    Text(observacao)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if status.clientePodeDecidirOrcamento {
                    HStack(spacing: DSSpacing.md) {
                        STPrimaryButton("Aprovar", carregando: store.estado.decidindo) {
                            confirmandoAprovacao = true
                        }
                        STDestructiveButton("Reprovar") {
                            reprovando = true
                        }
                        .disabled(store.estado.decidindo)
                    }
                }
            }
        }
        .overlay {
            if status.clientePodeDecidirOrcamento {
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(DSColor.status(.aguardandoAprovacao).opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    private func linhaValor(_ titulo: String, _ valor: Double) -> some View {
        HStack {
            Text(titulo)
                .font(DSFont.subhead)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            STCurrencyText(valor)
        }
    }

    /// Checklist de execução (spec §15.6): `feito` com check animado.
    private func checklistServicos(_ itens: [ItemServico]) -> some View {
        STCard {
            VStack(spacing: DSSpacing.md) {
                ForEach(Array(itens.enumerated()), id: \.element.id) { indice, item in
                    if indice > 0 { Divider() }
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: item.feito ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(item.feito ? DSColor.success : DSColor.borderSubtle)
                            .contentTransition(.symbolEffect(.replace))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            Text(item.observacao ?? "Serviço")
                                .font(DSFont.subhead)
                                .foregroundStyle(DSColor.textPrimary)
                            if let data = item.dataRealizacao {
                                Text("Concluído \(data.formatted(.dateTime.day().month(.abbreviated).locale(.ptBR)))")
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textTertiary)
                            }
                        }

                        Spacer()
                        STCurrencyText(item.valor)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(item.feito ? "concluído" : "pendente")
                }
            }
        }
    }

    private var listaInsumos: some View {
        STCard {
            VStack(spacing: DSSpacing.md) {
                ForEach(Array(store.estado.insumosAgregados.enumerated()), id: \.element.id) { indice, item in
                    if indice > 0 { Divider() }
                    HStack {
                        Text(store.estado.nomesInsumos[item.id] ?? "Insumo")
                            .font(DSFont.subhead)
                            .foregroundStyle(DSColor.textPrimary)
                        Spacer()
                        Text("×\(item.quantidade)")
                            .font(DSFont.mono)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
    }

    /// Ações contextuais por estado (spec §5.3): cancelar só onde a transição é
    /// válida (C3 — o código do domínio decide, não a UI).
    @ViewBuilder
    private func acoes(_ ordem: OrdemServico) -> some View {
        if ordem.status.clientePodeCancelar {
            STDestructiveButton("Cancelar ordem de serviço", carregando: store.estado.decidindo) {
                cancelando = true
            }
        }
    }

    private var esqueleto: some View {
        VStack(spacing: DSSpacing.lg) {
            STSkeleton(altura: 28, raio: DSRadius.pill)
            STSkeleton(altura: 24)
            STSkeleton(altura: 300, raio: DSRadius.md)
            STSkeleton(altura: 160, raio: DSRadius.md)
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

/// Sheet de motivo (reprovação: obrigatório RN-05; cancelamento: opcional RN-06).
private struct MotivoSheet: View {
    let titulo: String
    let descricao: String
    let motivoObrigatorio: Bool
    let tituloCTA: String
    let aoConfirmar: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var motivo = ""
    @State private var erro: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(descricao)
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)

                STTextField(motivoObrigatorio ? "Motivo" : "Motivo (opcional)",
                            texto: $motivo, erro: erro)

                STDestructiveButton(tituloCTA) {
                    let limpo = motivo.trimmingCharacters(in: .whitespacesAndNewlines)
                    if motivoObrigatorio && limpo.isEmpty {
                        erro = "O motivo é obrigatório."
                        return
                    }
                    aoConfirmar(limpo.isEmpty ? nil : limpo)
                    dismiss()
                }

                Spacer()
            }
            .padding(DSSpacing.margemTela)
            .background(DSColor.bgCanvas)
            .navigationTitle(titulo)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium])
    }
}
