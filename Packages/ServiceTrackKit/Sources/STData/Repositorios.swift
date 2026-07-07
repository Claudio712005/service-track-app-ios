import Foundation
import STDomain
import STNetworking

// Adapters HTTP dos ports do domínio (spec §10.2). Sem cache nesta fase —
// SWR entra na camada de cache prevista para as fases seguintes (spec §11.2).

public struct AuthRepositoryHTTP: AuthRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func login(email: String, senha: String) async throws -> Sessao {
        let body = try STJSON.encoder.encode(LoginRequestDTO(email: email, senha: senha))
        let dto: LoginResponseDTO = try await client.send(ServiceTrackAPI.login(body))
        return dto.domain
    }

    public func alterarSenha(senhaAtual: String, novaSenha: String, confirmacao: String) async throws {
        let body = try STJSON.encoder.encode(ResetarSenhaRequestDTO(
            senhaAtual: senhaAtual, novaSenha: novaSenha, confirmacaoNovaSenha: confirmacao))
        try await client.send(ServiceTrackAPI.resetSenha(body))
    }
}

public struct ClienteRepositoryHTTP: ClienteRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func cadastrar(nome: String, email: String, senha: String, dataNascimento: Date,
                          telefone: String, cpf: String) async throws -> Cliente {
        let body = try STJSON.encoder.encode(CadastrarClienteRequestDTO(
            nome: nome, email: email, senha: senha,
            dataNascimento: STJSON.stringData(dataNascimento), telefone: telefone, cpf: cpf))
        let dto: ClienteResponseDTO = try await client.send(ServiceTrackAPI.cadastrarCliente(body))
        return dto.domain
    }

    public func buscar(id: UUID) async throws -> Cliente {
        let dto: ClienteResponseDTO = try await client.send(ServiceTrackAPI.cliente(id))
        return dto.domain
    }

    public func atualizar(id: UUID, nome: String, email: String, telefone: String) async throws -> Cliente {
        let body = try STJSON.encoder.encode(AtualizarClienteRequestDTO(
            nome: nome, email: email, telefone: telefone))
        let dto: ClienteResponseDTO = try await client.send(ServiceTrackAPI.atualizarCliente(id, body))
        return dto.domain
    }

    public func desativar(id: UUID) async throws {
        try await client.send(ServiceTrackAPI.desativarCliente(id))
    }
}

public struct VeiculoRepositoryHTTP: VeiculoRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func listar() async throws -> [Veiculo] {
        let dtos: [DadosVeiculoResponseDTO] = try await client.send(ServiceTrackAPI.veiculos)
        return dtos.map(\.domain)
    }

    public func buscar(id: UUID) async throws -> Veiculo {
        let dto: DadosVeiculoResponseDTO = try await client.send(ServiceTrackAPI.veiculo(id))
        return dto.domain
    }

    public func cadastrar(placa: String, modelo: String, marca: String, ano: Int,
                          proprietarioId: UUID, urlImagem: URL?) async throws -> Veiculo {
        let body = try STJSON.encoder.encode(CadastrarVeiculoRequestDTO(
            placa: placa, modelo: modelo, marca: marca, ano: ano,
            proprietarioId: proprietarioId, urlImagem: urlImagem?.absoluteString))
        let dto: DadosVeiculoResponseDTO = try await client.send(ServiceTrackAPI.cadastrarVeiculo(body))
        return dto.domain
    }

    public func atualizar(id: UUID, placa: String, modelo: String, marca: String, ano: Int,
                          urlImagem: URL?) async throws -> Veiculo {
        let body = try STJSON.encoder.encode(AtualizarVeiculoRequestDTO(
            placa: placa, modelo: modelo, marca: marca, ano: ano,
            urlImagem: urlImagem?.absoluteString))
        let dto: DadosVeiculoResponseDTO = try await client.send(ServiceTrackAPI.atualizarVeiculo(id, body))
        return dto.domain
    }

    public func remover(id: UUID) async throws {
        try await client.send(ServiceTrackAPI.removerVeiculo(id))
    }

    public func sugestoesDeImagem(marca: String, modelo: String) async throws -> [URL] {
        let dto: SugestoesImagensResponseDTO =
            try await client.send(ServiceTrackAPI.sugestoesImagens(marca: marca, modelo: modelo))
        return (dto.imagens ?? []).compactMap(URL.init(string:))
    }
}

public struct OrdemServicoRepositoryHTTP: OrdemServicoRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func listar(status: StatusOrdemServico?, page: Int, size: Int) async throws -> Page<ResumoOrdemServico> {
        let dto: PageDTO<ResumoOrdemServicoResponseDTO> =
            try await client.send(ServiceTrackAPI.listarOrdens(status: status, page: page, size: size))
        return dto.domain(\.domain)
    }

    public func buscar(id: UUID) async throws -> OrdemServico {
        let dto: OrdemServicoResponseDTO = try await client.send(ServiceTrackAPI.ordemServico(id))
        return dto.domain
    }

    public func abrir(motivo: String, clienteId: UUID, veiculoId: UUID, mecanicoId: UUID?,
                      observacao: String?) async throws -> OrdemServico {
        // Conflito C4: contrato exige mecanicoId, RN-01 impede o cliente de fornecê-lo.
        // Bloqueio explícito até resolução com o backend (ADR-iOS-002).
        guard let mecanicoId else {
            throw AppError.regraNegocio(
                "Abertura de OS indisponível: aguardando definição do contrato (C4/ADR-iOS-002).")
        }
        let body = try STJSON.encoder.encode(OrdemServicoRequestDTO(
            motivo: motivo, clienteId: clienteId, mecanicoId: mecanicoId,
            veiculoId: veiculoId, observacao: observacao))
        let dto: OrdemServicoResponseDTO = try await client.send(ServiceTrackAPI.abrirOrdemServico(body))
        return dto.domain
    }

    public func aprovarOrcamento(osId: UUID) async throws -> ResumoOrdemServico {
        let dto: ResumoOrdemServicoResponseDTO = try await client.send(ServiceTrackAPI.aprovarOrcamento(osId))
        return dto.domain
    }

    public func reprovarOrcamento(osId: UUID, motivo: String) async throws -> ResumoOrdemServico {
        // RN-05: motivo obrigatório.
        let motivoLimpo = motivo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !motivoLimpo.isEmpty else {
            throw AppError.validacao(campo: "motivo", mensagem: "Informe o motivo da reprovação.")
        }
        let body = try STJSON.encoder.encode(ReprovarOrcamentoRequestDTO(motivo: motivoLimpo))
        let dto: ResumoOrdemServicoResponseDTO =
            try await client.send(ServiceTrackAPI.reprovarOrcamento(osId, body))
        return dto.domain
    }

    public func cancelar(osId: UUID, motivo: String?) async throws -> ResumoOrdemServico {
        let body = try STJSON.encoder.encode(CancelarOsRequestDTO(motivo: motivo))
        let dto: ResumoOrdemServicoResponseDTO =
            try await client.send(ServiceTrackAPI.cancelarOrdemServico(osId, body))
        return dto.domain
    }
}

public struct DashboardRepositoryHTTP: DashboardRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func buscar(clienteId: UUID) async throws -> DashboardCliente {
        let dto: DashboardClienteResponseDTO =
            try await client.send(ServiceTrackAPI.dashboard(clienteId: clienteId))
        return dto.domain
    }
}

public struct NotificacaoRepositoryHTTP: NotificacaoRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func listar(apenasNaoLidas: Bool?, page: Int, size: Int) async throws -> Page<Notificacao> {
        let visualizada = apenasNaoLidas.map { !$0 }
        let dto: PageDTO<NotificacaoResponseDTO> =
            try await client.send(ServiceTrackAPI.notificacoes(visualizada: visualizada, page: page, size: size))
        return dto.domain(\.domain)
    }

    public func buscar(id: UUID) async throws -> Notificacao {
        let dto: NotificacaoResponseDTO = try await client.send(ServiceTrackAPI.notificacao(id))
        return dto.domain
    }

    public func contagemNaoLidas() async throws -> Int {
        let dto: ContadorNaoLidasResponseDTO = try await client.send(ServiceTrackAPI.contagemNaoLidas)
        return dto.total
    }

    public func marcarVisualizada(id: UUID) async throws {
        try await client.send(ServiceTrackAPI.visualizarNotificacao(id))
    }
}

public struct CatalogoRepositoryHTTP: CatalogoRepository {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func servicos() async throws -> [CatalogoServico] {
        let dtos: [CatalogoServicoResponseDTO] = try await client.send(ServiceTrackAPI.catalogoServicos)
        return dtos.map(\.domain)
    }

    public func insumos() async throws -> [CatalogoInsumo] {
        let dtos: [CatalogoInsumoResponseDTO] = try await client.send(ServiceTrackAPI.catalogoInsumos)
        return dtos.map(\.domain)
    }
}
