//
//  CompareAndMergeWizard.swift
//  MacBox
//
//  Created by Strongbox on 05/05/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class CompareAndMergeWizard: NSViewController {
    @objc
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "CompareAndMergeWizard", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    @objc var firstModel: ViewModel!
    @objc var onSelectedSecondDatabase: ((_ secondDatabase: DatabaseModel, _ secondModelMetadata: MacDatabasePreferences?, _ secondModelFileUrl: URL?) -> Void)?

    @IBAction func onCancel(_: Any) {
        dismiss(nil)
    }

    @IBAction func onSelectFile(_: Any) {
        let openPanel = NSOpenPanel()

        if openPanel.runModal() == .OK {
            swlog("%@", String(describing: openPanel.url))

            guard let url = openPanel.url else {
                return
            }

            onSelectedFileUrl(url: url)
        }
    }

    func onSelectedFileUrl(url: URL) {
        let ckfs = firstModel.compositeKeyFactors!

        tryUnlockFileUrlWithCkfs(url: url, ckfs: ckfs) { [weak self] model, error in
            if let error {
                MacAlerts.error(error, window: self?.view.window)
            } else if let model {
                self?.onSelectedDatabaseModel(secondModel: model, secondModelMetadata: nil, secondModelFileUrl: url)
            }
        }
    }

    func tryUnlockFileUrlWithCkfs(url: URL,
                                  ckfs: CompositeKeyFactors,
                                  completion: @escaping (_ model: DatabaseModel?, _ error: Error?) -> Void)
    {
        Serializator.fromUrl(url, ckf: ckfs) { userCancelled, model, _, error in
            if error != nil {
                completion(nil, error)
            } else if !userCancelled, let model {
                completion(model, nil)
            }
        }
    }

    @IBAction func onSelectDatabase(_: Any) {
        let vc = SelectDatabaseViewController.fromStoryboard()
        vc.disabledDatabases = Set([firstModel.databaseUuid])

        vc.onDone = { [weak self] userCancelled, database in
            if !userCancelled, let database {
                self?.onSelectedSecond(database)
            }
        }

        presentAsSheet(vc)
    }

    func onSelectedSecond(_ database: MacDatabasePreferences) {
        if let ckfs = firstModel.compositeKeyFactors,
           let express = DatabaseUnlocker.expressTryUnlock(withKey: database, key: ckfs)
        {
            onSelectedDatabaseModel(secondModel: express.database, secondModelMetadata: database, secondModelFileUrl: nil)
            return
        }

        let keyDeterminer = MacCompositeKeyDeterminer(viewController: self, database: database, isNativeAutoFillAppExtensionOpen: false)
        keyDeterminer.getCkfs { [weak self] result, ckfs, fromConvenience, error in
            switch result {
            case .success:
                if let ckfs {
                    self?.onSuccessfulSecondDatabaseGotKeys(database, ckfs, fromConvenience)
                }
            case .error:
                MacAlerts.error(error, window: self?.view.window)
            case .userCancelled, .duressIndicated:
                
                break
            @unknown default:
                break
            }
        }
    }

    func onSuccessfulSecondDatabaseGotKeys(_ database: MacDatabasePreferences, _ ckfs: CompositeKeyFactors, _ fromConvenience: Bool) {
        let unlocker = DatabaseUnlocker(forDatabase: database, viewController: self, forceReadOnly: true, isNativeAutoFillAppExtensionOpen: false, offlineMode: true)
        unlocker.unlockLocal(withKey: ckfs, keyFromConvenience: fromConvenience) { [weak self] unlockResult, model, error in
            switch unlockResult {
            case .success:
                if let model {
                    self?.onSelectedDatabaseModel(secondModel: model.database, secondModelMetadata: database, secondModelFileUrl: nil)
                }
            case .error:
                MacAlerts.error(error, window: self?.view.window)
            case .userCancelled, .viewDebugSyncLogRequested:
                break
            case .incorrectCredentials:
                MacAlerts.info(NSLocalizedString("open_sequence_problem_opening_incorrect_credentials_title", comment: "Incorrect Credentials"),
                               informativeText: NSLocalizedString("open_sequence_problem_opening_incorrect_credentials_message", comment: "The credentials were incorrect for this database."),
                               window: self?.view.window,
                               completion: nil)
            @unknown default:
                break
            }
        }
    }

    func onSelectedDatabaseModel(secondModel: DatabaseModel, secondModelMetadata: MacDatabasePreferences?, secondModelFileUrl: URL?) {
        swlog("✅ Second Database Loaded")

        dismiss(nil)

        onSelectedSecondDatabase?(secondModel, secondModelMetadata, secondModelFileUrl)
    }
}
