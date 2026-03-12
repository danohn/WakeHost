import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var address: String {
        didSet { UserDefaults.standard.set(address, forKey: "opn_address") }
    }
    @Published var port: String {
        didSet { UserDefaults.standard.set(port, forKey: "opn_port") }
    }
    @Published var key: String
    @Published var secret: String

    init() {
        self.address = UserDefaults.standard.string(forKey: "opn_address") ?? ""
        self.port = UserDefaults.standard.string(forKey: "opn_port") ?? "7443"
        self.key = KeychainHelper.get("opn_key") ?? ""
        self.secret = KeychainHelper.get("opn_secret") ?? ""
    }

    var connectionFingerprint: String {
        [address, port, key, secret].joined(separator: "|")
    }

    var connectionValidation: ConnectionValidation {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            return .warning("Enter your OPNsense address.")
        }

        let normalizedAddress = trimmedAddress.contains("://") ? trimmedAddress : "https://\(trimmedAddress)"
        guard let components = URLComponents(string: normalizedAddress), components.host != nil else {
            return .error("Enter a valid OPNsense address.")
        }

        guard !trimmedPort.isEmpty else {
            return .warning("Enter the OPNsense port.")
        }

        guard let portValue = Int(trimmedPort), (1...65535).contains(portValue) else {
            return .error("Use a port between 1 and 65535.")
        }

        guard !trimmedKey.isEmpty, !trimmedSecret.isEmpty else {
            return .warning("Add your API key and secret in Credentials.")
        }

        return .success("Ready to connect.")
    }

    func saveCredentials(key: String, secret: String) {
        self.key = key
        self.secret = secret

        KeychainHelper.set(key, forKey: "opn_key")
        KeychainHelper.set(secret, forKey: "opn_secret")
    }

    func clearCredentials() {
        key = ""
        secret = ""
        KeychainHelper.delete("opn_key")
        KeychainHelper.delete("opn_secret")
    }
}

enum ConnectionValidation {
    case success(String)
    case warning(String)
    case error(String)

    var message: String {
        switch self {
        case .success(let message), .warning(let message), .error(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
}
