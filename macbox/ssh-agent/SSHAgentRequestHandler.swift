//
//  SSHAgentRequestHandler.swift
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa
import LocalAuthentication

class SSHAgentRequestHandler: NSObject {
    @objc static let shared = SSHAgentRequestHandler()
    
    private enum Constants {
        static let SecureOfflinePkMapKey = "ssh-agent-offline-public-key-db-map"
    }
    
    override private init() {
        super.init()
    }
    
    @objc
    public func updateOffilnePublicKeysForDatabase ( publicKeyBlobs : [Data], databaseUuid : String ) {
        var pkMap : [Data : String] = [:]
        
        if let map = SecretStore.sharedInstance().getSecureObject(Constants.SecureOfflinePkMapKey),
           let typed = map as? [Data : String] {
            
            
            
            let filtered = typed.filter { element in
                element.value != databaseUuid
            }
            
            pkMap = filtered
        }
        
        for publicKeyBlob in publicKeyBlobs {
            pkMap[publicKeyBlob] = databaseUuid
        }
        
        SecretStore.sharedInstance().setSecureObject(pkMap, forIdentifier: Constants.SecureOfflinePkMapKey)
    }
    
    @objc public func clearAllOfflinePublicKeys() {
        SecretStore.sharedInstance().deleteSecureItem(Constants.SecureOfflinePkMapKey);
    }
    
    public func getOfflinePublicKeys() -> [Data : String] {
        if let map = SecretStore.sharedInstance().getSecureObject(Constants.SecureOfflinePkMapKey),
           let typed = map as? [Data : String] {
            return typed
        }
        
        return [:]
    }
    
    @objc
    public func getKnownPublicKeys() -> [Data] {
        
        
        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        var used : Set<Data> = []
        var ret : [Data] = []
        for meta in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: meta.uuid) else {
                continue
            }
                    
            for node in model.keeAgentSSHKeyEntries {
                guard let data = node.keeAgentEnabledSshPrivateKeyData, let key = OpenSSHPrivateKey.fromData(data) else {
                    continue
                }
                
                NSLog("✅ Returning Identity %@", key );

                let pkBlob = key.publicKeySerializationBlob
                if !used.contains( pkBlob ) {
                    ret.append( pkBlob )
                    used.insert( pkBlob )
                }
            }
        }
        
        
        
        let offlinePks = getOfflinePublicKeys().keys
        for pkBlob in offlinePks {
            if !used.contains( pkBlob ) {
                ret.append( pkBlob )
                used.insert( pkBlob )
            }
        }
        
        return ret
    }
        
    @objc
    public func signChallenge ( _ challenge : Data, requestedKeyBlobB64 : String, processName : String?, flags : u_int ) -> Data? {
        if let node = getNodeBySerializationBlobBase64(requestedKeyBlobB64) {
            return signChallengeWithNode(node, challenge, requestedKeyBlobB64: requestedKeyBlobB64, processName: processName, flags: flags)
        }
        else {
            NSLog("Could not find requested key in Unlocked Databases to sign in with... Checking Offline Map");
            
            guard let node = getNodeFromOfflinePublicKeyWithUnlock( requestedKeyBlobB64, processName: processName ) else {
                NSLog("🔴 Unsuccessful Unlock or find the request key in the unlocked database")
                return nil
            }
            
            return signChallengeWithNode(node, challenge, requestedKeyBlobB64: requestedKeyBlobB64, processName: processName, flags: flags, skipAuthorize: true)
        }
    }
    
    private func getNodeFromOfflinePublicKeyWithUnlock ( _ requestedKeyBlobB64 : String, processName : String?) -> Node? {
        let offlinePks = getOfflinePublicKeys()
        
        guard let requestKeyData = requestedKeyBlobB64.dataFromBase64,
              let databaseUuid = offlinePks[requestKeyData],
              let database = MacDatabasePreferences.getById(databaseUuid) else {
            NSLog("Could not find requested key in Offline PK Cache to sign in with... Cannot Sign.");
            return nil
        }
        
        var go = false
        let g = DispatchGroup()
        g.enter()
        
        let pname = processName ?? NSLocalizedString("ssh_agent_unknown_process", comment: "Unknown Process")
        let reason = String (format: NSLocalizedString("ssh_agent_approve_unlock_key_use_fmt", comment: "unlock \"%@\" to allow \"%@\" to use an SSH Key"), database.nickName, pname )

        DatabasesCollection.shared.initiateDatabaseUnlock(uuid: databaseUuid,
                                                          message : reason ) { success in
            go = success
            g.leave()
        }
        
        if g.wait(timeout: .now() + 15) == .timedOut {
            NSLog("⚠️ Waiting for Database Unlock, timed out.")
        }
        else {
            NSLog("Waiting for Database Unlock done, result = [%@]", localizedOnOrOffFromBool(go))
        }

        guard go else {
            return nil
        }
        
        return getNodeBySerializationBlobBase64(requestedKeyBlobB64);
    }
    
    private func signChallengeWithNode ( _ node : Node, _ challenge : Data, requestedKeyBlobB64 : String, processName : String?, flags : u_int, skipAuthorize : Bool = false ) -> Data? {
        
        
        if !skipAuthorize && Settings.sharedInstance().requireApprovalSshAgent {
            guard requestSignatureAuthorization(node, processName: processName) else {
                NSLog("⚠️ Authorization Denied - Will not sign request");
                return nil;
            }
        }
        
        
        
        guard let data = node.keeAgentEnabledSshPrivateKeyData, let theKey = OpenSSHPrivateKey.fromData(data) else {
            return nil
        }
        
        return theKey.sign(challenge, passphrase: node.fields.password, flags: flags)
    }
    
    private func getNodeBySerializationBlobBase64( _ blobBase64 : String ) -> Node? {
        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }
        
        for meta in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: meta.uuid) else {
                continue
            }
            
            for node in model.keeAgentSSHKeyEntries {
                guard let data = node.keeAgentEnabledSshPrivateKeyData, let theKey = OpenSSHPrivateKey.fromData(data) else {
                    continue
                }

                if theKey.publicKeySerializationBlobBase64 == blobBase64 {
                    return node
                }
            }
        }
        
        return nil
    }
    
    private func requestSignatureAuthorization( _ node : Node, processName : String? ) -> Bool {
        
        
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print(error?.localizedDescription ?? "Can't evaluate policy")
            return false
        }
        
        let pname = processName ?? NSLocalizedString("ssh_agent_unknown_process", comment: "Unknown Process")
        let reason = String (format: NSLocalizedString("ssh_agent_approve_key_use_fmt", comment: "allow \"%@\" to use the key \"%@\" for SSH"), pname, node.title )
        
        
        
        var go = false
        let g = DispatchGroup()
        g.enter()
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            if let error {
                print(error.localizedDescription)
            }
            
            go = success
            
            g.leave()
        }
        
        g.wait()
        
        return go
    }
}
