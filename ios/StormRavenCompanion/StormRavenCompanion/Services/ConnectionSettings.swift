import Foundation

/// Connection settings for the kernel's Bifrost gateway, persisted to UserDefaults.
/// Supports both local LAN HTTP gateways (e.g. http://192.168.1.50:8787) and
/// cloud/mobile HTTPS gateways (e.g. https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app).
struct ConnectionSettings: Equatable {
    var host: String
    var port: Int
    var useTLS: Bool

    static let cloudDefaultHost = "01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"

    /// Normalize a user-supplied host or full URL into (host, port, useTLS).
    init(host: String, port: Int = 8787, useTLS: Bool = false) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = URL(string: trimmed), let parsedHost = parsed.host {
            self.host = parsedHost
            let isHttps = parsed.scheme?.lowercased() == "https" || parsed.scheme?.lowercased() == "wss"
            self.useTLS = isHttps ? true : useTLS
            self.port = parsed.port ?? (self.useTLS ? 443 : port)
        } else {
            self.host = trimmed
            self.useTLS = useTLS || trimmed.hasSuffix(".skydive.app")
            self.port = (self.useTLS && port == 8787) ? 443 : port
        }
    }

    var baseURL: URL {
        var comps = URLComponents()
        comps.scheme = useTLS ? "https" : "http"
        comps.host = host
        let isStandardPort = (useTLS && port == 443) || (!useTLS && port == 80)
        comps.port = isStandardPort ? nil : port
        return comps.url ?? URL(string: "https://\(Self.cloudDefaultHost)")!
    }

    var webSocketURL: URL {
        var comps = URLComponents()
        comps.scheme = useTLS ? "wss" : "ws"
        comps.host = host
        let isStandardPort = (useTLS && port == 443) || (!useTLS && port == 80)
        comps.port = isStandardPort ? nil : port
        comps.path = "/ws"
        return comps.url!
    }

    static let loopback = ConnectionSettings(host: "127.0.0.1", port: 8787, useTLS: false)
    static let cloudMobile = ConnectionSettings(host: cloudDefaultHost, port: 443, useTLS: true)

    static func load() -> ConnectionSettings {
        let d = UserDefaults.standard
        let savedHost = d.string(forKey: "sr.host") ?? cloudDefaultHost
        let isCloud = savedHost.hasSuffix(".skydive.app") || savedHost.starts(with: "https://")
        let savedTLS = d.object(forKey: "sr.tls") as? Bool ?? isCloud
        let savedPort = d.object(forKey: "sr.port") as? Int ?? (savedTLS ? 443 : 8787)
        return ConnectionSettings(
            host: savedHost,
            port: savedPort,
            useTLS: savedTLS
        )
    }

    func save() {
        UserDefaults.standard.set(host, forKey: "sr.host")
        UserDefaults.standard.set(port, forKey: "sr.port")
        UserDefaults.standard.set(useTLS, forKey: "sr.tls")
    }
}
