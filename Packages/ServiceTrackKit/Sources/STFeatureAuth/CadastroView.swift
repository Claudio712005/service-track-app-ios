import SwiftUI
import STCore
import STDomain

/// Formulário de cadastro em passos (spec §15.1) — não é um `Form` corrido.
public struct CadastroView: View {
    @State private var store: CadastroStore

    public init(store: CadastroStore) {
        self._store = State(initialValue: store)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                cabecalho
                barraProgresso
                etapaAtual

                if let erro = store.estado.erroGeral {
                    Text(erro)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.danger)
                }

                botoes
            }
            .padding(DSSpacing.margemTela)
            .animation(DSMotion.transicao, value: store.estado.etapa)
        }
        .background(DSColor.bgCanvas)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Criar conta")
                .font(DSFont.title1)
                .foregroundStyle(DSColor.textPrimary)
            Text(subtitulo)
                .font(DSFont.callout)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var subtitulo: String {
        switch store.estado.etapa {
        case .identidade: "Como podemos te chamar?"
        case .documentos: "Seus documentos — só o essencial."
        case .senha: "Escolha uma senha segura."
        }
    }

    private var barraProgresso: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.borderSubtle)
                Capsule()
                    .fill(DSColor.brandPrimary)
                    .frame(width: geo.size.width * store.estado.progresso)
                    .animation(DSMotion.transicao, value: store.estado.progresso)
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passo \(store.estado.etapa.rawValue + 1) de 3")
    }

    @ViewBuilder
    private var etapaAtual: some View {
        switch store.estado.etapa {
        case .identidade:
            VStack(spacing: DSSpacing.lg) {
                STTextField("Nome completo", texto: campo(.nome), erro: erro(.nome))
                #if os(iOS)
                STTextField("E-mail", texto: campo(.email), erro: erro(.email), teclado: .emailAddress)
                #else
                STTextField("E-mail", texto: campo(.email), erro: erro(.email))
                #endif
            }
        case .documentos:
            VStack(spacing: DSSpacing.lg) {
                #if os(iOS)
                STTextField("CPF", texto: campo(.cpf), mascara: .cpf, erro: erro(.cpf), teclado: .numberPad)
                STTextField("Telefone", texto: campo(.telefone), mascara: .telefone,
                            erro: erro(.telefone), teclado: .phonePad)
                #else
                STTextField("CPF", texto: campo(.cpf), mascara: .cpf, erro: erro(.cpf))
                STTextField("Telefone", texto: campo(.telefone), mascara: .telefone, erro: erro(.telefone))
                #endif

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    DatePicker("Data de nascimento",
                               selection: Binding(get: { store.estado.dataNascimento },
                                                  set: { store.send(.dataNascimentoAlterada($0)) }),
                               in: ...Date.now,
                               displayedComponents: .date)
                        .font(DSFont.body)
                        .padding(.horizontal, DSSpacing.lg)
                        .frame(minHeight: 58)
                        .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.md)
                                .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
                        )
                    if let erroData = erro(.dataNascimento) {
                        Text(erroData)
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.danger)
                    }
                }
            }
        case .senha:
            VStack(spacing: DSSpacing.lg) {
                VStack(spacing: DSSpacing.sm) {
                    STTextField("Senha", texto: campo(.senha), seguro: true, erro: erro(.senha))
                    STMedidorForcaSenha(senha: store.estado.senha)
                }
                STTextField("Confirmar senha", texto: campo(.confirmacaoSenha),
                            seguro: true, erro: erro(.confirmacaoSenha))
            }
        }
    }

    private var botoes: some View {
        VStack(spacing: DSSpacing.md) {
            STPrimaryButton(tituloAvancar, carregando: store.estado.carregando) {
                store.send(.avancar)
            }
            .disabled(!store.estado.podeEnviar)

            if store.estado.etapa != .identidade {
                STSecondaryButton("Voltar") {
                    store.send(.voltar)
                }
            }
        }
    }

    private var tituloAvancar: String {
        if store.estado.segundosBloqueio > 0 {
            return "Tente novamente em \(store.estado.segundosBloqueio)s"
        }
        return store.estado.etapa == .senha ? "Criar conta" : "Continuar"
    }

    private func campo(_ campo: CadastroStore.Campo) -> Binding<String> {
        Binding(get: {
            switch campo {
            case .nome: store.estado.nome
            case .email: store.estado.email
            case .cpf: store.estado.cpf
            case .telefone: store.estado.telefone
            case .senha: store.estado.senha
            case .confirmacaoSenha: store.estado.confirmacaoSenha
            case .dataNascimento: ""
            }
        }, set: { store.send(.campoAlterado(campo, $0)) })
    }

    private func erro(_ campo: CadastroStore.Campo) -> String? {
        store.estado.erros[campo]
    }
}
