//
//  WatchClientSyncer.swift
//  Strongbox
//
//  Created by Strongbox on 07/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import WatchConnectivity

class WatchClientSyncer: NSObject, WCSessionDelegate {
    var wcSession: WCSession! = nil
    var appModel: WatchAppModel! = nil

    let taskSerializer = SerialTasks<Void>()

    init(model: WatchAppModel) {
        appModel = model

        super.init()

        wcSession = WCSession.default
        wcSession.delegate = self
    }

    private var activateContinuation: CheckedContinuation<WCSessionActivationState, Error>?

    func activate() async throws -> Bool {
        let astate = try await withCheckedThrowingContinuation { con in
            activateContinuation = con
            wcSession.activate()
        }

        return astate == .activated
    }

    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        swlog("⌚︎ activationDidCompleteWith \(activationState) and \(error?.localizedDescription ?? "")")

        if let error {
            activateContinuation?.resume(throwing: error)
        } else {
            activateContinuation?.resume(returning: activationState)
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        #if targetEnvironment(simulator)
            Task {
                defer {
                    replyHandler([:])
                }

                do {
                    try await onGotMessage(message: message)
                } catch {
                    swlog("🔴 taskSerializer - onGotMessageSerialized \(error)")
                }
            }
        #endif
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task {
            do {
                try await onGotMessage(message: userInfo)
            } catch {
                swlog("🔴 taskSerializer - onGotMessageSerialized \(error)")
            }
        }
    }

    func onGotMessage(message: [String: Any]) async throws {
        try await taskSerializer.add { [weak self] in
            guard let self else { return }

            try await onGotMessageSerialized(message: message)
        }
    }

    func onGotMessageSerialized(message: [String: Any]) async throws {
        let decoder = JSONDecoder()

        if let resetMessage = message[WatchAppMessage.resetEntries] as? Data {
            let message = try decoder.decode(ResetMessage.self, from: resetMessage)

            swlog("🐞 Got Reset Entries message for database uuid \(message.databaseUuid)...\(message.isStartOfBatchUpdate) Clearing...")

            appModel.resetEntries(databaseUuid: message.databaseUuid, publish: !message.isStartOfBatchUpdate)

        } else {
            swlog("🐞 Got Append Entries message...")

            guard let entryValue = message[WatchAppMessage.appendEntries] as? Data,
                  let settingsValue = message[WatchAppMessage.settings] as? Data,
                  let databasesValue = message[WatchAppMessage.databases] as? Data
            else {
                swlog("🔴 Error getting Append Entries message")
                return
            }

            let entries = try decoder.decode([String: [WatchEntry]].self, from: entryValue)
            guard let databaseUuid = entries.keys.first, entries.keys.count == 1, let appendEntries = entries[databaseUuid] else {
                swlog("🔴 Error getting database entries from WatchEntry array")
                return
            }

            let settings = try decoder.decode(WatchSettingsModel.self, from: settingsValue)
            let databases = try decoder.decode([WatchDatabaseModel].self, from: databasesValue)

            var entriesToUpdate: [WatchEntry]
            if let entriesForThisDatabase = appModel.entriesByDatabase[databaseUuid] {
                var tmp = entriesForThisDatabase
                tmp.append(contentsOf: appendEntries)
                entriesToUpdate = tmp
            } else {
                entriesToUpdate = appendEntries
            }

            appModel.updateModel(settings: settings, databases: databases, databaseUuid: databaseUuid, entries: entriesToUpdate)
        }
    }
}
