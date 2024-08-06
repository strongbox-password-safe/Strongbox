//
//  WiFiSyncServerConnectionConfig.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

@objc
class WiFiSyncServerConnectionConfig: NSObject, Codable {
    @objc var serverName: String
    @objc var databaseId: String

    var passcodeSEUuid: String

    var passcode: String? {
        get {
            guard let passcode = SecretStore.sharedInstance().getSecureString(keychainIdentifier) else {
                swlog("🔴 Could not get Passcode in the SE for [%@]", keychainIdentifier)
                return nil
            }

            return passcode
        }
        set {
            if let newPasscode = newValue {
                SecretStore.sharedInstance().setSecureString(newValue, forIdentifier: keychainIdentifier)
            } else {
                SecretStore.sharedInstance().deleteSecureItem(keychainIdentifier)
            }
        }
    }

    var keychainIdentifier: String {
        WiFiSyncServerConnectionConfig.getKeyChainIdentifier(passcodeSEUuid)
    }

    class func getKeyChainIdentifier(_ passcodeSEUuid: String) -> String {
        String(format: "WiFiSyncServerConnectionConfig-%@", passcodeSEUuid)
    }

    

    class func newConfig(databaseId: String, serverName: String, passcode: String) -> WiFiSyncServerConnectionConfig {
        let uuid = UUID().uuidString

        SecretStore.sharedInstance().setSecureString(passcode, forIdentifier: getKeyChainIdentifier(uuid))

        return WiFiSyncServerConnectionConfig(databaseId: databaseId, serverName: serverName, passcodeSEUuid: uuid)
    }

    var json: String {
        let data = try? JSONEncoder().encode(self)

        guard let data, let str = String(data: data, encoding: .utf8) else {
            swlog("🔴 Could not encode WiFiSyncServerConnectionConfig to JSON")
            return "{}"
        }

        return str
    }

    class func fromJson(_ json: String) -> WiFiSyncServerConnectionConfig? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONDecoder().decode(WiFiSyncServerConnectionConfig.self, from: data)
        else {
            swlog("🔴 Could not convert JSON string to object")
            return nil
        }

        return obj
    }

    @objc
    init(databaseId: String, serverName: String, passcodeSEUuid: String) {
        self.databaseId = databaseId
        self.serverName = serverName
        self.passcodeSEUuid = passcodeSEUuid
    }
}
