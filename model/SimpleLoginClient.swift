import Foundation

@objc
public enum SimpleLoginError: Int, Error {
    case apiKeyNotConfigured
    case invalidApiKey
    case rateLimited
    case freePlanLimitReached
    case networkError
    case serverError
    case unexpectedResponse
}

@objc
public class SimpleLoginAlias: NSObject {
    @objc public let email: String
    @objc public let aliasId: Int

    init(email: String, aliasId: Int) {
        self.email = email
        self.aliasId = aliasId
    }
}

@objc
public class SimpleLoginUserInfo: NSObject {
    @objc public let name: String
    @objc public let email: String
    @objc public let isPremium: Bool

    init(name: String, email: String, isPremium: Bool) {
        self.name = name
        self.email = email
        self.isPremium = isPremium
    }
}

@objc
public class SimpleLoginClient: NSObject {
    @objc public static let shared = SimpleLoginClient()

    private static let baseURL = "https://app.simplelogin.io"
    private static let apiKeyIdentifier = "simpleLoginApiKey"

    private let urlSession: URLSession

    private override init() {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        urlSession = URLSession(configuration: config)

        super.init()
    }

    @objc public func setApiKey(_ key: String?) {
        if let key, !key.isEmpty {
            SecretStore.sharedInstance().setSecureString(key, forIdentifier: SimpleLoginClient.apiKeyIdentifier)
        } else {
            SecretStore.sharedInstance().deleteSecureItem(SimpleLoginClient.apiKeyIdentifier)
        }
    }

    @objc public func getApiKey() -> String? {
        return SecretStore.sharedInstance().getSecureString(SimpleLoginClient.apiKeyIdentifier)
    }

    @objc public var isConfigured: Bool {
        guard let key = getApiKey() else { return false }
        return !key.isEmpty
    }

    public func getUserInfo() async throws -> SimpleLoginUserInfo {
        guard let apiKey = getApiKey(), !apiKey.isEmpty else {
            throw SimpleLoginError.apiKeyNotConfigured
        }

        var request = URLRequest(url: URL(string: "\(SimpleLoginClient.baseURL)/api/user_info")!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authentication")

        let (data, _) = try await performRequest(request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SimpleLoginError.unexpectedResponse
        }

        guard let email = json["email"] as? String else {
            throw SimpleLoginError.unexpectedResponse
        }

        let name = json["name"] as? String ?? ""
        let isPremium = json["is_premium"] as? Bool ?? false

        return SimpleLoginUserInfo(name: name, email: email, isPremium: isPremium)
    }

    public func createRandomAlias(hostname: String? = nil, note: String? = nil) async throws -> SimpleLoginAlias {
        guard let apiKey = getApiKey(), !apiKey.isEmpty else {
            throw SimpleLoginError.apiKeyNotConfigured
        }

        var urlString = "\(SimpleLoginClient.baseURL)/api/alias/random/new"

        if let hostname, !hostname.isEmpty {
            if let encoded = hostname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?hostname=\(encoded)"
            }
        }

        guard let url = URL(string: urlString) else {
            throw SimpleLoginError.unexpectedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authentication")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let note, !note.isEmpty {
            let body: [String: Any] = ["note": note]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }

        let (data, _) = try await performRequest(request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String,
              let aliasId = json["id"] as? Int else {
            throw SimpleLoginError.unexpectedResponse
        }

        return SimpleLoginAlias(email: email, aliasId: aliasId)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw SimpleLoginError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleLoginError.unexpectedResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            return (data, httpResponse)
        case 401:
            throw SimpleLoginError.invalidApiKey
        case 429:
            throw SimpleLoginError.rateLimited
        case 400:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String,
               error.lowercased().contains("limit") || error.lowercased().contains("plan") {
                throw SimpleLoginError.freePlanLimitReached
            }
            throw SimpleLoginError.unexpectedResponse
        case 500 ... 599:
            throw SimpleLoginError.serverError
        default:
            throw SimpleLoginError.unexpectedResponse
        }
    }

    @objc public static func localizedErrorMessage(_ error: SimpleLoginError) -> String {
        switch error {
        case .apiKeyNotConfigured:
            return NSLocalizedString("simplelogin_error_api_key_not_configured", comment: "SimpleLogin API key is not configured. Please add your API key in Settings.")
        case .invalidApiKey:
            return NSLocalizedString("simplelogin_error_invalid_api_key", comment: "Invalid SimpleLogin API key. Please check your key in Settings.")
        case .rateLimited:
            return NSLocalizedString("simplelogin_error_rate_limited", comment: "Too many requests. Please try again later.")
        case .freePlanLimitReached:
            return NSLocalizedString("simplelogin_error_free_plan_limit", comment: "You have reached the alias limit for your SimpleLogin plan.")
        case .networkError:
            return NSLocalizedString("simplelogin_error_network", comment: "Network error. Please check your internet connection.")
        case .serverError:
            return NSLocalizedString("simplelogin_error_server", comment: "SimpleLogin server error. Please try again later.")
        case .unexpectedResponse:
            return NSLocalizedString("simplelogin_error_unexpected", comment: "Unexpected response from SimpleLogin.")
        }
    }

    @objc public func getUserInfoWithCompletion(_ completion: @escaping (SimpleLoginUserInfo?, NSError?) -> Void) {
        Task {
            do {
                let info = try await getUserInfo()
                await MainActor.run { completion(info, nil) }
            } catch {
                let nsError = error as NSError
                await MainActor.run { completion(nil, nsError) }
            }
        }
    }

    @objc public func createRandomAliasWithHostname(_ hostname: String?,
                                                     note: String?,
                                                     completion: @escaping (SimpleLoginAlias?, NSError?) -> Void) {
        Task {
            do {
                let alias = try await createRandomAlias(hostname: hostname, note: note)
                await MainActor.run { completion(alias, nil) }
            } catch {
                let nsError = error as NSError
                await MainActor.run { completion(nil, nsError) }
            }
        }
    }

    @objc public static func extractHostname(from urlString: String?) -> String? {
        guard let urlString, !urlString.isEmpty else { return nil }

        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if !str.contains("://") {
            str = "https://\(str)"
        }

        return URL(string: str)?.host
    }
}
