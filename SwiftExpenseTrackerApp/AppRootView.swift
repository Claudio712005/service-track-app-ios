//
//  ContentView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 10/06/26.
//

import SwiftUI

struct AppRootView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path){
            HomeView(
                onOpenTransactionForm: { id in
                    path.append(AppRoute.formTransaction(id: id))
                }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    HomeView(onOpenTransactionForm: { id in
                        path.append(AppRoute.formTransaction(id: id))
                    })
                case .formTransaction(let id):
                    TransactionFormView(id: id)
                }
            }
        }
    }
}

#Preview {
    AppRootView()
}
