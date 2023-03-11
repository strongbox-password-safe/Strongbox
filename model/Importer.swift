//
//  Importer.swift
//  MacBox
//
//  Created by Strongbox on 01/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

@objc public protocol Importer {
    var allowedFileTypes : [String] { get }
    func convert ( url : URL) throws -> DatabaseModel
}

enum CsvGenericImporterError: Error {
    case errorParsing (details : String)
}

extension CsvGenericImporterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .errorParsing(details: let details):
            return details
        }
    }
}


class BaseImporter {
    class func addUrl(_ node: Node, _ url: String, _ label : String? = nil) {
        if node.fields.url == url || node.fields.alternativeUrls.contains(url) {
            return
        }
        
        if node.fields.url.count == 0 {
            node.fields.url = url
        }
        else {
            node.fields.addSecondaryUrl(url, optionalCustomFieldSuffixLabel: label)
        }
    }
    
    class func addCustomField ( node: Node, name : String?, value : String, protected : Bool = false ) {
        if let url = value.urlExtendedParse, url.scheme != nil, url.absoluteString.count == value.count, !protected { 
            addUrl(node, url.absoluteString, name)
            return
        }
        
        let base = (name != nil && !(name!.isEmpty)) ? name! : "Unknown Field"
        var uniqueName = base
        
        var i = 2;
        
        while node.fields.customFields.containsKey(uniqueName as NSString) || Constants.reservedCustomFieldKeys().contains(uniqueName) {
            uniqueName = String(format: "%@-%d", base, i)
            i = i + 1
        }
        
        node.fields.setCustomField(uniqueName, value: StringValue(string: value, protected: protected ))
    }
    
    







}
