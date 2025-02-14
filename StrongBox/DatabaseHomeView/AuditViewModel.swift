//
//  AuditViewModel.swift
//  Strongbox
//
//  Created by Strongbox on 31/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

struct AuditViewModel {
    var isEnabled: Bool
    var isInProgress: Bool

    var duplicated: [String: [any SwiftEntryModelInterface]]
    var noPasswords: [any SwiftEntryModelInterface]
    var common: [any SwiftEntryModelInterface]
    var similar: [String: [any SwiftEntryModelInterface]]
    var tooShort: [any SwiftEntryModelInterface]
    var pwned: [any SwiftEntryModelInterface]
    var lowEntropy: [any SwiftEntryModelInterface]
    var twoFactorAvailable: [any SwiftEntryModelInterface]

    var similarEntryCount: Int
    var duplicateEntryCount: Int

    var totalIssueCount: Int {
        similarEntryCount + duplicateEntryCount + common.count + noPasswords.count + tooShort.count + pwned.count + lowEntropy.count + twoFactorAvailable.count
    }

    init(isEnabled: Bool = true,
         isInProgress: Bool = false,
         duplicated: [String: [any SwiftEntryModelInterface]] = [:],
         noPasswords: [any SwiftEntryModelInterface] = [],
         common: [any SwiftEntryModelInterface] = [],
         similar: [String: [any SwiftEntryModelInterface]] = [:],
         tooShort: [any SwiftEntryModelInterface] = [],
         pwned: [any SwiftEntryModelInterface] = [],
         lowEntropy: [any SwiftEntryModelInterface] = [],
         twoFactorAvailable: [any SwiftEntryModelInterface] = [],
         similarEntryCount: Int = 0,
         duplicateEntryCount: Int = 0)
    {
        self.isEnabled = isEnabled
        self.isInProgress = isInProgress
        self.duplicated = duplicated
        self.noPasswords = noPasswords
        self.common = common
        self.similar = similar
        self.tooShort = tooShort
        self.pwned = pwned
        self.lowEntropy = lowEntropy
        self.twoFactorAvailable = twoFactorAvailable
        self.similarEntryCount = similarEntryCount
        self.duplicateEntryCount = duplicateEntryCount
    }
}
