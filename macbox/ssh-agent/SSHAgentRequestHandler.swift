//
//  SSHAgentRequestHandler.swift
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa
import LocalAuthentication

enum SSHAgentApprovalExpiryType: Codable {
    case timed(time: Date)
    case quit
}

struct SSHAgentApproval: Codable {
    var processName: String
    var processId: String
    var expiry: SSHAgentApprovalExpiryType
}

class SSHAgentSignRequest: NSObject {
    var processName: String?
    var processId: String?
    var databaseUuid: String
    var nodeId: UUID
    var approved: Bool
    var timestamp: Date

    init(processName: String? = nil, processId: String? = nil, databaseUuid: String, nodeId: UUID, approved: Bool, timestamp: Date) {
        self.processName = processName
        self.processId = processId
        self.databaseUuid = databaseUuid
        self.nodeId = nodeId
        self.approved = approved
        self.timestamp = timestamp
    }
}

class SSHAgentRequestHandler: NSObject {
    @objc static let shared = SSHAgentRequestHandler()

    private enum Constants {
        static let SecureOfflinePkMapKey = "ssh-agent-offline-public-key-db-map"
    }

    override private init() {
        super.init()
    }

    var signRequests = ConcurrentCircularBuffer<SSHAgentSignRequest>(capacity: 512)

    var rawApprovals: [SSHAgentApproval] = []

    var approvals: [SSHAgentApproval] {
        get {
            let ret = rawApprovals.filter { approval in
                if case let .timed(time: date) = approval.expiry {
                    return (date as NSDate).isInFuture
                } else {
                    return true
                }
            }

            rawApprovals = ret

            return ret
        }
        set {
            rawApprovals = newValue
        }
    }

    func requiresApproval(_ processName: String?) -> Bool {
        guard let processName else { return true }

        let firstApproval = approvals.first(where: { approval in
            approval.processName == processName
        })

        return firstApproval == nil
    }

    func addApproval(_ processName: String, processId: String) {
        let expiryConfig = Settings.sharedInstance().sshAgentApprovalDefaultExpiryMinutes

        let expiry: SSHAgentApprovalExpiryType
        if expiryConfig == -1 {
            expiry = .quit
        } else {
            let date = Date().addSec(n: expiryConfig * 60)
            expiry = .timed(time: date)
        }

        let approval = SSHAgentApproval(processName: processName, processId: processId, expiry: expiry)
        approvals.append(approval)
    }

    @objc
    public func updateOfflinePublicKeysForDatabase(publicKeyBlobs: [Data], databaseUuid: String) {
        var pkMap: [Data: String] = [:]

        if let map = SecretStore.sharedInstance().getSecureObject(Constants.SecureOfflinePkMapKey),
           let typed = map as? [Data: String]
        {
            

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
        SecretStore.sharedInstance().deleteSecureItem(Constants.SecureOfflinePkMapKey)
    }

    public func getOfflinePublicKeys() -> [Data: String] {
        if let map = SecretStore.sharedInstance().getSecureObject(Constants.SecureOfflinePkMapKey),
           let typed = map as? [Data: String]
        {
            return typed
        }

        return [:]
    }

    @objc
    public func getKnownPublicKeys() -> [Data] {


        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        var used: Set<Data> = []
        var ret: [Data] = []
        for meta in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: meta.uuid) else {
                continue
            }

            for node in model.keeAgentSSHKeyEntries {
                guard let kaKey = node.keeAgentSshKeyViewModel, kaKey.enabled else {
                    continue
                }
                let key = kaKey.openSshKey

                

                let pkBlob = key.publicKeySerializationBlob
                if !used.contains(pkBlob) {
                    ret.append(pkBlob)
                    used.insert(pkBlob)
                }
            }
        }

        

        let offlinePks = getOfflinePublicKeys().keys
        for pkBlob in offlinePks {
            if !used.contains(pkBlob) {
                ret.append(pkBlob)
                used.insert(pkBlob)
            }
        }

        return ret
    }

    @objc
    public func signChallenge(_ challenge: Data, requestedKeyBlobB64: String, processName: String?, processId: String?, flags: u_int) -> Data? {
        if let (node, databaseUuid) = getNodeBySerializationBlobBase64(requestedKeyBlobB64) {
            return signChallengeWithNode(node, databaseUuid, challenge, requestedKeyBlobB64: requestedKeyBlobB64, processName: processName, processId: processId, flags: flags)
        } else if Settings.sharedInstance().sshAgentRequestDatabaseUnlockAllowed {
            swlog("Could not find requested key in Unlocked Databases to sign in with... Checking Offline Map")

            guard let (node, databaseUuid) = getNodeFromOfflinePublicKeyWithUnlock(requestedKeyBlobB64, processName: processName) else {
                swlog("🔴 Unsuccessful Unlock or find the request key in the unlocked database")
                return nil
            }

            return signChallengeWithNode(node, databaseUuid, challenge, requestedKeyBlobB64: requestedKeyBlobB64, processName: processName, processId: processId, flags: flags, preAuthorized: true)
        } else {
            swlog("Could not find requested key in Unlocked Databases and not allowed to request Unlock.")
            return nil
        }
    }

    var recentUnlockFailure: Date? = nil

    private func getNodeFromOfflinePublicKeyWithUnlock(_ requestedKeyBlobB64: String, processName: String?) -> (Node, String)? {
        let offlinePks = getOfflinePublicKeys()

        guard let requestKeyData = requestedKeyBlobB64.dataFromBase64,
              let databaseUuid = offlinePks[requestKeyData],
              let database = MacDatabasePreferences.getById(databaseUuid)
        else {
            swlog("Could not find requested key in Offline PK Cache to sign in with... Cannot Sign.")
            return nil
        }

        if Settings.sharedInstance().sshAgentPreventRapidRepeatedUnlockRequests {
            let blockRecentFailsTimeoutSeconds = 3.0
            if let recentFailTime = recentUnlockFailure, (-recentFailTime.timeIntervalSinceNow) < blockRecentFailsTimeoutSeconds {
                swlog("🙅‍♂️ Auto Blocking Unlock Request since it has already been failed %f less than %f seconds ago", -recentFailTime.timeIntervalSinceNow, blockRecentFailsTimeoutSeconds)
                return nil
            }
        }

        

        let pname = processName ?? NSLocalizedString("ssh_agent_unknown_process", comment: "Unknown Process")
        let reason = String(format: NSLocalizedString("ssh_agent_approve_unlock_key_use_fmt", comment: "unlock \"%@\" to allow \"%@\" to use an SSH Key"), database.nickName, pname)

        let go = DatabasesCollection.shared.initiateUnlockWithSynchronousTimeout(databaseUuid, timeoutSeconds: 15, message: reason)

        if go {
            

            DispatchQueue.main.async {
                NSApp.hide(nil)
            }

            return getNodeBySerializationBlobBase64(requestedKeyBlobB64)
        } else {
            recentUnlockFailure = Date()
            return nil
        }
    }

    private func signChallengeWithNode(_ node: Node, _ databaseUuid: String, _ challenge: Data, requestedKeyBlobB64 _: String, processName: String?, processId: String?, flags: u_int, preAuthorized: Bool = false) -> Data? {
        

        if requiresApproval(processName) {
            if !preAuthorized {
                guard requestSignatureAuthorization(node, processName: processName) else {
                    swlog("⚠️ Authorization Denied - Will not sign request")

                    signRequests.add(SSHAgentSignRequest(processName: processName, processId: processId, databaseUuid: databaseUuid, nodeId: node.uuid, approved: false, timestamp: Date()))

                    return nil
                }
            }

            addApproval(processName ?? NSLocalizedString("generic_unknown", comment: "Unknown"),
                        processId: processId ?? NSLocalizedString("generic_unknown", comment: "Unknown"))
        }

        signRequests.add(SSHAgentSignRequest(processName: processName,
                                             processId: processId,
                                             databaseUuid: databaseUuid,
                                             nodeId: node.uuid,
                                             approved: true,
                                             timestamp: Date()))

        

        guard let kaKey = node.keeAgentSshKeyViewModel, kaKey.enabled else {
            return nil
        }
        let theKey = kaKey.openSshKey

        return theKey.sign(challenge, passphrase: node.fields.password, flags: flags)
    }

    private func getNodeBySerializationBlobBase64(_ blobBase64: String) -> (Node, String)? {
        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        for meta in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: meta.uuid) else {
                continue
            }

            for node in model.keeAgentSSHKeyEntries {
                guard let kaKey = node.keeAgentSshKeyViewModel, kaKey.enabled else {
                    continue
                }
                let theKey = kaKey.openSshKey

                if theKey.publicKeySerializationBlobBase64 == blobBase64 {
                    return (node, meta.uuid)
                }
            }
        }

        return nil
    }

    private func requestSignatureAuthorization(_ node: Node, processName: String?) -> Bool {
        

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            swlog(error?.localizedDescription ?? "Can't evaluate policy")
            return false
        }

        let pname = processName ?? NSLocalizedString("ssh_agent_unknown_process", comment: "Unknown Process")
        let reason = String(format: NSLocalizedString("ssh_agent_approve_key_use_fmt", comment: "allow \"%@\" to use the key \"%@\" for SSH"), pname, node.title)

        

        var go = false
        let g = DispatchGroup()
        g.enter()

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            if let error {
                swlog(error.localizedDescription)
            }

            go = success

            g.leave()
        }

        g.wait()

        return go
    }
}
