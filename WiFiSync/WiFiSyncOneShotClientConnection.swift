//
//  WiFiSyncOneShotClientConnection.swift
//
//  Created by Strongbox on 07/12/2023.
//

import Foundation
import Network
import OSLog

class WiFiSyncOneShotClientConnection {
    static let connectionQ: DispatchQueue = .init(label: "Wi-Fi-Sync-Client-Connection-Queue", qos: .userInitiated) 

    let resolver: BonjourResolver
    let endpoint: NWEndpoint
    let passcode: String

    var connection: NWConnection?

    var onConnected: (WiFiSyncOneShotClientConnection) -> Void
    var onError: (Error) -> Void
    var onReceived: (Data?, NWProtocolFramer.Message) -> Void

    var errorHasOccurred = false
    var hasSent = false

    init(endpoint: NWEndpoint, passcode: String, onConnected: @escaping ((WiFiSyncOneShotClientConnection) -> Void),
         onReceived: @escaping ((Data?, NWProtocolFramer.Message) -> Void),
         onError: @escaping ((Error) -> Void))
    {
        self.endpoint = endpoint
        self.passcode = passcode
        resolver = BonjourResolver()
        self.onConnected = onConnected
        self.onError = onError
        self.onReceived = onReceived
    }

    func connect() {
        DebugLogger.info("Starting resolve for endpoint...")

        do {
            try resolver.start(endpoint: endpoint) { result in
                DebugLogger.info("Resolve done for endpoint with \(result)")

                WiFiSyncOneShotClientConnection.connectionQ.async {
                    self.onResolved(result)
                }
            }
        } catch {
            onError(error)
        }
    }

    func onResolved(_ result: Result<(String, UInt16), Error>) {
        switch result {
        case let .success(success):
            let (host, port) = success
            NSLog("🟢 Resolved service to: \(host) on \(port)")
            connect(host: host, port: port)
        case let .failure(failure):
            onError(failure)
        }
    }

    func connect(host: String, port: UInt16) {
        let connection = NWConnection(host: NWEndpoint.Host(host),
                                      port: NWEndpoint.Port(integerLiteral: port),
                                      using: NWParameters(passcode: passcode))

        self.connection = connection

        connection.stateUpdateHandler = onStateChanged

        connection.start(queue: Self.connectionQ)
    }

    

    func onStateChanged(_ newState: NWConnection.State) {
        NSLog("🐞 WiFiSyncOneShotClientConnection::onStateChanged \(String(describing: newState))")

        guard let connection else {
            NSLog("🔴 WiFiSyncOneShotClientConnection::onStateChanged - connection nil!")
            return
        }

        switch newState {
        case .ready:
            onConnected(self)
            receiveMessage()
        case let .waiting(error):
            if case let .tls(os) = error, os == errSSLPeerBadRecordMac { 
                NSLog("🔴 Sender has detected an Incorrect PIN")
                errorHasOccurred = true
                connection.forceCancel()
                onError(Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
            } else {
                NSLog("🔴 WiFiSyncOneShotClientConnection::onStateChanged - WAITING SERVER ERROR: \(error)\n")
                errorHasOccurred = true
                connection.cancel()
                onError(error)
            }
        case let .failed(error):
            NSLog("🔴 WiFiSyncOneShotClientConnection::onStateChanged - Failed with \(error)")

            errorHasOccurred = true
            connection.cancel()
            onError(error)
        default:
            NSLog("WiFiSyncOneShotClientConnection::onStateChanged \(String(describing: newState))")
        }
    }

    func send(_ data: Data? = nil, _ messageType: WiFiSyncMessageType) -> Bool {
        guard let connection, !errorHasOccurred, !hasSent else {
            NSLog("🔴 Strange scenario, WiFiSyncOneShotClientConnection::send() - connection is invalid.")
            return false
        }

        let message = NWProtocolFramer.Message(wiFiSyncMessageType: messageType)
        let identifier = "\(messageType)"
        let context = NWConnection.ContentContext(identifier: identifier, metadata: [message])

        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { [weak self] error in
                            guard let self else { return }

                            if let error {
                                NSLog("🔴 WiFiSyncOneShotClientConnection::sendGetDatabaseRequest - Send Completed: \(String(describing: error)) - encoded data length: \(String(describing: data?.count))")
                                onError(error)
                            } else {
                                
                            }
                        })

        hasSent = true

        return true
    }

    func receiveMessage() {
        guard let connection, !errorHasOccurred, hasSent else {
            NSLog("🔴 Strange scenario, WiFiSyncOneShotClientConnection::receive() - connection is invalid.")
            return
        }

        connection.receiveMessage { [weak self] content, context, _, error in
            guard let self else { return }

            if let message = context?.protocolMetadata(definition: WifiSyncProtocol.definition) as? NWProtocolFramer.Message {
                onReceived(content, message)
            } else if let error {
                onError(error)
            } else {
                NSLog("🔴 Unknown Error occurred in receiveMessage completion - probably connection closed")
                onError(Utils.createNSError("Unknown error in WiFiSyncOneShotClientConnection::receive()", errorCode: -1))
            }

            connection.cancel()
        }
    }
}
