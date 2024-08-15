//
//  SelectStorageSwiftHelper.swift
//  Strongbox
//
//  Created by Strongbox on 04/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//
import Foundation

@objc
class SelectStorageSwiftHelper: NSObject {
    private enum Mode {
        case initialInvalid
        case createOnStorage(nickName: String, model: DatabaseModel)
        case copyToStorage(metadata: DatabasePreferences)
    }

    private var mode: Mode = .initialInvalid
    let parentViewController: UIViewController
    let completion: (_ database: DatabasePreferences?, _ userCancelled: Bool, _ error: Error?) -> Void

    @objc
    init(parentViewController: UIViewController, completion: @escaping (_: DatabasePreferences?, _: Bool, _: Error?) -> Void) {
        self.parentViewController = parentViewController
        self.completion = completion
    }

    @objc
    func beginCreateOnStorageInteraction(nickName: String, databaseModel: DatabaseModel) {
        mode = .createOnStorage(nickName: nickName, model: databaseModel)

        begin()
    }

    @objc
    func beginCopyToStorageInteraction(databaseToCopy: DatabasePreferences) {
        mode = .copyToStorage(metadata: databaseToCopy)

        begin()
    }

    func begin() {
        let nav = SelectStorageProviderController.navControllerFromStoryboard()

        guard let vc = nav.topViewController as? SelectStorageProviderController else {
            swlog("🔴 Couldnt convert nav top vc to selectspvc")
            completion(nil, false, Utils.createNSError("Could not create the Select Storage view!", errorCode: -1))
            return
        }

        vc.existing = false
        vc.onDone = { [weak self] params in
            DispatchQueue.main.async { [weak self] in
                self?.parentViewController.dismiss(animated: true) { [weak self] in
                    self?.onUserDoneWithSelectionUI(params)
                }
            }
        }

        parentViewController.present(nav, animated: true)
    }

    func onUserDoneWithSelectionUI(_ selectedStorageParameters: SelectedStorageParameters) {
        

        switch selectedStorageParameters.method {
        case .storageMethodUserCancelled:
            onUserCancelled()
        case .storageMethodErrorOccurred:
            onErrorOccurred(selectedStorageParameters.error ?? Utils.createNSError("N/A", errorCode: -1))
        case .storageMethodFilesAppUrl, .storageMethodNativeStorageProvider:
            onSelectedNewStorageLocation(selectedStorageParameters)
        case .storageMethodManualUrlDownloadedData:
            swlog("🔴 storageMethodManualUrlDownloadedData returned from onSelectStorageLocationCompleted")
        @unknown default:
            swlog("🔴 Unknown Result returned from onSelectStorageLocationCompleted")
        }
    }

    func onUserCancelled() {
        completion(nil, true, nil)
    }

    func onErrorOccurred(_ error: Error) {
        completion(nil, false, error)
    }

    func onSelectedNewStorageLocation(_ selectedStorageParameters: SelectedStorageParameters) {
        if case let .copyToStorage(metadata) = mode {
            onSelectedNewStorageLocationForCopy(metadata, selectedStorageParameters)
        } else if case let .createOnStorage(nickName, model) = mode {
            onSelectedNewStorageLocationForCreate(nickName: nickName, model, selectedStorageParameters)
        }
    }

    func onSelectedNewStorageLocationForCreate(nickName: String, _ model: DatabaseModel, _ selectedStorageParameters: SelectedStorageParameters) {
        let outputStream = OutputStream.toMemory()
        outputStream.open()

        CrossPlatformDependencies.defaults().spinnerUi.show(NSLocalizedString("generic_encrypting", comment: "Encrypting"), viewController: parentViewController)

        DispatchQueue.global().async {
            Serializator.getAsData(model, format: model.originalFormat, outputStream: outputStream) { [weak self] userCancelled, _, maybeError in
                CrossPlatformDependencies.defaults().spinnerUi.dismiss()

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }

                    onDatabaseSerializationDone(nickName: nickName, format: model.originalFormat, outputStream: outputStream, userCancelled: userCancelled, selectedStorageParameters, maybeError: maybeError)
                }
            }
        }
    }

    func onDatabaseSerializationDone(nickName: String, format: DatabaseFormat, outputStream: OutputStream, userCancelled: Bool, _ selectedStorageParameters: SelectedStorageParameters, maybeError: Error?) {
        outputStream.close()

        if let error = maybeError {
            swlog("🔴 Error Serializing new database: \(error)")
            completion(nil, false, error)
        } else if userCancelled {
            completion(nil, true, nil) 
            return
        } else {
            guard let data = outputStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
                let error = Utils.createNSError("Could not get data parameter from output stream", errorCode: -1)
                swlog("🔴 Error Serializing new database: \(error)")
                completion(nil, false, error)
                return
            }

            onDatabaseSerialized(nickName: nickName, format: format, data: data, selectedStorageParameters)
        }
    }

    func onDatabaseSerialized(nickName: String, format: DatabaseFormat, data: Data, _ selectedStorageParameters: SelectedStorageParameters) {
        let filename = String(format: "%@.%@", nickName, Serializator.getDefaultFileExtension(for: format))

        createDatabaseOnStorage(nickName: nickName, fileName: filename, data: data, modDate: Date.now, selectedStorageParameters)
    }

    func onSelectedNewStorageLocationForCopy(_ database: DatabasePreferences, _ selectedStorageParameters: SelectedStorageParameters) {
        guard let url = WorkingCopyManager.sharedInstance().getLocalWorkingCache(database.uuid),
              let modDate = WorkingCopyManager.sharedInstance().getModDate(database.uuid)
        else {
            swlog("🔴 Could not read local working cache.")
            completion(nil, false, Utils.createNSError("Could not read working cache, an online sync is required.", errorCode: -1))
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            swlog("🔴 \(error)")
            completion(nil, false, error)
            return
        }

        let nickName = DatabasePreferences.getUniqueName(fromSuggestedName: String(format: NSLocalizedString("copy_of_fmt", comment: "Copy of %@"), database.nickName))

        createDatabaseOnStorage(nickName: nickName, fileName: database.fileName, data: data, modDate: modDate, selectedStorageParameters)
    }

    func createDatabaseOnStorage(nickName: String, fileName: String, data: Data, modDate _: Date, _ selectedStorageParameters: SelectedStorageParameters) {
        guard let provider = selectedStorageParameters.provider else {
            completion(nil, false, Utils.createNSError("Could not get Storage Provider!", errorCode: -1))
            return
        }

        CrossPlatformDependencies.defaults().spinnerUi.show(NSLocalizedString("generic_saving_ellipsis", comment: "Saving..."), viewController: parentViewController)

        provider.create(nickName,
                        fileName: fileName,
                        data: data,
                        parentFolder: selectedStorageParameters.parentFolder,
                        viewController: parentViewController)
        { [weak self] maybeNewDatabase, maybeError in
            CrossPlatformDependencies.defaults().spinnerUi.dismiss()

            guard let self else { return }

            if let error = maybeError {
                onCreateError(error)
            } else if let newDatabase = maybeNewDatabase {
                onCreated(newDatabase)
            } else {
                onCreateError(Utils.createNSError("Unknown error creating database!", errorCode: -1))
            }
        }
    }

    func onCreateError(_ error: Error) {
        completion(nil, false, error)
    }

    func onCreated(_ newDatabase: DatabasePreferences) {
        do {
            try newDatabase.add() 
        } catch {
            completion(nil, false, error)
            return
        }

        if case let .copyToStorage(sourceDatabase) = mode {
            newDatabase.likelyFormat = sourceDatabase.likelyFormat
            newDatabase.readOnly = sourceDatabase.readOnly
            newDatabase.nextGenPrimaryYubiKeyConfig = sourceDatabase.nextGenPrimaryYubiKeyConfig
            newDatabase.setKeyFile(sourceDatabase.keyFileBookmark, keyFileFileName: sourceDatabase.keyFileFileName)
        }

        

        Task.detached {
            try? await SyncManager.sharedInstance().backgroundSyncDatabase(newDatabase, join: true, key: nil)
        }

        completion(newDatabase, false, nil)
    }
}
