import SwiftUI

@main
struct ServiceTrackApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                // MVP é pt-BR (spec §18): UI inteira em pt-BR, então datas e
                // moeda seguem o mesmo locale. i18n plena é evolução.
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}
