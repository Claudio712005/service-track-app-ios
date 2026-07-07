import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Face ID/Touch ID opcional para desbloquear sessão persistida (spec §8.4).
enum Biometria {
    /// Dispositivo sem biometria configurada não bloqueia o uso (degrade gracioso).
    static func autenticar(motivo: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let contexto = LAContext()
        var erro: NSError?
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &erro) else {
            return true
        }
        do {
            return try await contexto.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                     localizedReason: motivo)
        } catch {
            return false
        }
        #else
        return true
        #endif
    }
}
