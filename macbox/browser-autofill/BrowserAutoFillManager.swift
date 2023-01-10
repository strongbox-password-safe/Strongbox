//
//  BrowserAutoFillManager.swift
//  MacBox
//
//  Created by Strongbox on 29/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.

import Foundation

@objc
public class BrowserAutoFillManager: NSObject {
    private static let domainParser : DomainParser! = getParser();
    
    class func getParser () -> DomainParser? {
        do {
            return try DomainParser()
        }
        catch {
            NSLog("🔴 Error initializing Domain Parser in BrowserAutoFillManager: [%@]", String(describing: error))
            return nil
        }
    }

    @objc public class func extractPSLDomainFromUrl(url: String) -> String {
        guard let urlProcessed = url.urlExtendedParseAddingDefaultScheme else {
            return url.lowercased()
        }

        if let components = URLComponents(url: urlProcessed, resolvingAgainstBaseURL: false),
           let host = components.host {
            let parsed = domainParser.parse(host: host)
            return parsed?.domain?.lowercased() ?? host.lowercased()
        }
        else {
            let parsed = domainParser.parse(host: url)
            return parsed?.domain?.lowercased() ?? url.lowercased()
        }
    }

    @objc class func getMatchingNodes(url: String, domainNodeMap : [String: Set<UUID>]) -> Set<UUID> {

        
        let domain = extractPSLDomainFromUrl(url: url)
        
        var ret : Set<UUID> = Set()
        
        if let direct = domainNodeMap[domain] {
            ret = direct
        }
        else {
            
        
            for equivalentDomain in ApplePasswordManagerQuirks.shared.getEquivalentDomains(domain) {
                
            
                if let found = domainNodeMap[equivalentDomain] {
                    
                    ret = found
                    break;
                }
            }
        }



        if ( !ret.isEmpty ) {

        }
        else {

        }

        return ret
    }

    @objc class func loadDomainNodeMap(_ database: DatabaseModel, alternativeUrls: Bool = true, customFields: Bool = false, notes: Bool = false) -> [String: Set<UUID>] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let all = database.allSearchableNoneExpiredEntries

        var mutableRet: [String: Set<UUID>] = [:]

        for node in all {
            let uniqueUrls = AutoFillCommon.getUniqueUrls(forNode: database, node: node, alternativeUrls: alternativeUrls, customFields: customFields, notes: notes)

            let domains = Set(uniqueUrls.map { extractPSLDomainFromUrl(url: $0) })

            for domain in domains {
                mutableRet[domain, default: Set<UUID>()].insert(node.uuid)
            }
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        NSLog("⏱ loadDomainNodeMap: Loaded \(mutableRet.count) domains from \(all.count) entries in \(timeElapsed) s.")

        return mutableRet
    }
    
    @objc public class func compareMatches(node1 : Node, node2 : Node, url : String, isFavourite : ((Node) -> Bool) ) -> ComparisonResult {
        
        
        if ( isFavourite(node1) ) {

            
            return isFavourite(node2) ? .orderedSame : .orderedAscending
        }
        if ( isFavourite(node2) ) {
            
            
            return isFavourite(node1) ? .orderedSame : .orderedDescending
        }

        
        
        if ( node1.fields.url != node2.fields.url ) {
            
            
            if ( node1.fields.url == url ) {

                return .orderedAscending
            }
            
            if ( node2.fields.url == url ) {

                return .orderedDescending
            }
            

            
            
            
            let distance1 = node1.fields.url.levenshteinDistance(url)
            let distance2 = node2.fields.url.levenshteinDistance(url)



            if ( distance1 != distance2 ) {
                return (distance1 < distance2) ? .orderedAscending : .orderedDescending
            }
        }
        else {

        }
        
        
        return node1.title.compare(node2.title)
    }
}
