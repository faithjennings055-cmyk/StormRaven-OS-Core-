import Foundation

/// Connection settings for the kernel's Bifrost gateway, persisted to UserDefaults.
struct ConnectionSettings: Equatable {
    var host: String
    var port: Int
    var useTLS: Bool

    var baseURL: URL {
        var comps = URLComponents()
        comps.scheme = useTLS ? "https" : "http"
        comps.host = host
        comps.port = port
        return comps.url ?? URL(string: "http://\(host):\(port)")!
    }

    var webSocketURL: URL {
        var comps = URLComponents()
        comps.scheme = useTLS ? "wss" : "ws"
        comps.host = host
        comps.port = port
        comps.path = "/ws"
        return comps.url!
    }

    static let loopback = ConnectionSettings(host: "127.0.0.1", port: 8787, useTLS: false)

    static func load() -> ConnectionSettings {
        let d = UserDefaults.standard
        return ConnectionSettings(
            host: d.string(forKey: "sr.host") ?? "192.168.1.50",
            port: d.object(forKey: "sr.port") as? Int ?? 8787,
            useTLS: d.bool(forKey: "sr.tls")
        )
    }

    func save() {
        UserDefaults.standard.set(host, forKey: "sr.host")
        UserDefaults.standard.set(port, forKey: "sr.port")
        UserDefaults.standard.set(useTLS, forKey: "sr.tls")
    }
}
