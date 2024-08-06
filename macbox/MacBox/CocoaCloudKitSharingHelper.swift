//
//  CocoaCloudKitSharingHelper.swift
//  MacBox
//
//  Created by Strongbox on 14/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import Foundation

@objc
class CocoaCloudKitSharingHelper: NSObject, NSCloudSharingServiceDelegate {
    let database: MacDatabasePreferences
    let window: NSWindow
    let completion: (_: Error?) -> Void

    enum StrongboxSyncSharingError: Error {
        case couldNotGetExistingCloudKitShare
        case couldNotCreateSharingService
    }

    @objc
    init(database: MacDatabasePreferences, window: NSWindow, completion: @escaping (_: Error?) -> Void) {
        self.database = database
        self.window = window
        self.completion = completion
    }

    @MainActor
    @objc
    func beginNewShare() {
        if database.isSharedInCloudKit {
            Task { [weak self] in
                guard let self else { return }

                do {
                    let (theShare, container) = try await CloudKitDatabasesInteractor.shared.getCurrentCKShare(for: database)

                    guard let theShare else {
                        throw StrongboxSyncSharingError.couldNotGetExistingCloudKitShare
                    }

                    let item = NSItemProvider()

                    item.registerCloudKitShare(theShare, container: container)

                    share(item: item)
                } catch {
                    completion(error)
                }
            }
        } else {
            let item = NSItemProvider()

            item.registerCloudKitShare { completion in
                swlog("🐞 registerCloudKitShare called...")

                Task { [weak self] in
                    guard let self else { return }

                    do {
                        let (share, container) = try await CloudKitDatabasesInteractor.shared.beginSharing(for: database)

                        completion(share, container, nil)
                    } catch {
                        completion(nil, nil, error)
                    }
                }
            }

            share(item: item)
        }
    }

    @MainActor
    func share(item: NSItemProvider) {
        do {
            let items = [item]

            guard let service = NSSharingService(named: .cloudSharing), service.canPerform(withItems: items) else {
                swlog("🔴 Could not create NSSharingService")
                throw StrongboxSyncSharingError.couldNotCreateSharingService
            }

            service.delegate = self

            service.perform(withItems: items)
        } catch {
            completion(error)
        }
    }

    func sharingService(_: NSSharingService, sourceWindowForShareItems _: [Any], sharingContentScope _: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        window
    }

    func sharingService(_: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        swlog("🔴 \(#function) - \(items) - Error = \(String(describing: error))")

        if (error as NSError).code == NSUserCancelledError {
            completion(nil) 
        } else {
            completion(error)
        }
    }

    func sharingService(_: NSSharingService, didShareItems _: [Any]) {
        swlog("🐞 \(#function)")

        completion(nil)
    }

    func options(for _: NSSharingService, share _: NSItemProvider) -> NSSharingService.CloudKitOptions {
        
        [.allowPrivate, .allowPublic, .allowReadOnly, .allowReadWrite]
    }

    func sharingService(_: NSSharingService, didStopSharing _: CKShare) {
        swlog("🐞 \(#function)")
        completion(nil)
    }




















}
