//
//  KeeAgentSettings.swift
//  MacBox
//
//  Created by Strongbox on 25/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

// <?xml version="1.0" encoding="UTF-16"?>
// <EntrySettings xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
//     <AllowUseOfSshKey>true</AllowUseOfSshKey>






import Foundation

enum KeeAgentSettingsParseError: Error {
    case generic(detail: String)
}

@objc
public class KeeAgentSettings: NSObject {
    enum XmlElementNames {
        static let EntrySettings = "EntrySettings"
        static let AllowUseOfSshKey = "AllowUseOfSshKey"
        static let AddAtDatabaseOpen = "AddAtDatabaseOpen"
        static let RemoveAtDatabaseClose = "RemoveAtDatabaseClose"
        static let UseConfirmConstraintWhenAdding = "UseConfirmConstraintWhenAdding"
        static let UseLifetimeConstraintWhenAdding = "UseLifetimeConstraintWhenAdding"
        static let LifetimeConstraintDuration = "LifetimeConstraintDuration"
        static let Location = "Location"
        static let SelectedType = "SelectedType"
        static let AttachmentName = "AttachmentName"
        static let SaveAttachmentToTempFile = "SaveAttachmentToTempFile"
        static let FileName = "FileName"
    }

    @objc public var enabled: Bool = false
    @objc public var attachmentName: String

    public var addAtDatabaseOpen: Bool = true
    public var removeAtDatabaseClose: Bool = true
    public var useConfirmConstraintWhenAdding: Bool = false
    public var useLifetimeConstraintWhenAdding: Bool = false
    public var lifetimeConstraintDuration: String = "600"
    public var selectedType: String = "attachment"
    public var fileName: String = ""
    public var saveAttachmentToTempFile: Bool = false

    init(enabled: Bool, attachmentName: String) {
        self.enabled = enabled
        self.attachmentName = attachmentName
    }

    @objc public class func settingsWithAttachmentName(_ attachmentName: String, enabled: Bool = false) -> KeeAgentSettings {
        KeeAgentSettings(enabled: enabled, attachmentName: attachmentName)
    }

    @objc public class func fromString(_ string: String) throws -> KeeAgentSettings {
        guard let data = string.data(using: .utf8) else {
            throw KeeAgentSettingsParseError.generic(detail: "Could not convert string to data")
        }

        return try fromData(data)
    }

    @objc public class func fromData(_ data: Data) throws -> KeeAgentSettings {
        let document = try XMLDocument(data: data)

        guard let rootDoc = document.rootDocument,
              rootDoc.childCount == 1,
              let root = rootDoc.child(at: 0),
              root.name == XmlElementNames.EntrySettings
        else {
            throw KeeAgentSettingsParseError.generic(detail: "Could not find EntrySettings element")
        }

        let settings = root.children

        let allow = settings?.first { setting in
            setting.name == "AllowUseOfSshKey"
        }
        let location = settings?.first { setting in
            setting.name == "Location"
        }

        

        let enabled = allow?.stringValue == "true"

        

        var attachmentName = ""
        if let location {
            guard let locChildren = location.children else {
                throw KeeAgentSettingsParseError.generic(detail: "Could not find Location children")
            }

            

            let attachmentNameEl = locChildren.first { locChild in
                locChild.name == "AttachmentName"
            }

            guard let attachmentNameEl, let name = attachmentNameEl.stringValue, name.count > 0 else {
                throw KeeAgentSettingsParseError.generic(detail: "Could not find valid AttachmentName element")
            }

            attachmentName = name
        }

        return KeeAgentSettings(enabled: enabled, attachmentName: attachmentName)
    }

    @objc public func toXmlData() -> Data {
        let writer = XMLWriter()
        writer.setPrettyPrinting("  ", withLineBreak: "\n")
        writer.automaticEmptyElements = true
        writer.writeStartDocument(withEncodingAndVersion: "UTF-16", version: nil)

        writer.writeStartElement(XmlElementNames.EntrySettings)
        writer.writeAttribute("xmlns:xsd", value: "http:
        writer.writeAttribute("xmlns:xsi", value: "http:

        writer.writeStartElement(XmlElementNames.AllowUseOfSshKey)
        writer.writeCharacters(enabled ? "true" : "false")
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.AddAtDatabaseOpen)
        writer.writeCharacters(addAtDatabaseOpen ? "true" : "false")
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.RemoveAtDatabaseClose)
        writer.writeCharacters(removeAtDatabaseClose ? "true" : "false")
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.UseConfirmConstraintWhenAdding)
        writer.writeCharacters(useConfirmConstraintWhenAdding ? "true" : "false")
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.UseLifetimeConstraintWhenAdding)
        writer.writeCharacters(useLifetimeConstraintWhenAdding ? "true" : "false")
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.LifetimeConstraintDuration)
        writer.writeCharacters(lifetimeConstraintDuration)
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.Location)

        writer.writeStartElement(XmlElementNames.SelectedType)
        writer.writeCharacters(selectedType)
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.AttachmentName)
        writer.writeCharacters(attachmentName)
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.SaveAttachmentToTempFile)
        writer.writeCharacters(saveAttachmentToTempFile ? "true" : "false")
        writer.writeEndElement()

        writer.writeStartElement(XmlElementNames.FileName)
        writer.writeCharacters(fileName)
        writer.writeEndElement()

        writer.writeEndElement() 
        writer.writeEndElement() 
        writer.writeEndDocument()

        return writer.toData()
    }

    public func isSameAs(_ other: KeeAgentSettings) -> Bool {
        enabled == other.enabled &&
            attachmentName == other.attachmentName &&
            addAtDatabaseOpen == other.addAtDatabaseOpen &&
            removeAtDatabaseClose == other.removeAtDatabaseClose &&
            useConfirmConstraintWhenAdding == other.useConfirmConstraintWhenAdding &&
            useLifetimeConstraintWhenAdding == other.useLifetimeConstraintWhenAdding &&
            lifetimeConstraintDuration == other.lifetimeConstraintDuration &&
            selectedType == other.selectedType &&
            fileName == other.fileName &&
            saveAttachmentToTempFile == other.saveAttachmentToTempFile
    }
}
