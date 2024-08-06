//
//  CloudKitSharingUIHelper.swift
//  Strongbox
//
//  Created by Strongbox on 05/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import UIKit

@objc
class CloudKitSharingUIHelper: NSObject, UICloudSharingControllerDelegate {
    let database: DatabasePreferences
    let parentViewController: UIViewController
    let completion: (_ error: Error?) -> Void

    enum StrongboxSyncSharingError: Error {
        case couldNotGetExistingCloudKitShare
    }

    @objc
    init(database: DatabasePreferences, parentViewController: UIViewController, completion: @escaping (_: Error?) -> Void) {
        self.database = database
        self.parentViewController = parentViewController
        self.completion = completion
    }

    @objc
    func present(rect: CGRect, sourceView: UIView) {
        if database.isSharedInCloudKit {
            Task { [weak self] in
                guard let self else { return }

                do {
                    let (share, container) = try await CloudKitDatabasesInteractor.shared.getCurrentCKShare(for: database)

                    guard let share else {
                        throw StrongboxSyncSharingError.couldNotGetExistingCloudKitShare
                    }

                    createExistingShareControllerAndPresent(share, container, rect: rect, sourceView: sourceView)
                } catch {
                    completion(error)
                }
            }
        } else {
            let cloudSharingController = UICloudSharingController { [weak self] (_, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
                guard let self else { return }

                share(completion: completion)
            }

            presentCloudSharingController(cloudSharingController, rect: rect, sourceView: sourceView)
        }
    }

    @MainActor
    func createExistingShareControllerAndPresent(_ share: CKShare, _ container: CKContainer, rect: CGRect, sourceView: UIView) {
        let cloudSharingController = UICloudSharingController(share: share, container: container)

        presentCloudSharingController(cloudSharingController, rect: rect, sourceView: sourceView)
    }

    @MainActor
    func presentCloudSharingController(_ cloudSharingController: UICloudSharingController, rect: CGRect, sourceView: UIView) {
        cloudSharingController.delegate = self

        if let popover = cloudSharingController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = rect
            popover.permittedArrowDirections = .any
        }

        parentViewController.present(cloudSharingController, animated: true)
    }

    func cloudSharingController(_: UICloudSharingController, failedToSaveShareWithError error: any Error) {
        swlog("🔴 failedToSaveShareWithError: \(error)")

        completion(error)
    }

    func itemTitle(for _: UICloudSharingController) -> String? {
        database.nickName
    }

    func cloudSharingControllerDidSaveShare(_: UICloudSharingController) {
        swlog("🟢 \(#function)")
        completion(nil) 
    }

    func cloudSharingControllerDidStopSharing(_: UICloudSharingController) {
        swlog("🟢 \(#function)")
        completion(nil)
    }

    func itemThumbnailData(for _: UICloudSharingController) -> Data? {
        let imageName: String
        if #available(iOS 16.0, *) {
            imageName = "cloud.circle"
        } else {
            imageName = "cloud"
        }

        let config = UIImage.SymbolConfiguration(scale: .large)

        guard let icon = UIImage(systemName: imageName),
              let tinted = icon.withTintColor(.systemBlue, renderingMode: .alwaysTemplate).applyingSymbolConfiguration(config)
        else {
            return nil
        }

        if #available(iOS 17.0, *) {
            return tinted.heicData()
        } else {
            return tinted.pngData()
        }
    }

    func share(completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        swlog("Share Called!")

        Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await CloudKitDatabasesInteractor.shared.beginSharing(for: database)

                completion(result.share, result.container, nil)
            } catch {
                swlog("🔴 \(error)")
                completion(nil, nil, error)
            }
        }
    }
}
