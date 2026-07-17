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
    private static let wwwPrefix = "www."

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

    private class func extractRawHost(url: String) -> String? {
        if let urlProcessed = url.urlExtendedParseAddingDefaultScheme,
           let components = URLComponents(url: urlProcessed, resolvingAgainstBaseURL: false),
           let host = components.host
        {
            return host.lowercased()
        }

        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private class func normalizeHost(_ host: String) -> String {
        host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }

    private class func extractMatchingHost(url: String) -> String? {
        guard let host = extractRawHost(url: url) else {
            return nil
        }

        let normalized = normalizeHost(host)
        return normalized.isEmpty ? nil : normalized
    }

    private class func getHostComponents(_ host: String) -> [String] {
        host.split(separator: ".").map(String.init)
    }

    private class func isHostSuffixMatch(candidateHost: String, targetHost: String) -> Bool {
        if candidateHost == targetHost {
            return true
        }

        return targetHost.hasSuffix(".\(candidateHost)")
    }

    private class func getHostMatchRank(candidateHost: String, targetHost: String) -> Int {
        guard isHostSuffixMatch(candidateHost: candidateHost, targetHost: targetHost) else {
            return 0
        }

        let labelCount = getHostComponents(candidateHost).count
        return candidateHost == targetHost ? 10_000 + labelCount : labelCount
    }

    private class func getRegistrableDomain(host: String) -> String? {
        if let parsedHost = domainParser.parse(host: host),
           let domain = parsedHost.domain
        {
            return normalizeHost(domain.lowercased())
        }

        
        
        let components = getHostComponents(host)
        guard components.count >= 2 else {
            return nil
        }

        return components.suffix(2).joined(separator: ".")
    }

    private class func getImmediateWwwEquivalent(host: String) -> String? {
        guard let registrableDomain = getRegistrableDomain(host: host) else {
            return nil
        }

        if host == registrableDomain {
            return "\(wwwPrefix)\(registrableDomain)"
        }

        if host == "\(wwwPrefix)\(registrableDomain)" {
            return registrableDomain
        }

        return nil
    }

    private class func getAllowedHosts(url: String, subdomainMatching: Bool) -> [String] {
        guard let exactHost = extractMatchingHost(url: url) else {
            return []
        }

        var allowedHosts = [String]()
        var seenHosts = Set<String>()

        func appendAllowedHost(_ host: String) {
            guard seenHosts.insert(host).inserted else {
                return
            }

            allowedHosts.append(host)

            if let equivalentHost = getImmediateWwwEquivalent(host: host),
               seenHosts.insert(equivalentHost).inserted
            {
                allowedHosts.append(equivalentHost)
            }
        }

        guard subdomainMatching, let registrableDomain = getRegistrableDomain(host: exactHost) else {
            appendAllowedHost(exactHost)
            return allowedHosts
        }

        let exactComponents = getHostComponents(exactHost)
        let registrableComponents = getHostComponents(registrableDomain)

        guard exactComponents.count > registrableComponents.count else {
            appendAllowedHost(exactHost)
            return allowedHosts
        }

        appendAllowedHost(exactHost)

        for index in 1...(exactComponents.count - registrableComponents.count) {
            appendAllowedHost(exactComponents[index...].joined(separator: "."))
        }

        return allowedHosts
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

    @objc(getMatchingNodesWithUrl:domainNodeMap:)
    class func getMatchingNodes(url: String, domainNodeMap: [String: Set<UUID>]) -> Set<UUID> {
        getMatchingNodes(url: url, domainNodeMap: domainNodeMap, subdomainMatching: true)
    }

    @objc(getMatchingNodesWithUrl:domainNodeMap:subdomainMatching:)
    class func getMatchingNodes(url: String, domainNodeMap: [String: Set<UUID>], subdomainMatching: Bool) -> Set<UUID> {


        let allowedHosts = getAllowedHosts(url: url, subdomainMatching: subdomainMatching)
        let ret = allowedHosts.reduce(into: Set<UUID>()) { partialResult, host in
            partialResult.formUnion(domainNodeMap[host] ?? Set())
        }






        return ret
    }

    @objc class func loadDomainNodeMap(_ model: Model) -> [String: Set<UUID>] {
        let startTime = CFAbsoluteTimeGetCurrent()

        let allSearchable = model.database.allSearchableNoneExpiredEntries
        let all = allSearchable.filter { !model.isExcluded(fromAutoFill: $0.uuid) }

        var mutableRet: [String: Set<UUID>] = [:]

        for node in all {
            let uniqueUrls = AutoFillCommon.getUniqueUrls(forNode: model, node: node)

            let hosts = Set(uniqueUrls.compactMap { extractMatchingHost(url: $0) })

            for host in hosts {
                mutableRet[host, default: Set<UUID>()].insert(node.uuid)
            }
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        swlog("🐞 ⏱ loadDomainNodeMap: Loaded \(mutableRet.count) hosts from \(all.count) entries in \(timeElapsed) s.")

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



            

            let targetDomain = extractMatchingHost(url: url) ?? extractFullDomainFromUrl(url: url)
            let fullDomain1 = extractMatchingHost(url: node1.fields.url) ?? extractFullDomainFromUrl(url: node1.fields.url)
            let fullDomain2 = extractMatchingHost(url: node2.fields.url) ?? extractFullDomainFromUrl(url: node2.fields.url)

            if fullDomain1 != fullDomain2 { 
                if fullDomain1 == targetDomain {
                    
                    return .orderedAscending
                }

                if fullDomain2 == targetDomain {
                    
                    return .orderedDescending
                }

                let hostMatchRank1 = getHostMatchRank(candidateHost: fullDomain1, targetHost: targetDomain)
                let hostMatchRank2 = getHostMatchRank(candidateHost: fullDomain2, targetHost: targetDomain)

                if hostMatchRank1 != hostMatchRank2 {
                    return hostMatchRank1 > hostMatchRank2 ? .orderedAscending : .orderedDescending
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
