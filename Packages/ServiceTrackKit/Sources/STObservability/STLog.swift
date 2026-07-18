import Foundation
#if canImport(os)
import os
#endif

public enum STLog {
    #if canImport(os)
    private static let subsistema = "br.com.claus.ServiceTrackApp"

    public static let network = Logger(subsystem: subsistema, category: "network")
    public static let auth = Logger(subsystem: subsistema, category: "auth")
    public static let ui = Logger(subsystem: subsistema, category: "ui")
    public static let cache = Logger(subsystem: subsistema, category: "cache")
    public static let analytics = Logger(subsystem: subsistema, category: "analytics")
    #endif
}
