//
//  TypeTransactionSelector.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 15/06/26.
//

import SwiftUI

struct TypeTransactionSelector: View {
    @Binding var selection: CategoryType
    @Namespace private var namespace

    private let types: [CategoryType] = [.income, .expense]

    private func getBackgroundColor(for type: CategoryType) -> Color {
        type == .income ? Color.green : Color.red
    }

    private func getDisplayName(for type: CategoryType) -> String {
        type == .income ? "Receita" : "Despesa"
    }

    private func getSelectedBackground(item: CategoryType) -> some View {
        let backgroundColor = getBackgroundColor(for: item)
        return RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor)
            .matchedGeometryEffect(id: "selected", in: namespace)
    }

    private func buttonLabel(for item: CategoryType) -> some View {
        Text(getDisplayName(for: item))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selection == item ? .white : .gray)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(types, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selection = item
                    }
                } label: {
                    buttonLabel(for: item)
                        .background {
                            if selection == item {
                                getSelectedBackground(item: item)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    @Previewable @State var selection = CategoryType.income
    TypeTransactionSelector(selection: $selection)
}
    
