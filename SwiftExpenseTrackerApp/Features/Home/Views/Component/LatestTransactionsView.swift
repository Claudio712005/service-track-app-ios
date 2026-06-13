//
//  LatestTransactionsView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import SwiftUI

struct LatestTransactionsView: View {
    let transactions: [LatestTransactionItem]

    init(transactions: [LatestTransactionItem] = LatestTransactionItem.mock) {
        self.transactions = transactions
    }

    var body: some View {
        headerView

        VStack(spacing: 14) {

            VStack(spacing: 0) {
                ForEach(transactions) { transaction in
                    LatestTransactionRowView(transaction: transaction)

                    if transaction.id != transactions.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.padding(10)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private var headerView: some View {
        HStack {
            Text("ÚLTIMAS TRANSAÇÕES".uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(.systemGray))
                .tracking(1)

            Spacer()

            Text("\(transactions.count) no total")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    LatestTransactionsView()
}
