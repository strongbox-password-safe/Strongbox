//
//  CloudKitSharingUIHelper.swift
//  Strongbox
//
//  Created by Strongbox on 05/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import UIKit

@available(iOS 15.0, *)
@objc
class CloudKitSharingUIHelper: NSObject, UICloudSharingControllerDelegate {
    var database: DatabasePreferences
    var parentViewController: UIViewController 
    var fooCompletion: (() -> Void)? = nil

    deinit {
        NSLog("🔴 RUHG ROH!") 
    }

    @objc
    init(database: DatabasePreferences, parentViewController: UIViewController) {
        self.database = database
        self.parentViewController = parentViewController
    }

    @objc
    func present(rect: CGRect, sourceView: UIView, fooCompletion: @escaping (() -> Void)) {
        self.fooCompletion = fooCompletion

        let cloudSharingController = UICloudSharingController { [weak self] (_, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
            guard let self else { return }

            share(completion: completion)
        }

        

        cloudSharingController.delegate = self

        if let popover = cloudSharingController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = rect
            popover.permittedArrowDirections = .any
        }

        parentViewController.present(cloudSharingController, animated: true) {
            NSLog("Yo! TODO: ")
        }
    }

    func cloudSharingController(_: UICloudSharingController, failedToSaveShareWithError error: any Error) {
        NSLog("🔴 failedToSaveShareWithError: \(error)")
    }

    func itemTitle(for _: UICloudSharingController) -> String? {
        database.nickName
    }

    func cloudSharingControllerDidSaveShare(_: UICloudSharingController) {
        NSLog("🟢 \(#function)")
    }

    func cloudSharingControllerDidStopSharing(_: UICloudSharingController) {
        NSLog("🟢 \(#function)") 
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
        NSLog("Share Called!")

        Task {
            do {
                let result = try await CloudKitDatabasesInteractor.shared.beginSharing(for: database)

                completion(result.share, result.container, nil)
            } catch {
                completion(nil, nil, error)
            }
        }
    }
}
