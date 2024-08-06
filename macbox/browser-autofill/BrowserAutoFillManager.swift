//
//  BrowserAutoFillManager.swift
//  MacBox
//
//  Created by Strongbox on 29/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.

import Foundation

@objc
public class BrowserAutoFillManager: NSObject {
    private static let domainParser: DomainParser! = getParser()

    class func getParser() -> DomainParser? {
        do {
            return try DomainParser()
        } catch {
            swlog("🔴 Error initializing Domain Parser in BrowserAutoFillManager: [%@]", String(describing: error))
            return nil
        }
    }

    @objc public class func extractFullDomainFromUrl(url: String) -> String {
        guard let urlProcessed = url.urlExtendedParseAddingDefaultScheme else {
            return url.lowercased()
        }

        if let components = URLComponents(url: urlProcessed, resolvingAgainstBaseURL: false),
           let host = components.host
        {
            return host.lowercased()
        } else {
            return url.lowercased()
        }
    }

    @objc public class func extractPSLDomainFromUrl(url: String) -> String {
        guard let urlProcessed = url.urlExtendedParseAddingDefaultScheme else {
            return url.lowercased()
        }

        if let components = URLComponents(url: urlProcessed, resolvingAgainstBaseURL: false),
           let host = components.host
        {
            let parsed = domainParser.parse(host: host)
            return parsed?.domain?.lowercased() ?? host.lowercased()
        } else {
            let parsed = domainParser.parse(host: url)
            return parsed?.domain?.lowercased() ?? url.lowercased()
        }
    }

    @objc class func getAssociatedDomains(url: String) -> Set<String> {
        let domain = extractPSLDomainFromUrl(url: url)

        var equivs = ApplePasswordManagerQuirks.shared.getEquivalentDomains(domain)



        

        if let u = URL(string: url), let host = u.host, equivs.contains(host.lowercased()) {
            equivs.remove(host)
        }

        

        equivs.remove(domain)

        return equivs
    }

    @objc class func getMatchingNodes(url: String, domainNodeMap: [String: Set<UUID>]) -> Set<UUID> {


        let domain = extractPSLDomainFromUrl(url: url)

        let ret: Set<UUID> = domainNodeMap[domain] ?? Set()






        return ret
    }

    @objc class func loadDomainNodeMap(_ model: Model) -> [String: Set<UUID>] {
        let startTime = CFAbsoluteTimeGetCurrent()

        let allSearchable = model.database.allSearchableNoneExpiredEntries
        let all = allSearchable.filter { !model.isExcluded(fromAutoFill: $0.uuid) }

        var mutableRet: [String: Set<UUID>] = [:]

        for node in all {
            let uniqueUrls = AutoFillCommon.getUniqueUrls(forNode: model, node: node)

            let domains = Set(uniqueUrls.map { extractPSLDomainFromUrl(url: $0) })

            for domain in domains {
                mutableRet[domain, default: Set<UUID>()].insert(node.uuid)
            }
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        swlog("🐞 ⏱ loadDomainNodeMap: Loaded \(mutableRet.count) domains from \(all.count) entries in \(timeElapsed) s.")

        return mutableRet
    }

    @objc public class func compareMatches(node1: Node, node2: Node, url: String, isFavourite: (Node) -> Bool) -> ComparisonResult {
        

        
        
        
        
        
        

        if isFavourite(node1) {


            return isFavourite(node2) ? .orderedSame : .orderedAscending
        }
        if isFavourite(node2) {
            

            return isFavourite(node1) ? .orderedSame : .orderedDescending
        }

        

        if node1.fields.url != node2.fields.url {
            

            if node1.fields.url == url {

                return .orderedAscending
            }

            if node2.fields.url == url {

                return .orderedDescending
            }



            

            let targetDomain = extractFullDomainFromUrl(url: url)
            let fullDomain1 = extractFullDomainFromUrl(url: node1.fields.url)
            let fullDomain2 = extractFullDomainFromUrl(url: node2.fields.url)

            if fullDomain1 != fullDomain2 { 
                if fullDomain1 == targetDomain {
                    
                    return .orderedAscending
                }

                if fullDomain2 == targetDomain {
                    
                    return .orderedDescending
                }

                

                
                

                let components1 = Array(fullDomain1.split(separator: ".").reversed())
                let components2 = Array(fullDomain2.split(separator: ".").reversed())
                let targetComponents = Array(targetDomain.split(separator: ".").reversed())

                let checkCount = min(min(components1.count, components2.count), targetComponents.count)

                if checkCount > 0 {
                    for idx in 0 ... checkCount - 1 { 
                        let comp1 = components1[idx]
                        let comp2 = components2[idx]
                        let target = targetComponents[idx]

                        let comp1Match = comp1 == target
                        let comp2Match = comp2 == target

                        if comp1Match, comp2Match { 
                            continue
                        } else if comp1Match {
                            return .orderedAscending
                        } else if comp2Match {
                            return .orderedDescending
                        } else { 
                            break
                        }
                    }
                }

                

                let targetPslDomain = extractPSLDomainFromUrl(url: url)
                let pslDomain1 = extractPSLDomainFromUrl(url: node1.fields.url)
                let pslDomain2 = extractPSLDomainFromUrl(url: node2.fields.url)

                if pslDomain1 == pslDomain2, pslDomain1 == targetPslDomain {
                    

                    return fullDomain1.count < fullDomain2.count ? .orderedAscending : .orderedDescending
                } else {
                    if pslDomain1 == targetPslDomain {
                        return .orderedAscending
                    }

                    if pslDomain2 == targetPslDomain {
                        
                        return .orderedDescending
                    }
                }
            }

            

            let distance1 = node1.fields.url.levenshteinDistance(url)
            let distance2 = node2.fields.url.levenshteinDistance(url)



            if distance1 != distance2 {
                return (distance1 < distance2) ? .orderedAscending : .orderedDescending
            }
        } else {

        }
        

        return node1.title.compare(node2.title)
    }
}
