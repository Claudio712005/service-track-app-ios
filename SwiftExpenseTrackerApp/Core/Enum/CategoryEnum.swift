//
//  CategoryEnum.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 13/06/26.
//

import Foundation
import SwiftUI

enum CategoryType {
    case income
    case expense
}

enum CategoryEnum: String, CaseIterable, Identifiable, Hashable {
    case salary
    case food
    case housing
    case transport
    case bills
    case health
    case leisure
    case shopping
    case others

    var id: String {
        rawValue
    }

    var name: String {
        switch self {
        case .salary:
            return "Salário"
        case .food:
            return "Alimentação"
        case .housing:
            return "Moradia"
        case .transport:
            return "Transporte"
        case .bills:
            return "Contas"
        case .health:
            return "Saúde"
        case .leisure:
            return "Lazer"
        case .shopping:
            return "Compras"
        case .others:
            return "Outros"
        }
    }

    var iconName: String {
        switch self {
        case .salary:
            return "banknote"
        case .food:
            return "fork.knife"
        case .housing:
            return "house"
        case .transport:
            return "car"
        case .bills:
            return "doc.text"
        case .health:
            return "heart"
        case .leisure:
            return "gamecontroller"
        case .shopping:
            return "bag"
        case .others:
            return "ellipsis"
        }
    }

    var color: Color {
        switch self {
        case .salary:
            return Color.green
        case .food:
            return Color.orange
        case .housing:
            return Color.purple
        case .transport:
            return Color.blue
        case .bills:
            return Color.cyan
        case .health:
            return Color.pink
        case .leisure:
            return Color.indigo
        case .shopping:
            return Color.yellow
        case .others:
            return Color.gray
        }
    }

    var type: CategoryType {
        switch self {
        case .salary:
            return .income
        case .food, .housing, .transport, .bills, .health, .leisure, .shopping, .others:
            return .expense
        }
    }

    static var incomes: [CategoryEnum] {
        allCases.filter { $0.type == .income }
    }

    static var expenses: [CategoryEnum] {
        allCases.filter { $0.type == .expense }
    }

    static func findById(_ id: String) -> CategoryEnum? {
        CategoryEnum(rawValue: id)
    }
}
