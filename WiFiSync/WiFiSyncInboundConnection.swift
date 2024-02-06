//
//  WiFiSyncInboundConnection.swift
//  WeeFee-Server
//
//  Created by Strongbox on 07/12/2023.
//

import Foundation
import Network
import OSLog

class WiFiSyncInboundConnection {
    static let ConnectionQ: DispatchQueue = .init(label: "Wi-Fi-Sync-Inbound-Connection-Queue")

    let connection: NWConnection
    var onErrorOrClosed: ((WiFiSyncInboundConnection, Error?) -> Void)?

    static var badConsecutivePasscodes = 0

    init(connection: NWConnection, onErrorOrClosed: ((WiFiSyncInboundConnection, Error?) -> Void)?) {
        self.connection = connection
        self.onErrorOrClosed = onErrorOrClosed



        connection.stateUpdateHandler = stateUpdateHandler
        connection.start(queue: Self.ConnectionQ)
    }

    func stateUpdateHandler(_ newState: NWConnection.State) {
        NSLog("🐞 WiFiSyncInboundConnection::stateUpdateHandler \(String(describing: newState))")

        switch newState {
        case .ready:
            NSLog("🐞 \(connection) established")
            receiveSingleMessage()
        case let .failed(error):
            NSLog("🐞 \(connection) failed with \(error)")
            connection.cancel()
            onErrorOrClosed?(self, error)

            if case let .tls(oSStatus) = error, oSStatus == errSSLBadRecordMac {
                WiFiSyncInboundConnection.badConsecutivePasscodes = WiFiSyncInboundConnection.badConsecutivePasscodes + 1

                NSLog("🔴 WiFiSyncInboundConnection::receiveMessage => invalid passcode detected = [%@]", String(describing: error))

                if WiFiSyncInboundConnection.badConsecutivePasscodes > 4 {
                    NSLog("🔴 Too many invalid passcodes detected. Shutting down Wi-Fi Sync server.")
                    WiFiSyncInboundConnection.badConsecutivePasscodes = 0

                    WiFiSyncServer.shared.stop(with: NSLocalizedString("wifi_sync_too_many_bad_passcode_attempts", comment: "Wi-Fi Sync was stopped because there were too many incorrect passcode attempts."))
                }
            }
        case .cancelled:
            NSLog("🐞 \(connection) cancelled")
            onErrorOrClosed?(self, nil)
        default:
            break
        }
    }

    func receiveSingleMessage() {
        connection.receiveMessage { [weak self] content, context, _, error in
            guard let self else { return }

            if let wiFiSyncMessage = context?.protocolMetadata(definition: WifiSyncProtocol.definition) as? NWProtocolFramer.Message {
                onReceivedMessage(content, wiFiSyncMessage)
            } else {
                NSLog("🔴 WiFiSyncInboundConnection::receiveMessage => Error = [%@]", String(describing: error))
                onErrorOrClosed?(self, error ?? Utils.createNSError("WiFiSyncInboundConnection::receiveMessage - Unknown Error", errorCode: -1))
            }
        }
    }

    func onReceivedMessage(_ content: Data?, _ message: NWProtocolFramer.Message) {
        NSLog("🐞 onReceivedMessage \(message)")

        WiFiSyncInboundConnection.badConsecutivePasscodes = 0

        switch message.wifiSyncMessageType {
        case .listDatabasesRequest:
            handleListDatabases()
        case .getDatabaseRequest:
            handleGetDatabaseRequest(content, message)
        case .pushDatabaseRequest:
            handlePushDatabaseRequest(content, message)
        case .invalid, .listDatabasesResponse, .getDatabaseResponse, .pushDatabaseResponse:
            NSLog("🐞 Received invalid message! \(message.wifiSyncMessageType)")
        }
    }

    

    func handleListDatabases() {
        let message = NWProtocolFramer.Message(wiFiSyncMessageType: .listDatabasesResponse)

        let context = NWConnection.ContentContext(identifier: "listDatabasesResponse",
                                                  metadata: [message])

        let summaries = getDatabaseSummaries()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds

        guard let encodedData = try? encoder.encode(summaries) else {
            NSLog("🔴 WiFiSyncInboundConnection::handleListDatabases => could not encode to JSON")
            connection.forceCancel()
            return
        }

        connection.send(content: encodedData, contentContext: context, isComplete: true,
                        completion: .contentProcessed { error in
                            if let error {
                                NSLog("🔴 WiFiSyncInboundConnection::handleListDatabases - Send Completed: \(String(describing: error)) - encoded data length: \(encodedData.count)")
                            } else {

                            }

                            
                            
                        })
    }

    func handleGetDatabaseRequest(_ content: Data?, _: NWProtocolFramer.Message) {
        guard let data = content, let databaseId = String(data: data, encoding: .utf8) else {
            NSLog("🔴 Could not read handleGetDatabaseRequest")
            connection.forceCancel()
            return
        }

        NSLog("🟢 handleGetDatabaseRequest: \(String(describing: databaseId))")

        var nsmod: NSDate?

        guard let url = WorkingCopyManager.sharedInstance().getLocalWorkingCache(databaseId, modified: &nsmod, fileSize: nil),
              let workingCopy = try? Data(contentsOf: url),
              let mod = nsmod as? Date
        else {
            NSLog("🔴 Could not getLocalWorkingCache or read it, or the mod date")
            connection.forceCancel()
            return
        }

        let modDateStr = mod.iso8601withFractionalSeconds

        guard var combined = modDateStr.data(using: .utf8) else {
            NSLog("🔴 Could not convert moddate to data")
            connection.forceCancel()
            return
        }

        combined.append(workingCopy)

        let message = NWProtocolFramer.Message(wiFiSyncMessageType: .getDatabaseResponse)

        let context = NWConnection.ContentContext(identifier: "listDatabasesResponse",
                                                  metadata: [message])

        connection.send(content: combined, contentContext: context, isComplete: true,
                        completion: .contentProcessed { error in
                            if let error {
                                NSLog("🔴 WiFiSyncInboundConnection::handleGetDatabaseRequest - Send Completed: \(String(describing: error)) - encoded data length: \(combined.count)")
                            } else {

                            }

                            
                            
                        })

        NSLog("🟢 handleGetDatabaseRequest done: \(String(describing: databaseId))")
    }

    func isEditsAreInProgress(_ database: MacDatabasePreferences) -> Bool {
        var ret = false

        DispatchQueue.main.sync {
            ret = DatabasesCollection.shared.databaseHasEditsOrIsBeingEdited(uuid: database.uuid)
        }

        return ret
    }

    func isSyncInProgress(_ database: MacDatabasePreferences) -> Bool {
        MacSyncManager.sharedInstance().syncInProgress(forDatabase: database.uuid)
    }

    func handlePushDatabaseRequest(_ content: Data?, _: NWProtocolFramer.Message) {
        let uuidStringLength = 36

        guard let allData = content,
              let databaseId = String(data: allData.prefix(uuidStringLength), encoding: .utf8),
              let database = MacDatabasePreferences.getById(databaseId)
        else {
            NSLog("🔴 handlePushDatabaseRequest - Could not read content or get databaseId/database")
            sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil, error: "Could not read content or get databaseId/database"))
            return
        }

        NSLog("🟢 handlePushDatabaseRequest: \(String(describing: databaseId))")

        if isEditsAreInProgress(database) {
            NSLog("🔴 Edits are in progress, push is not possible. Save changes on remote WiFi Server before pushing.")
            sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil,
                                                                error: NSLocalizedString("wifi_sync_edits_in_progress_try_again", comment: "Edits are in progress, so updating is not currently possible. Finish edits on destination Wi-Fi device and try again.")))
        } else if isSyncInProgress(database) {
            NSLog("🔴 A sync is in progress so updating is not currently possible. Allow Sync to finish on destination Wi-Fi device and try again.")

            sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false,
                                                                newModDate: nil,
                                                                error: NSLocalizedString("wifi_sync_sync_in_progress_try_again", comment: "A sync is in progress, push is not possible. Finish Sync on remote Wi-Fi Server before pushing.")))
        } else {
            let updatedDatabase = allData.suffix(from: uuidStringLength)

            do {
                try MacSyncManager.sharedInstance().updateLocalCopyMark(asRequiringSync: database, data: updatedDatabase) 

                
                

                DatabasesCollection.shared.reloadFromWorkingCopy(databaseId, dispatchSyncAfterwards: true) { [weak self] in
                    guard let self else { return }

                    guard let mod = WorkingCopyManager.sharedInstance().getModDate(databaseId) else {
                        NSLog("🔴 handlePushDatabaseRequest - Could not read current mod date of working cache")
                        sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil, error: "Could not read current mod date of working cache"))
                        return
                    }

                    sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: true, newModDate: mod, error: nil))
                }
            } catch {
                NSLog("🔴 handlePushDatabaseRequest - Error Updating Local: [%@]", String(describing: error))
                sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil, error: String(describing: error)))
            }
        }
    }

    func sendPushDatabaseResponse(_ pushResult: WiFiSyncPushDatabaseResult) {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds

        guard let encodedData = try? encoder.encode(pushResult) else {
            NSLog("🔴 Could not encode to JSON")
            connection.forceCancel()
            return
        }

        let message = NWProtocolFramer.Message(wiFiSyncMessageType: .pushDatabaseResponse)
        let context = NWConnection.ContentContext(identifier: "pushDatabaseResponse",
                                                  metadata: [message])

        connection.send(content: encodedData,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in
                            if let error {
                                NSLog("🔴 WiFiSyncInboundConnection::sendPushDatabaseResponse - Send Completed: \(String(describing: error)) - encoded data length: \(encodedData.count)")
                            } else {

                            }

                            
                            
                        })
    }

    

    func getDatabaseSummaries() -> [WiFiSyncDatabaseSummary] {
        let summaries: [WiFiSyncDatabaseSummary] = MacDatabasePreferences.allDatabases.compactMap { database in
            var nsmod: NSDate?
            var fsize: UInt64 = 0

            guard WorkingCopyManager.sharedInstance().getLocalWorkingCache(database.uuid, modified: &nsmod, fileSize: &fsize) != nil,
                  let mod = nsmod as? Date
            else {
                NSLog("⚠️ Could not get working cache or mod date for database: [%@] - Skipping...", database.nickName)
                return nil
            }

            let filename = database.fileUrl.lastPathComponent

            return WiFiSyncDatabaseSummary(uuid: database.uuid,
                                           filename: filename,
                                           nickName: database.nickName,
                                           modDate: mod,
                                           fileSize: fsize)
        }

        return summaries
    }
}
