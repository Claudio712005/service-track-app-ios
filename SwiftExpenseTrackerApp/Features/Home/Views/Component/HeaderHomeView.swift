//
//  HeaderHomeView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 11/06/26.
//

import SwiftUI

struct HeaderHomeView: View {
    
    let name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4){
            Text("Olá, \(name)")
                .font(.subheadline)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
            HStack(
                spacing: 20
            ){
                Text("Resumo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 12) {
                    Button(
                        action: {}
                    ){
                        Image(systemName: "tag")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Visualizar Categorias")
                    Button(
                        action: {}
                    ){
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Visualizar Categorias")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.top, 24)
    }
}

#Preview {
    HeaderHomeView(name: "Cláudio")
}
