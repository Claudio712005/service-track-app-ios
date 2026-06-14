//
//  HomeView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 11/06/26.
//

import SwiftUI

struct HomeView: View {
    let onOpenTransactionForm: (UUID?) -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                        }.padding(.horizontal, 9)
                    }
                    LatestTransactionsView()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 15)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Button{
                onOpenTransactionForm(nil)
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.blue)
                    .clipShape(Circle())
                    .shadow(radius: 6)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    HomeView(onOpenTransactionForm: { _ in })
}
