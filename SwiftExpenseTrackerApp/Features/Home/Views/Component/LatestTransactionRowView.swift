//
//  LatestTransactionRowView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import SwiftUI

struct LatestTransactionRowView: View {
    let transaction: LatestTransactionItem

    private var category: CategoryEnum {
        transaction.category
    }

    var body: some View {
        HStack(spacing: 10) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(transaction.formattedAmount)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(transaction.type == .income ? Color.green : Color.black)
                .lineLimit(1)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(category.color.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: category.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(category.color)
        }
    }

    private var subtitle: String {
        "\(category.name) · \(transaction.formattedDate)"
    }
}

#Preview {
    ZStack {
        LatestTransactionsView()
    }
}
