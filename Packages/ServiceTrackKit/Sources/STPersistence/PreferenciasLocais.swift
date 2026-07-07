import Foundation

/// Preferências locais do dispositivo (não sensíveis — sessão fica no Keychain).
/// Onboarding é estado por instalação, decisão registrada em ADR-iOS-004.
public struct PreferenciasLocais: Sendable {
    private let defaults: UserDefaults

    private enum Chave {
        static let onboardingVisto = "st.onboardingVisto"
        static let biometriaHabilitada = "st.biometriaHabilitada"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var onboardingVisto: Bool {
        get { defaults.bool(forKey: Chave.onboardingVisto) }
        nonmutating set { defaults.set(newValue, forKey: Chave.onboardingVisto) }
    }

    public var biometriaHabilitada: Bool {
        get { defaults.bool(forKey: Chave.biometriaHabilitada) }
        nonmutating set { defaults.set(newValue, forKey: Chave.biometriaHabilitada) }
    }
}
