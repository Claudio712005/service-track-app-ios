import SwiftUI
import STCore
import STDomain

/// Tela de login (spec §15.2). Sem "esqueci minha senha": não existe endpoint
/// público de recuperação (spec §9 C6) — orientação vive no Perfil/Sobre.
public struct LoginView: View {
    @State private var store: LoginStore
    let aoCriarConta: () -> Void

    public init(store: LoginStore, aoCriarConta: @escaping () -> Void) {
        self._store = State(initialValue: store)
        self.aoCriarConta = aoCriarConta
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.x3l) {
                marca

                VStack(spacing: DSSpacing.lg) {
                    #if os(iOS)
                    STTextField("CPF",
                                texto: Binding(get: { store.estado.cpf },
                                               set: { store.send(.cpfAlterado($0)) }),
                                erro: store.estado.erroCpf,
                                teclado: .numberPad)
                    #else
                    STTextField("CPF",
                                texto: Binding(get: { store.estado.cpf },
                                               set: { store.send(.cpfAlterado($0)) }),
                                erro: store.estado.erroCpf)
                    #endif

                    STTextField("Senha",
                                texto: Binding(get: { store.estado.senha },
                                               set: { store.send(.senhaAlterada($0)) }),
                                seguro: true,
                                erro: store.estado.erroSenha)

                    if let erro = store.estado.erroGeral {
                        Text(erro)
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    STPrimaryButton(tituloCTA, carregando: store.estado.carregando) {
                        store.send(.entrar)
                    }
                    .disabled(!store.estado.podeEnviar)

                    STSecondaryButton("Criar conta", acao: aoCriarConta)
                }
            }
            .padding(DSSpacing.margemTela)
        }
        .background(DSColor.bgCanvas)
    }

    private var tituloCTA: String {
        store.estado.segundosBloqueio > 0
            ? "Tente novamente em \(store.estado.segundosBloqueio)s"
            : "Entrar"
    }

    private var marca: some View {
        VStack(spacing: DSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.lg)
                    .fill(DSColor.brandPrimary)
                    .frame(width: 84, height: 84)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(DSColor.onPrimary)
            }
            .dsShadow(.e2)
            .accessibilityHidden(true)

            Text("ServiceTrack")
                .font(DSFont.title1)
                .foregroundStyle(DSColor.textPrimary)
            Text("Acompanhe o serviço do seu veículo")
                .font(DSFont.callout)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.top, DSSpacing.x5l)
    }
}
