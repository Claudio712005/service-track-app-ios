import Foundation
import STDomain
import STPersistence
import STObservability
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(os)
import os
#endif

@MainActor
struct NotificacoesBadgeMonitor {
    let notificacoes: NotificacaoRepository
    let preferencias: PreferenciasLocais

    func pedirAutorizacaoSeNecessario() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
        #endif
    }

    func sincronizar() async {
        guard let atual = try? await notificacoes.contagemNaoLidas() else { return }
        let anterior = preferencias.ultimaContagemNaoLidas

        #if canImport(UserNotifications)
        try? await UNUserNotificationCenter.current().setBadgeCount(atual)
        #endif

        if BadgeSync.deveAvisar(anterior: anterior, atual: atual) {
            avisar(quantidade: atual)
        }
        preferencias.ultimaContagemNaoLidas = atual
    }

    private func avisar(quantidade: Int) {
        #if canImport(UserNotifications)
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "ServiceTrack"
        conteudo.body = BadgeSync.corpoDoAviso(quantidade: quantidade)
        conteudo.sound = .default
        let pedido = UNNotificationRequest(identifier: "st.avisos.\(UUID().uuidString)",
                                           content: conteudo, trigger: nil)
        UNUserNotificationCenter.current().add(pedido)
        #endif
        STLog.ui.info("badge: aviso local disparado (contagem=\(quantidade))")
    }
}
