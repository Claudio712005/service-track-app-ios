import Foundation

// Ports do domínio (spec §10.2) — implementados pelos adapters de STData/STPersistence.

public protocol AuthRepository: Sendable {
    /// `POST /autenticacao/login` — não persiste a sessão; quem decide é o chamador (role gate §8.2).
    func login(email: String, senha: String) async throws -> Sessao
    /// `POST /autenticacao/reset-senha` — troca de senha autenticada (spec §9 C6).
    func alterarSenha(senhaAtual: String, novaSenha: String, confirmacao: String) async throws
}

public protocol ClienteRepository: Sendable {
    func cadastrar(nome: String, email: String, senha: String, dataNascimento: Date,
                   telefone: String, cpf: String) async throws -> Cliente
    func buscar(id: UUID) async throws -> Cliente
    func atualizar(id: UUID, nome: String, email: String, telefone: String) async throws -> Cliente
    /// Soft delete (RN-08).
    func desativar(id: UUID) async throws
}

public protocol VeiculoRepository: Sendable {
    func listar() async throws -> [Veiculo]
    func buscar(id: UUID) async throws -> Veiculo
    func cadastrar(placa: String, modelo: String, marca: String, ano: Int,
                   proprietarioId: UUID, urlImagem: URL?) async throws -> Veiculo
    func atualizar(id: UUID, placa: String, modelo: String, marca: String, ano: Int,
                   urlImagem: URL?) async throws -> Veiculo
    func remover(id: UUID) async throws
    /// Sugestões Unsplash (RN-11, best-effort).
    func sugestoesDeImagem(marca: String, modelo: String) async throws -> [URL]
}

public protocol OrdemServicoRepository: Sendable {
    /// `GET /ordem-servico/lista` (ADR-iOS-002 D1). Backend filtra pelo cliente do token (RN-02).
    func listar(status: StatusOrdemServico?, page: Int, size: Int) async throws -> Page<ResumoOrdemServico>
    func buscar(id: UUID) async throws -> OrdemServico
    /// RN-01: abertura simples. `mecanicoId` pendente de resolução C4 — ver ADR-iOS-002.
    func abrir(motivo: String, clienteId: UUID, veiculoId: UUID, mecanicoId: UUID?,
               observacao: String?) async throws -> OrdemServico
    /// Ações devolvem resumo; chamador refaz o fetch do detalhe (ADR-iOS-002 D3).
    func aprovarOrcamento(osId: UUID) async throws -> ResumoOrdemServico
    /// RN-05: motivo obrigatório.
    func reprovarOrcamento(osId: UUID, motivo: String) async throws -> ResumoOrdemServico
    /// RN-06: motivo opcional.
    func cancelar(osId: UUID, motivo: String?) async throws -> ResumoOrdemServico
}

public protocol DashboardRepository: Sendable {
    /// `GET /dashboard/clientes/{id}` — `id` deve ser o `usuarioId` da sessão (RN-02).
    func buscar(clienteId: UUID) async throws -> DashboardCliente
}

public protocol NotificacaoRepository: Sendable {
    func listar(apenasNaoLidas: Bool?, page: Int, size: Int) async throws -> Page<Notificacao>
    func buscar(id: UUID) async throws -> Notificacao
    func contagemNaoLidas() async throws -> Int
    func marcarVisualizada(id: UUID) async throws
}

public protocol CatalogoRepository: Sendable {
    func servicos() async throws -> [CatalogoServico]
    func insumos() async throws -> [CatalogoInsumo]
}

/// Port de persistência de sessão (Keychain em produção — spec §8.2).
public protocol SessaoStore: Sendable {
    func carregar() throws -> Sessao?
    func salvar(_ sessao: Sessao) throws
    func limpar() throws
}
