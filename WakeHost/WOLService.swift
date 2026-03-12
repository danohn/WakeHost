import Foundation
import OSLog

struct HostsResponse: Decodable {
    let rows: [WOLHost]
}

enum WOLServiceError: LocalizedError {
    case missingAddress
    case missingPort
    case missingCredentials
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case requestFailed(statusCode: Int, message: String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAddress:
            return "Enter your OPNsense address in Settings."
        case .missingPort:
            return "Enter your OPNsense port in Settings."
        case .missingCredentials:
            return "Enter your API key and secret in Settings."
        case .invalidURL:
            return "The OPNsense server address is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .authenticationFailed:
            return "Authentication failed. Check your API key and secret."
        case .requestFailed(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Request failed (\(statusCode)): \(message)"
            }
            return "Request failed with HTTP \(statusCode)."
        case .emptyResponse:
            return "The server returned an empty response."
        }
    }
}

final class WOLService {
    private static let logger = Logger(subsystem: "com.dohnesorge.WakeHost", category: "network")
    private let viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    func testConnection() async throws {
        var request = try makeRequest(path: "/api/wol/wol/search_host")
        request.httpMethod = "GET"

        let (data, response) = try await performRequest(request)
        try validate(response: response, data: data, requestURL: request.url)

        guard !data.isEmpty else {
            throw WOLServiceError.emptyResponse
        }

        _ = try JSONDecoder().decode(HostsResponse.self, from: data)
    }

    func fetchHosts() async throws -> [WOLHost] {
        var request = try makeRequest(path: "/api/wol/wol/search_host")
        request.httpMethod = "GET"

        let (data, response) = try await performRequest(request)
        try validate(response: response, data: data, requestURL: request.url)

        guard !data.isEmpty else {
            throw WOLServiceError.emptyResponse
        }

        return try JSONDecoder().decode(HostsResponse.self, from: data).rows
    }

    func wakeHost(uuid: String) async throws {
        var request = try makeRequest(path: "/api/wol/wol/set")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(WakeHostRequest(uuid: uuid))

        let (data, response) = try await performRequest(request)
        try validate(response: response, data: data, requestURL: request.url)
    }

    private func makeRequest(path: String) throws -> URLRequest {
        let configuration = try configuration()

        var components = URLComponents()
        components.scheme = configuration.scheme
        components.host = configuration.host
        components.port = configuration.port
        components.path = path

        guard let url = components.url else {
            throw WOLServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(configuration.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        return request
    }

    private func configuration() throws -> Configuration {
        let trimmedAddress = viewModel.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = viewModel.port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = viewModel.key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = viewModel.secret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            throw WOLServiceError.missingAddress
        }

        guard !trimmedPort.isEmpty, let port = Int(trimmedPort) else {
            throw WOLServiceError.missingPort
        }

        guard !trimmedKey.isEmpty, !trimmedSecret.isEmpty else {
            throw WOLServiceError.missingCredentials
        }

        let normalizedAddress = trimmedAddress.contains("://") ? trimmedAddress : "https://\(trimmedAddress)"
        guard let components = URLComponents(string: normalizedAddress),
              let host = components.host,
              !host.isEmpty else {
            throw WOLServiceError.invalidURL
        }

        let cred = "\(trimmedKey):\(trimmedSecret)"
        guard let data = cred.data(using: .utf8) else {
            throw WOLServiceError.invalidResponse
        }
        let authorizationHeader = "Basic \(data.base64EncodedString())"

        return Configuration(
            scheme: components.scheme ?? "https",
            host: host,
            port: components.port ?? port,
            authorizationHeader: authorizationHeader
        )
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return (data, response)
        } catch {
            let requestURL = request.url?.absoluteString ?? "<missing-url>"
            Self.logger.error("Request failed before response. URL: \(requestURL, privacy: .public), error: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func validate(response: URLResponse, data: Data, requestURL: URL?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WOLServiceError.invalidResponse
        }

        let originalURL = requestURL?.absoluteString ?? "<missing-url>"
        let finalURL = httpResponse.url?.absoluteString ?? "<missing-url>"
        Self.logger.info("HTTP \(httpResponse.statusCode) for \(originalURL, privacy: .public) -> \(finalURL, privacy: .public)")

        if let finalURL = httpResponse.url?.absoluteString,
           finalURL.contains("/?url=") {
            Self.logger.error("Authentication redirect detected for \(originalURL, privacy: .public)")
            throw WOLServiceError.authenticationFailed
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw WOLServiceError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }

    private struct Configuration {
        let scheme: String
        let host: String
        let port: Int
        let authorizationHeader: String
    }

    private struct WakeHostRequest: Encodable {
        let uuid: String
    }
}
