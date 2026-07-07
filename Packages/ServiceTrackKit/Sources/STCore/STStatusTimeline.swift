import SwiftUI
import STDomain

/// Timeline vertical premium da jornada da OS (spec §5.4/§15.6): nós concluídos,
/// nó atual pulsante, futuros esmaecidos, ramo CANCELADA como desvio vermelho.
/// Navegável por VoiceOver com anúncio por extenso (§16).
public struct STStatusTimeline: View {
    let statusAtual: StatusOrdemServico
    let dataCriacao: Date?
    let dataAtualizacao: Date?

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var pulso = false

    public init(statusAtual: StatusOrdemServico, dataCriacao: Date? = nil, dataAtualizacao: Date? = nil) {
        self.statusAtual = statusAtual
        self.dataCriacao = dataCriacao
        self.dataAtualizacao = dataAtualizacao
    }

    private var cancelada: Bool { statusAtual == .cancelada }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(StatusOrdemServico.jornada.enumerated()), id: \.element) { indice, status in
                no(status: status,
                   ultimo: indice == StatusOrdemServico.jornada.count - 1 && !cancelada)
            }
            if cancelada {
                no(status: .cancelada, ultimo: true)
            }
        }
        .onAppear {
            guard !reduzirMovimento else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulso = true
            }
        }
    }

    private enum Situacao {
        case concluido, atual, futuro
    }

    private func situacao(_ status: StatusOrdemServico) -> Situacao {
        if status == statusAtual { return .atual }
        if cancelada { return .futuro } // jornada interrompida: tudo esmaecido, desvio em destaque
        return status.ordem < statusAtual.ordem ? .concluido : .futuro
    }

    private func no(status: StatusOrdemServico, ultimo: Bool) -> some View {
        let situacao = situacao(status)
        let cor = DSColor.status(status)

        return HStack(alignment: .top, spacing: DSSpacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    if situacao == .atual && !reduzirMovimento {
                        Circle()
                            .fill(cor.opacity(0.25))
                            .frame(width: 30, height: 30)
                            .scaleEffect(pulso ? 1.35 : 0.9)
                    }
                    Circle()
                        .fill(situacao == .futuro ? DSColor.bgSurface : cor)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(
                            situacao == .futuro ? DSColor.borderSubtle : cor, lineWidth: 2))
                    if situacao == .concluido {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DSColor.onPrimary)
                    }
                }
                .frame(width: 30, height: 30)

                if !ultimo {
                    Rectangle()
                        .fill(situacao == .concluido ? cor.opacity(0.5) : DSColor.borderSubtle)
                        .frame(width: 2, height: 34)
                }
            }

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(status.rotulo)
                    .font(situacao == .atual ? DSFont.headline : DSFont.subhead)
                    .foregroundStyle(situacao == .futuro ? DSColor.textTertiary : DSColor.textPrimary)
                if let detalhe = detalhe(status: status, situacao: situacao) {
                    Text(detalhe)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotuloAcessivel(status: status, situacao: situacao))
    }

    private func detalhe(status: StatusOrdemServico, situacao: Situacao) -> String? {
        // O contrato só expõe criação e última atualização — datas nos nós que as têm.
        if status == .recebida, let dataCriacao {
            return dataCriacao.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(.ptBR))
        }
        if situacao == .atual, let dataAtualizacao {
            return dataAtualizacao.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(.ptBR))
        }
        return nil
    }

    private func rotuloAcessivel(status: StatusOrdemServico, situacao: Situacao) -> String {
        switch situacao {
        case .concluido: "\(status.rotulo): concluído"
        case .atual: "Etapa atual: \(status.descricaoAcessivel)"
        case .futuro: "\(status.rotulo): pendente"
        }
    }
}
