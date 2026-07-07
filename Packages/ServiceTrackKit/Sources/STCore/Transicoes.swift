import SwiftUI

// Transições padrão de fase de tela (spec §13.7): a troca skeleton → conteúdo
// nunca é um corte seco. O container anima a mudança de fase; o conteúdo entra
// com fade + deslize sutil (desliga o deslocamento sob Reduce Motion).

public extension View {
    /// Aplicar no **container** que troca de fase (skeleton/conteúdo/vazio/erro).
    func dsAnimaFase(_ valor: some Equatable) -> some View {
        animation(DSMotion.transicao, value: valor)
    }

    /// Aplicar em **cada ramo** da fase: entrada suave, saída em fade.
    func dsEntradaSuave() -> some View {
        modifier(EntradaSuave())
    }
}

private struct EntradaSuave: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    func body(content: Content) -> some View {
        content.transition(.asymmetric(
            insertion: reduzirMovimento
                ? .opacity
                : .opacity.combined(with: .offset(y: 12)).combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity))
    }
}
