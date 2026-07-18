import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class VeiculoFormStore {
    public enum Modo: Equatable {
        case criar
        case editar(Veiculo)
    }

    public enum Etapa: Int, CaseIterable {
        case identificacao = 0
        case imagem = 1
        case dados = 2
    }

    public struct Estado {
        public var etapa: Etapa = .identificacao
        public var marca = ""
        public var modelo = ""
        public var ano = ""
        public var placa = ""
        public var sugestoes: [URL] = []
        public var imagemSelecionada: URL?
        public var buscandoSugestoes = false
        public var sugestoesFalharam = false
        public var salvando = false
        public var erros: [Campo: String] = [:]
        public var erroGeral: String?

        public var progresso: Double { Double(etapa.rawValue + 1) / Double(Etapa.allCases.count) }
    }

    public enum Campo: Hashable {
        case marca, modelo, ano, placa
    }

    public enum Acao {
        case campoAlterado(Campo, String)
        case imagemEscolhida(URL?)
        case avancar
        case voltar
    }

    public private(set) var estado = Estado()
    public let modo: Modo

    private let veiculos: VeiculoRepository
    private let proprietarioId: UUID
    private let cache: CacheStore?
    private let aoSalvar: (Veiculo) -> Void

    public init(modo: Modo, veiculos: VeiculoRepository, proprietarioId: UUID,
                cache: CacheStore? = nil, aoSalvar: @escaping (Veiculo) -> Void) {
        self.modo = modo
        self.veiculos = veiculos
        self.proprietarioId = proprietarioId
        self.cache = cache
        self.aoSalvar = aoSalvar

        if case .editar(let veiculo) = modo {
            estado.marca = veiculo.marca
            estado.modelo = veiculo.modelo
            estado.ano = String(veiculo.ano)
            estado.placa = veiculo.placa
            estado.imagemSelecionada = veiculo.urlImagem
        }
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .campoAlterado(let campo, let valor):
            switch campo {
            case .marca: estado.marca = valor
            case .modelo: estado.modelo = valor
            case .ano: estado.ano = String(valor.filter(\.isNumber).prefix(4))
            case .placa: estado.placa = valor
            }
            estado.erros[campo] = nil
            estado.erroGeral = nil
        case .imagemEscolhida(let url):
            estado.imagemSelecionada = url
        case .avancar:
            avancar()
        case .voltar:
            if let anterior = Etapa(rawValue: estado.etapa.rawValue - 1) {
                estado.etapa = anterior
            }
        }
    }

    private func avancar() {
        guard validar(estado.etapa) else { return }
        switch estado.etapa {
        case .identificacao:
            estado.etapa = .imagem
            buscarSugestoes()
        case .imagem:
            estado.etapa = .dados
        case .dados:
            salvar()
        }
    }

    func validar(_ etapa: Etapa) -> Bool {
        var erros: [Campo: String] = [:]
        switch etapa {
        case .identificacao:
            if estado.marca.trimmingCharacters(in: .whitespaces).isEmpty {
                erros[.marca] = "Informe a marca."
            }
            if estado.modelo.trimmingCharacters(in: .whitespaces).isEmpty {
                erros[.modelo] = "Informe o modelo."
            }
        case .imagem:
            break
        case .dados:
            if Int(estado.ano).map({ $0 < 1886 || $0 > 2100 }) ?? true {
                erros[.ano] = "Informe um ano válido (a partir de 1886)."
            }
            if !Validadores.placaValida(estado.placa) {
                erros[.placa] = "Placa inválida (ex.: ABC1D23)."
            }
        }
        estado.erros = erros
        return erros.isEmpty
    }

    private func buscarSugestoes() {
        guard estado.sugestoes.isEmpty else { return }
        estado.buscandoSugestoes = true
        estado.sugestoesFalharam = false
        Task {
            do {
                estado.sugestoes = try await veiculos.sugestoesDeImagem(
                    marca: estado.marca.trimmingCharacters(in: .whitespaces),
                    modelo: estado.modelo.trimmingCharacters(in: .whitespaces))
            } catch {
                estado.sugestoesFalharam = true
            }
            estado.buscandoSugestoes = false
        }
    }

    private func salvar() {
        guard !estado.salvando, let ano = Int(estado.ano) else { return }
        estado.salvando = true
        estado.erroGeral = nil

        let marca = estado.marca.trimmingCharacters(in: .whitespaces)
        let modelo = estado.modelo.trimmingCharacters(in: .whitespaces)
        let placa = STMascaraPlaca.normalizar(estado.placa)

        Task {
            do {
                let salvo: Veiculo
                switch modo {
                case .criar:
                    salvo = try await veiculos.cadastrar(placa: placa, modelo: modelo, marca: marca,
                                                         ano: ano, proprietarioId: proprietarioId,
                                                         urlImagem: estado.imagemSelecionada)
                case .editar(let original):
                    salvo = try await veiculos.atualizar(id: original.id, placa: placa, modelo: modelo,
                                                         marca: marca, ano: ano,
                                                         urlImagem: estado.imagemSelecionada)
                }
                Telemetria.registrar(modo == .criar ? "vehicle_create" : "vehicle_edit")
                await cache?.invalidar(chaves: [CacheChave.veiculos, CacheChave.dashboard])
                aoSalvar(salvo)
            } catch let erro as AppError {
                estado.erroGeral = erro.mensagemPadrao
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.salvando = false
        }
    }
}

enum STMascaraPlaca {
    static func normalizar(_ placa: String) -> String {
        placa.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
