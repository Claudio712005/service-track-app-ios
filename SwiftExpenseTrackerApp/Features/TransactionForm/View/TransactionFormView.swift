//
//  TransactionFormView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 14/06/26.
//

import SwiftUI

struct TransactionFormView: View {
    var id: UUID?
    @State var selection = CategoryType.income
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            header	
            Text("VALOR")
                .font(.system(size: 18))
                .fontWeight(.light)
                .foregroundColor(.gray)
            HStack{
                Text("R$")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.green)
                Text("0,00")
                    .font(.system(size: 44, weight: .bold)).foregroundColor(.gray).opacity(0.5)
                    
            }
            TypeTransactionSelector(selection: $selection).padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(true)	
    }
    
    var header: some View {
        HStack(spacing: 8) {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Cancelar")
                        .font(.system(size: 16))
                        .fontWeight(.light)
                }
                .foregroundColor(.blue)
            }
            Spacer()
            Text(id == nil ? "Nova transação" : "Transação")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("Cancelar")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TransactionFormView()
}
