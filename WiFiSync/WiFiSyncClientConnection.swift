//
//  WiFiSyncClientConnection.swift
//
//  Created by Strongbox on 10/12/2023.
//

import Foundation
import Network
import OSLog

class WiFiSyncClientConnection {
    var passcode: String
    var endpoint: NWEndpoint

    init(endpoint: NWEndpoint, passcode: String) {
        self.endpoint = endpoint
        self.passcode = passcode
    }

    public func getDatabase(_ databaseId: String, _ completion: @escaping ((Date?, Data?, Bool, Error?) -> Void)) {
        let connection = WiFiSyncOneShotClientConnection(endpoint: endpoint,
                                                         passcode: passcode,
                                                         onConnected: { connection in
                                                             swlog("🟢 WiFiSyncClientConnection::getDatabase Connected...")

                                                             guard let data = databaseId.data(using: .utf8), connection.send(data, .getDatabaseRequest) else {
                                                                 completion(nil, nil, false, Utils.createNSError("WiFiSyncClientConnection::getDatabase - Could not begin send!", errorCode: -1))
                                                                 return
                                                             }
                                                         },
                                                         onReceived: { data, _ in
                                                             guard let data else {
                                                                 swlog("🔴 WiFiSyncClientConnection::getDatabase - Data nil")
                                                                 completion(nil, nil, false, Utils.createNSError("Data Nil from Server", errorCode: -1))
                                                                 return
                                                             }

                                                             let modData = data.prefix(ISO8601DateFormatter.Iso8601withFractionalSecondsCharacterCount)

                                                             guard let modDateIso8601 = String(data: modData, encoding: .utf8),
                                                                   let date = modDateIso8601.iso8601withFractionalSeconds
                                                             else {
                                                                 swlog("🔴 WiFiSyncClientConnection::getDatabase - Could not read Mod Date")
                                                                 completion(nil, nil, false, Utils.createNSError("Could not read Mod Date", errorCode: -1))
                                                                 return
                                                             }

                                                             let contents = data.suffix(from: ISO8601DateFormatter.Iso8601withFractionalSecondsCharacterCount)

                                                             completion(date, contents, false, nil)
                                                         }, onIncorrectPasscode: {
                                                             completion(nil, nil, true, nil)
                                                         },
                                                         onError: { error in
                                                             swlog("🔴 WiFiSyncClientConnection::getDatabase - Error = \(error)")
                                                             completion(nil, nil, false, error)
                                                         })

        connection.connect()
    }

    public func pushDatabase(_ databaseId: String, _ updatedDatabase: Data, _ completion: @escaping ((Date?, Bool, Error?) -> Void)) {
        let connection = WiFiSyncOneShotClientConnection(endpoint: endpoint,
                                                         passcode: passcode,
                                                         onConnected: { connection in
                                                             swlog("🟢 WiFiSyncClientConnection::pushDatabase Connected...")

                                                             guard var data = databaseId.data(using: .utf8) else {
                                                                 swlog("🔴 WiFiSyncOneShotClientConnection::sendPushDatabaseRequest - Could not convert database id to data!")
                                                                 completion(nil, false, Utils.createNSError("WiFiSyncClientConnection::pushDatabase - Could not convert database id to data!", errorCode: -1))
                                                                 return
                                                             }

                                                             data.append(updatedDatabase) 

                                                             guard connection.send(data, .pushDatabaseRequest) else {
                                                                 swlog("🔴 WiFiSyncOneShotClientConnection::sendPushDatabaseRequest - Could not begin send!")
                                                                 completion(nil, false, Utils.createNSError("WiFiSyncClientConnection::pushDatabase - Could not begin send!", errorCode: -1))
                                                                 return
                                                             }
                                                         },
                                                         onReceived: { data, _ in
                                                             

                                                             guard let data else {
                                                                 swlog("🔴 WiFiSyncClientConnection::pushDatabase - Data nil")
                                                                 completion(nil, false, Utils.createNSError("WiFiSyncClientConnection::pushDatabase could not read data or convert to json string", errorCode: -1))
                                                                 return
                                                             }

                                                             let decoder = JSONDecoder()
                                                             decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

                                                             guard let result = try? decoder.decode(WiFiSyncPushDatabaseResult.self, from: data) else {
                                                                 swlog("🔴 WiFiSyncClientConnection::listDatabases - could not decode JSON")
                                                                 completion(nil, false, Utils.createNSError("WiFiSyncClientConnection::listDatabases - could not decode JSON", errorCode: -1))
                                                                 return
                                                             }

                                                             completion(result.newModDate, false, result.success ? nil : Utils.createNSError(result.error ?? "Unknown Error", errorCode: -1))
                                                         }, onIncorrectPasscode: {
                                                             completion(nil, true, nil)
                                                         },
                                                         onError: { error in
                                                             swlog("🔴 WiFiSyncClientConnection::pushDatabase - Error = \(error)")
                                                             completion(nil, false, error)
                                                         })

        connection.connect()
    }

    public func listDatabases(_ databaseId: String?, completion: @escaping (([WiFiSyncDatabaseSummary]?, Bool, Error?) -> Void)) {
        let connection = WiFiSyncOneShotClientConnection(endpoint: endpoint,
                                                         passcode: passcode,
                                                         onConnected: { connection in
                                                             

                                                             let data = databaseId != nil ? databaseId!.data(using: .utf8) : nil

                                                             guard connection.send(data, .listDatabasesRequest) else {
                                                                 completion(nil, false, Utils.createNSError("Could not begin send!", errorCode: -1))
                                                                 return
                                                             }
                                                         },
                                                         onReceived: { data, _ in
                                                             guard let data else {
                                                                 swlog("🔴 WiFiSyncClientConnection::listDatabases - could not read data or convert to json string")
                                                                 completion(nil, false, Utils.createNSError("WiFiSyncClientConnection::listDatabases - could not read data or convert to json string", errorCode: -1))
                                                                 return
                                                             }

                                                             let decoder = JSONDecoder()
                                                             decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

                                                             guard let databases = try? decoder.decode([WiFiSyncDatabaseSummary].self, from: data) else {
                                                                 swlog("🔴 WiFiSyncClientConnection::listDatabases - could not decode JSON")
                                                                 completion(nil, false, Utils.createNSError("WiFiSyncClientConnection::listDatabases - could not decode JSON", errorCode: -1))
                                                                 return
                                                             }

                                                             completion(databases, false, nil)
                                                         },
                                                         onIncorrectPasscode: {
                                                             completion(nil, true, nil)
                                                         },
                                                         onError: { error in
                                                             swlog("🔴 WiFiSyncClientConnection::listDatabases - Error = \(error)")
                                                             completion(nil, false, error)
                                                         })

        connection.connect()
    }
}
