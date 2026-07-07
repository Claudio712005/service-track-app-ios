import Foundation

/// Fixtures JSON derivadas dos `example:` dos contratos `openApi/**`.
/// Cobrem de propósito as variações reais: datas sem offset (camelCase),
/// datas com `Z` e enums legados no dashboard (C1/C2/C5).
enum MockFixtures {
    static let clienteId = "550e8400-e29b-41d4-a716-446655440000"
    static let veiculoId = "660e8400-e29b-41d4-a716-446655550001"
    static let osId = "4d32c6ae-46d1-403d-8e65-d9527126d093"

    /// JWT de brinquedo: payload real (base64url) para o parse local de claims
    /// funcionar (spec §8.2 item 5); assinatura falsa — o app não valida (§8.1).
    static var token: String {
        let header = base64url(#"{"alg":"RS256","typ":"JWT"}"#)
        let exp = Int(Date.now.timeIntervalSince1970) + 8 * 3600
        let payload = base64url(
            #"{"iss":"service-track-api","sub":"\#(clienteId)","upn":"cliente@servicetrack.dev","groups":["CLIENTE"],"exp":\#(exp)}"#)
        return "\(header).\(payload).mock-assinatura"
    }

    private static func base64url(_ json: String) -> String {
        Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static var loginResponse: String {
        """
        {
          "token": "\(token)",
          "usuarioId": "\(clienteId)",
          "nome": "Cláudio da Silva Araújo",
          "email": "cliente@servicetrack.dev",
          "roles": ["CLIENTE"]
        }
        """
    }

    static let cliente = """
        {
          "id": "\(clienteId)",
          "nome": "Cláudio da Silva Araújo",
          "email": "cliente@servicetrack.dev",
          "cpf": "54927170063",
          "telefone": "11987654321",
          "roles": ["CLIENTE"],
          "ativo": true
        }
        """

    static let veiculo = """
        {
          "id": "\(veiculoId)",
          "placa": "ABC1D23",
          "modelo": "Corolla",
          "marca": "Toyota",
          "ano": 2022,
          "proprietarioId": "\(clienteId)",
          "urlImagem": "https://images.unsplash.com/photo-1605559424843-9e4c3ca4b7f1?w=800",
          "codigoFipe": "002110-8"
        }
        """

    static let veiculos = """
        [
          \(veiculo),
          {
            "id": "660e8400-e29b-41d4-a716-446655550002",
            "placa": "XYZ9B76",
            "modelo": "Gol",
            "marca": "Volkswagen",
            "ano": 2019,
            "proprietarioId": "\(clienteId)",
            "urlImagem": null,
            "codigoFipe": null
          }
        ]
        """

    static let sugestoesImagens = """
        {
          "imagens": [
            "https://images.unsplash.com/photo-1464219414232-fdb7452e77ca?w=800",
            "https://images.unsplash.com/photo-1562162192-3c90c1c1b1fa?w=800"
          ]
        }
        """

    // Datas camelCase sem offset, de propósito (C5).
    static func ordemServicoDetalhe(status: String = "AGUARDANDO_APROVACAO") -> String {
        """
        {
          "id": "\(osId)",
          "motivo": "Barulho ao frear e revisão geral",
          "observacao": "Veículo apresenta ruído no motor",
          "clienteId": "\(clienteId)",
          "mecanicoId": "550e8400-e29b-41d4-a716-446655440101",
          "veiculoId": "\(veiculoId)",
          "status": "\(status)",
          "dataCriacao": "2026-07-01T09:30:00",
          "dataAtualizacao": "2026-07-03T15:45:00",
          "itensServico": [
            {
              "id": "7f0a0a10-0000-4000-8000-000000000001",
              "servicoId": "8f0a0a10-0000-4000-8000-000000000001",
              "valor": 180.0,
              "feito": false,
              "mecanicoResponsavelId": "550e8400-e29b-41d4-a716-446655440101",
              "observacao": "Troca das pastilhas dianteiras"
            },
            {
              "id": "7f0a0a10-0000-4000-8000-000000000002",
              "servicoId": "8f0a0a10-0000-4000-8000-000000000002",
              "valor": 120.0,
              "feito": false
            }
          ],
          "insumos": [
            "9f0a0a10-0000-4000-8000-000000000001",
            "9f0a0a10-0000-4000-8000-000000000001",
            "9f0a0a10-0000-4000-8000-000000000002"
          ],
          "orcamento": {
            "id": "af0a0a10-0000-4000-8000-000000000001",
            "custoMaoDeObra": 300.0,
            "custoInsumos": 260.5,
            "valorTotal": 560.5,
            "aprovado": false,
            "observacao": "Validade de 7 dias",
            "dataCriacao": "2026-07-03T15:45:00",
            "dataAtualizacao": "2026-07-03T15:45:00"
          }
        }
        """
    }

    static let ordemServicoRecebida = """
        {
          "id": "5e43d7bf-57e2-414e-9f76-e0638237fabc",
          "motivo": "Revisão de 40.000 km",
          "clienteId": "\(clienteId)",
          "veiculoId": "\(veiculoId)",
          "status": "RECEBIDA",
          "dataCriacao": "2026-07-06T10:00:00",
          "dataAtualizacao": "2026-07-06T10:00:00",
          "itensServico": [],
          "insumos": []
        }
        """

    static func resumoOrdem(status: String) -> String {
        """
        {
          "id": "\(osId)",
          "mecanicoId": "550e8400-e29b-41d4-a716-446655440101",
          "clienteId": "\(clienteId)",
          "veiculoId": "\(veiculoId)",
          "motivo": "Barulho ao frear e revisão geral",
          "observacao": "Veículo apresenta ruído no motor",
          "status": "\(status)"
        }
        """
    }

    static func pageOrdens(statusDestaque: String = "AGUARDANDO_APROVACAO") -> String {
        """
        {
          "content": [
            \(resumoOrdem(status: statusDestaque)),
            {
              "id": "5e43d7bf-57e2-414e-9f76-e0638237fabc",
              "clienteId": "\(clienteId)",
              "veiculoId": "660e8400-e29b-41d4-a716-446655550002",
              "motivo": "Revisão de 40.000 km",
              "status": "EM_EXECUCAO"
            },
            {
              "id": "6a1b2c3d-0000-4000-8000-000000000003",
              "clienteId": "\(clienteId)",
              "veiculoId": "\(veiculoId)",
              "motivo": "Troca de óleo",
              "status": "ENTREGUE"
            }
          ],
          "page": 0,
          "size": 20,
          "total": 3,
          "totalPages": 1
        }
        """
    }

    // Dashboard: snake_case, datas com Z e enum legado APROVADO, de propósito (C1/C2).
    static let dashboard = """
        {
          "usuario_id": "\(clienteId)",
          "usuario_nome": "Cláudio da Silva Araújo",
          "resumo": {
            "ordens_ativas": 2,
            "ordens_concluidas": 5,
            "ordens_canceladas": 1,
            "total_ordens": 8,
            "veiculos_cadastrados": 2
          },
          "ordens_ativas": [
            {
              "id": "\(osId)",
              "motivo": "Barulho ao frear e revisão geral",
              "status": "AGUARDANDO_APROVACAO",
              "veiculo_id": "\(veiculoId)",
              "veiculo_placa": "ABC1D23",
              "veiculo_modelo": "Corolla 2022",
              "mecanico_id": "550e8400-e29b-41d4-a716-446655440101",
              "mecanico_nome": "Mário Máquina",
              "data_criacao": "2026-07-01T09:30:00Z",
              "data_atualizacao": "2026-07-03T15:45:00Z",
              "dias_em_andamento": 5,
              "valor_orcado": 560.50,
              "prazo_conclusao": "2026-07-10T18:00:00Z"
            },
            {
              "id": "5e43d7bf-57e2-414e-9f76-e0638237fabc",
              "motivo": "Revisão de 40.000 km",
              "status": "APROVADO",
              "veiculo_id": "660e8400-e29b-41d4-a716-446655550002",
              "veiculo_placa": "XYZ9B76",
              "veiculo_modelo": "Gol 2019",
              "data_criacao": "2026-07-04T08:00:00Z",
              "data_atualizacao": "2026-07-05T11:20:00Z",
              "dias_em_andamento": 2,
              "valor_orcado": null,
              "prazo_conclusao": null
            }
          ],
          "ordens_recentes": [
            {
              "id": "6a1b2c3d-0000-4000-8000-000000000003",
              "motivo": "Troca de óleo",
              "status": "FINALIZADA",
              "veiculo_id": "\(veiculoId)",
              "veiculo_placa": "ABC1D23",
              "veiculo_modelo": "Corolla 2022",
              "data_criacao": "2026-06-10T08:00:00Z",
              "data_conclusao": "2026-06-12T17:30:00Z",
              "dias_para_conclusao": 2,
              "valor_total": 320.00,
              "mecanico_nome": "Especialista Diego"
            },
            {
              "id": "6a1b2c3d-0000-4000-8000-000000000004",
              "motivo": "Pastilhas de freio",
              "status": "ENTREGUE",
              "veiculo_id": "660e8400-e29b-41d4-a716-446655550002",
              "veiculo_placa": "XYZ9B76",
              "veiculo_modelo": "Gol 2019",
              "data_criacao": "2026-05-04T09:00:00Z",
              "data_conclusao": "2026-05-06T16:00:00Z",
              "dias_para_conclusao": 2,
              "valor_total": 480.00,
              "mecanico_nome": "Mário Máquina"
            },
            {
              "id": "6a1b2c3d-0000-4000-8000-000000000005",
              "motivo": "Alinhamento e balanceamento",
              "status": "ENTREGUE",
              "veiculo_id": "\(veiculoId)",
              "veiculo_placa": "ABC1D23",
              "veiculo_modelo": "Corolla 2022",
              "data_criacao": "2026-05-20T10:00:00Z",
              "data_conclusao": "2026-05-21T15:00:00Z",
              "dias_para_conclusao": 1,
              "valor_total": 180.00,
              "mecanico_nome": "Técnico João"
            },
            {
              "id": "6a1b2c3d-0000-4000-8000-000000000006",
              "motivo": "Revisão de 30.000 km",
              "status": "ENTREGUE",
              "veiculo_id": "\(veiculoId)",
              "veiculo_placa": "ABC1D23",
              "veiculo_modelo": "Corolla 2022",
              "data_criacao": "2026-04-08T08:30:00Z",
              "data_conclusao": "2026-04-11T18:00:00Z",
              "dias_para_conclusao": 3,
              "valor_total": 890.50,
              "mecanico_nome": "Especialista Diego"
            },
            {
              "id": "6a1b2c3d-0000-4000-8000-000000000007",
              "motivo": "Troca de bateria",
              "status": "ENTREGUE",
              "veiculo_id": "660e8400-e29b-41d4-a716-446655550002",
              "veiculo_placa": "XYZ9B76",
              "veiculo_modelo": "Gol 2019",
              "data_criacao": "2026-03-14T11:00:00Z",
              "data_conclusao": "2026-03-14T14:30:00Z",
              "dias_para_conclusao": 0,
              "valor_total": 650.00,
              "mecanico_nome": "Mário Máquina"
            }
          ],
          "veiculos": [
            {
              "id": "\(veiculoId)",
              "placa": "ABC1D23",
              "marca": "Toyota",
              "modelo": "Corolla",
              "ano": 2022,
              "imagem_url": "https://images.unsplash.com/photo-1605559424843-9e4c3ca4b7f1?w=800",
              "codigo_fipe": "002110-8",
              "ativo": true,
              "total_ordens": 5,
              "total_gasto": 1850.50,
              "data_criacao": "2026-01-10T14:20:00Z"
            },
            {
              "id": "660e8400-e29b-41d4-a716-446655550002",
              "placa": "XYZ9B76",
              "marca": "Volkswagen",
              "modelo": "Gol",
              "ano": 2019,
              "ativo": true,
              "total_ordens": 3,
              "total_gasto": 650.00,
              "data_criacao": "2026-02-05T10:15:00Z"
            }
          ],
          "data_atualizacao": "2026-07-06T09:00:00Z"
        }
        """

    static let notificacao = """
        {
          "id": "a1b2c3d4-e5f6-4890-abcd-ef1234567890",
          "titulo": "Orçamento disponível",
          "assunto": "Sua OS aguarda aprovação",
          "descricao": "O diagnóstico foi concluído e o orçamento de R$ 560,50 aguarda sua decisão.",
          "tipoNotificacao": "EMAIL",
          "tipoConteudo": "MUDANCA_STATUS_OS",
          "statusEnvio": "ENVIADA",
          "visualizada": false,
          "dataCriacao": "2026-07-03T15:46:00",
          "dataEnvio": "2026-07-03T15:46:30",
          "dataVisualizacao": null
        }
        """

    private static let notificacoesNaoLidas = """
            \(notificacao),
            {
              "id": "c1b2c3d4-e5f6-4890-abcd-ef1234567892",
              "titulo": "Diagnóstico iniciado",
              "assunto": "Seu Corolla entrou em diagnóstico",
              "descricao": "O mecânico Mário Máquina iniciou a avaliação do veículo.",
              "tipoNotificacao": "EMAIL",
              "tipoConteudo": "MUDANCA_STATUS_OS",
              "statusEnvio": "ENVIADA",
              "visualizada": false,
              "dataCriacao": "2026-07-02T08:15:00",
              "dataEnvio": "2026-07-02T08:15:30",
              "dataVisualizacao": null
            },
            {
              "id": "d1b2c3d4-e5f6-4890-abcd-ef1234567893",
              "titulo": "Ordem recebida",
              "assunto": "Recebemos seu veículo",
              "descricao": "Sua ordem de serviço foi aberta e aguarda o início do diagnóstico.",
              "tipoNotificacao": "EMAIL",
              "tipoConteudo": "MUDANCA_STATUS_OS",
              "statusEnvio": "ENVIADA",
              "visualizada": false,
              "dataCriacao": "2026-07-01T09:31:00",
              "dataEnvio": "2026-07-01T09:31:20",
              "dataVisualizacao": null
            }
        """

    private static let notificacaoLida = """
            {
              "id": "b1b2c3d4-e5f6-4890-abcd-ef1234567891",
              "titulo": "Ordem de Serviço Atualizada",
              "assunto": "Sua OS mudou de status",
              "descricao": "A ordem de serviço entrou em execução.",
              "tipoNotificacao": "EMAIL",
              "tipoConteudo": "MUDANCA_STATUS_OS",
              "statusEnvio": "ENVIADA",
              "visualizada": true,
              "dataCriacao": "2026-07-05T11:21:00",
              "dataEnvio": "2026-07-05T11:21:20",
              "dataVisualizacao": "2026-07-05T12:00:00"
            }
        """

    /// Respeita a query `visualizada=false` do contrato (spec §7.8).
    static func pageNotificacoes(apenasNaoLidas: Bool = false) -> String {
        let itens = apenasNaoLidas
            ? notificacoesNaoLidas
            : "\(notificacoesNaoLidas),\n\(notificacaoLida)"
        let total = apenasNaoLidas ? 3 : 4
        return """
        {
          "content": [
        \(itens)
          ],
          "page": 0,
          "size": 20,
          "total": \(total),
          "totalPages": 1
        }
        """
    }

    static let catalogoServicos = """
        [
          {
            "id": "8f0a0a10-0000-4000-8000-000000000001",
            "nomeServico": "Troca de Óleo",
            "descricaoServico": "Substituição do óleo do motor e filtro"
          },
          {
            "id": "8f0a0a10-0000-4000-8000-000000000002",
            "nomeServico": "Freios",
            "descricaoServico": "Inspeção e substituição de pastilhas e discos"
          }
        ]
        """

    static let catalogoInsumos = """
        [
          {
            "id": "9f0a0a10-0000-4000-8000-000000000001",
            "nome": "Pastilha de freio",
            "descricao": "Par de pastilhas dianteiras cerâmicas"
          },
          {
            "id": "9f0a0a10-0000-4000-8000-000000000002",
            "nome": "Óleo de Motor 5W30",
            "descricao": "Óleo sintético para motores a gasolina e flex"
          }
        ]
        """
}
