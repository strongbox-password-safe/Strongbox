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

    @objc public class func extractDomainFromUrl(url: String) -> String {
        guard let urlProcessed = url.urlExtendedParse else {
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
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let domain = extractDomainFromUrl(url: url)
        
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

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        if ( !ret.isEmpty ) {
            NSLog("✅ Found \(ret.count) domain matches for [\(domain)] in \(timeElapsed) s.")
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

            let domains = Set(uniqueUrls.map { extractDomainFromUrl(url: $0) })

            for domain in domains {
                mutableRet[domain, default: Set<UUID>()].insert(node.uuid)
            }
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        NSLog("⏱ loadDomainNodeMap: Loaded \(mutableRet.count) domains from \(all.count) entries in \(timeElapsed) s.")

        return mutableRet
    }
}
