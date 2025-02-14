//
//  WiFiSyncInboundConnection.swift
//  WeeFee-Server
//
//  Created by Strongbox on 07/12/2023.
//

import Foundation
import Network
import OSLog

protocol WiFiSyncManagementInterface {
    func isEditsAreInProgress(id: String) -> Bool

    func getDatabaseSummaries(id: String?, _ completion: @escaping (([WiFiSyncDatabaseSummary]) -> Void))

    func pullDatabase(id: String, _ completion: @escaping (((Date, Data)?) -> Void))

    func pushDatabase(id: String, _ data: Data, _ completion: @escaping ((_ success: Bool, _ mod: Date?, _ error: String?) -> Void)) throws
}

class WiFiSyncInboundConnection {
    static let ConnectionQ: DispatchQueue = .init(label: "Wi-Fi-Sync-Inbound-Connection-Queue")

    let connection: NWConnection
    var onErrorOrClosed: ((WiFiSyncInboundConnection, Error?) -> Void)?

    static var badConsecutivePasscodes = 0

    let managementInterface: WiFiSyncManagementInterface
    init(connection: NWConnection, managementInterface: WiFiSyncManagementInterface, onErrorOrClosed: ((WiFiSyncInboundConnection, Error?) -> Void)?) {
        self.connection = connection
        self.managementInterface = managementInterface
        self.onErrorOrClosed = onErrorOrClosed



        connection.stateUpdateHandler = stateUpdateHandler
        connection.start(queue: Self.ConnectionQ)
    }

    func stateUpdateHandler(_ newState: NWConnection.State) {
        swlog("🐞 WiFiSyncInboundConnection::stateUpdateHandler \(String(describing: newState))")

        switch newState {
        case .ready:
            swlog("🐞 \(connection) established")
            receiveSingleMessage()
        case let .failed(error):
            swlog("🐞 \(connection) failed with \(error)")
            connection.cancel()
            onErrorOrClosed?(self, error)

            if case let .tls(oSStatus) = error, oSStatus == errSSLBadRecordMac {
                WiFiSyncInboundConnection.badConsecutivePasscodes = WiFiSyncInboundConnection.badConsecutivePasscodes + 1

                swlog("🔴 WiFiSyncInboundConnection::receiveMessage => invalid passcode detected = [%@]", String(describing: error))

                if WiFiSyncInboundConnection.badConsecutivePasscodes > 4 {
                    swlog("🔴 Too many invalid passcodes detected. Shutting down Wi-Fi Sync server.")
                    WiFiSyncInboundConnection.badConsecutivePasscodes = 0

                    WiFiSyncServer.shared.stop(with: NSLocalizedString("wifi_sync_too_many_bad_passcode_attempts", comment: "Wi-Fi Sync was stopped because there were too many incorrect passcode attempts."))
                }
            }
        case .cancelled:
            swlog("🐞 \(connection) cancelled")
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
                swlog("🔴 WiFiSyncInboundConnection::receiveMessage => Error = [%@]", String(describing: error))
                onErrorOrClosed?(self, error ?? Utils.createNSError("WiFiSyncInboundConnection::receiveMessage - Unknown Error", errorCode: -1))
            }
        }
    }

    func onReceivedMessage(_ content: Data?, _ message: NWProtocolFramer.Message) {
        swlog("🐞 onReceivedMessage \(message)")

        WiFiSyncInboundConnection.badConsecutivePasscodes = 0

        switch message.wifiSyncMessageType {
        case .listDatabasesRequest:
            handleListDatabases(content)
        case .getDatabaseRequest:
            handleGetDatabaseRequest(content, message)
        case .pushDatabaseRequest:
            handlePushDatabaseRequest(content, message)
        case .invalid, .listDatabasesResponse, .getDatabaseResponse, .pushDatabaseResponse:
            swlog("🐞 Received invalid message! \(message.wifiSyncMessageType)")
        }
    }

    

    func handleListDatabases(_ content: Data?) {
        let databaseId = content != nil ? String(data: content!, encoding: .utf8) : nil

        swlog("🟢 handleListDatabases: \(String(describing: databaseId))")

        let message = NWProtocolFramer.Message(wiFiSyncMessageType: .listDatabasesResponse)

        let context = NWConnection.ContentContext(identifier: "listDatabasesResponse",
                                                  metadata: [message])

        getDatabaseSummaries(databaseId) { [weak self] summaries in
            guard let self else { return }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601withFractionalSeconds

            guard let encodedData = try? encoder.encode(summaries) else {
                swlog("🔴 WiFiSyncInboundConnection::handleListDatabases => could not encode to JSON")
                connection.forceCancel()
                return
            }

            connection.send(content: encodedData, contentContext: context, isComplete: true,
                            completion: .contentProcessed { error in
                                if let error {
                                    swlog("🔴 WiFiSyncInboundConnection::handleListDatabases - Send Completed: \(String(describing: error)) - encoded data length: \(encodedData.count)")
                                } else {
                                    
                                }

                                
                                
                            })
        }
    }

    func handleGetDatabaseRequest(_ content: Data?, _: NWProtocolFramer.Message) {
        guard let data = content, let databaseId = String(data: data, encoding: .utf8) else {
            swlog("🔴 Could not read handleGetDatabaseRequest")
            connection.forceCancel()
            return
        }

        swlog("🟢 handleGetDatabaseRequest: \(String(describing: databaseId))")

        managementInterface.pullDatabase(id: databaseId) { [weak self] modAndEncryptedData in
            guard let self else { return }

            handlePullDatabaseResponse(databaseId, modAndEncryptedData) 
        }
    }

    func handlePullDatabaseResponse(_ databaseId: String, _ modAndEncryptedData: (Date, Data)?) {
        guard let modAndEncryptedData else {
            swlog("🔴 Could not getLocalWorkingCache or read it, or the mod date")
            connection.forceCancel()
            return
        }

        let mod = modAndEncryptedData.0
        let enc = modAndEncryptedData.1

        guard var combined = mod.iso8601withFractionalSeconds.data(using: .utf8) else {
            swlog("🔴 Could not convert moddate to data")
            connection.forceCancel()
            return
        }

        combined.append(enc)

        let message = NWProtocolFramer.Message(wiFiSyncMessageType: .getDatabaseResponse)

        let context = NWConnection.ContentContext(identifier: "listDatabasesResponse",
                                                  metadata: [message])

        connection.send(content: combined, contentContext: context, isComplete: true,
                        completion: .contentProcessed { error in
                            if let error {
                                swlog("🔴 WiFiSyncInboundConnection::handleGetDatabaseRequest - Send Completed: \(String(describing: error)) - encoded data length: \(combined.count)")
                            } else {

                            }

                            
                            
                        })

        swlog("🟢 handleGetDatabaseRequest done: \(String(describing: databaseId))")
    }

    func handlePushDatabaseRequest(_ content: Data?, _: NWProtocolFramer.Message) {
        let uuidStringLength = 36

        guard let allData = content,
              let databaseId = String(data: allData.prefix(uuidStringLength), encoding: .utf8)
        else {
            swlog("🔴 handlePushDatabaseRequest - Could not read content or get databaseId/database")
            sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil, error: "Could not read content or get databaseId/database"))
            return
        }

        swlog("🟢 handlePushDatabaseRequest: \(String(describing: databaseId))")

        if managementInterface.isEditsAreInProgress(id: databaseId) {
            swlog("🔴 Edits are in progress, push is not possible. Save changes on remote WiFi Server before pushing.")
            sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil,
                                                                error: NSLocalizedString("wifi_sync_edits_in_progress_try_again", comment: "Edits are in progress, so updating is not currently possible. Finish edits on destination Wi-Fi device and try again.")))
        } else if managementInterface.isEditsAreInProgress(id: databaseId) {
            swlog("🔴 A sync is in progress so updating is not currently possible. Allow Sync to finish on destination Wi-Fi device and try again.")

            sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false,
                                                                newModDate: nil,
                                                                error: NSLocalizedString("wifi_sync_sync_in_progress_try_again", comment: "A sync is in progress, push is not possible. Finish Sync on remote Wi-Fi Server before pushing.")))
        } else {
            let updatedDatabase = allData.suffix(from: uuidStringLength)

            do {
                try managementInterface.pushDatabase(id: databaseId, updatedDatabase) { [weak self] success, mod, error in
                    guard let self else { return }

                    sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: success, newModDate: mod, error: error))
                }
            } catch {
                swlog("🔴 handlePushDatabaseRequest - Error Updating Local: [%@]", String(describing: error))
                sendPushDatabaseResponse(WiFiSyncPushDatabaseResult(success: false, newModDate: nil, error: String(describing: error)))
            }
        }
    }

    func sendPushDatabaseResponse(_ pushResult: WiFiSyncPushDatabaseResult) {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds

        guard let encodedData = try? encoder.encode(pushResult) else {
            swlog("🔴 Could not encode to JSON")
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
                                swlog("🔴 WiFiSyncInboundConnection::sendPushDatabaseResponse - Send Completed: \(String(describing: error)) - encoded data length: \(encodedData.count)")
                            } else {

                            }

                            
                            
                        })
    }

    

    func getDatabaseSummaries(_ id: String?, _ completion: @escaping (([WiFiSyncDatabaseSummary]) -> Void)) {
        managementInterface.getDatabaseSummaries(id: id, completion)
    }
}
