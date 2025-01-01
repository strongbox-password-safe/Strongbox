//
//  ApplePasswordManagerQuirks.swift
//  MacBox
//
//  Created by Strongbox on 30/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

private struct AppleSharedCredentials: Codable {
    var shared: [String]?
    var from: [String]?
    var to: [String]?
    var fromDomainsAreObsoleted: Bool?
}

class ApplePasswordManagerQuirks {
    private var equivalents: [String: [String]] = [:]

    static let shared = ApplePasswordManagerQuirks()



















    private init() {
        let decoder = JSONDecoder()

        guard let url = Bundle.main.url(forResource: "shared-credentials", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sharedCredentialsGroups = try? decoder.decode([AppleSharedCredentials].self, from: data)
        else {
            swlog("🔴 Could not load file 'shared-credentials.json' from Bundle!")
            return
        }

        for sharedCredentialGroup in sharedCredentialsGroups {
            if let sharedDomains = sharedCredentialGroup.shared {
                for domain in sharedDomains {
                    equivalents[domain] = sharedDomains
                }
            } else if let from = sharedCredentialGroup.from, let to = sharedCredentialGroup.to {
                

                for f in from {
                    equivalents[f] = to
                }
                for t in to {
                    equivalents[t] = from
                }
            } else {
                swlog("🔴 Couldn't process \(sharedCredentialGroup)")
            }
        }
    }

    func getEquivalentDomains(_ domain: String) -> Set<String> {
        Set(equivalents[domain.lowercased()] ?? [])
    }
}
