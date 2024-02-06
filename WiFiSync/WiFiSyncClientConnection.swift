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

    public func getDatabase(_ databaseId: String, _ completion: @escaping ((Date?, Data?, Error?) -> Void)) {
        let connection = WiFiSyncOneShotClientConnection(endpoint: endpoint,
                                                         passcode: passcode,
                                                         onConnected: { connection in
                                                             NSLog("🟢 WiFiSyncClientConnection::getDatabase Connected...")

                                                             guard let data = databaseId.data(using: .utf8), connection.send(data, .getDatabaseRequest) else {
                                                                 completion(nil, nil, Utils.createNSError("WiFiSyncClientConnection::getDatabase - Could not begin send!", errorCode: -1))
                                                                 return
                                                             }
                                                         },
                                                         onReceived: { data, _ in
                                                             guard let data else {
                                                                 NSLog("🔴 WiFiSyncClientConnection::getDatabase - Data nil")
                                                                 completion(nil, nil, Utils.createNSError("Data Nil from Server", errorCode: -1))
                                                                 return
                                                             }

                                                             let modData = data.prefix(ISO8601DateFormatter.Iso8601withFractionalSecondsCharacterCount)

                                                             guard let modDateIso8601 = String(data: modData, encoding: .utf8),
                                                                   let date = modDateIso8601.iso8601withFractionalSeconds
                                                             else {
                                                                 NSLog("🔴 WiFiSyncClientConnection::getDatabase - Could not read Mod Date")
                                                                 completion(nil, nil, Utils.createNSError("Could not read Mod Date", errorCode: -1))
                                                                 return
                                                             }

                                                             let contents = data.suffix(from: ISO8601DateFormatter.Iso8601withFractionalSecondsCharacterCount)

                                                             completion(date, contents, nil)
                                                         },
                                                         onError: { error in
                                                             NSLog("🔴 WiFiSyncClientConnection::getDatabase - Error = \(error)")
                                                             completion(nil, nil, error)
                                                         })

        connection.connect()
    }

    public func pushDatabase(_ databaseId: String, _ updatedDatabase: Data, _ completion: @escaping ((Date?, Error?) -> Void)) {
        let connection = WiFiSyncOneShotClientConnection(endpoint: endpoint,
                                                         passcode: passcode,
                                                         onConnected: { connection in
                                                             NSLog("🟢 WiFiSyncClientConnection::pushDatabase Connected...")

                                                             guard var data = databaseId.data(using: .utf8) else {
                                                                 NSLog("🔴 WiFiSyncOneShotClientConnection::sendPushDatabaseRequest - Could not convert database id to data!")
                                                                 completion(nil, Utils.createNSError("WiFiSyncClientConnection::pushDatabase - Could not convert database id to data!", errorCode: -1))
                                                                 return
                                                             }

                                                             data.append(updatedDatabase) 

                                                             guard connection.send(data, .pushDatabaseRequest) else {
                                                                 NSLog("🔴 WiFiSyncOneShotClientConnection::sendPushDatabaseRequest - Could not begin send!")
                                                                 completion(nil, Utils.createNSError("WiFiSyncClientConnection::pushDatabase - Could not begin send!", errorCode: -1))
                                                                 return
                                                             }
                                                         },
                                                         onReceived: { data, _ in
                                                             

                                                             guard let data else {
                                                                 NSLog("🔴 WiFiSyncClientConnection::pushDatabase - Data nil")
                                                                 completion(nil, Utils.createNSError("WiFiSyncClientConnection::pushDatabase could not read data or convert to json string", errorCode: -1))
                                                                 return
                                                             }

                                                             let decoder = JSONDecoder()
                                                             decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

                                                             guard let result = try? decoder.decode(WiFiSyncPushDatabaseResult.self, from: data) else {
                                                                 NSLog("🔴 WiFiSyncClientConnection::listDatabases - could not decode JSON")
                                                                 completion(nil, Utils.createNSError("WiFiSyncClientConnection::listDatabases - could not decode JSON", errorCode: -1))
                                                                 return
                                                             }

                                                             completion(result.newModDate, result.success ? nil : Utils.createNSError(result.error ?? "Unknown Error", errorCode: -1))
                                                         },
                                                         onError: { error in
                                                             NSLog("🔴 WiFiSyncClientConnection::pushDatabase - Error = \(error)")
                                                             completion(nil, error)
                                                         })

        connection.connect()
    }

    public func listDatabases(completion: @escaping (([WiFiSyncDatabaseSummary]?, Error?) -> Void)) {
        let connection = WiFiSyncOneShotClientConnection(endpoint: endpoint,
                                                         passcode: passcode,
                                                         onConnected: { connection in
                                                             NSLog("🟢 WiFiSyncClientConnection::listDatabases Connected...")

                                                             guard connection.send(nil, .listDatabasesRequest) else {
                                                                 completion(nil, Utils.createNSError("Could not begin send!", errorCode: -1))
                                                                 return
                                                             }
                                                         },
                                                         onReceived: { data, _ in
                                                             guard let data else {
                                                                 NSLog("🔴 WiFiSyncClientConnection::listDatabases - could not read data or convert to json string")
                                                                 completion(nil, Utils.createNSError("WiFiSyncClientConnection::listDatabases - could not read data or convert to json string", errorCode: -1))
                                                                 return
                                                             }

                                                             let decoder = JSONDecoder()
                                                             decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

                                                             guard let databases = try? decoder.decode([WiFiSyncDatabaseSummary].self, from: data) else {
                                                                 NSLog("🔴 WiFiSyncClientConnection::listDatabases - could not decode JSON")
                                                                 completion(nil, Utils.createNSError("WiFiSyncClientConnection::listDatabases - could not decode JSON", errorCode: -1))
                                                                 return
                                                             }

                                                             completion(databases, nil)
                                                         },
                                                         onError: { error in
                                                             NSLog("🔴 WiFiSyncClientConnection::listDatabases - Error = \(error)")
                                                             completion(nil, error)
                                                         })

        connection.connect()
    }
}
