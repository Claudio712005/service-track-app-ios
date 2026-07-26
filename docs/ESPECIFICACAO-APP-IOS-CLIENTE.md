# ServiceTrack — Especificação de Engenharia do Aplicativo iOS (Cliente)

> **Documento único de verdade.** Esta especificação consolida SRS, ADRs, RFCs, Casos de Uso,
> diagramas C4, contratos OpenAPI, DTOs, controllers e modelos de domínio do repositório
> `ServiceTrack-API` e os expande para um guia completo de implementação do aplicativo iOS
> destinado **exclusivamente ao perfil Cliente**. A implementação integral do app deve ser
> possível usando apenas este documento, sem reinterpretar a documentação de origem.
>
> **Versão:** 1.0 · **Base backend:** branch `fase-2` · **Data:** 2026-07-06
> **Autor da consolidação:** Engenharia de Produto iOS · **Fonte primária:** `/docs`, `/software/service-track-api`

---

## Sumário

1. [Visão geral e objetivo do produto](#1-visão-geral-e-objetivo-do-produto)
2. [Escopo — o que é e o que não é do app Cliente](#2-escopo)
3. [Rastreabilidade: RF → Caso de uso → Tela → Endpoint](#3-rastreabilidade)
4. [Domínio e entidades](#4-domínio-e-entidades)
5. [Máquina de estados da Ordem de Serviço](#5-máquina-de-estados-da-ordem-de-serviço)
6. [Regras de negócio consolidadas](#6-regras-de-negócio-consolidadas)
7. [Contrato da API para o Cliente](#7-contrato-da-api-para-o-cliente)
8. [Autenticação, autorização e segurança](#8-autenticação-autorização-e-segurança)
9. [Conflitos identificados na documentação e resoluções propostas](#9-conflitos-identificados)
10. [Arquitetura do aplicativo iOS](#10-arquitetura-do-aplicativo-ios)
11. [Camada de rede, cache, sincronização e offline](#11-camada-de-rede-cache-sincronização-e-offline)
12. [Tratamento de falhas e resiliência no cliente](#12-tratamento-de-falhas-e-resiliência-no-cliente)
13. [Design System](#13-design-system)
14. [Biblioteca de componentes](#14-biblioteca-de-componentes)
15. [Telas e jornadas completas](#15-telas-e-jornadas-completas)
16. [Acessibilidade](#16-acessibilidade)
17. [Observabilidade, telemetria e analytics](#17-observabilidade-telemetria-e-analytics) 18. [Requisitos não funcionais do app](#18-requisitos-não-funcionais-do-app)
19. [Estratégia de testes](#19-estratégia-de-testes)
20. [Estrutura do projeto Xcode](#20-estrutura-do-projeto-xcode)
21. [Roadmap de implementação](#21-roadmap-de-implementação)
22. [Anexos: dicionário de erros, tokens de design, checklists](#22-anexos)

---

## 1. Visão geral e objetivo do produto

### 1.1 Contexto

A Auto Center ABC opera uma oficina mecânica de médio porte cujo processo de atendimento,
diagnóstico, orçamento, execução e entrega era gerido por anotações manuais e planilhas
(`docs/mvp-1/CASE.md`). O backend **ServiceTrack-API** (Kotlin + Quarkus, monólito modular
hexagonal — ADR-001/003/004) substituiu esse processo. Ele controla todo o ciclo de vida de uma
Ordem de Serviço (OS): abertura → diagnóstico → orçamento → execução → finalização → entrega,
com rastreabilidade por auditoria (SRS §7.6).

O backend atende **dois perfis** — `CLIENTE` e `MECANICO` (`domain/shared/enums/Role.kt`). Este
documento especifica o **aplicativo iOS do Cliente**: o produto que dá ao dono do veículo o poder
de acompanhar em tempo real o andamento dos serviços, autorizar/recusar orçamentos e manter seu
cadastro e frota.

### 1.2 Proposta de valor

O CASE define o valor central (`docs/mvp-1/CASE.md`, linha 17): *"permitir aos clientes acompanhar
em tempo real o andamento do serviço, autorizar reparos adicionais via aplicativo e garantir uma
gestão interna eficiente e segura"*. O app materializa essa promessa para o cliente com:

- **Transparência:** dashboard e timeline de status em tempo (quase) real de cada OS.
- **Controle:** aprovar ou reprovar orçamento em um toque, direto no app.
- **Confiança:** histórico completo por veículo, custos e prazos visíveis.
- **Autonomia:** gestão da própria frota (veículos) e do próprio cadastro.

### 1.3 Princípio de produto — experiência premium

O app **não pode parecer um app iOS genérico**. A referência de qualidade é a de produtos como
Nubank, Airbnb, Linear, Notion Calendar, Arc Search, Apple Wallet, Apple Fitness e Revolut. As
Human Interface Guidelines (HIG) são usadas **apenas como base de comportamento, ergonomia e
navegação** — não como aparência. A identidade visual é própria (ver [Design System](#13-design-system)).
Nenhuma tela pode ser confundível com um template padrão de `List`/`Form` do SwiftUI; se puder,
deve ser reprojetada.

### 1.4 Plataforma-alvo

| Item | Definição |
|---|---|
| Plataforma | iOS nativo |
| Versão mínima | iOS 17.0 (SwiftUI moderno: `Observation`, `NavigationStack`, `ScrollView` com `scrollTargetBehavior`, `ContentUnavailableView` customizável, Swift Charts, `SensoryFeedback`) |
| Linguagem | Swift 5.9+ / Swift 6 concurrency-ready |
| UI | SwiftUI first; UIKit apenas onde SwiftUI não entrega (ex.: interações de gesto avançadas, haptics finos) |
| Distribuição | App Store + TestFlight |
| Dispositivos | iPhone (retrato prioritário; adaptativo para Dynamic Type e telas maiores) |

---

## 2. Escopo

### 2.1 Dentro do escopo (perfil Cliente)

Toda funcionalidade abaixo tem rastreabilidade direta com RF/caso de uso/endpoint existente
(§3). Nada é inventado.

- **Cadastro e conta:** criar conta de cliente, login, alterar senha, ver/editar dados de perfil,
  desativar (soft delete) a própria conta.
- **Veículos (frota):** cadastrar, listar, ver detalhe, editar, remover; buscar sugestões de imagem
  (Unsplash) e enriquecimento FIPE do veículo.
- **Ordens de Serviço:** abrir OS simples (motivo + veículo), listar as próprias OS com filtros e
  paginação, ver detalhe completo (itens de serviço, insumos, orçamento, status), aprovar orçamento,
  reprovar orçamento (com motivo), cancelar OS.
- **Dashboard:** visão consolidada do cliente — resumo estatístico, ordens ativas, ordens recentes,
  veículos com estatísticas de gasto e volume.
- **Notificações:** listar notificações (paginado, filtro por lidas/não lidas), ver detalhe, contar
  não lidas, marcar como visualizada.
- **Catálogo (consulta):** listar serviços e insumos do catálogo (somente leitura) — usado para
  contexto e telas informativas.

### 2.2 Fora do escopo (perfil Mecânico — ignorar)

As seguintes capacidades existem no backend mas são **exclusivas do Mecânico** (`@RolesAllowed("MECANICO")`)
e **não** compõem o app Cliente:

- `POST /ordem-servico/completa` (abertura completa com itens diagnosticados).
- Enviar OS para diagnóstico, associar itens (serviços/insumos), gerar orçamento.
- Finalizar OS, entregar OS, concluir item de serviço.
- CRUD de mecânicos, CRUD de serviços do catálogo, CRUD de insumos com controle de estoque,
  tempo médio de serviços (telas administrativas).

> **Regra de negócio decisiva (SRS RF03, README):** *"o cliente não conhece serviços e peças ao
> abrir a OS — quem diagnostica é o mecânico."* Por isso a abertura pelo cliente é **simples** e o
> app **nunca** monta orçamento nem seleciona insumos/serviços para a OS.

### 2.3 Endpoints compartilhados — usar o comportamento do Cliente

Quando um endpoint é `@RolesAllowed("CLIENTE","MECANICO")`, o app usa **apenas** o comportamento do
Cliente. Exemplo canônico: `GET /ordem-servico` — a documentação declara *"Clientes veem apenas as
suas"* e o parâmetro `clienteId` é **ignorado para clientes** (o backend usa o ID do próprio token).
O app não deve enviar `clienteId`/`mecanicoId` nesses casos.

---

## 3. Rastreabilidade

Mapa que garante que cada funcionalidade do app deriva de artefato existente.

| RF (SRS) | Caso de uso / C4 | Endpoint(s) | Papel | Tela do app |
|---|---|---|---|---|
| RF01 Cadastro de cliente | `CriarUsuario`, `BuscarCliente`, `AtualizarUsuario`, `DesativarUsuario` | `POST /clientes`, `GET/PUT/DELETE /clientes/{id}` | Cliente | Onboarding, Perfil |
| — Autenticação | `LoginUsuario`, `ResetarSenha`, ADR-005 | `POST /autenticacao/login`, `POST /autenticacao/reset-senha` | Cliente | Login, Alterar senha |
| RF02 Cadastro de veículo | `CadastrarVeiculo`, `ListarVeiculos`, `BuscarVeiculo`, `AtualizarVeiculo`, `RemoverVeiculo`, `BuscarSugestoesImagens` (ADR-006 FIPE, ADR-007 Unsplash) | `POST /veiculos`, `GET /veiculos`, `GET/PUT/DELETE /veiculos/{id}`, `GET /veiculos/imagens/sugestoes` | Cliente | Garagem, Detalhe do veículo, Cadastro de veículo |
| RF03 Abertura de OS (simples) | `criar-ordem-servico.mmd`, `CriarOrdemServico` | `POST /ordem-servico` | Cliente | Nova OS |
| RF04 Acompanhamento de status | `buscar-ordem-servico.mmd`, `listar-ordens-servico.mmd`, `StatusOrdemServico` (state machine) | `GET /ordem-servico`, `GET /ordem-servico/{id}` | Cliente | OS — lista, OS — detalhe/timeline |
| RF06/RF07 Orçamento e autorização | `aprovar-orcamento.mmd`, `reprovar-orcamento.mmd`, ADR-014 | `PATCH /ordem-servico/{id}/orcamento/aprovacao`, `.../reprovacao` | Cliente | Card de orçamento, fluxo aprovar/reprovar |
| RF04 (cancelamento) | `cancelar-ordem-servico.mmd`, `CancelarOrdemServico` | `PATCH/POST /ordem-servico/{id}/cancelamento` | Cliente | Cancelar OS |
| Dashboard (mvp-2) | `BuscarResumoDashCliente` | `GET /dashboard/clientes/{id}` | Cliente | Home / Dashboard |
| RF09 Notificações | `listar-notificacoes.mmd`, `contar-nao-lidas.mmd`, `buscar-notificacao.mmd`, `marcar-notificacao-visualizada.mmd`, ADR-009 | `GET /notificacoes`, `GET /notificacoes/nao-lidas/contagem`, `GET /notificacoes/{id}`, `PATCH /notificacoes/{id}/visualizar` | Cliente | Central de notificações |
| RF08 Histórico | Dashboard + `GET /ordem-servico?status=…` | `GET /dashboard/...`, `GET /ordem-servico` | Cliente | Histórico por veículo, Dashboard |
| — Catálogo (consulta) | `ListarServicos`, `ListarInsumos` | `GET /catalogo/servicos`, `GET /catalogo/insumos` | Cliente (read) | Telas informativas / contexto |

> **Regra de rastreabilidade obrigatória:** nenhuma tela, componente de dados ou ação pode existir
> no app sem uma linha correspondente nesta tabela. Ao propor evolução, adicione a linha antes de
> implementar.

---

## 4. Domínio e entidades

Modelos derivados de `_domain` e dos DTOs OpenAPI. Nomes de campos abaixo são os **da API**
(camelCase no corpo JSON, salvo o dashboard que usa snake_case — ver §7 e §9).

### 4.1 Cliente (Usuário com role CLIENTE)

Fonte: `ClienteResponse`, `CadastrarClienteRequest`, `AtualizarClienteRequest`.

| Campo | Tipo | Regra |
|---|---|---|
| `id` | UUID | Gerado pelo backend |
| `nome` | String | min 2 chars |
| `email` | String (email) | único; usado no login e como `upn` no JWT |
| `cpf` | String | 11–14 chars; validado (CPF válido) |
| `telefone` | String | 10–11 dígitos |
| `dataNascimento` | Date (`yyyy-MM-dd`) | obrigatório no cadastro |
| `senha` | String | min 6; formato com maiúscula/número/símbolo recomendado (ex. `Senha@123`) — write-only |
| `roles` | [String] | `["CLIENTE"]` |
| `ativo` | Bool | soft delete: `false` = desativado |

### 4.2 Veículo

Fonte: `DadosVeiculoResponse`, `CadastrarVeiculoRequest`, `AtualizarVeiculoRequest`.

| Campo | Tipo | Regra |
|---|---|---|
| `id` | UUID | |
| `placa` | String | formato brasileiro (antigo `ABC1D23` / Mercosul); validado no backend |
| `marca` | String | |
| `modelo` | String | |
| `ano` | Int | `>= 1886` |
| `proprietarioId` | UUID | = `id` do cliente autenticado |
| `urlImagem` | String? | opcional; sugerida via Unsplash (ADR-007) |
| `codigoFipe` | String? | enriquecido via integração FIPE (ADR-006) |

### 4.3 Ordem de Serviço

Fonte: `OrdemServicoResponse`, `ResumoOrdemServicoResponse`, `OrdemServicoRequest`.

| Campo | Tipo | Observação para o Cliente |
|---|---|---|
| `id` | UUID | |
| `motivo` | String | Descrição do problema relatado pelo cliente |
| `observacao` | String? | Observação adicional |
| `clienteId` | UUID | = cliente autenticado |
| `mecanicoId` | UUID? | Mecânico responsável (pode ser nulo até atribuição — ver §9 conflito C4) |
| `veiculoId` | UUID | |
| `status` | Enum | Ver §5 |
| `dataCriacao` | DateTime | |
| `dataAtualizacao` | DateTime | |
| `itensServico[]` | Array | `{id, servicoId, valor, feito, mecanicoResponsavelId, dataRealizacao, observacao}` — somente leitura no app |
| `insumos[]` | [UUID] | IDs de insumos (repetidos por quantidade) — somente leitura |
| `orcamento` | Objeto? | `{id, custoMaoDeObra, custoInsumos, valorTotal, aprovado, observacao, dataCriacao, dataAtualizacao}` |

### 4.4 Orçamento (embutido na OS)

Só existe a partir de `AGUARDANDO_APROVACAO`. Campos monetários são `double` (BRL). O app **exibe**
o orçamento; nunca o cria/edita (isso é do mecânico).

### 4.5 Notificação

Fonte: `NotificacaoResponse`.

| Campo | Tipo | Valores |
|---|---|---|
| `id` | UUID | |
| `titulo` | String | |
| `assunto` | String | |
| `descricao` | String | |
| `tipoNotificacao` | Enum | `EMAIL` |
| `tipoConteudo` | Enum | `MUDANCA_STATUS_OS` (e correlatos como `SOLICITACAO_APROVACAO_ORCAMENTO_OS`, `DECISAO_ORCAMENTO_OS` — ADR-014) |
| `statusEnvio` | Enum | `PENDENTE`, `ENVIADA`, `FALHA_ENVIO` |
| `visualizada` | Bool | |
| `dataCriacao` / `dataEnvio?` / `dataVisualizacao?` | DateTime | |

### 4.6 Catálogo

`CatalogoServicoResponse {id, nomeServico, descricaoServico}` e
`CatalogoInsumoResponse {id, nome, descricao}` — somente leitura para o cliente.

---

## 5. Máquina de estados da Ordem de Serviço

Fonte de verdade: `domain/ordemServico/StatusOrdemServicoEnum.kt` e
`vo/StatusOrdemServico.kt` (método `podeTransitarPara`). Esta é a referência canônica que resolve
as inconsistências de enums nos schemas do dashboard (§9, conflito C1).

### 5.1 Estados canônicos

| Enum | `ordem` | Rótulo PT | Cor de origem (backend) | Semântica p/ cliente |
|---|---|---|---|---|
| `RECEBIDA` | 1 | Recebida | `#4ECDC4` | OS aberta, aguardando a oficina iniciar diagnóstico |
| `EM_DIAGNOSTICO` | 2 | Em Diagnóstico | `#FFE66D` | Mecânico avaliando o veículo |
| `AGUARDANDO_APROVACAO` | 3 | Aguardando Aprovação | `#95E1D3` | **Ação do cliente:** aprovar/reprovar orçamento |
| `EM_EXECUCAO` | 4 | Em Execução | `#6BCB77` | Serviços sendo realizados |
| `FINALIZADA` | 5 | Finalizada | `#4D96FF` | Serviço concluído, aguardando retirada |
| `ENTREGUE` | 6 | Entregue | `#2D3436` | Veículo entregue ao cliente |
| `CANCELADA` | 0 | Cancelada | `#FF6B6B` | OS cancelada |

> As cores de origem servem apenas de referência semântica. O Design System **redefine** a paleta
> de status (§13.3) para coerência com a identidade visual premium — não use os hex acima cru na UI.

### 5.2 Transições válidas (state machine do backend)

```
RECEBIDA              → EM_DIAGNOSTICO | CANCELADA
EM_DIAGNOSTICO        → AGUARDANDO_APROVACAO | CANCELADA
AGUARDANDO_APROVACAO  → EM_EXECUCAO | CANCELADA
EM_EXECUCAO           → FINALIZADA | CANCELADA
FINALIZADA            → ENTREGUE
ENTREGUE              → (terminal)
CANCELADA             → (terminal)
```

### 5.3 Ações do Cliente por estado (o que o app permite)

| Estado | Ação do cliente disponível no app | Endpoint |
|---|---|---|
| `RECEBIDA` | Acompanhar; **Cancelar** | cancelamento |
| `EM_DIAGNOSTICO` | Acompanhar; **Cancelar** | cancelamento |
| `AGUARDANDO_APROVACAO` | **Aprovar** ou **Reprovar** orçamento; **Cancelar** | aprovação / reprovação / cancelamento |
| `EM_EXECUCAO` | Acompanhar; **Cancelar** | cancelamento |
| `FINALIZADA` | Acompanhar (aguardar entrega). **Sem cancelar** (transição inválida) | — |
| `ENTREGUE` | Somente histórico | — |
| `CANCELADA` | Somente histórico | — |

> O app **habilita botões conforme o estado**. Aprovar/reprovar só aparecem em
> `AGUARDANDO_APROVACAO`. Cancelar não aparece em `FINALIZADA`/`ENTREGUE`/`CANCELADA` (evitar erro
> 409/estado inválido). Ver §9, conflito C3 (SRS diz "qualquer status → cancelada", mas o código
> restringe — o código prevalece).

### 5.4 Timeline visual

O detalhe da OS renderiza a jornada como uma **timeline vertical premium** (não uma `List`): nós
concluídos, nó atual pulsante, nós futuros esmaecidos; ramo `CANCELADA` mostrado como desvio
vermelho. Ver §15.6.

---

## 6. Regras de negócio consolidadas

Numeradas para citação em código (`// RN-07`) e testes.

- **RN-01 (abertura simples do cliente):** o cliente abre OS informando `motivo` + `veiculoId` (e
  observação opcional). A OS nasce em `RECEBIDA`. O cliente **não** informa serviços/insumos/
  orçamento. Fonte: SRS RF03, README §"Abertura de OS".
- **RN-02 (posse de dados):** o cliente só acessa/edita seus próprios recursos. `GET /ordem-servico`
  filtra automaticamente pelo cliente do token; `GET /dashboard/clientes/{id}` exige `id == sub` do
  token (403 caso contrário). O app **nunca** confia em IDs de outros clientes.
- **RN-03 (orçamento gerado pelo mecânico):** o orçamento é gerado pelo mecânico após diagnóstico;
  o cliente apenas o visualiza e decide. `valorTotal = custoMaoDeObra + custoInsumos`. Fonte: RF06.
- **RN-04 (autorização):** sem aprovação, a OS não vai para execução. Aprovar → `EM_EXECUCAO`;
  reprovar (com motivo obrigatório) mantém fora de execução e **repõe estoque de insumos** no
  backend (ADR-014). Uso único garantido pela transição de estado. Fonte: RF07.
- **RN-05 (reprovação exige motivo):** `ReprovarOrcamentoRequest.motivo` é obrigatório (`minLength 1`).
- **RN-06 (cancelamento):** cliente pode cancelar de `RECEBIDA`, `EM_DIAGNOSTICO`,
  `AGUARDANDO_APROVACAO`, `EM_EXECUCAO`. Motivo é opcional (`CancelarOsRequest.motivo`). Não é
  possível cancelar OS `FINALIZADA`/`ENTREGUE`/`CANCELADA`.
- **RN-07 (magic link é canal alternativo, não do app):** aprovar/reprovar por e-mail (magic link,
  ADR-014) é um canal paralelo com token dedicado e página HTML. O **app usa os endpoints
  autenticados** (`aprovarOrcamento`/`reprovarOrcamento`). Como o mesmo `DecididorOrcamento` serve
  os dois canais, **uma OS pode mudar de estado fora do app** (cliente clicou no e-mail). O app deve
  tratar 409/estado inválido graciosamente e revalidar o estado (§12).
- **RN-08 (soft delete):** desativar cliente/veículo é soft delete (`ativo=false`), não exclusão
  física. Auditável.
- **RN-09 (auditoria):** toda mudança de status, aprovação, cancelamento e ação de usuário é
  auditada no backend (SRS §7.6). O app não gerencia auditoria, mas **não deve** duplicar ações
  (evitar toques repetidos → idempotência via UI e revalidação).
- **RN-10 (notificações):** cada mudança de status gera evento/notificação (RF09, ADR-009 outbox
  ADR-010). O `tipoNotificacao` atual é `EMAIL`. O app consome a lista de notificações persistidas
  (não é push nativo APNs no MVP — ver §17.4 evolução).
- **RN-11 (enriquecimento de veículo):** ao cadastrar veículo, o backend pode enriquecer com FIPE
  (`codigoFipe`) e o cliente pode escolher imagem via sugestões Unsplash. Ambos são **best-effort**
  (fault tolerance ADR-012): a criação do veículo não falha se as integrações externas caírem.
- **RN-12 (validações de entrada):** CPF/CNPJ e placa são validados (CASE §"Segurança e qualidade").
  O app valida **no cliente** para UX imediata, mas o backend é a autoridade final.

---

## 7. Contrato da API para o Cliente

### 7.1 Base

| Item | Valor |
|---|---|
| Base URL (dev/local) | `http://localhost:8080` |
| Base URL (prod) | configurável (`SERVICETRACK_API_BASE_URL`, LoadBalancer — ADR-014) |
| Formato | JSON (`application/json`) |
| Auth | `Authorization: Bearer <JWT>` em todos os endpoints exceto `POST /clientes` e `POST /autenticacao/login` |
| Docs vivas | `GET /q/swagger-ui`, contratos em `software/service-track-api/openApi/` |
| Contract-first | Sim (SRS §5). O app deve **gerar/derivar seus modelos do OpenAPI** para não divergir. |

### 7.2 Convenções

- **Datas:** ISO-8601. Boa parte usa `date-time` sem timezone (`2024-06-01T14:30:00`); o dashboard
  usa sufixo `Z`. O app deve parsear **ambos** (parser tolerante, §11.4) e assumir horário do
  servidor quando não houver offset. Conflito documentado em §9 (C5).
- **Paginação:** query `page` (0-based, default 0) e `size` (default 20, min 1, max 100). Respostas
  paginadas usam envelope `{content[], page, size, total, totalPages}` (ver `PageOrdemServicoResponse`,
  `PageNotificacaoResponse`).
- **snake_case vs camelCase:** o **dashboard** responde em `snake_case`
  (`ordens_ativas`, `veiculo_placa`, `total_gasto`, …). O restante usa camelCase. O app mapeia
  explicitamente por endpoint (§9 C2).
- **Erros:** envelope `ErroResponse` — ver §22.1.

### 7.3 Endpoints — Autenticação

| Método | Caminho | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/autenticacao/login` | pública · rate-limit 20/min | `LoginRequest {email, senha}` | `LoginResponse {token, usuarioId, nome, email, roles[]}` |
| POST | `/autenticacao/reset-senha` | CLIENTE/MECANICO · rate-limit 5/min | `ResetarSenhaRequest {senhaAtual, novaSenha, confirmacaoNovaSenha}` | 204 |

> `reset-senha` é **troca de senha autenticada** (exige senha atual), não recuperação. Ver §9 C6.

### 7.4 Endpoints — Cliente/Perfil

| Método | Caminho | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/clientes` | pública · rate-limit 10/min | `CadastrarClienteRequest` | 201 + `ClienteResponse` (Location `/clientes/{id}`) |
| GET | `/clientes/{id}` | CLIENTE/MECANICO | — | `ClienteResponse` |
| PUT | `/clientes/{id}` | CLIENTE/MECANICO | `AtualizarClienteRequest {nome, email, telefone}` | `ClienteResponse` |
| DELETE | `/clientes/{id}` | CLIENTE/MECANICO | — | 204 (soft delete) |

### 7.5 Endpoints — Veículos

| Método | Caminho | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/veiculos` | CLIENTE/MECANICO · timeout 15s · bulkhead 10 | `CadastrarVeiculoRequest` | 201 + `DadosVeiculoResponse` |
| GET | `/veiculos` | CLIENTE/MECANICO | — | `[DadosVeiculoResponse]` (do cliente autenticado) |
| GET | `/veiculos/{id}` | CLIENTE/MECANICO | — | `DadosVeiculoResponse` |
| PUT | `/veiculos/{id}` | CLIENTE/MECANICO | `AtualizarVeiculoRequest` | `DadosVeiculoResponse` |
| DELETE | `/veiculos/{id}` | CLIENTE/MECANICO | — | 204 (soft delete) |
| GET | `/veiculos/imagens/sugestoes?marca&modelo` | CLIENTE/MECANICO · timeout 12s · bulkhead 5 | query | `SugestoesImagensResponse {imagens[]}` |

### 7.6 Endpoints — Ordens de Serviço (Cliente)

| Método | Caminho | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/ordem-servico` | CLIENTE/MECANICO · timeout 5s | `OrdemServicoRequest {motivo, clienteId, mecanicoId, veiculoId, observacao?}` | 201 + `OrdemServicoResponse` |
| GET | `/ordem-servico?status&page&size` | CLIENTE/MECANICO · bulkhead 15 | query (`clienteId`/`mecanicoId` ignorados p/ cliente) | `PageOrdemServicoResponse` |
| GET | `/ordem-servico/{id}` | CLIENTE/MECANICO · timeout 2s | — | `OrdemServicoResponse` |
| PATCH | `/ordem-servico/{id}/orcamento/aprovacao` | **CLIENTE** · timeout 5s | — | `OrdemServicoResponse` |
| PATCH | `/ordem-servico/{id}/orcamento/reprovacao` | **CLIENTE** · timeout 5s | `ReprovarOrcamentoRequest {motivo}` | `OrdemServicoResponse` |
| POST/PATCH | `/ordem-servico/{id}/cancelamento` | **CLIENTE** · timeout 5s | `CancelarOsRequest {motivo?}` | `OrdemServicoResponse` |

> Verbos/caminhos exatos de aprovação/reprovação/cancelamento derivam dos arquivos
> `openApi/ordemServico/ordemServico_orcamento_aprovacao.yaml`,
> `..._reprovacao.yaml`, `..._cancelamento.yaml`. **Gerar o cliente HTTP a partir do OpenAPI**
> garante método/caminho corretos; não hardcode divergente.

### 7.7 Endpoint — Dashboard

| Método | Caminho | Auth | Response |
|---|---|---|---|
| GET | `/dashboard/clientes/{id}` | **CLIENTE** · timeout 10s · bulkhead 10 | Dashboard agregado (snake_case) |

Estrutura da resposta (dashboard):

```jsonc
{
  "usuario_id": "uuid",
  "usuario_nome": "João Silva",
  "resumo": { "ordens_ativas": 3, "ordens_concluidas": 12, "ordens_canceladas": 1,
              "total_ordens": 16, "veiculos_cadastrados": 3 },
  "ordens_ativas":   [ { "id","motivo","status","veiculo_id","veiculo_placa","veiculo_modelo",
                         "mecanico_id","mecanico_nome","data_criacao","data_atualizacao",
                         "dias_em_andamento","valor_orcado","prazo_conclusao" } ],
  "ordens_recentes": [ { "id","motivo","status","veiculo_id","veiculo_placa","veiculo_modelo",
                         "data_criacao","data_conclusao","dias_para_conclusao","valor_total",
                         "mecanico_nome" } ],
  "veiculos":        [ { "id","placa","marca","modelo","ano","imagem_url","codigo_fipe","ativo",
                         "total_ordens","total_gasto","data_criacao" } ],
  "data_atualizacao": "2024-11-16T15:45:30Z"
}
```

O `id` do path deve ser o `usuarioId` do login. `ordens_ativas` (por descrição do schema) agrega
`RECEBIDA, EM_DIAGNOSTICO, AGUARDANDO_APROVACAO, EM_EXECUCAO, ENTREGUE` — ver §9 C7 (ENTREGUE em
"ativas" é semanticamente estranho; app trata ENTREGUE como concluída na UI).

### 7.8 Endpoints — Notificações

| Método | Caminho | Auth | Response |
|---|---|---|---|
| GET | `/notificacoes?visualizada&page&size` | CLIENTE/MECANICO | `PageNotificacaoResponse` |
| GET | `/notificacoes/{id}` | CLIENTE/MECANICO | `NotificacaoResponse` |
| GET | `/notificacoes/nao-lidas/contagem` | CLIENTE/MECANICO | `ContadorNaoLidasResponse {total}` |
| PATCH | `/notificacoes/{id}/visualizar` | CLIENTE/MECANICO | 204 |

### 7.9 Endpoints — Catálogo (consulta)

| Método | Caminho | Auth | Response |
|---|---|---|---|
| GET | `/catalogo/servicos` | CLIENTE/MECANICO | `[CatalogoServicoResponse]` |
| GET | `/catalogo/insumos` | CLIENTE/MECANICO | `[CatalogoInsumoResponse]` |

---

## 8. Autenticação, autorização e segurança

### 8.1 Modelo de token (JWT RS256 — ADR-005, `JwtAdapter.kt`)

- Assinatura **RS256** (chave privada assina no backend, pública valida). O app **não valida
  assinatura** (não tem a chave); trata o token como opaco.
- Claims: `iss=service-track-api`, `sub=<usuarioId>`, `upn=<email>`, `groups=[roles]`,
  `exp = now + 8h` (config `servicetrack.jwt.expiracao-horas`, default 8).
- **Não há refresh token** (ADR-005 §Consequências). Expiração de sessão = re-login.

### 8.2 Fluxo de sessão no app

1. `POST /login` → guarda `token`, `usuarioId`, `nome`, `email`, `roles`.
2. **Persistir o token no Keychain** (item `kSecClassGenericPassword`, `WhenUnlockedThisDeviceOnly`),
   nunca em `UserDefaults`.
3. Injetar `Authorization: Bearer <token>` em todas as chamadas autenticadas.
4. **Gate de role:** se `roles` não contém `CLIENTE`, bloquear login com mensagem "Este app é
   exclusivo para clientes" (um mecânico não deve usar o app do cliente).
5. **Expiração:** decodificar o `exp` localmente (parse do payload base64, sem validar assinatura)
   para exibir aviso proativo e, ao receber **401**, limpar sessão e enviar ao Login preservando
   deep-link de retorno.
6. **Logout:** apagar item do Keychain + limpar cache sensível.

### 8.3 Autorização no cliente

- O app **espelha** as regras do backend para UX, mas o backend é a autoridade: aprovar/reprovar/
  cancelar são `@RolesAllowed("CLIENTE")`; dashboard exige posse (`id==sub`).
- Nunca exibir dados/ações de outro cliente. Todo `id` usado em path vem do `usuarioId` da sessão.

### 8.4 Segurança de aplicação (iOS)

- **Keychain** para token e quaisquer segredos. Biometria (Face ID/Touch ID) opcional para
  desbloquear sessão persistida (`LAContext`).
- **ATS on** (TLS obrigatório em prod). Em dev local (`http://localhost`) usar exceção restrita só
  para o esquema de debug.
- **Certificate pinning** recomendado em prod (pin da CA do LoadBalancer) — configurável; degrada
  para validação padrão se o pin não estiver disponível.
- **No-store** de dados sensíveis em logs/analytics (sem token, sem senha, sem CPF em claro nos
  eventos — §17.3).
- **Proteção de tela:** ocultar conteúdo sensível no app switcher (overlay em `scenePhase == .inactive`).
- **Rate-limit awareness:** login (20/min), cadastro (10/min), reset senha (5/min) — o app respeita
  com backoff visível (§12.3) para não estourar 429.

---

## 9. Conflitos identificados

Conflitos entre documentos, com resolução arquitetural. **O código de domínio prevalece** sobre a
prosa do SRS quando divergem (o domínio é executável e testado).

- **C1 — Enums de status divergentes.** `OrdensRecentesDashboardResponse` lista
  `DIAGNOSTICO, ORCAMENTO_GERADO, APROVADO` e o exemplo do dashboard usa `status: 'APROVADO'`,
  enquanto o enum canônico (`StatusOrdemServicoEnum`) é
  `RECEBIDA, EM_DIAGNOSTICO, AGUARDANDO_APROVACAO, EM_EXECUCAO, FINALIZADA, ENTREGUE, CANCELADA`.
  **Resolução:** o app decodifica status com um enum **tolerante** que mapeia sinônimos legados
  (`DIAGNOSTICO→EM_DIAGNOSTICO`, `ORCAMENTO_GERADO→AGUARDANDO_APROVACAO`, `APROVADO→EM_EXECUCAO`)
  para os 7 estados canônicos; valores desconhecidos caem em `.desconhecido` com UI neutra. Abrir
  issue no backend para padronizar os schemas do dashboard.
- **C2 — snake_case só no dashboard.** Todos os outros contratos usam camelCase. **Resolução:**
  DTOs de dashboard com `CodingKeys` próprios; não aplicar `.convertFromSnakeCase` global (quebraria
  os demais). Isolar em módulo `Dashboard`.
- **C3 — Cancelamento "qualquer status".** SRS RF04 diz "Qualquer status → Cancelada", mas
  `podeTransitarPara` só permite cancelar de RECEBIDA/EM_DIAGNOSTICO/AGUARDANDO_APROVACAO/EM_EXECUCAO.
  **Resolução:** seguir o domínio; o app só oferece "Cancelar" nesses 4 estados.
- **C4 — `mecanicoId` obrigatório na abertura simples.** `OrdemServicoRequest` marca `mecanicoId`
  como `required`, mas a regra de negócio diz que o cliente **não** escolhe mecânico (o cliente nem
  sabe quem é). **Resolução proposta (a validar com backend):** tornar `mecanicoId` opcional para o
  fluxo do cliente e deixar a atribuição a cargo da oficina; enquanto o contrato exigir, o app não
  tem como preencher corretamente. **Ação:** confirmar com o time backend se `POST /ordem-servico`
  aceita `mecanicoId` nulo/omitido quando o solicitante é CLIENTE. Registrar como bloqueio de
  integração da tela "Nova OS" até resolução. (Não inventar um mecânico no cliente.)
- **C5 — Formato de data inconsistente.** camelCase endpoints usam `date-time` sem `Z`; dashboard
  usa `Z`. **Resolução:** parser de data tolerante (tenta ISO com offset, depois sem offset
  assumindo TZ do servidor). §11.4.
- **C6 — Não existe recuperação de senha pública.** Só há troca autenticada (`reset-senha`).
  **Resolução:** o onboarding **não** oferece "Esqueci minha senha" ligado à API (não existe
  endpoint). Exibir orientação "entre em contato com a oficina" ou marcar como evolução futura
  (endpoint de recuperação por e-mail). Não simular um fluxo inexistente.
- **C7 — `ENTREGUE` contado como "ordem ativa".** A descrição de `resumo.ordens_ativas` inclui
  `ENTREGUE`. **Resolução visual:** no app, ENTREGUE é tratada como **concluída** (histórico), mas o
  card de resumo respeita o número que o backend envia (fonte única). Explicar na UI via rótulo
  "em andamento" alinhado ao que o backend agrega, sem recalcular no cliente.
- **C8 — Token de login de exemplo "mock".** `LoginResponse.token` exemplifica `"mock-jwt-token-"`;
  a implementação real assina RS256. **Resolução:** tratar `token` como JWT real; nunca depender do
  exemplo.

---

## 10. Arquitetura do aplicativo iOS

### 10.1 Princípios

Espelhar a disciplina do backend (hexagonal, dependências apontando para o domínio) no cliente,
adaptada ao SwiftUI moderno. Metas: testabilidade alta, camadas isoladas, UI declarativa premium,
navegação por estado, concorrência estruturada (async/await, `@MainActor` onde toca UI).

### 10.2 Estilo arquitetural

**MV + Clean modular (feature-based), unidirecional**:

```
┌───────────────────────────────────────────────────────────┐
│ Presentation (SwiftUI Views + @Observable Store por feature)│  <- estado unidirecional
├───────────────────────────────────────────────────────────┤
│ Domain (Use Cases, Entities, State Machine, Regras RN-xx)  │  <- puro, sem UIKit/Foundation-net
├───────────────────────────────────────────────────────────┤
│ Data (Repositories, DTOs, Mappers, APIClient, Cache)       │  <- implementa ports do Domain
├───────────────────────────────────────────────────────────┤
│ Infrastructure (Networking, Keychain, Persistence, Telemetry)│
└───────────────────────────────────────────────────────────┘
```

- **Domain** define *protocols* (ports) — ex.: `OrdemServicoRepository`, `AuthRepository`. **Data**
  os implementa (adapters). Inversão de dependência idêntica ao backend (`ports.in`/`ports.out`).
- **Store** por feature: classe `@Observable` (`Observation` framework, iOS 17), expõe `state` +
  `send(_ action:)`. Sem two-way binding disperso; mutação centralizada.
- **Navegação:** `NavigationStack` dirigido por `enum Route` + um `Router`/`Coordinator` por aba;
  deep-links resolvidos para `Route`.
- **DI:** container leve (composição na `App`), protocolos injetados por inicializador; previews e
  testes usam fakes.

> **Justificativa (requisito "atualize a arquitetura, justifique tecnicamente"):** MV com
> `@Observable` reduz boilerplate frente a MVVM clássico e evita `ObservableObject`/`@Published`
> pesados; o fluxo unidirecional (state+action) dá previsibilidade tipo TCA sem o custo de adotar a
> lib inteira. Feature-modularização (SPM) permite build incremental e times paralelos, adequado a
> "app de grande porte".

### 10.3 Modularização (Swift Package Manager)

Cada feature e cada camada transversal é um pacote local:

```
Packages/
  Core/            DesignSystem, Localization, Analytics, Logging, Utilities
  Networking/      APIClient, Interceptors, Auth, ErrorMapping
  Persistence/     Keychain, Cache (SQLite/GRDB ou SwiftData), Migrations
  Domain/          Entities, StateMachine, UseCases, RepositoryProtocols
  Data/            Repositories, DTOs, Mappers (gerados do OpenAPI)
  Features/
    Auth/  Onboarding/  Dashboard/  OrdensServico/  Veiculos/
    Notificacoes/  Perfil/  Catalogo/
  App/             Composition root, Router, TabBar, DI
```

### 10.4 Concorrência

- `async/await` em toda a borda de rede/persistência; `Task` cancelável atrelado ao ciclo de vida da
  view (`.task {}`).
- `@MainActor` nos Stores que publicam estado de UI; repositórios em executores de fundo.
- **Structured concurrency** para agregações (dashboard busca em paralelo quando aplicável).

---

## 11. Camada de rede, cache, sincronização e offline

### 11.1 APIClient

- Cliente HTTP baseado em `URLSession` com `async` + `Codable`. **Modelos derivados do OpenAPI**
  (geração via ferramenta contract-first) para não divergir do backend.
- **Interceptors** encadeados: (1) Auth (injeta Bearer), (2) Telemetry (trace-id, timing),
  (3) Retry/backoff, (4) ErrorMapper (HTTP → `AppError`).
- **Trace-id por request** (`X-Request-Id` UUID) para correlacionar com logs do backend (§17).

### 11.2 Estratégia de cache

Objetivo: app rápido e utilizável mesmo com rede instável (RNF SRS §7 — resposta ≤ 2s percebida).

| Dado | Política | TTL sugerido | Invalida quando |
|---|---|---|---|
| Dashboard | stale-while-revalidate | 60s | pull-to-refresh, retorno ao foreground, ação em OS |
| Lista de OS | SWR + paginação em disco | 120s | nova OS, aprovação/reprovação/cancelamento |
| Detalhe de OS | SWR | 30s | ação na própria OS, push/notif de status |
| Veículos | cache-first | 10min | CRUD de veículo |
| Catálogo | cache-first (quase estático) | 24h | manual |
| Notificações | SWR + contador separado | 60s | marcar lida, nova notificação |
| Perfil | cache-first | sessão | edição de perfil |

Implementação: camada `Cache` (SwiftData ou GRDB) com registros `{key, payload, etag?, fetchedAt}`.
Repositórios expõem `stream` que emite **cache primeiro** e depois **rede** (dois quadros → UI sem
skeleton em revisita).

### 11.3 Sincronização e offline

- **Leitura offline:** dashboard, OS (lista+detalhe), veículos e notificações visíveis a partir do
  cache; banner sutil "Offline — mostrando dados salvos".
- **Ações offline (mutações):** aprovar/reprovar/cancelar/abrir OS **não** são enfileiradas
  cegamente (risco de estado inválido, RN-07). Em vez disso: **outbox otimista com confirmação** —
  a ação é aplicada visualmente como "pendente" e só efetivada quando há rede; se o servidor
  responder 409 (estado mudou), reconciliar e informar. Para o MVP, ações que exigem rede exibem
  estado desabilitado + CTA "Reconectar" se offline (evita divergência com backend que não expõe
  idempotency-key). Documentar outbox como evolução (§21).
- **Revalidação em foreground:** ao voltar ao app, revalidar dashboard + contador de não lidas.

### 11.4 Parsing tolerante

- **Datas:** decoder que tenta, em ordem: ISO8601 com fração+offset → ISO8601 sem offset (assume
  TZ do servidor) → `yyyy-MM-dd`. (Resolve C5.)
- **Status:** enum tolerante com mapeamento de sinônimos legados (C1) + caso `.desconhecido`.
- **Decodificação defensiva:** campos opcionais nunca quebram a tela; erros de parsing viram
  `AppError.decoding` logado, não crash.

---

## 12. Tratamento de falhas e resiliência no cliente

O backend usa fault tolerance (ADR-012: Timeout, Bulkhead, RateLimit). O app espelha com UX clara.

### 12.1 Mapa HTTP → `AppError` → UX

| HTTP | `AppError` | UX |
|---|---|---|
| 400 | `.validacao(campo?, msg)` | erro inline no campo / toast |
| 401 | `.naoAutenticado` | limpar sessão → Login (preserva rota de retorno) |
| 403 | `.semPermissao` | tela "acesso negado" (não deveria ocorrer no fluxo cliente) |
| 404 | `.naoEncontrado` | Empty State específico |
| 409 | `.conflitoEstado` | revalidar recurso, mostrar estado atual, explicar (RN-07) |
| 422/regra | `.regraNegocio(msg)` | mensagem amigável derivada de `ErroResponse.mensagem` |
| 429 | `.rateLimited(retryAfter?)` | backoff visível, desabilita CTA com contador |
| 5xx | `.servidor` | retry com backoff + Empty/Error State ilustrado |
| timeout/offline | `.rede` | banner offline + retry |

### 12.2 Retry/backoff

- Idempotentes (GET): retry automático até 2x com backoff exponencial (250ms, 1s) + jitter.
- Não idempotentes (POST/PATCH de ação): **sem retry automático**; oferecer retry manual explícito
  para evitar dupla execução (RN-09).

### 12.3 Rate limit

Respeitar `Retry-After` quando presente; senão backoff local alinhado às janelas do backend (login
20/min, cadastro 10/min, reset 5/min). CTA mostra "Tente novamente em N s".

### 12.4 Estados de tela

Cada tela define explicitamente: **loading (skeleton)**, **conteúdo**, **vazio (empty state
ilustrado)**, **erro (ilustrado + retry)**, **offline**. Nunca spinner solto sobre tela branca.

---

## 13. Design System

Identidade visual **própria**, premium, consistente. Tokens versionados em `Core/DesignSystem`.
HIG só como base de comportamento/ergonomia/navegação — não de aparência.

### 13.1 Conceito visual

**"Oficina de confiança, engenharia de precisão."** Estética escura-primária opcional + clara,
superfícies com profundidade sutil (glass/blur em headers), acento vibrante de marca, tipografia
forte, dados como protagonistas (números grandes, gráficos limpos). Nada de listas cinza padrão.

### 13.2 Cores — tokens semânticos

Tokens **semânticos** (não literais) com suporte a light/dark e alto contraste. Valores base
(ajustáveis por brand):

```
brand/primary        #2F6BFF   (azul-elétrico de marca)
brand/primaryStrong  #1B4DDB
brand/onPrimary      #FFFFFF
accent/spark         #00D3A7   (verde-menta de destaque)

bg/canvas            light #F6F7FB  dark #0B0D12
bg/surface           light #FFFFFF  dark #14171F
bg/surfaceElevated   light #FFFFFF  dark #1B1F2A
bg/scrim             rgba(0,0,0,.45)

text/primary         light #0B0D12  dark #F4F6FB
text/secondary       light #5B6270  dark #A6ADBB
text/tertiary        light #8A909C  dark #6E7686
border/subtle        light #E7E9F0  dark #232838

feedback/success     #16A36B
feedback/warning     #E4A11B
feedback/danger      #E5484D
feedback/info        #2F6BFF
```

**Cores de status da OS (redefinidas para a identidade — substituem os hex do backend):**

```
status/recebida            #6C7BFF  (índigo)
status/emDiagnostico       #E4A11B  (âmbar)
status/aguardandoAprovacao #00B4D8  (ciano — pede ação)
status/emExecucao          #16A36B  (verde)
status/finalizada          #2F6BFF  (azul marca)
status/entregue            #7A8194  (grafite — concluído)
status/cancelada           #E5484D  (vermelho)
```

Cada status tem par `{cor, corSuave(fundo 12% alpha), ícone SF Symbol semanticamente escolhido}`.

### 13.3 Tipografia

Fonte de marca com fallback ao sistema (ex.: **"SF Pro"** ajustada ou fonte custom licenciada tipo
Inter/Söhne). Escala tipográfica (Dynamic Type-ready, todas escalam):

```
display   34/40 bold      (saldos, números-herói do dashboard)
title1    28/34 bold
title2    22/28 semibold
title3    18/24 semibold
headline  17/22 semibold
body      17/24 regular
callout   16/22 regular
subhead   15/20 medium
footnote  13/18 regular
caption   12/16 medium
mono      15/20 (valores monetários alinhados — variante tabular)
```

Números monetários usam **tabular figures** para alinhamento em listas/dashboards.

### 13.4 Espaçamento e grid

Escala 4pt: `2, 4, 8, 12, 16, 20, 24, 32, 40, 56, 72`. Margem de tela padrão `20`. Grid de conteúdo
de 1 coluna com gutters `16`; cards podem compor grid 2-col em telas maiores. Toque mínimo 44×44pt.

### 13.5 Raio, bordas, sombras, elevação

```
radius/sm 10   radius/md 16   radius/lg 22   radius/pill 999
border padrão 1px border/subtle
elevação:
  e0 flat (sem sombra) — itens em superfície
  e1 card:  y2 blur8  alpha .06
  e2 sheet: y8 blur24 alpha .12
  e3 popover/menu: y16 blur40 alpha .18
```

Modo escuro usa **elevação por luminosidade** (superfícies mais claras) em vez de sombras fortes.

### 13.6 Iconografia

SF Symbols como base (consistência de peso/óptico), **mais** um conjunto custom de ilustrações de
marca para empty states, status heroes e onboarding. Ícones de status mapeados por estado.

### 13.7 Movimento e microinterações

- **Curvas:** `spring(response:0.4, dampingFraction:0.85)` para transições de tela; `easeOut 0.2s`
  para toques; `spring` mais solto para haptics de sucesso.
- **Transições:** push com parallax sutil; sheets customizados com detentes; hero transition entre
  card de OS (lista) → detalhe (matchedGeometryEffect).
- **Microinterações:** botão com "press scale" 0.97; contador de não lidas com bounce; barra de
  progresso de status animada; pull-to-refresh com animação de marca (não a padrão).
- **Feedback tátil (`SensoryFeedback`/CoreHaptics):** `.success` ao aprovar orçamento; `.warning`
  ao reprovar/cancelar; `.impact(soft)` em seleção; `.error` em falha.
- **Skeleton loading** com shimmer em todos os primeiros carregamentos.

### 13.8 Estados de componente

Todo componente define: `default / pressed / focused / disabled / loading / error / success`.
Foco visível (acessibilidade §16). Nenhum estado ausente.

### 13.9 Tokens como código

Expostos como `enum` Swift (`DSColor`, `DSFont`, `DSSpacing`, `DSRadius`, `DSShadow`, `DSMotion`) e,
opcionalmente, arquivo `tokens.json` fonte-única para gerar tema (facilita futura paridade com
Android/web). Um `Theme` `@Observable` alterna light/dark/alto-contraste.

---

## 14. Biblioteca de componentes

Componentes próprios (nunca `List`/`Form` crus). Cada um com preview, estados e acessibilidade.

- **STCard** — superfície base (radius/md, e1), variações: informativo, ação, status.
- **STStatusBadge** — pílula de status da OS (cor+ícone+rótulo), tamanhos sm/md.
- **STStatusTimeline** — timeline vertical premium da jornada da OS (§5.4).
- **STMetricTile / STStatCard** — número-herói + rótulo + ícone + variação (dashboard resumo).
- **STVehicleCard** — card do veículo com imagem (Unsplash), placa em "chip", marca/modelo/ano,
  micro-stats (nº ordens, total gasto).
- **STOrderRow / STOrderCard** — item de OS com veículo, motivo, status badge, valor, tempo.
- **STBudgetCard** — card de orçamento: mão de obra, insumos, total (mono tabular), CTA
  aprovar/reprovar; destaque quando `AGUARDANDO_APROVACAO`.
- **STPrimaryButton / STSecondaryButton / STDestructiveButton** — com loading e press-scale.
- **STBottomSheet** — sheet customizado com detentes, grabber próprio, blur de fundo.
- **STTextField** — campo com label flutuante, validação inline, máscaras (CPF, telefone, placa).
- **STSegmentedFilter** — filtro de status (não o `Picker` padrão), pill scrollável horizontal.
- **STEmptyState** — ilustração de marca + título + subtítulo + CTA (por contexto: sem OS, sem
  veículo, sem notificação, offline, erro).
- **STErrorState** — variante de erro com retry.
- **STSkeleton** — placeholders shimmer por tipo de tela.
- **STProgressBar / STRadialProgress** — progresso de status/execução elegante.
- **STNotificationRow** — linha de notificação com indicador de não lida, tipo e tempo relativo.
- **STAvatar / STHeaderBar** — header com blur, saudação, avatar, sino de notificações com contador.
- **STCurrencyText** — formatação BRL tabular, com/sem centavos, placeholder quando nulo.
- **STToast / STBanner** — feedback efêmero (sucesso/erro/offline).

Guideline para novas telas: **compor a partir desta biblioteca**; qualquer componente novo entra na
lib com tokens, estados, preview e teste de snapshot antes de uso em produção.

---

## 15. Telas e jornadas completas

Navegação raiz: **TabBar customizada** (não a padrão) com 4 abas — **Início (Dashboard)**,
**Ordens**, **Garagem**, **Notificações** — e **Perfil** acessível pelo header. Todas as telas
seguem o padrão de estados de §12.4.

### 15.1 Onboarding + Cadastro

**Jornada:** primeira abertura → carrossel de valor (3 telas ilustradas: "Acompanhe em tempo real",
"Aprove com um toque", "Sua garagem organizada") → **Criar conta** ou **Entrar**.

**Cadastro (`POST /clientes`):** formulário em passos (não um `Form` corrido) — (1) nome+email,
(2) CPF+telefone+data de nascimento, (3) senha com medidor de força. Máscaras e validação inline
(CPF válido, e-mail, senha ≥6). Sucesso → auto-login (chama `POST /login`) → Dashboard. Rate-limit
10/min tratado. Empty/erro ilustrados. Sem "esqueci a senha" (C6).

### 15.2 Login

Tela premium (fundo de marca, logo, campos STTextField). `POST /login` → valida role CLIENTE (§8.2),
guarda no Keychain, opção "manter conectado" + Face ID. Erros: credenciais inválidas (inline),
429 (backoff). Deep-link de retorno preservado.

### 15.3 Dashboard (Início) — `GET /dashboard/clientes/{id}`

**Não é uma lista.** Layout:

- **Header** com saudação ("Olá, {primeiro nome}"), avatar, sino com contador de não lidas.
- **Faixa de métricas (STMetricTile em scroll horizontal ou grid 2×2):** Ordens ativas, Concluídas,
  Canceladas, Veículos — números-herói com ícones. (Fonte: `resumo`.)
- **"Precisa da sua atenção":** se houver OS em `AGUARDANDO_APROVACAO`, card destacado (STBudgetCard
  compacto) com CTA aprovar/reprovar direto — atalho para a ação mais valiosa (RF07).
- **Ordens ativas** (carrossel de STOrderCard): status badge, veículo, dias em andamento, valor
  orçado se houver, prazo. Tap → detalhe (hero transition).
- **Seus veículos** (carrossel de STVehicleCard) com total gasto/ordens.
- **Atividade recente** (`ordens_recentes`): timeline compacta de concluídas.
- Pull-to-refresh de marca; SWR (§11.2). Skeleton no primeiro load; empty ilustrado se cliente novo
  (0 ordens/veículos) com CTA "Cadastrar meu veículo".

### 15.4 Ordens — Lista — `GET /ordem-servico`

- **STSegmentedFilter** por status (Todas / Ativas / Aguardando aprovação / Concluídas / Canceladas)
  — mapeado para o query `status` (uma ou várias chamadas; para "Ativas" pode filtrar client-side
  sobre página carregada respeitando paginação).
- Lista de **STOrderCard** com **paginação infinita** (`page`/`size`, envelope `PageOrdemServico`).
- Ordenação padrão por `dataAtualizacao` desc (client-side sobre a página; documentar que o backend
  não expõe sort — evolução).
- Empty states por filtro; skeleton; erro/offline.

### 15.5 Nova OS — `POST /ordem-servico`

**Fluxo (RN-01):** escolher veículo (da garagem) → descrever `motivo` → `observacao` opcional →
confirmar. **Não** há seleção de serviços/insumos/valor (regra de negócio). Sucesso → detalhe da OS
recém-criada (status RECEBIDA) com timeline. **Bloqueio conhecido:** contrato exige `mecanicoId`
(C4) — resolver com backend antes de habilitar; enquanto isso, feature-flag desliga a tela ou envia
conforme decisão acordada. Se o cliente não tiver veículo, redirecionar para cadastro de veículo.

### 15.6 OS — Detalhe / Timeline — `GET /ordem-servico/{id}`

Tela-assinatura do produto:

- **Hero header:** veículo (imagem), placa em chip, motivo, STStatusBadge grande.
- **STStatusTimeline vertical:** RECEBIDA → EM_DIAGNOSTICO → AGUARDANDO_APROVACAO → EM_EXECUCAO →
  FINALIZADA → ENTREGUE; nó atual pulsante; ramo CANCELADA como desvio. Datas em cada nó.
- **STBudgetCard** (quando há `orcamento`): mão de obra, insumos, total (mono). Se
  `AGUARDANDO_APROVACAO`: botões **Aprovar** (primary) e **Reprovar** (destructive).
- **Itens de serviço** (somente leitura): lista de `itensServico` com `feito` (check animado),
  valor, observação — como "checklist de execução" premium, não `List`.
- **Insumos**: contagem agregada por insumo (IDs → nomes via catálogo cacheado).
- **Ações contextuais** conforme estado (§5.3): Cancelar (bottom sheet com motivo opcional).
- Atualização: SWR 30s + refresh ao focar; após ação, refetch e animação de transição de status.

### 15.7 Aprovar / Reprovar orçamento (RF07, ADR-014)

- **Aprovar** (`PATCH .../orcamento/aprovacao`): confirmação em STBottomSheet ("Confirmar aprovação
  de R$ X?") → haptic `.success` → animação status → EM_EXECUCAO. Sem retry automático (RN-09).
- **Reprovar** (`PATCH .../orcamento/reprovacao`): sheet com **motivo obrigatório** (RN-05) →
  haptic `.warning`. Backend repõe estoque (informar "solicitação registrada").
- **Conflito 409** (cliente já decidiu por e-mail — RN-07): mensagem "Este orçamento já foi
  decidido" + refetch mostrando estado atual. Nunca crash, nunca dupla ação.

### 15.8 Garagem — Lista de veículos — `GET /veiculos`

Grid/carrossel de **STVehicleCard** com imagem, placa-chip, ano, micro-stats. CTA flutuante
"Adicionar veículo". Empty ilustrado. Tap → detalhe.

### 15.9 Detalhe do veículo

- Imagem grande (Unsplash), dados (marca/modelo/ano/placa/FIPE se houver).
- Estatísticas: total de ordens, total gasto (do dashboard/veículos).
- Histórico de OS desse veículo (filtro client-side por `veiculoId` sobre `GET /ordem-servico`) —
  RF08 histórico por veículo.
- Ações: **Editar** (`PUT`), **Remover** (`DELETE`, soft delete, confirmação destrutiva),
  **Nova OS para este veículo** (atalho para 15.5).

### 15.10 Cadastro/Edição de veículo — `POST`/`PUT /veiculos`, sugestões `GET /veiculos/imagens/sugestoes`

Passos: marca+modelo → **galeria de sugestões de imagem** (Unsplash, `imagens[]`) em grid selecionável
→ ano+placa (máscara/validação) → salvar. `proprietarioId` = cliente autenticado. Enriquecimento FIPE
é best-effort (RN-11): não bloquear salvar se a sugestão/FIPE falhar (banner discreto).

### 15.11 Notificações — `GET /notificacoes`, contagem, detalhe, visualizar

- Header com contador (`/nao-lidas/contagem`).
- **STSegmentedFilter** Todas / Não lidas (`visualizada=false`).
- Lista paginada de **STNotificationRow** (título, assunto, tempo relativo, indicador não lida).
- Tap → detalhe (descrição completa) e `PATCH /{id}/visualizar` (marca lida; decrementa contador
  otimista). Deep-link: notificação de status → detalhe da OS relacionada (quando o conteúdo
  permitir resolver o `osId`).
- Ação em massa "marcar todas como lidas" (itera visualizar) — opcional.
- Empty ilustrado; SWR 60s; revalida em foreground.

### 15.12 Perfil — `GET/PUT/DELETE /clientes/{id}`, `POST /reset-senha`

- Cabeçalho com avatar, nome, e-mail.
- **Editar dados** (`PUT`: nome, email, telefone) — CPF/data nascimento somente leitura (não
  editáveis pelo contrato).
- **Alterar senha** (`reset-senha`: senha atual + nova + confirmação, com medidor de força).
- **Preferências:** tema (claro/escuro/sistema/alto contraste), biometria, idioma.
- **Sessão:** sair (logout, limpa Keychain).
- **Desativar conta** (`DELETE`, soft delete): fluxo destrutivo com dupla confirmação e explicação.
- **Sobre/legal:** versão, termos, privacidade, contato da oficina (inclui orientação de recuperação
  de senha — C6).

### 15.13 Catálogo (contexto) — `GET /catalogo/servicos|insumos`

Tela informativa "Serviços oferecidos" (grid de STCard com nome+descrição) acessível a partir do
Perfil/Início — reforça confiança e contexto. Somente leitura. Cache 24h.

---

## 16. Acessibilidade

Requisito explícito: **acessibilidade completa, com foco em deficiência visual.** Meta: WCAG 2.2 AA.

- **VoiceOver:** todos os elementos com `accessibilityLabel`/`Value`/`Hint` significativos. Status da
  OS anunciado por extenso ("Aguardando sua aprovação"), não só cor. Timeline navegável por rotor.
  Ordem de foco lógica; agrupamento de cards com `.accessibilityElement(children:.combine)`.
- **Dynamic Type:** toda tipografia escala até tamanhos de acessibilidade (AX5); layouts reflow
  (sem truncamento crítico); nada com fonte fixa em pt.
- **Contraste:** todos os pares texto/fundo ≥ 4.5:1 (texto normal) e 3:1 (texto grande/ícones);
  tema **alto contraste** dedicado. Nunca comunicar **só por cor** — sempre cor + ícone + rótulo
  (status, sucesso/erro).
- **Toque:** alvos ≥ 44×44pt; espaçamento anti-toque-acidental em ações destrutivas.
- **Movimento:** respeitar `Reduce Motion` (desliga parallax/hero, usa fades); `Reduce Transparency`
  (troca blur por sólido).
- **Haptics + som:** feedback não exclusivamente visual em ações críticas (aprovar/reprovar).
- **Foco visível** para navegação por teclado/switch control.
- **Formulários:** erros associados ao campo (`accessibilityLabel` do erro), não só cor vermelha.
- **Imagens:** `urlImagem`/ilustrações com descrição; imagens decorativas marcadas como tal.
- **Testes:** auditoria com Accessibility Inspector + testes automatizados de contraste e de rótulos.

---

## 17. Observabilidade, telemetria e analytics

### 17.1 Logging

- Logger estruturado (`OSLog`/`Logger` por subsistema: `network`, `auth`, `ui`, `cache`). Níveis
  debug/info/error. **Sem PII** (sem token, senha, CPF em claro). `X-Request-Id` logado para
  correlação com backend.

### 17.2 Telemetria de app (performance)

- Métricas via **MetricKit**: launch time, hangs, energia, crashes. Sinais de rede: latência p/
  endpoint, taxa de erro, timeouts (espelhar limites do backend: OS detalhe 2s, dashboard 10s, etc.).
- Traços de tela: tempo até conteúdo interativo (TTI) por tela-chave (Dashboard, OS detalhe).

### 17.3 Analytics de produto

Eventos (nomeados, sem PII; IDs pseudonimizados). Núcleo:

```
app_open, login_success, login_fail(reason), signup_completed
dashboard_view, order_list_view(filter), order_detail_view(status)
budget_approve(os_id_hash, valor_faixa), budget_reject(os_id_hash, motivo_len)
order_create, order_cancel(status_origem)
vehicle_create, vehicle_edit, vehicle_delete
notification_open, notification_read, notifications_badge_seen
error_shown(type, http_status, endpoint), offline_banner_shown
```

Consentimento (ATT/privacidade) respeitado; analytics desativável nas preferências. Provedor
abstrato (`AnalyticsClient` protocolo) — sem lock-in.

### 17.4 Monitoramento e notificações (evolução)

- **MVP:** notificações são consumidas via `GET /notificacoes` (pull), pois `tipoNotificacao=EMAIL`
  e não há APNs no backend (RF09/ADR-009 outbox).
- **Evolução (§21):** push nativo (APNs) disparado pelo outbox de notificações do backend, com
  deep-link para a OS; badge do app sincronizado com `/nao-lidas/contagem`.

---

## 18. Requisitos não funcionais do app

Derivados/alinhados ao SRS §7.

| RNF | Alvo |
|---|---|
| Performance percebida | TTI ≤ 2s em rede boa; SWR para revisitas instantâneas (SRS ≤2s) |
| Cold start | < 1.5s até primeira tela útil |
| Resiliência | funcional offline para leitura; degrade gracioso das integrações externas (ADR-012) |
| Segurança | Keychain, ATS, no-PII em logs, biometria opcional, proteção de app switcher (SRS §7.2) |
| Disponibilidade | tolera 5xx/timeout do backend sem crash; retries idempotentes |
| Escalabilidade de código | modular SPM, feature teams paralelos |
| Manutenibilidade | cobertura de testes: Domain ≥90%, Data/Stores ≥80% (espelha SRS §7.5) |
| Acessibilidade | WCAG 2.2 AA (§16) |
| Internacionalização | pt-BR base; strings externalizadas para futura i18n; formatação de moeda/data por locale |
| Consumo | eficiência de rede via cache; imagens com downsampling/prefetch controlado |

---

## 19. Estratégia de testes

Espelha a disciplina de testes do backend (memória: unit + IT, cobertura por camada).

- **Domain (SwiftTesting/XCTest):** state machine da OS (todas as transições válidas/inválidas,
  RN-06), regras RN-xx, validadores (CPF, placa, telefone), mappers legados de status (C1). ≥90%.
- **Data:** repositórios com `URLProtocol` stub (respostas OpenAPI reais como fixtures), parser
  tolerante de data (C5), snake_case dashboard (C2), paginação, cache SWR. ≥80%.
- **Stores:** dado action → estado esperado (loading/success/empty/error/offline); efeitos de rede
  mockados; sem retry em não-idempotente (RN-09). ≥80%.
- **UI/Snapshot:** cada componente do Design System em light/dark/alto contraste + Dynamic Type
  (XL/AX5); telas-chave (Dashboard, OS detalhe, orçamento).
- **Acessibilidade:** testes de rótulos VoiceOver e contraste automatizados.
- **Integração de fluxo (UITest):** login → dashboard → aprovar orçamento; cadastro → veículo →
  nova OS (quando C4 resolvido); notificação → detalhe da OS.
- **Contrato:** validar DTOs contra os YAML do `openApi/` (fixtures geradas do contrato) para
  detectar drift do backend em CI.

CI: rodar em cada PR (espelha `.github/workflows/ci.yml`): build, testes, cobertura por pacote,
lint (SwiftLint/SwiftFormat), checagem de contrato.

---

## 20. Estrutura do projeto Xcode

```
ServiceTrackApp/
├── App/
│   ├── ServiceTrackApp.swift        (entry, DI composition root)
│   ├── RootRouter.swift             (TabBar customizada, deep-link)
│   └── AppEnvironment.swift
├── Packages/
│   ├── Core/            (DesignSystem, Tokens, Localization, Analytics, Logging)
│   ├── Networking/      (APIClient, Interceptors, AuthInterceptor, ErrorMapper)
│   ├── Persistence/     (Keychain, Cache, Migrations)
│   ├── Domain/          (Entities, StatusOS state machine, UseCases, RepositoryProtocols, RN)
│   ├── Data/            (DTOs gerados do OpenAPI, Mappers, Repositories)
│   └── Features/
│       ├── Auth/  Onboarding/  Dashboard/  OrdensServico/
│       ├── Veiculos/  Notificacoes/  Perfil/  Catalogo/
├── Resources/           (Assets, ilustrações, fontes, Localizable, tokens.json)
├── Tests/               (por pacote) + UITests/
└── openapi/             (cópia dos contratos + config do gerador — fonte dos DTOs)
```

Config: `Debug` (localhost, ATS relaxado só p/ localhost), `Release` (prod URL, pinning). Base URL
por `xcconfig`/`Info.plist` sobrescrevível por env (paridade com `SERVICETRACK_API_BASE_URL`).

---

## 21. Roadmap de implementação

Fases incrementais, cada uma entregável e testável.

**Fase 0 — Fundação (1 sprint).** Setup SPM modular, Design System (tokens, tipografia, cores,
componentes base STCard/STButton/STStatusBadge/STEmptyState/STSkeleton), APIClient + auth
interceptor + error mapper, Keychain, geração de DTOs do OpenAPI, tema light/dark.

**Fase 1 — Identidade e conta.** Onboarding, Cadastro (`POST /clientes`), Login (JWT, role gate,
biometria), Perfil (ver/editar, alterar senha, logout, desativar). Testes de auth.

**Fase 2 — Garagem.** Veículos CRUD, sugestões de imagem (Unsplash), FIPE display, empty states,
histórico por veículo (base). Testes de veículo.

**Fase 3 — Ordens de Serviço (núcleo de valor).** Dashboard, lista de OS (filtros+paginação),
detalhe + STStatusTimeline, STBudgetCard. Aprovar/Reprovar/Cancelar com haptics e tratamento de
409 (RN-07). Nova OS (após resolver C4). Testes de state machine e fluxo de orçamento.

**Fase 4 — Notificações & polimento.** Central de notificações (lista/detalhe/contador/visualizar),
deep-links para OS, microinterações finais, skeleton/hero transitions, acessibilidade completa,
telemetria/analytics, catálogo informativo.

**Fase 5 — Evoluções (pós-MVP).**
- Push nativo APNs a partir do outbox de notificações (§17.4).
- Outbox otimista para ações offline com idempotency-key (requer suporte do backend).
- Recuperação de senha pública (requer novo endpoint — C6).
- Ordenação/sort server-side na listagem de OS.
- Padronização dos enums de status no dashboard (C1) e do contrato `mecanicoId` (C4) com backend.
- Pagamento/PIX do orçamento (mencionado como evolução em ADR-014).

---

## 22. Anexos

### 22.1 Dicionário de erros (`ErroResponse`)

Envelope observado nos contratos (dashboard usa `status_code`/`mensagem`):

```json
{ "status_code": 403, "mensagem": "Acesso proibido - Você pode acessar apenas seu próprio dashboard" }
```

O app extrai `mensagem` para exibição amigável e `status_code` para o mapa §12.1. Manter tabela de
mensagens conhecidas por endpoint (400 ID inválido, 401 token, 403 posse, 404 não encontrado, 409
estado inválido) para localização e tom de voz consistente.

### 22.2 Checklist "premium" por tela (gate de qualidade)

Antes de considerar uma tela pronta, confirmar:

- [ ] Não parece template padrão de `List`/`Form` (senão, reprojetar).
- [ ] Tem os 5 estados (loading skeleton / conteúdo / vazio ilustrado / erro ilustrado / offline).
- [ ] Usa apenas componentes do Design System e tokens (sem cores/spacings mágicos).
- [ ] Microinterações + haptics nas ações principais.
- [ ] Acessível: VoiceOver, Dynamic Type AX5, contraste AA, Reduce Motion/Transparency.
- [ ] Rastreável (linha na tabela §3) e ligada a RF/endpoint reais.
- [ ] Telemetria/eventos instrumentados.
- [ ] Testes (unit do store + snapshot do componente).

### 22.3 Fontes consolidadas (repositório)

- Requisitos: `docs/srs.md`, `docs/mvp-1/CASE.md`, `docs/mvp-2/CASE.md`.
- Decisões: `docs/adr/ADR-001..014`, `docs/rfc/RFC-001..014` (destaques: ADR-005 JWT, ADR-006 FIPE,
  ADR-007 Unsplash, ADR-009 e-mail, ADR-010 CDI events/outbox, ADR-012 fault tolerance, ADR-014
  magic link).
- Arquitetura: `docs/c4/{context,container,components,code-diagram}`, READMEs de `_domain`,
  `_application`, `_infrastructure`.
- Contrato: `software/service-track-api/openApi/**` (fonte contract-first dos DTOs e caminhos).
- Domínio/código: `_domain/.../ordemServico/StatusOrdemServicoEnum.kt` e `vo/StatusOrdemServico.kt`
  (state machine — verdade canônica de status), `*ResourceImpl.kt` (autorização por role e
  timeouts/bulkheads), `config/jwt/JwtAdapter.kt` (claims do token).

---

> **Encerramento.** Esta especificação é autossuficiente para implementar o app iOS do Cliente do
> ServiceTrack. Toda funcionalidade é rastreável a um RF, caso de uso ou endpoint existente; nenhuma
> foi inventada. Conflitos da documentação estão explicitados (§9) com resolução proposta — os itens
> C4 (contrato `mecanicoId`) e C6 (recuperação de senha) exigem alinhamento com o time de backend e
> estão marcados como bloqueios/evoluções, não como suposições silenciosas.
</content>
</invoke>
