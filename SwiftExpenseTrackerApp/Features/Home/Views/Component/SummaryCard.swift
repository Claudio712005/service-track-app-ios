//
//  SummaryCard.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import SwiftUI

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let iconBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}

#Preview {
    SummaryCard(
        title: "Receitas",
        value: "R$ 6.000,00",
        icon: "arrow.down.left",
        iconColor: .green,
        iconBackground: .green.opacity(0.12)
    )
}
