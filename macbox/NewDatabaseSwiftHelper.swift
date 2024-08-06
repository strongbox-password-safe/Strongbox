//
//  NewDatabaseSwiftHelper.swift
//  MacBox
//
//  Created by Strongbox on 06/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
class NewDatabaseSwiftHelper: NSObject {
    enum NewDatabaseWizardError: Error {
        case invalidParameter
        case cannotCopyNoLocal
    }

    let wizard = CreateDatabaseOrSetCredentialsWizard.newCreateDatabase()

    let parentViewController: NSViewController
    let provider: SafeStorageProvider
    let providerLocationParam: NSObject?
    let completion: (_ database: MacDatabasePreferences?, _ userCancelled: Bool, _ error: Error?) -> Void

    @objc
    init(parentViewController: NSViewController,
         provider: SafeStorageProvider,
         providerLocationParam: NSObject?,
         completion: @escaping (_: MacDatabasePreferences?, _: Bool, _: Error?) -> Void)
    {
        self.parentViewController = parentViewController
        self.provider = provider
        self.providerLocationParam = providerLocationParam
        self.completion = completion
    }

    @objc
    func beginBrandNewDatabaseSequence() throws {
        wizard.allowFormatSelection = true

        try requestCkfsForNewOrImportedDatabase()
    }

    @objc
    func beginImportNewDatabaseSequence(importedModel: DatabaseModel) throws {
        

        wizard.allowFormatSelection = false

        try requestCkfsForNewOrImportedDatabase(importedModel: importedModel)
    }

    @objc
    func beginCopyToNewDatabaseSequence(sourceDatabase: MacDatabasePreferences) throws {
        guard let url = WorkingCopyManager.sharedInstance().getLocalWorkingCache(sourceDatabase.uuid) else {
            swlog("🔴 Could not open Strongbox's local copy of this database. A online sync is required")
            throw NewDatabaseWizardError.cannotCopyNoLocal
        }

        let data = try Data(contentsOf: url)

        let nickName = MacDatabasePreferences.getUniqueName(fromSuggestedName: String(format: NSLocalizedString("copy_of_fmt", comment: "Copy of %@"), sourceDatabase.nickName))

        let fileName = sourceDatabase.fileUrl.lastPathComponent

        createDatabaseWithSerializedData(nickName: nickName, fileName: fileName, data: data)
    }

    

    func requestCkfsForNewOrImportedDatabase(importedModel: DatabaseModel? = nil) throws {
        guard let window = wizard.window,
              let parentWindow = parentViewController.view.window
        else {
            swlog("🔴 Could not get wizard or parent window, cannot present wizard sheet")
            throw NewDatabaseWizardError.invalidParameter
        }

        parentWindow.beginSheet(window) { [weak self] response in
            guard let self else { return }

            guard response == .OK else {
                completion(nil, true, nil)
                return
            }

            onGotNicknameAndCredentials(importedModel: importedModel, parentViewController: parentViewController)
        }
    }

    func onGotNicknameAndCredentials(importedModel: DatabaseModel?, parentViewController: NSViewController) {
        let ckfs: CompositeKeyFactors

        do {
            ckfs = try wizard.generateCkf(fromSelectedFactors: parentViewController)

            createNewDatabase(importedModel: importedModel, ckfs: ckfs)
        } catch {
            completion(nil, false, error)
        }
    }

    func getDatabaseModel(importedModel: DatabaseModel?, ckfs: CompositeKeyFactors) -> DatabaseModel {
        let databaseModel: DatabaseModel

        if let importedModel {
            databaseModel = importedModel
            databaseModel.ckfs = ckfs 
        } else {
            databaseModel = DatabaseModel(format: wizard.selectedDatabaseFormat, compositeKeyFactors: ckfs)

            SampleItemsGenerator.addSampleGroupAndRecord(toRoot: databaseModel, passwordConfig: Settings.sharedInstance().passwordGenerationConfig)
        }

        return databaseModel
    }

    func createNewDatabase(importedModel: DatabaseModel?, ckfs: CompositeKeyFactors) {
        let databaseModel = getDatabaseModel(importedModel: importedModel, ckfs: ckfs)

        let outputStream = OutputStream.toMemory()
        outputStream.open()

        CrossPlatformDependencies.defaults().spinnerUi.show(NSLocalizedString("generic_encrypting", comment: "Encrypting"), viewController: parentViewController)

        DispatchQueue.global().async {
            Serializator.getAsData(databaseModel, format: databaseModel.originalFormat, outputStream: outputStream) { [weak self] userCancelled, _, maybeError in
                CrossPlatformDependencies.defaults().spinnerUi.dismiss()

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }

                    onNewDatabaseDatabaseSerializationDone(outputStream: outputStream, userCancelled: userCancelled, maybeError: maybeError)
                }
            }
        }
    }

    func onNewDatabaseDatabaseSerializationDone(outputStream: OutputStream, userCancelled: Bool, maybeError: Error?) {
        outputStream.close()

        if let error = maybeError {
            swlog("🔴 Error Serializing new database: \(error)")
            completion(nil, false, error)
        } else if userCancelled {
            completion(nil, true, nil) 
        } else {
            guard let data = outputStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
                let error = Utils.createNSError("Could not get data parameter from output stream", errorCode: -1)
                swlog("🔴 Error Serializing new database: \(error)")
                completion(nil, false, error)
                return
            }

            let filename = String(format: "%@.%@", wizard.selectedNickname, Serializator.getDefaultFileExtension(for: wizard.selectedDatabaseFormat))

            createDatabaseWithSerializedData(nickName: wizard.selectedNickname, fileName: filename, data: data)
        }
    }

    func createDatabaseWithSerializedData(nickName: String, fileName: String, data: Data) {
        if provider.storageId == .kLocalDevice {
            guard let url = getLocalDeviceFileSaveURL(fileName: fileName) else {
                completion(nil, true, nil) 
                return
            }

            createDatabaseOnStorage(nickName: nickName, fileName: fileName, data: data, providerLocationParamOverride: url as NSURL)
        } else {
            createDatabaseOnStorage(nickName: nickName, fileName: fileName, data: data)
        }
    }

    func getLocalDeviceFileSaveURL(fileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("mac_save_new_database", comment: "Save New Password Database...")

        let loc3 = NSLocalizedString("mac_save_action", comment: "Save")
        panel.prompt = loc3

        let loc4 = NSLocalizedString("mac_save_new_db_message", comment: "You must save this new database before you can use it")
        panel.message = loc4

        panel.nameFieldStringValue = fileName

        if panel.runModal() != .OK {
            return nil
        }

        return panel.url
    }

    func createDatabaseOnStorage(nickName: String, fileName: String, data: Data, providerLocationParamOverride: NSObject? = nil) {
        var location: NSObject? = nil

        if let providerLocationParamOverride {
            location = providerLocationParamOverride 
        } else if let loc = providerLocationParam as? StorageBrowserItem {
            location = loc.providerData
        }

        CrossPlatformDependencies.defaults().spinnerUi.show(NSLocalizedString("storage_provider_status_authenticating_creating", comment: "Creating..."),
                                                            viewController: parentViewController)

        provider.create(nickName,
                        fileName: fileName,
                        data: data,
                        parentFolder: location,
                        viewController: parentViewController)
        { [weak self] maybeDatabase, maybeError in
            guard let self else { return }

            DispatchQueue.main.async { [weak self] in
                CrossPlatformDependencies.defaults().spinnerUi.dismiss()

                self?.onDatabaseCreationDone(database: maybeDatabase, error: maybeError)
            }
        }
    }

    func onDatabaseCreationDone(database: MacDatabasePreferences?, error: Error?) {
        if let error {
            swlog("🔴 Error Creating Database on Storage [\(provider.storageId)] => [\(error)]")
            completion(nil, false, error)
        } else {
            guard let database else {
                let error = Utils.createNSError("🔴 Unknown Error Creating Database on Storage", errorCode: -1)
                swlog("🔴 Unknown Error Creating Database on Storage [\(provider.storageId)] => [\(error)]")
                completion(nil, false, error)
                return
            }



            onDatabaseSuccessfullyCreated(database: database)
        }
    }

    func onDatabaseSuccessfullyCreated(database: MacDatabasePreferences) {
        if !Settings.sharedInstance().doNotRememberKeyFile {
            database.keyFileBookmark = wizard.selectedKeyFileBookmark
        }

        database.yubiKeyConfiguration = wizard.selectedYubiKeyConfiguration
        database.showAdvancedUnlockOptions = wizard.selectedKeyFileBookmark != nil || wizard.selectedYubiKeyConfiguration != nil

        

        completion(database, false, nil)
    }
}
