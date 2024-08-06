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
    var onIncorrectPasscode: () -> Void
    var onReceived: (Data?, NWProtocolFramer.Message) -> Void

    var errorHasOccurred = false
    var hasSent = false

    init(endpoint: NWEndpoint,
         passcode: String,
         onConnected: @escaping ((WiFiSyncOneShotClientConnection) -> Void),
         onReceived: @escaping ((Data?, NWProtocolFramer.Message) -> Void),
         onIncorrectPasscode: @escaping (() -> Void),
         onError: @escaping ((Error) -> Void))
    {
        self.endpoint = endpoint
        self.passcode = passcode
        resolver = BonjourResolver()
        self.onConnected = onConnected
        self.onError = onError
        self.onIncorrectPasscode = onIncorrectPasscode
        self.onReceived = onReceived
    }

    func connect() {
        swlog("Starting resolve for endpoint...")

        do {
            try resolver.start(endpoint: endpoint) { result in
                swlog("Resolve done for endpoint with \(result)")

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
        swlog("🐞 WiFiSyncOneShotClientConnection::onStateChanged \(String(describing: newState))")

        guard let connection else {
            swlog("🔴 WiFiSyncOneShotClientConnection::onStateChanged - connection nil!")
            return
        }

        switch newState {
        case .ready:
            onConnected(self)
            receiveMessage()
        case let .waiting(error):
            if case let .tls(os) = error, os == errSSLPeerBadRecordMac { 
                swlog("🔴 Sender has detected an Incorrect PIN")
                errorHasOccurred = true
                connection.forceCancel()
                onIncorrectPasscode()
            } else {
                swlog("🔴 WiFiSyncOneShotClientConnection::onStateChanged - WAITING SERVER ERROR: \(error)\n")
                errorHasOccurred = true
                connection.cancel()
                onError(error)
            }
        case let .failed(error):
            swlog("🔴 WiFiSyncOneShotClientConnection::onStateChanged - Failed with \(error)")

            errorHasOccurred = true
            connection.cancel()
            onError(error)
        default:
            swlog("WiFiSyncOneShotClientConnection::onStateChanged \(String(describing: newState))")
        }
    }

    func send(_ data: Data? = nil, _ messageType: WiFiSyncMessageType) -> Bool {
        guard let connection, !errorHasOccurred, !hasSent else {
            swlog("🔴 Strange scenario, WiFiSyncOneShotClientConnection::send() - connection is invalid.")
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
                                swlog("🔴 WiFiSyncOneShotClientConnection::sendGetDatabaseRequest - Send Completed: \(String(describing: error)) - encoded data length: \(String(describing: data?.count))")
                                onError(error)
                            } else {
                                
                            }
                        })

        hasSent = true

        return true
    }

    func receiveMessage() {
        guard let connection, !errorHasOccurred, hasSent else {
            swlog("🔴 Strange scenario, WiFiSyncOneShotClientConnection::receive() - connection is invalid.")
            return
        }

        connection.receiveMessage { [weak self] content, context, _, error in
            guard let self else { return }

            if let message = context?.protocolMetadata(definition: WifiSyncProtocol.definition) as? NWProtocolFramer.Message {
                onReceived(content, message)
            } else if let error {
                onError(error)
            } else {
                swlog("🔴 Unknown Error occurred in receiveMessage completion - probably connection closed")
                onError(Utils.createNSError("Unknown error in WiFiSyncOneShotClientConnection::receive()", errorCode: -1))
            }

            connection.cancel()
        }
    }
}
