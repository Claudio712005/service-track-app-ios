//
//  LatestTransactionItem.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import Foundation

struct LatestTransactionItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let amount: Decimal
    let category: CategoryEnum
    let date: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        category: CategoryEnum,
        date: Date
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
    }

    var type: CategoryType {
        category.type
    }

    var categoryId: String {
        category.id
    }

    var formattedAmount: String {
        let value = NSDecimalNumber(decimal: amount).doubleValue

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.currencySymbol = "R$"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let formattedValue = formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"

        switch type {
        case .income:
            return "+ \(formattedValue)"
        case .expense:
            return "- \(formattedValue)"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}

extension LatestTransactionItem {
    static let mock: [LatestTransactionItem] = [
        LatestTransactionItem(
            title: "Restaurante Madero",
            amount: 72.00,
            category: .food,
            date: .mock(day: 10, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Renner · roupas",
            amount: 259.90,
            category: .shopping,
            date: .mock(day: 10, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Freelance de design",
            amount: 800.00,
            category: .salary,
            date: .mock(day: 9, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Uber",
            amount: 28.90,
            category: .transport,
            date: .mock(day: 9, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Mercado Pão de Açúcar",
            amount: 342.80,
            category: .food,
            date: .mock(day: 8, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Netflix",
            amount: 39.90,
            category: .leisure,
            date: .mock(day: 7, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Farmácia São João",
            amount: 86.40,
            category: .health,
            date: .mock(day: 6, month: 6, year: 2026)
        ),
        LatestTransactionItem(
            title: "Salário · Empresa XYZ",
            amount: 5200.00,
            category: .salary,
            date: .mock(day: 5, month: 6, year: 2026)
        )
    ]
}
