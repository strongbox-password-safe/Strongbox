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

    @objc public class func extractFullDomainFromUrl(url: String) -> String {
        guard let urlProcessed = url.urlExtendedParseAddingDefaultScheme else {
            return url.lowercased()
        }
        
        if let components = URLComponents(url: urlProcessed, resolvingAgainstBaseURL: false),
           let host = components.host {
            return host.lowercased()
        }
        else {
            return url.lowercased()
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

    @objc class func loadDomainNodeMap(_ model: Model, alternativeUrls: Bool = true, customFields: Bool = false, notes: Bool = false) -> [String: Set<UUID>] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let allSearchable = model.database.allSearchableNoneExpiredEntries
        let all = allSearchable.filter { return !model.isExcluded(fromAutoFill: $0.uuid )}
        
        var mutableRet: [String: Set<UUID>] = [:]

        for node in all {
            let uniqueUrls = AutoFillCommon.getUniqueUrls(forNode: model.database,
                                                          node: node,
                                                          alternativeUrls: alternativeUrls,
                                                          customFields: customFields,
                                                          notes: notes)

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
            

            
            

            let targetDomain = extractFullDomainFromUrl(url: url)
            let fullDomain1 = extractFullDomainFromUrl(url: node1.fields.url)
            let fullDomain2 = extractFullDomainFromUrl(url: node2.fields.url)

            if ( fullDomain1 != fullDomain2 ) { 
                if ( fullDomain1 == targetDomain ) {
                    
                    return .orderedAscending
                }
                
                if ( fullDomain2 == targetDomain ) {
                    
                    return .orderedDescending
                }
                
                
                
                let targetPslDomain = extractPSLDomainFromUrl(url: url)
                let pslDomain1 = extractPSLDomainFromUrl(url: node1.fields.url)
                let pslDomain2 = extractPSLDomainFromUrl(url: node2.fields.url)
                
                if ( pslDomain1 == pslDomain2 && (pslDomain1 == targetPslDomain)) {
                    
                    
                    return fullDomain1.count < fullDomain2.count ? .orderedAscending : .orderedDescending
                }
                else {
                    if ( pslDomain1 == targetPslDomain ) {
                        return .orderedAscending
                    }
                    
                    if ( pslDomain2 == targetPslDomain ) {
                        
                        return .orderedDescending
                    }
                }
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
