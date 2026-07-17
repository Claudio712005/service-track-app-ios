import SwiftUI
import Observation
import STCore
import STDomain

/// Catálogo informativo (spec §15.13): serviços e insumos oferecidos pela
/// oficina, somente leitura — reforça confiança e contexto.
@MainActor
@Observable
public final class CatalogoStore {
    public enum Fase: Equatable {
        case carregando
        case conteudo(servicos: [CatalogoServico], insumos: [CatalogoInsumo])
        case erro(AppError)
    }

    /// Par cacheado junto (uma chave, um TTL — spec §11.2: catálogo 24h).
    struct Snapshot: Codable, Sendable {
        let servicos: [CatalogoServico]
        let insumos: [CatalogoInsumo]
    }

    public private(set) var fase: Fase = .carregando

    private let repo: CatalogoRepository
    private let cache: CacheStore?
    private let ttl: TimeInterval = 24 * 3600

    public init(repo: CatalogoRepository, cache: CacheStore? = nil) {
        self.repo = repo
        self.cache = cache
    }

    public func carregar() async {
        var cacheFresco = false
        if case .carregando = fase, let cache,
           let entrada = await cache.ler(Snapshot.self, chave: CacheChave.catalogo) {
            fase = .conteudo(servicos: entrada.valor.servicos, insumos: entrada.valor.insumos)
            cacheFresco = !entrada.vencida(ttl: ttl)
        }
        // Catálogo é quase estático: dentro do TTL não vai à rede (spec §11.2).
        if cacheFresco { return }

        do {
            async let servicos = repo.servicos()
            async let insumos = repo.insumos()
            let snapshot = try await Snapshot(servicos: servicos, insumos: insumos)
            fase = .conteudo(servicos: snapshot.servicos, insumos: snapshot.insumos)
            await cache?.gravar(snapshot, chave: CacheChave.catalogo)
        } catch let erro as AppError {
            if case .conteudo = fase { return } // cache velho ainda serve
            fase = .erro(erro)
        } catch {
            if case .conteudo = fase { return }
            fase = .erro(.rede)
        }
    }
}

public struct CatalogoView: View {
    @State private var store: CatalogoStore

    public init(repo: CatalogoRepository, cache: CacheStore? = nil) {
        self._store = State(initialValue: CatalogoStore(repo: repo, cache: cache))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                switch store.fase {
                case .carregando:
                    VStack(spacing: DSSpacing.md) {
                        ForEach(0..<4, id: \.self) { _ in
                            STSkeleton(altura: 84, raio: DSRadius.md)
                        }
                    }
                    .dsEntradaSuave()
                case .erro(let erro):
                    STErrorState(mensagem: erro.mensagemPadrao) {
                        Task { await store.carregar() }
                    }
                    .dsEntradaSuave()
                case .conteudo(let servicos, let insumos):
                    Group {
                        if !servicos.isEmpty {
                            secao("Serviços oferecidos") {
                                ForEach(servicos) { servico in
                                    cartao(icone: "wrench.and.screwdriver",
                                           titulo: servico.nomeServico,
                                           descricao: servico.descricaoServico)
                                }
                            }
                        }
                        if !insumos.isEmpty {
                            secao("Peças e insumos") {
                                ForEach(insumos) { insumo in
                                    cartao(icone: "shippingbox",
                                           titulo: insumo.nome,
                                           descricao: insumo.descricao)
                                }
                            }
                        }
                    }
                    .dsEntradaSuave()
                }
            }
            .padding(DSSpacing.margemTela)
            .dsAnimaFase(faseId)
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Nossos serviços")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.carregar() }
    }

    private var faseId: Int {
        switch store.fase {
        case .carregando: 0
        case .conteudo: 1
        case .erro: 2
        }
    }

    private func secao(_ titulo: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(titulo)
                .font(DSFont.title3)
                .foregroundStyle(DSColor.textPrimary)
            VStack(spacing: DSSpacing.md, content: conteudo)
        }
    }

    private func cartao(icone: String, titulo: String, descricao: String) -> some View {
        STCard {
            HStack(alignment: .top, spacing: DSSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .fill(DSColor.brandPrimary.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: icone)
                        .foregroundStyle(DSColor.brandPrimary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(titulo)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(descricao)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
