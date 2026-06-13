//
//  FinanceCard.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import SwiftUI

import SwiftUI

struct FinanceCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text("Saldo total")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))

                Text("R$ 3.212,80")
                    .font(.system(size: 33, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("Junho de 2026")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 8)

            Image(systemName: "creditcard.fill")
                .font(.system(size: 100, weight: .regular))
                .foregroundStyle(.white.opacity(0.18))
                .overlay {
                    Image(systemName: "creditcard")
                        .font(.system(size: 100, weight: .regular))
                        .foregroundStyle(.white.opacity(0.12))
                }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.53, blue: 1.00),
                    Color(red: 0.36, green: 0.38, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 5)
    }
}

#Preview {		
    FinanceCard()
}
