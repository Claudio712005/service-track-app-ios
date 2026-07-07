import SwiftUI
import STCore
import STDomain

/// Tela temporária da Fase 0 (spec §21): galeria viva do Design System +
/// smoke test da pilha completa (APIClient → mock → DTOs → domínio).
/// Substituída pelo RootRouter/TabBar na Fase 1.
struct FundacaoView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                cabecalho
                secaoStatus
                secaoComponentes
                SmokeTestCard()
            }
            .padding(DSSpacing.margemTela)
        }
        .background(DSColor.bgCanvas)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("ServiceTrack")
                .font(DSFont.display)
                .foregroundStyle(DSColor.textPrimary)
            Text("Fase 0 — fundação: Design System, rede, mocks e domínio")
                .font(DSFont.callout)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var secaoStatus: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Status da OS")
                .font(DSFont.title3)
                .foregroundStyle(DSColor.textPrimary)
            STCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    ForEach(StatusOrdemServico.allCases, id: \.self) { status in
                        STStatusBadge(status)
                    }
                }
            }
        }
    }

    private var secaoComponentes: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Componentes")
                .font(DSFont.title3)
                .foregroundStyle(DSColor.textPrimary)

            STCard {
                VStack(spacing: DSSpacing.md) {
                    HStack {
                        Text("Valor total")
                            .font(DSFont.subhead)
                            .foregroundStyle(DSColor.textSecondary)
                        Spacer()
                        STCurrencyText(560.5, fonte: DSFont.monoDestaque)
                    }
                    HStack {
                        Text("Sem orçamento")
                            .font(DSFont.subhead)
                            .foregroundStyle(DSColor.textSecondary)
                        Spacer()
                        STCurrencyText(nil)
                    }
                    STPrimaryButton("Aprovar orçamento") {}
                    STSecondaryButton("Ver detalhes") {}
                    STDestructiveButton("Cancelar OS") {}
                    STSkeleton(altura: 20)
                }
            }
        }
    }
}

/// Prova a pilha de ponta a ponta contra o ambiente de mocks.
private struct SmokeTestCard: View {
    @Environment(AppEnvironment.self) private var env
    @State private var estado: Estado = .ocioso

    enum Estado {
        case ocioso
        case executando
        case sucesso(nome: String, ativas: Int, veiculos: Int, statusOS: StatusOrdemServico)
        case falha(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Integração (ambiente mock)")
                .font(DSFont.title3)
                .foregroundStyle(DSColor.textPrimary)

            STCard {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    switch estado {
                    case .ocioso:
                        Text("Login → dashboard → detalhe de OS, usando as fixtures do OpenAPI.")
                            .font(DSFont.callout)
                            .foregroundStyle(DSColor.textSecondary)
                    case .executando:
                        VStack(spacing: DSSpacing.sm) {
                            STSkeleton(altura: 16)
                            STSkeleton(altura: 16)
                        }
                    case .sucesso(let nome, let ativas, let veiculos, let statusOS):
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            linha("Cliente", nome)
                            linha("Ordens ativas", "\(ativas)")
                            linha("Veículos", "\(veiculos)")
                            HStack {
                                Text("OS em destaque")
                                    .font(DSFont.subhead)
                                    .foregroundStyle(DSColor.textSecondary)
                                Spacer()
                                STStatusBadge(statusOS, tamanho: .sm)
                            }
                        }
                    case .falha(let mensagem):
                        STErrorState(mensagem: mensagem) {
                            executar()
                        }
                    }

                    if case .falha = estado {} else {
                        STPrimaryButton("Executar smoke test",
                                        carregando: eExecutando) {
                            executar()
                        }
                    }
                }
            }
        }
    }

    private var eExecutando: Bool {
        if case .executando = estado { return true }
        return false
    }

    private func linha(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(DSFont.subhead)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            Text(valor)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
        }
    }

    private func executar() {
        estado = .executando
        Task {
            do {
                let sessao = try await env.auth.login(email: "cliente@servicetrack.dev",
                                                      senha: "Senha@123")
                try env.iniciarSessao(sessao)
                let dash = try await env.dashboard.buscar(clienteId: sessao.usuarioId)
                let ordens = try await env.ordens.listar(status: nil, page: 0, size: 20)
                let statusDestaque = ordens.content.first?.status ?? .desconhecido("")
                estado = .sucesso(nome: dash.usuarioNome ?? sessao.nome,
                                  ativas: dash.resumo.ordensAtivas,
                                  veiculos: dash.resumo.veiculosCadastrados,
                                  statusOS: statusDestaque)
            } catch let erro as AppError {
                estado = .falha(erro.mensagemPadrao)
            } catch {
                estado = .falha(error.localizedDescription)
            }
        }
    }
}

#Preview {
    FundacaoView()
        .environment(AppEnvironment())
}
