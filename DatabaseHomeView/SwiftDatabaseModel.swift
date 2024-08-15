//
//  SwiftDatabaseModel.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

struct SwiftDatabaseModel: SwiftDatabaseModelInterface {
    var showIcons: Bool {
        #if os(iOS)
            !model.metadata.hideIconInBrowse
        #else
            true
        #endif
    }

    var format: DatabaseFormat {
        model.originalFormat
    }

    var ckfs: CompositeKeyFactors {
        model.ckfs
    }

    #if os(iOS)
        func isHomeViewSectionVisible(section: HomeViewSection) -> Bool {
            let num = NSNumber(value: section.rawValue)
            return model.metadata.visibleHomeSections.contains(num)
        }

        func setHomeViewSectionVisible(section: HomeViewSection, visible: Bool) {
            var prev = Set(model.metadata.visibleHomeSections)
            let num = NSNumber(value: section.rawValue)

            if visible {
                prev.insert(num)
            } else {
                prev.remove(num)
            }

            model.metadata.visibleHomeSections = Array(prev)
        }
    #endif

    var isReadOnly: Bool { model.isReadOnly }
    var isInOfflineMode: Bool { model.isInOfflineMode }
    var isKeePass2Format: Bool { model.isKeePass2Format }

    var appPreferences: any ApplicationPreferences {
        CrossPlatformDependencies.defaults().applicationPreferences
    }

    var isItemsCanBeExported: Bool {
        guard !appPreferences.disableExport else {
            return false
        }

        #if os(iOS)
            return DatabasePreferences.allDatabases.first(where: { $0.uuid != uuid && !$0.readOnly }) != nil
        #else
            return MacDatabasePreferences.allDatabases.first(where: { $0.uuid != uuid && !$0.readOnly }) != nil
        #endif
    }

    var disableExport: Bool {
        appPreferences.disableExport
    }

    var disablePrinting: Bool {
        appPreferences.disablePrinting
    }

    var uuid: String { model.metadata.uuid }
    var model: Model

    var nickName: String {
        model.metadata.nickName
    }

    var favourites: [any SwiftEntryModelInterface] {
        model.favourites
            .map { SwiftEntryModel(node: $0, model: model) }
            .sorted()
    }

    var totpCodeEntries: [any SwiftEntryModelInterface] {
        model.totpEntries
            .map { SwiftEntryModel(node: $0, model: model) }
            .sorted()
    }

    func search(searchText: String, searchScope: SearchScope) -> [any SwiftEntryModelInterface] {
        let results = model.searchAutoBestMatch(searchText, scope: searchScope)

        return results.map { SwiftEntryModel(node: $0, model: model) }
    }

    var entryCount: Int {
        var recycleBinEntryCount = 0

        if let recycleBinNode = model.database.recycleBinNode {
            recycleBinEntryCount = recycleBinNode.allChildRecords.count
        }

        return model.fastEntryTotalCount - recycleBinEntryCount
    }

    var groupCount: Int {
        var recycleBinEntryCount = 0

        if let recycleBinNode = model.database.recycleBinNode {
            recycleBinEntryCount = recycleBinNode.allChildGroups.count
        }

        return model.fastGroupTotalCount - recycleBinEntryCount
    }

    var allTags: Set<String> {
        var tagSet = model.tagSet
        tagSet.remove(kCanonicalFavouriteTag)
        return tagSet
    }

    var tags: [String] {
        allTags.sorted()
    }

    var popularTags: [String] {
        Array(model.database.mostPopularTags.prefix(15))
    }

    var tagCount: Int {
        allTags.count
    }

    var recycleBinCount: Int {
        if let recycleBinNode = model.database.recycleBinNode {
            return recycleBinNode.allChildren.count
        } else {
            return 0
        }
    }

    var auditModel: AuditViewModel {
        if !model.isAuditEnabled {
            return AuditViewModel(isEnabled: false)
        } else if model.auditState == .running || model.auditState == .initial {
            return AuditViewModel(isEnabled: true, isInProgress: true)
        } else {
            if let report = model.auditReport {
                

                let sorted = model
                    .getItemsById(Array(report.entriesWithDuplicatePasswords))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                let groupedDuplicates = Dictionary(grouping: sorted) { $0.password }

                

                let groupedSimilarKvps = report.similarDictionary.map { key, value in
                    let nodes = model.getItemsById(Array(value))
                        .map { SwiftEntryModel(node: $0, model: model) }
                        .sorted()

                    return (key.uuidString, nodes)
                }

                let groupedSimilar = Dictionary(uniqueKeysWithValues: groupedSimilarKvps)

                

                let noPasswords = model.getItemsById(Array(report.entriesWithNoPasswords))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                

                let common = model.getItemsById(Array(report.entriesWithCommonPasswords))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                

                let tooShort = model.getItemsById(Array(report.entriesTooShort))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                

                let pwned = model.getItemsById(Array(report.entriesPwned))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                

                let lowEntropy = model.getItemsById(Array(report.entriesWithLowEntropyPasswords))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                

                let twoFactorAvailable = model.getItemsById(Array(report.entriesWithTwoFactorAvailable))
                    .map { SwiftEntryModel(node: $0, model: model) }
                    .sorted()

                return AuditViewModel(duplicated: groupedDuplicates,
                                      noPasswords: noPasswords,
                                      common: common,
                                      similar: groupedSimilar,
                                      tooShort: tooShort,
                                      pwned: pwned,
                                      lowEntropy: lowEntropy,
                                      twoFactorAvailable: twoFactorAvailable,
                                      similarEntryCount: report.entriesWithSimilarPasswords.count,
                                      duplicateEntryCount: report.entriesWithDuplicatePasswords.count)
            } else {
                return AuditViewModel(isEnabled: true, isInProgress: false)
            }
        }
    }

    var auditIssueEntryCount: Int {
        model.auditEntryCount
    }

    var passkeyEntryCount: Int {
        model.database.passkeyEntries.count
    }

    var sshKeyEntryCount: Int {
        model.database.keeAgentSSHKeyEntries.count
    }

    var attachmentsEntryCount: Int {
        model.database.attachmentEntries.count
    }

    var expiredEntryCount: Int {
        model.database.expiredEntries.count
    }

    var expiringEntryCount: Int {
        model.database.nearlyExpiredEntries.count
    }

    #if os(iOS)
        var startWithSearch: Bool {
            get {
                model.metadata.immediateSearchOnBrowse
            }
            set {
                model.metadata.immediateSearchOnBrowse = newValue
            }
        }
    #else
        var startWithSearch: Bool {
            get {
                model.metadata.startWithSearch
            }
            set {
                model.metadata.startWithSearch = newValue
            }
        }
    #endif

    var recycleBinNodeUuid: UUID? { model.database.recycleBinNodeUuid }

    func canRecycle(item: any SwiftItemModelInterface) -> Bool {
        model.canRecycle(item.uuid)
    }

    var recycleBinGroup: (any SwiftGroupModelInterface)? {
        guard let recycleBinGroup = model.database.recycleBinNode else {
            return nil
        }

        return SwiftGroupModel(node: recycleBinGroup, model: model)
    }
}
