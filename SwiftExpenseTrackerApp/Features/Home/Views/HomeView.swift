//
//  HomeView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 11/06/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView{
            LazyVStack(alignment: .leading, spacing: 16) {
                    HeaderHomeView(name: "Marina")
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 15)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    HomeView()
}
