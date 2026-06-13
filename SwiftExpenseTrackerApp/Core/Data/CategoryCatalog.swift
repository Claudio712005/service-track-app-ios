//
//  CategoryCatalog.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import Foundation

enum CategoryCatalog {
    static let salary: CategoryEnum = .salary
    static let others: CategoryEnum = .others

    static let incomes: [CategoryEnum] = CategoryEnum.incomes
    static let expenses: [CategoryEnum] = CategoryEnum.expenses
    static let all: [CategoryEnum] = CategoryEnum.allCases

    static func findById(_ id: String) -> CategoryEnum? {
        CategoryEnum.findById(id)
    }
}
