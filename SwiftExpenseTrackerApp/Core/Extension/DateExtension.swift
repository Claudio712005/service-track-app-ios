//
//  DateExtension.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 12/06/26.
//

import Foundation

extension Date {
    static func mock(day: Int, month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year

        return Calendar.current.date(from: components) ?? Date()
    }
}
