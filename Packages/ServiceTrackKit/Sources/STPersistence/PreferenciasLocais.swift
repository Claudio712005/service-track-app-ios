import Foundation

public struct PreferenciasLocais: Sendable {
    private let defaults: UserDefaults

    private enum Chave {
        static let onboardingVisto = "st.onboardingVisto"
        static let biometriaHabilitada = "st.biometriaHabilitada"
        static let analyticsHabilitada = "st.analyticsHabilitada"
        static let ultimaContagemNaoLidas = "st.ultimaContagemNaoLidas"
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

    public var analyticsHabilitada: Bool {
        get { defaults.object(forKey: Chave.analyticsHabilitada) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Chave.analyticsHabilitada) }
    }

    public var ultimaContagemNaoLidas: Int {
        get { defaults.integer(forKey: Chave.ultimaContagemNaoLidas) }
        nonmutating set { defaults.set(newValue, forKey: Chave.ultimaContagemNaoLidas) }
    }
}
