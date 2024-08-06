//
//  ApplePasswordManagerQuirks.swift
//  MacBox
//
//  Created by Strongbox on 30/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class ApplePasswordManagerQuirks {
    private var equivalents: [String: [String]] = [:]

    static let shared = ApplePasswordManagerQuirks()

    private init() {
        let decoder = JSONDecoder()

        guard let url = Bundle.main.url(forResource: "websites-with-shared-credential-backends", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let equivs = try? decoder.decode([[String]].self, from: data)
        else {
            swlog("🔴 Could not load file 'websites-with-shared-credential-backends.json' from Bundle!")
            return
        }

        for eqGroup in equivs {
            for eq in eqGroup {
                equivalents[eq] = eqGroup
            }
        }
    }

    func getEquivalentDomains(_ domain: String) -> Set<String> {
        Set(equivalents[domain.lowercased()] ?? [])
    }
}
