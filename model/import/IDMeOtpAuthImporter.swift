import Foundation
import Security

@objcMembers
final class IDMeOtpAuthImporter: NSObject {
    private enum Constants {
        static let activationHost = "account.id.me"
        static let activationPathPrefix = "/mobile/generator/"
        static let baseURL = "https://api.id.me/api/mobile/v3"

        
        
        static let platform = "Android"
        static let osVersion = "16"
        static let apiLevel = 36
        static let manufacturer = "Google"
        static let model = "Pixel 10 Pro XL"
        static let deviceName = "AUTHN"
        static let appVersionName = "1.12.0-2025082916"
        static let appVersionCode = "2025082916"

        static let userAgent = "me.id.auth/\(appVersionName)/\(appVersionCode) (Android \(osVersion)/API \(apiLevel); \(model)/\(manufacturer))"
    }

    private enum ImportError: LocalizedError {
        case unsupportedActivationURL
        case requestFailed(statusCode: Int, message: String)
        case serviceRejected(String)
        case upgradeRequired
        case noPendingRegistration
        case missingOtpAuthURL
        case invalidOtpAuthURL
        case invalidPublicKey
        case securityFailure(String)
        case networkFailure(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedActivationURL:
                return NSLocalizedString("idme_totp_import_invalid_activation_url",
                                         comment: "This QR code is not a supported ID.me activation link.")
            case let .requestFailed(statusCode, message):
                if message.isEmpty {
                    return String(format: NSLocalizedString("idme_totp_import_request_failed_fmt",
                                                           comment: "ID.me rejected the activation request (HTTP %ld). Start setup again in ID.me and rescan the QR code."),
                                  statusCode)
                }

                return String(format: NSLocalizedString("idme_totp_import_request_failed_with_message_fmt",
                                                       comment: "ID.me rejected the activation request (HTTP %ld): %@"),
                              statusCode,
                              message)
            case let .serviceRejected(message):
                if message.isEmpty {
                    return NSLocalizedString("idme_totp_import_service_rejected",
                                             comment: "ID.me rejected the authenticator activation. Start setup again in ID.me and rescan the QR code.")
                }

                return String(format: NSLocalizedString("idme_totp_import_service_rejected_with_message_fmt",
                                                       comment: "ID.me rejected the authenticator activation: %@"),
                              message)
            case .upgradeRequired:
                return NSLocalizedString("idme_totp_import_upgrade_required",
                                         comment: "ID.me requires a newer mobile app protocol than Strongbox currently supports.")
            case .noPendingRegistration:
                return NSLocalizedString("idme_totp_import_no_pending_registration",
                                         comment: "ID.me did not return a pending authenticator registration. Start setup again in ID.me and rescan the QR code.")
            case .missingOtpAuthURL:
                return NSLocalizedString("idme_totp_import_missing_otpauth",
                                         comment: "ID.me did not return a standard OTPAuth URL for this activation.")
            case .invalidOtpAuthURL:
                return NSLocalizedString("idme_totp_import_invalid_otpauth",
                                         comment: "ID.me returned an invalid OTPAuth URL for this activation.")
            case .invalidPublicKey:
                return NSLocalizedString("idme_totp_import_invalid_public_key",
                                         comment: "Strongbox could not prepare the ID.me activation request.")
            case let .securityFailure(message):
                return message
            case let .networkFailure(message):
                return message
            }
        }
    }

    private struct ActivationInfo {
        let token: String
        let code: String

        init(url: URL) throws {
            guard url.scheme?.lowercased() == "https",
                  url.host?.lowercased() == Constants.activationHost
            else {
                throw ImportError.unsupportedActivationURL
            }

            let components = url.pathComponents.filter { $0 != "/" }
            guard components.count == 4,
                  components[0].lowercased() == "mobile",
                  components[1].lowercased() == "generator",
                  !components[2].isEmpty,
                  !components[3].isEmpty
            else {
                throw ImportError.unsupportedActivationURL
            }

            token = components[2]
            code = components[3]
        }
    }

    private struct RegisterDeviceRequest: Encodable {
        let platform: String
        let version: String
        let revision: String
        let model: String
        let name: String
        let uuid: String
        let token: String
    }

    private struct RegisterDeviceResponse: Decodable {
        let upgrade: Bool
    }

    private struct ActivateDeviceRequest: Encodable {
        let token: String
        let code: String
        let publicKey: String

        enum CodingKeys: String, CodingKey {
            case token
            case code
            case publicKey = "public_key"
        }
    }

    private struct ActivatedDevice: Decodable {
        let uuid: String
        let email: String
    }

    private struct EventsRequest: Encodable {
        let handles: [String]
    }

    private struct EventsResponse: Decodable {
        let registration: [RegistrationEvent]
    }

    private struct RegistrationEvent: Decodable {
        let uuid: String
        let kind: String
        let status: String
    }

    private struct GeneratorRegistrationRequest: Encodable {
        let token: String
        let code: String
    }

    private struct GeneratorRegistrationResponse: Decodable {
        let success: Bool
        let code: String?
        let message: String?
        let qrCode: String?

        enum CodingKeys: String, CodingKey {
            case success
            case code
            case message
            case qrCode = "qr_code"
        }
    }

    @objc(canImport:)
    class func canImport(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased(),
              host == Constants.activationHost
        else {
            return false
        }

        return url.path.lowercased().hasPrefix(Constants.activationPathPrefix)
    }

    @objc(canImportActivationString:)
    class func canImport(activationString: String) -> Bool {
        guard let url = activationString.urlExtendedParse else {
            return false
        }

        return canImport(url)
    }

    @objc(importTokenFromActivationString:completion:)
    class func importToken(fromActivationString activationString: String,
                           completion: @escaping (OTPToken?, NSError?) -> Void) {
        Task {
            do {
                let token = try await importToken(fromActivationString: activationString)
                await MainActor.run {
                    completion(token, nil)
                }
            } catch {
                await MainActor.run {
                    completion(nil, error as NSError)
                }
            }
        }
    }

    class func importToken(fromActivationString activationString: String) async throws -> OTPToken {
        guard let url = activationString.urlExtendedParse else {
            throw ImportError.unsupportedActivationURL
        }

        return try await importToken(fromActivationURL: url)
    }

    class func importToken(fromActivationURL activationURL: URL) async throws -> OTPToken {
        let activation = try ActivationInfo(url: activationURL)
        let deviceUUID = try randomHexString(byteCount: 8)
        let publicKey = try base64EncodedPEMEncodedPublicKey()

        let deviceSession = makeSession(deviceUUID: deviceUUID, deviceUser: nil)

        let registerBody = RegisterDeviceRequest(platform: Constants.platform,
                                                 version: String(Constants.apiLevel),
                                                 revision: Constants.appVersionName,
                                                 model: Constants.model,
                                                 name: Constants.deviceName,
                                                 uuid: deviceUUID,
                                                 token: "")
        let registerResponse: RegisterDeviceResponse = try await postJSON(session: deviceSession,
                                                                          path: "devices/register",
                                                                          body: registerBody)
        if registerResponse.upgrade {
            throw ImportError.upgradeRequired
        }

        let activateBody = ActivateDeviceRequest(token: activation.token,
                                                 code: activation.code,
                                                 publicKey: publicKey)
        let activated: ActivatedDevice = try await postJSON(session: deviceSession,
                                                            path: "devices/activate",
                                                            body: activateBody)

        let userSession = makeSession(deviceUUID: deviceUUID, deviceUser: activated.uuid)
        let events: EventsResponse = try await postJSON(session: userSession,
                                                        path: "events",
                                                        body: EventsRequest(handles: []))

        guard let registration = events.registration.first(where: { $0.kind == "registration" && $0.status == "waiting" }) else {
            throw ImportError.noPendingRegistration
        }

        let generatorBody = GeneratorRegistrationRequest(token: activation.token,
                                                         code: activation.code)
        let generator: GeneratorRegistrationResponse = try await postJSON(session: userSession,
                                                                          path: "events/generator/\(registration.uuid)/registrations",
                                                                          body: generatorBody)

        guard generator.success else {
            let message = [generator.code, generator.message]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ": ")
            throw ImportError.serviceRejected(message)
        }

        guard let qrCode = generator.qrCode, !qrCode.isEmpty else {
            throw ImportError.missingOtpAuthURL
        }

        guard let otpURL = qrCode.urlExtendedParse else {
            throw ImportError.invalidOtpAuthURL
        }

        guard let token = OTPToken(url: otpURL) else {
            throw ImportError.invalidOtpAuthURL
        }

        return token
    }

    private class func makeSession(deviceUUID: String, deviceUser: String?) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30

        var headers: [String: String] = [
            "user-agent": Constants.userAgent,
            "x-device-name": Constants.deviceName,
            "x-device-uuid": deviceUUID,
            "accept": "application/json",
            "content-type": "application/json",
        ]

        if let deviceUser {
            headers["x-device-user"] = deviceUser
        }

        config.httpAdditionalHeaders = headers
        return URLSession(configuration: config)
    }

    private class func postJSON<Request: Encodable, Response: Decodable>(session: URLSession,
                                                                         path: String,
                                                                         body: Request) async throws -> Response {
        guard let baseURL = URL(string: Constants.baseURL) else {
            throw ImportError.networkFailure(NSLocalizedString("generic_error", comment: "Error"))
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ImportError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImportError.networkFailure(NSLocalizedString("generic_error", comment: "Error"))
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ImportError.requestFailed(statusCode: httpResponse.statusCode, message: bodyMessage)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ImportError.networkFailure(error.localizedDescription)
        }
    }

    private class func randomHexString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard result == errSecSuccess else {
            throw ImportError.securityFailure(NSLocalizedString("idme_totp_import_random_failed",
                                                                comment: "Strongbox could not generate secure random data for the ID.me activation request."))
        }

        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private class func base64EncodedPEMEncodedPublicKey() throws -> String {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: false,
            ],
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw ImportError.securityFailure((error?.takeRetainedValue() as Error?)?.localizedDescription
                ?? NSLocalizedString("idme_totp_import_key_generation_failed",
                                     comment: "Strongbox could not generate an RSA key for ID.me activation."))
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
        else {
            throw ImportError.invalidPublicKey
        }

        let subjectPublicKeyInfo = wrapRSAPublicKeyInSubjectPublicKeyInfo(publicKeyData)
        let publicKeyPEM = pemString(for: subjectPublicKeyInfo)
        return Data(publicKeyPEM.utf8).base64EncodedString()
    }

    private class func pemString(for der: Data) -> String {
        let base64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----\n"
    }

    private class func wrapRSAPublicKeyInSubjectPublicKeyInfo(_ rsaPublicKey: Data) -> Data {
        let algorithmIdentifier = Data([
            0x30, 0x0d,
            0x06, 0x09,
            0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
            0x05, 0x00,
        ])

        var bitStringContent = Data([0x00])
        bitStringContent.append(rsaPublicKey)

        let bitString = asn1(tag: 0x03, content: bitStringContent)
        return asn1(tag: 0x30, content: algorithmIdentifier + bitString)
    }

    private class func asn1(tag: UInt8, content: Data) -> Data {
        var encoded = Data([tag])
        encoded.append(asn1Length(content.count))
        encoded.append(content)
        return encoded
    }

    private class func asn1Length(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }

        var value = length
        var bytes: [UInt8] = []

        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }

        var encoded = Data([0x80 | UInt8(bytes.count)])
        encoded.append(contentsOf: bytes)
        return encoded
    }
}
