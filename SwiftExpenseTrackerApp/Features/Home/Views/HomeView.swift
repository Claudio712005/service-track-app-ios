//
//  HomeView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 11/06/26.
//

import SwiftUI

struct HomeView: View {
    let onOpenTransactionForm: (UUID?) -> Void
    
    @State private var isAnimated = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView{
                LazyVStack(alignment: .leading, spacing: 16) {
                    HeaderHomeView(name: "Marina", isAnimated: $isAnimated)
                    VStack(spacing: 24) {
                        FinanceCard()
                            .opacity(isAnimated ? 1 : 0)
                            .padding(.horizontal, isAnimated ? 0 : 20)
                        
                        HStack(spacing: 18) {
                            SummaryCard(
                                title: "Receitas",
                                value: "R$ 6.000,00",
                                icon: "arrow.down.left",
                                iconColor: .green,
                                iconBackground: .green.opacity(0.12)
                            ).opacity(isAnimated ? 1 : 0)
                            
                            SummaryCard(
                                title: "Despesas",
                                value: "R$ 2.787,20",
                                icon: "arrow.up.right",
                                iconColor: .red,
                                iconBackground: .red.opacity(0.12)
                            ).opacity(isAnimated ? 1 : 0)
                        }.padding(.horizontal, isAnimated ? 0 : 9)
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
            .opacity(isAnimated ? 1 : 0)
            .padding(.trailing, 24)
            .padding(.bottom, isAnimated ? 24 : -100)
        }.onAppear{
            withAnimation(.easeInOut(duration: 0.8)){
                isAnimated = true
            }
        }
    }
}

#Preview {
    HomeView(onOpenTransactionForm: { _ in })
}
