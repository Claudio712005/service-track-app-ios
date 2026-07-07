import SwiftUI
import STDomain

// Componentes base da Fase 0 (spec §14/§21): STCard, botões, STStatusBadge,
// STEmptyState, STErrorState, STSkeleton, STCurrencyText.
// Demais componentes entram junto com as features que os consomem.

// MARK: - STCard

/// Superfície base (radius/md, e1) — spec §14.
public struct STCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
            )
            .dsShadow(.e1)
    }
}

// MARK: - Botões

/// Press-scale 0.97 (§13.7) com estado de loading (§13.8).
struct STButtonStyle: ButtonStyle {
    enum Variante {
        case primario, secundario, destrutivo
    }

    let variante: Variante
    let carregando: Bool
    @Environment(\.isEnabled) private var habilitado
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DSSpacing.sm) {
            if carregando {
                ProgressView().controlSize(.small).tint(corTexto)
            }
            configuration.label
                .font(DSFont.headline)
                .opacity(carregando ? 0.75 : 1)
        }
        .foregroundStyle(corTexto)
        .frame(maxWidth: .infinity, minHeight: DSSpacing.alvoMinimo)
        .padding(.horizontal, DSSpacing.lg)
        .background(fundo(pressionado: configuration.isPressed), in: .rect(cornerRadius: DSRadius.md))
        .overlay {
            if variante == .secundario {
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
            }
        }
        .scaleEffect(configuration.isPressed && !reduzirMovimento ? 0.97 : 1)
        .animation(DSMotion.toque, value: configuration.isPressed)
        .opacity(habilitado ? 1 : 0.45)
    }

    private var corTexto: Color {
        switch variante {
        case .primario, .destrutivo: DSColor.onPrimary
        case .secundario: DSColor.textPrimary
        }
    }

    private func fundo(pressionado: Bool) -> Color {
        switch variante {
        case .primario: pressionado ? DSColor.brandPrimaryStrong : DSColor.brandPrimary
        case .secundario: DSColor.bgSurface
        case .destrutivo: DSColor.danger.opacity(pressionado ? 0.85 : 1)
        }
    }
}

public struct STPrimaryButton: View {
    let titulo: String
    let carregando: Bool
    let acao: () -> Void

    public init(_ titulo: String, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.carregando = carregando
        self.acao = acao
    }

    public var body: some View {
        Button(titulo, action: acao)
            .buttonStyle(STButtonStyle(variante: .primario, carregando: carregando))
            .disabled(carregando)
    }
}

public struct STSecondaryButton: View {
    let titulo: String
    let carregando: Bool
    let acao: () -> Void

    public init(_ titulo: String, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.carregando = carregando
        self.acao = acao
    }

    public var body: some View {
        Button(titulo, action: acao)
            .buttonStyle(STButtonStyle(variante: .secundario, carregando: carregando))
            .disabled(carregando)
    }
}

public struct STDestructiveButton: View {
    let titulo: String
    let carregando: Bool
    let acao: () -> Void

    public init(_ titulo: String, carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.carregando = carregando
        self.acao = acao
    }

    public var body: some View {
        Button(titulo, role: .destructive, action: acao)
            .buttonStyle(STButtonStyle(variante: .destrutivo, carregando: carregando))
            .disabled(carregando)
    }
}

// MARK: - STStatusBadge

/// Pílula de status da OS: cor + ícone + rótulo (§14; nunca só cor — §16).
public struct STStatusBadge: View {
    public enum Tamanho {
        case sm, md
    }

    let status: StatusOrdemServico
    let tamanho: Tamanho

    public init(_ status: StatusOrdemServico, tamanho: Tamanho = .md) {
        self.status = status
        self.tamanho = tamanho
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: status.iconeSistema)
                .font(.system(size: tamanho == .sm ? 10 : 12, weight: .semibold))
            Text(status.rotulo)
                .font(tamanho == .sm ? DSFont.caption : DSFont.subhead)
        }
        .foregroundStyle(DSColor.status(status))
        .padding(.horizontal, tamanho == .sm ? DSSpacing.sm : DSSpacing.md)
        .padding(.vertical, tamanho == .sm ? DSSpacing.xs : DSSpacing.sm - 2)
        .background(DSColor.statusSuave(status), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.descricaoAcessivel)")
    }
}

// MARK: - Empty / Error states

/// Empty state ilustrado com CTA (§14) — telas nunca ficam em branco (§12.4).
public struct STEmptyState: View {
    let icone: String
    let titulo: String
    let subtitulo: String
    let tituloCTA: String?
    let acaoCTA: (() -> Void)?

    public init(icone: String, titulo: String, subtitulo: String,
                tituloCTA: String? = nil, acaoCTA: (() -> Void)? = nil) {
        self.icone = icone
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.tituloCTA = tituloCTA
        self.acaoCTA = acaoCTA
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(DSColor.brandPrimary.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: icone)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DSColor.brandPrimary)
            }
            .accessibilityHidden(true)

            VStack(spacing: DSSpacing.xs) {
                Text(titulo)
                    .font(DSFont.title3)
                    .foregroundStyle(DSColor.textPrimary)
                Text(subtitulo)
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let tituloCTA, let acaoCTA {
                STPrimaryButton(tituloCTA, acao: acaoCTA)
                    .fixedSize()
            }
        }
        .padding(DSSpacing.x3l)
        .frame(maxWidth: .infinity)
    }
}

/// Variante de erro com retry (§14).
public struct STErrorState: View {
    let mensagem: String
    let tentarNovamente: () -> Void

    public init(mensagem: String, tentarNovamente: @escaping () -> Void) {
        self.mensagem = mensagem
        self.tentarNovamente = tentarNovamente
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(DSColor.danger.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DSColor.danger)
            }
            .accessibilityHidden(true)

            VStack(spacing: DSSpacing.xs) {
                Text("Algo deu errado")
                    .font(DSFont.title3)
                    .foregroundStyle(DSColor.textPrimary)
                Text(mensagem)
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            STSecondaryButton("Tentar novamente", acao: tentarNovamente)
                .fixedSize()
        }
        .padding(DSSpacing.x3l)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - STSkeleton

/// Placeholder shimmer para primeiros carregamentos (§13.7/§14).
public struct STSkeleton: View {
    let altura: CGFloat
    let raio: CGFloat
    @State private var fase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public init(altura: CGFloat = 16, raio: CGFloat = DSRadius.sm) {
        self.altura = altura
        self.raio = raio
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: raio)
            .fill(DSColor.borderSubtle)
            .frame(height: altura)
            .overlay {
                if !reduzirMovimento {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width / 2)
                        .offset(x: fase * geo.size.width * 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: raio))
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            fase = 1
                        }
                    }
                }
            }
            .accessibilityLabel("Carregando")
    }
}

// MARK: - STCurrencyText

/// Formatação BRL tabular (§14), com placeholder quando nulo.
public struct STCurrencyText: View {
    let valor: Double?
    let fonte: Font

    public init(_ valor: Double?, fonte: Font = DSFont.mono) {
        self.valor = valor
        self.fonte = fonte
    }

    public var body: some View {
        Text(texto)
            .font(fonte)
            .foregroundStyle(valor == nil ? DSColor.textTertiary : DSColor.textPrimary)
    }

    private var texto: String {
        guard let valor else { return "—" }
        return valor.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
}
