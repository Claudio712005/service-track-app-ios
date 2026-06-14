//
//  AppRouteEnum.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 14/06/26.
//

import Foundation

enum AppRoute: Hashable {
    case home
    case formTransaction(id: UUID?)
}
