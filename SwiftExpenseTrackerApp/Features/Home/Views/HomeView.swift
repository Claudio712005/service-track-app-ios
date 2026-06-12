//
//  HomeView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 11/06/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView{
            LazyVStack(alignment: .leading, spacing: 16) {
                HeaderHomeView(name: "Marina")
                VStack(spacing: 24) {
                    FinanceCard()

                    HStack(spacing: 18) {
                        SummaryCard(
                                title: "Receitas",
                                value: "R$ 6.000,00",
                                icon: "arrow.down.left",
                                iconColor: .green,
                                iconBackground: .green.opacity(0.12)
                        )

                        SummaryCard(
                                title: "Despesas",
                                value: "R$ 2.787,20",
                                icon: "arrow.up.right",
                                iconColor: .red,
                                iconBackground: .red.opacity(0.12)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 15)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    HomeView()
}
