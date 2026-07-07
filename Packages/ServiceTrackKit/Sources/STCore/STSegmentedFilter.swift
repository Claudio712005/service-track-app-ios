import SwiftUI

/// Filtro de status em pílulas scrolláveis (spec §14) — não o `Picker` padrão.
public struct STSegmentedFilter<Opcao: Hashable>: View {
    let opcoes: [Opcao]
    let rotulo: (Opcao) -> String
    @Binding var selecao: Opcao
    @Namespace private var pilula

    public init(opcoes: [Opcao], selecao: Binding<Opcao>, rotulo: @escaping (Opcao) -> String) {
        self.opcoes = opcoes
        self._selecao = selecao
        self.rotulo = rotulo
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.sm) {
                ForEach(opcoes, id: \.self) { opcao in
                    Button {
                        withAnimation(DSMotion.transicao) { selecao = opcao }
                    } label: {
                        Text(rotulo(opcao))
                            .font(DSFont.subhead)
                            .foregroundStyle(selecao == opcao ? DSColor.onPrimary : DSColor.textSecondary)
                            .padding(.horizontal, DSSpacing.lg)
                            .frame(minHeight: 36)
                            .background {
                                if selecao == opcao {
                                    Capsule()
                                        .fill(DSColor.brandPrimary)
                                        .matchedGeometryEffect(id: "pilula", in: pilula)
                                } else {
                                    Capsule()
                                        .fill(DSColor.bgSurface)
                                        .overlay(Capsule().strokeBorder(DSColor.borderSubtle, lineWidth: 1))
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selecao == opcao ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, DSSpacing.margemTela)
            .padding(.vertical, DSSpacing.xs)
        }
    }
}
