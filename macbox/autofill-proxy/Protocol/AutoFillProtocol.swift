//
//  AutoFillProtocol.swift
//  MacBox
//
//  Created by Strongbox on 24/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import CryptoKit
import Foundation

@objc
enum AutoFillMessageType: NSInteger, Codable, CustomStringConvertible {
    var description: String {
        switch self {
        case .status:
            return "status"
        case .search:
            return "search"
        case .getCredentialsForUrl:
            return "getCredentialsForUrl"
        case .copyField:
            return "copyField"
        case .lock:
            return "lock"
        case .unlock:
            return "unlock"
        case .createEntry:
            return "createEntry"
        case .getGroups:
            return "getGroups"
        case .getNewEntryDefaults:
            return "getNewEntryDefaults"
        case .generatePassword:
            return "generatePassword"
        case .getIcon:
            return "getIcon"
        case .generatePasswordV2:
            return "generatePasswordV2"
        case .getPasswordStrength:
            return "getPasswordStrength"
        case .getNewEntryDefaultsV2:
            return "getNewEntryDefaultsV2"
        case .getFavourites:
            return "getFavourites"
        case .copyString:
            return "copyString"
        }
    }

    case status
    case search
    case getCredentialsForUrl
    case copyField
    case lock
    case unlock
    case createEntry
    case getGroups
    case getNewEntryDefaults
    case generatePassword
    case getIcon
    case generatePasswordV2
    case getPasswordStrength
    case getNewEntryDefaultsV2
    case getFavourites
    case copyString
}

enum AutoFillProtocolError: Error {
    case generic(detail: String)
}

@objc
public class AutoFillEncryptedRequest: NSObject, Codable {
    @objc var clientPublicKey: String = ""
    @objc var nonce: String = ""
    @objc var message: String = ""
    @objc var messageType: AutoFillMessageType = .status

    class func createEncryptedRequest(_ receiverPublicKey: String? = nil, _ message: String? = nil, _ messageType: AutoFillMessageType = .status) throws -> (AutoFillEncryptedRequest, String) {
        let keyPair: BoxKeyPair = CryptoBoxHelper.createKeyPair()

        let ret = AutoFillEncryptedRequest()

        ret.nonce = CryptoBoxHelper.createNonce()
        ret.messageType = messageType
        ret.clientPublicKey = keyPair.publicKey

        if let message {
            guard let receiverPublicKey else {
                throw AutoFillProtocolError.generic(detail: "Could not seal with crypto box because no receiver public key was provided.")
            }

            guard let cipherText = CryptoBoxHelper.seal(message, nonce: ret.nonce, theirPublicKey: receiverPublicKey, myPrivateKey: keyPair.privateKey) else {
                throw AutoFillProtocolError.generic(detail: "Could not seal with crypto box.")
            }
            ret.message = cipherText
        }

        return (ret, keyPair.privateKey)
    }

    @objc
    class func from(json: String) -> AutoFillEncryptedRequest? {
        let decoder = JSONDecoder()

        guard let data = json.data(using: .utf8),
              let encryptedRequest = try? decoder.decode(AutoFillEncryptedRequest.self, from: data)
        else {
            swlog("🔴 Could not decode AutoFillEncryptedRequest object from JSON")
            return nil
        }

        return encryptedRequest
    }

    func decryptMessage(keyPair: BoxKeyPair) -> String? {
        if message.count > 0 {
            return CryptoBoxHelper.unSeal(message, nonce: nonce, theirPublicKey: clientPublicKey, myPrivateKey: keyPair.privateKey)
        } else {
            return ""
        }
    }

    func toJson() -> String {
        AutoFillJsonHelper.toJson(object: self)
    }
}

@objc
class AutoFillEncryptedResponse: NSObject, Codable {
    @objc var success: Bool = false
    @objc var errorMessage: String = ""
    @objc var serverPublicKey: String = ""
    @objc var message: String = ""
    @objc var nonce: String = ""

    class func error(message: String) -> AutoFillEncryptedResponse {
        let ret = AutoFillEncryptedResponse()

        ret.success = false
        ret.errorMessage = message
        ret.serverPublicKey = ""

        return ret
    }

    class func successWithResult(resultJson: String, clientPublicKey: String, keyPair: BoxKeyPair) -> AutoFillEncryptedResponse {
        let nonce = CryptoBoxHelper.createNonce()

        guard let cipherText = CryptoBoxHelper.seal(resultJson, nonce: nonce, theirPublicKey: clientPublicKey, myPrivateKey: keyPair.privateKey) else {
            return error(message: "Could not seal with crypto box.")
        }

        let ret = AutoFillEncryptedResponse()

        ret.success = true
        ret.message = cipherText
        ret.nonce = nonce
        ret.serverPublicKey = keyPair.publicKey

        return ret
    }

    @objc
    class func from(json: String) -> AutoFillEncryptedResponse? {
        let decoder = JSONDecoder()

        guard let data = json.data(using: .utf8),
              let response = try? decoder.decode(AutoFillEncryptedResponse.self, from: data)
        else {
            swlog("🔴 Could not decode AutoFillEncryptedRequest object from JSON")
            return nil
        }

        return response
    }

    func decryptMessage(keyPair: BoxKeyPair) -> String? {
        decryptMessage(privateKey: keyPair.privateKey)
    }

    func decryptMessage(privateKey: String) -> String? {
        if message.count > 0 {
            return CryptoBoxHelper.unSeal(message, nonce: nonce, theirPublicKey: serverPublicKey, myPrivateKey: privateKey)
        } else {
            return ""
        }
    }

    @objc func toJson() -> String {
        AutoFillJsonHelper.toJson(object: self)
    }
}

class AutoFillJsonHelper {
    class func toJson(object: some Codable) -> String {
        let encoder = JSONEncoder()



        guard let encodedData = try? encoder.encode(object),
              let jsonString = String(data: encodedData, encoding: .utf8)
        else {
            swlog("🔴 Could not encode to JSON")
            return "{ \"error\" : \"🔴 Could not encode to JSON\" }"
        }

        return jsonString
    }
}
