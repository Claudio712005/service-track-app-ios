import SwiftUI
import STCore
import STDomain

/// Perfil (spec §15.12): cabeçalho com avatar, edição de dados, alteração de
/// senha, preferências, sair e desativar conta. Inclui a orientação de
/// recuperação de senha (spec §9 C6 — não existe endpoint público).
public struct PerfilView: View {
    @State private var store: PerfilStore
    @Binding var biometriaHabilitada: Bool
    @State private var mostrandoEditar = false
    @State private var mostrandoSenha = false
    @State private var mostrandoDesativar = false

    public init(store: PerfilStore, biometriaHabilitada: Binding<Bool>) {
        self._store = State(initialValue: store)
        self._biometriaHabilitada = biometriaHabilitada
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                switch (store.estado.carregando, store.estado.erroCarga) {
                case (true, _):
                    esqueleto.dsEntradaSuave()
                case (false, .some(let erro)):
                    STErrorState(mensagem: erro.mensagemPadrao) {
                        store.send(.recarregar)
                    }
                    .dsEntradaSuave()
                case (false, .none):
                    conteudo.dsEntradaSuave()
                }
            }
            .padding(DSSpacing.margemTela)
            .dsAnimaFase(store.estado.carregando)
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Perfil")
        .onAppear { store.send(.aparecer) }
        .sheet(isPresented: $mostrandoEditar) { EditarDadosSheet(store: store) }
        .sheet(isPresented: $mostrandoSenha) { AlterarSenhaSheet(store: store) }
        .confirmationDialog("Desativar conta?", isPresented: $mostrandoDesativar, titleVisibility: .visible) {
            Button("Desativar minha conta", role: .destructive) {
                store.send(.desativarConta)
            }
            Button("Manter conta", role: .cancel) {}
        } message: {
            Text("Sua conta será desativada e você sairá do app. A reativação exige contato com a oficina.")
        }
    }

    private var esqueleto: some View {
        VStack(spacing: DSSpacing.lg) {
            STSkeleton(altura: 96, raio: DSRadius.md)
            STSkeleton(altura: 200, raio: DSRadius.md)
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        cabecalho
        secaoConta
        secaoPreferencias
        secaoSobre
        secaoSessao
    }

    private var cabecalho: some View {
        STCard {
            HStack(spacing: DSSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(DSColor.brandPrimary.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Text(iniciais)
                        .font(DSFont.title2)
                        .foregroundStyle(DSColor.brandPrimary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(store.estado.cliente?.nome ?? "")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(store.estado.cliente?.email ?? "")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                    if let cpf = store.estado.cliente?.cpf, !cpf.isEmpty {
                        Text("CPF \(STMascara.cpf.aplicar(cpf))")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                    }
                }
            }
        }
    }

    private var iniciais: String {
        let palavras = (store.estado.cliente?.nome ?? "").split(separator: " ")
        let letras = [palavras.first, palavras.dropFirst().first]
            .compactMap { $0?.first.map(String.init) }
        return letras.joined().uppercased()
    }

    private var secaoConta: some View {
        secao("Conta") {
            linhaBotao("person.text.rectangle", "Editar dados") {
                mostrandoEditar = true
            }
            Divider()
            linhaBotao("key", "Alterar senha") {
                mostrandoSenha = true
            }
        }
    }

    private var secaoPreferencias: some View {
        secao("Preferências") {
            Toggle(isOn: $biometriaHabilitada) {
                Label("Desbloquear com biometria", systemImage: "faceid")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            .tint(DSColor.brandPrimary)
            .frame(minHeight: DSSpacing.alvoMinimo)
        }
    }

    private var secaoSobre: some View {
        secao("Sobre") {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Label {
                    Text("Esqueceu a senha? A troca é feita dentro do app. Sem acesso, entre em contato com a oficina.")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(DSColor.info)
                }
                Text("ServiceTrack para Clientes · v1.0")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }
        }
    }

    private var secaoSessao: some View {
        VStack(spacing: DSSpacing.md) {
            if let sucesso = store.estado.mensagemSucesso {
                feedback(sucesso, cor: DSColor.success, icone: "checkmark.circle.fill")
            }
            if let erro = store.estado.erroGeral {
                feedback(erro, cor: DSColor.danger, icone: "exclamationmark.triangle.fill")
            }

            STSecondaryButton("Sair") {
                store.send(.sair)
            }
            STDestructiveButton("Desativar conta", carregando: store.estado.salvando) {
                mostrandoDesativar = true
            }
        }
    }

    private func feedback(_ texto: String, cor: Color, icone: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icone)
            Text(texto).font(DSFont.subhead)
        }
        .foregroundStyle(cor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .background(cor.opacity(0.12), in: .rect(cornerRadius: DSRadius.sm))
        .task {
            try? await Task.sleep(for: .seconds(4))
            store.send(.limparFeedback)
        }
    }

    private func secao(_ titulo: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(titulo)
                .font(DSFont.subhead)
                .foregroundStyle(DSColor.textSecondary)
            STCard {
                VStack(spacing: DSSpacing.md, content: conteudo)
            }
        }
    }

    private func linhaBotao(_ icone: String, _ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack {
                Label(titulo, systemImage: icone)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }
            .frame(minHeight: DSSpacing.alvoMinimo)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheets

private struct EditarDadosSheet: View {
    @Bindable var store: PerfilStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    STTextField("Nome completo", texto: campo(.nome), erro: erro(.nome))
                    #if os(iOS)
                    STTextField("E-mail", texto: campo(.email), erro: erro(.email), teclado: .emailAddress)
                    STTextField("Telefone", texto: campo(.telefone), mascara: .telefone,
                                erro: erro(.telefone), teclado: .phonePad)
                    #else
                    STTextField("E-mail", texto: campo(.email), erro: erro(.email))
                    STTextField("Telefone", texto: campo(.telefone), mascara: .telefone, erro: erro(.telefone))
                    #endif

                    Text("CPF e data de nascimento não podem ser alterados pelo app.")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let erroGeral = store.estado.erroGeral {
                        Text(erroGeral).font(DSFont.footnote).foregroundStyle(DSColor.danger)
                    }

                    STPrimaryButton("Salvar", carregando: store.estado.salvando) {
                        store.send(.salvarDados)
                    }
                }
                .padding(DSSpacing.margemTela)
            }
            .background(DSColor.bgCanvas)
            .navigationTitle("Editar dados")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onChange(of: store.estado.mensagemSucesso) { _, novo in
                if novo != nil { dismiss() }
            }
        }
    }

    private func campo(_ campo: PerfilStore.Campo) -> Binding<String> {
        Binding(get: {
            switch campo {
            case .nome: store.estado.nome
            case .email: store.estado.email
            case .telefone: store.estado.telefone
            default: ""
            }
        }, set: { store.send(.campoAlterado(campo, $0)) })
    }

    private func erro(_ campo: PerfilStore.Campo) -> String? {
        store.estado.erroFormulario[campo]
    }
}

private struct AlterarSenhaSheet: View {
    @Bindable var store: PerfilStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    STTextField("Senha atual", texto: campo(.senhaAtual), seguro: true,
                                erro: store.estado.erroFormulario[.senhaAtual])
                    VStack(spacing: DSSpacing.sm) {
                        STTextField("Nova senha", texto: campo(.novaSenha), seguro: true,
                                    erro: store.estado.erroFormulario[.novaSenha])
                        STMedidorForcaSenha(senha: store.estado.novaSenha)
                    }
                    STTextField("Confirmar nova senha", texto: campo(.confirmacaoNovaSenha), seguro: true,
                                erro: store.estado.erroFormulario[.confirmacaoNovaSenha])

                    if let erroGeral = store.estado.erroGeral {
                        Text(erroGeral).font(DSFont.footnote).foregroundStyle(DSColor.danger)
                    }

                    STPrimaryButton("Alterar senha", carregando: store.estado.salvando) {
                        store.send(.alterarSenha)
                    }
                }
                .padding(DSSpacing.margemTela)
            }
            .background(DSColor.bgCanvas)
            .navigationTitle("Alterar senha")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onChange(of: store.estado.mensagemSucesso) { _, novo in
                if novo != nil { dismiss() }
            }
        }
    }

    private func campo(_ campo: PerfilStore.Campo) -> Binding<String> {
        Binding(get: {
            switch campo {
            case .senhaAtual: store.estado.senhaAtual
            case .novaSenha: store.estado.novaSenha
            case .confirmacaoNovaSenha: store.estado.confirmacaoNovaSenha
            default: ""
            }
        }, set: { store.send(.campoAlterado(campo, $0)) })
    }
}
