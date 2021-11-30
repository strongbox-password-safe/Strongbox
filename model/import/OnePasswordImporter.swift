//
//  File.swift
//  MacBox
//
//  Created by Strongbox on 19/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

//

enum OnePasswordImporterError : Error {
    case CouldNotConvertStringToData
    case UnknownRecordType(typeString : String)
}

class OnePasswordImporter : NSObject {
    static let magicSplitter : String = "***5642bee8-a5ff-11dc-8314-0800200c9a66***"
    
    @objc
    class func convertToStrongboxNodes(url : URL) throws -> Node {
        
        
        let text : String = try String(contentsOf: url)
        
        return try convertToStrongboxNodes(text: text)
    }
    
    @objc
    class func convertToStrongboxNodes(text : String) throws -> Node {
        let jsonRecords = text.components(separatedBy: magicSplitter)
                
        let records = try getRecords(jsonRecords)
                

        
        
        
        let uniqueRecordTypes = Array ( Set ( records.compactMap { recordTypeByTypeName [ $0.typeName ?? "" ] } ) )
        let uniqueCategories = uniqueRecordTypes.compactMap { $0.category() }

        let rot : Node = Node.rootWithDefaultKeePassEffectiveRootGroup()
        let effectiveRootGroup : Node = rot.childGroups.first!
        
        var categoryToNodeMap : [ ItemCategory : Node ] = [:]
        for category in uniqueCategories {
            if ( category == .Unknown ) {
                continue
            }

            let categoryNode = Node(asGroup: category.rawValue, parent: effectiveRootGroup, keePassGroupTitleRules: true, uuid: nil)
            
            if ( categoryNode != nil ) {
                categoryNode!.icon = NodeIcon.withPreset(category.icon().rawValue)
                effectiveRootGroup.addChild(categoryNode!, keePassGroupTitleRules: true)
                categoryToNodeMap[category] = categoryNode!
            }
        }

        
        
        for record in records {
            let trashed = record.trashed ?? false
            if ( trashed ) {
                continue
            }
            
            let recordType = record.type
            
            if ( !recordTypeIsProcessable (recordType) ) {
                print("Unprocessable Record Type, Ignoring: \(String(describing: record.typeName))")
                continue;
            }
            
            let category = recordType.category()
            let categoryNode = categoryToNodeMap[category]
            let parentNode = categoryNode ?? effectiveRootGroup
            
            let entry = Node(asRecord: "", parent: parentNode )
            
            record.fillStrongboxEntry(entry: entry)
            parentNode.addChild(entry, keePassGroupTitleRules: true)
        }
        
        return rot
    }
    
    class func recordTypeIsProcessable(_ recordType : RecordType) -> Bool {
        if ( recordType == .SavedSearch ) {
            return false
        }
        else if ( recordType == .RegularFolder ) {
            return false
        }
        
        return true
    }

    fileprivate static func getRecords(_ jsonRecords: [String]) throws -> [UnifiedRecord] {
        var records : [UnifiedRecord] = []

        for jsonRecord in jsonRecords {
            let trimmed : String  = jsonRecord.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines )
            
            if ( trimmed.count == 0 ) {
                continue
            }
            
            let jsonData : Data? = trimmed.data(using: .utf8, allowLossyConversion: true)
            if ( jsonData == nil ) {
                throw OnePasswordImporterError.CouldNotConvertStringToData
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            let baseRecord = try decoder.decode(UnifiedRecord.self, from: jsonData!)

            records.append(baseRecord)
        }
        
        return records
    }
}
