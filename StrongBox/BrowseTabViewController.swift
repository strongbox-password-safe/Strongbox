//
//  BrowseTabViewController.swift
//  Strongbox
//
//  Created by Strongbox on 23/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import UIKit

class BrowseTabViewController: UITabBarController {
    var model: Model!

    class func fromStoryboard(model: Model) -> BrowseTabViewController {
        let storyboard = UIStoryboard(name: "BrowseTabBar", bundle: nil)

        let ret = storyboard.instantiateInitialViewController() as! BrowseTabViewController

        ret.model = model

        return ret
    }

    func getTabTitle(tab: BrowseViewType) -> String {
        switch tab {
        case .tags:
            return NSLocalizedString("browse_prefs_item_subtitle_tags", comment: "Tags")
        case .hierarchy:
            return NSLocalizedString("browse_prefs_view_as_folders", comment: "Groups")
        case .list:
            return NSLocalizedString("browse_prefs_view_as_flat_list", comment: "Entries")
        case .totpList:
            return NSLocalizedString("browse_prefs_view_as_totp_list", comment: "2FA")
        case .favourites:
            return NSLocalizedString("browse_vc_section_title_pinned", comment: "Favourites")
        case .home:
            return NSLocalizedString("navigation_tab_home", comment: "Favourites")
        case .passkeys:
            return NSLocalizedString("generic_noun_plural_passkeys", comment: "Passkeys")
        case .sshKeys:
            return NSLocalizedString("sidebar_quick_view_keeagent_ssh_keys_title", comment: "SSH Keys")
        case .attachments:
            return NSLocalizedString("item_details_section_header_attachments", comment: "Attachments")
        case .expiredAndExpiring:
            return NSLocalizedString("quick_view_title_expired_and_expiring", comment: "Expired & Expiring")
        case .auditIssues:
            return NSLocalizedString("browse_vc_action_audit", comment: "Audit")
        @unknown default:
            return "🔴 UNKNOWN"
        }
    }

    func getTabImage(tab: BrowseViewType, large: Bool = false) -> UIImage {
        var imageName: String

        switch tab {
        case .tags:
            imageName = "tag.fill"
        case .hierarchy:
            imageName = "folder.fill"
        case .list:
            imageName = "list.bullet"
        case .totpList:
            imageName = "timer"
        case .favourites:
            imageName = "star.fill"
        case .home:
            imageName = "house.fill"
        case .passkeys:
            imageName = "person.badge.key.fill"
        case .sshKeys:
            var img = "network"
            if #available(iOS 17.0, *) {
                img = "apple.terminal.fill"
            }
            imageName = img
        case .attachments:
            imageName = "doc.richtext.fill"
        case .expiredAndExpiring:
            imageName = "calendar"
        case .auditIssues:
            imageName = "checkmark.shield.fill"
        @unknown default:
            imageName = "questionmark.circle.fill"
        }

        return UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(scale: large ? .default : .small))!
    }

    var currentVisibleTabs: [BrowseViewType] = []

    var configuredVisibleTabs: [BrowseViewType] {
        

        

        if !model.metadata.hasInitializedHomeTab {
            model.metadata.hasInitializedHomeTab = true

            var existing = model.metadata.visibleTabs
            let homeNum = NSNumber(value: BrowseViewType.home.rawValue)

            if !existing.contains(homeNum) {
                existing.insert(homeNum, at: 0)
                model.metadata.visibleTabs = existing
            }
        }

        return model.metadata.visibleTabs.compactMap { num in
            BrowseViewType(rawValue: num.uintValue)
        }
    }

    fileprivate func customizeUI() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        swlog("BrowseTabViewController::viewDidLoad")

        customizeUI()

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        tabBar.addGestureRecognizer(longPressRecognizer)

        refreshVisibleTabs(true)

        NotificationCenter.default.addObserver(forName: .ConfigureTabs.tabsChanged, object: nil, queue: nil) { [weak self] _ in
            self?.onTabsChanged(true)
        }

        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: kTabsMayHaveChangedDueToModelEdit), object: nil, queue: nil) { [weak self] _ in
            self?.onTabsChanged(false)
        }
    }

    @objc func onLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }

        let nav = ConfigureTabsViewController.fromStoryboard(model: model)

        present(nav, animated: true)
    }

    func computeEffectivelyVisibleTabs() -> [BrowseViewType] {
        var ret: [BrowseViewType] = []

        for tab in configuredVisibleTabs {
            if tab == .favourites, model.favourites.count == 0 {
                continue
            }

            if tab == .tags {
                var tags = model.database.tagSet

                tags.remove(kCanonicalFavouriteTag)

                if tags.isEmpty {
                    continue
                }
            }

            if tab == .totpList, model.database.totpEntries.isEmpty {
                continue
            }

            if tab == .home, AppPreferences.sharedInstance().disableHomeTab {
                continue
            }

            ret.append(tab)
        }

        return ret
    }

    func onTabsChanged(_ isDirectConfigChange: Bool) {
        refreshVisibleTabs(isDirectConfigChange)
    }

    func createNavEmbeddedVc(tab: BrowseViewType) -> UINavigationController {
        let nav: UINavigationController
        let vc: UIViewController

        if tab == .home {
            let actionsInterface = UIKitDatabaseActionsInterface(viewModel: model)
            let database = SwiftDatabaseModel(model: model)

            let homeViewModel = DatabaseHomeViewModel(database: database, externalWorldAdaptor: actionsInterface)
            vc = SwiftUIViewFactory.getDatabaseHomeView(model: homeViewModel)

            nav = UINavigationController(rootViewController: vc)

            actionsInterface.navController = nav
        } else if tab == .auditIssues {
            let actionsInterface = UIKitDatabaseActionsInterface(viewModel: model)
            let database = SwiftDatabaseModel(model: model)

            let homeViewModel = DatabaseHomeViewModel(database: database, externalWorldAdaptor: actionsInterface)
            vc = SwiftUIViewFactory.getAuditIssuesView(model: homeViewModel)

            nav = UINavigationController(rootViewController: vc)
            actionsInterface.navController = nav
        } else {
            vc = BrowseSafeView.fromStoryboard(tab, model: model)
            nav = UINavigationController(rootViewController: vc)
        }

        let tabBarItem = UITabBarItem(title: getTabTitle(tab: tab),
                                      image: getTabImage(tab: tab, large: true),
                                      tag: 0)

        vc.tabBarItem = tabBarItem

        return nav
    }

    func refreshVisibleTabs(_ isDirectConfigChangeOrInitialLoad: Bool = false) {
        
        
        
        

        var newEffectivelyVisible = computeEffectivelyVisibleTabs()

        

        if newEffectivelyVisible.count == 0 {
            swlog("⚠️ WARNWARN - Cannot display configured tab because there are no relevant items defaulting to heirarchy view...")
            newEffectivelyVisible = [.hierarchy]
            model.metadata.hideTabBarIfOnlySingleTab = false
        }

        guard currentVisibleTabs != newEffectivelyVisible else {
            
            if isDirectConfigChangeOrInitialLoad {
                bindShowHideBar() 
            }
            return
        }

        var newVcs: [UIViewController] = []

        for tab in newEffectivelyVisible {
            if let oldIdx = currentVisibleTabs.firstIndex(of: tab), let viewControllers, let previousVc = viewControllers[safe: oldIdx] {
                
                newVcs.append(previousVc)
            } else {
                let nav = createNavEmbeddedVc(tab: tab)
                nav.delegate = self
                newVcs.append(nav)
            }
        }

        setViewControllers(newVcs, animated: true)

        currentVisibleTabs = newEffectivelyVisible

        

        let selected = model.metadata.browseViewType
        if let idx = currentVisibleTabs.firstIndex(of: selected) {
            swlog("Found selected view type => making sure tab is selected")
            selectedIndex = idx
        } else {
            swlog("Could not find selected view type => updating selected to current selection")
            model.metadata.browseViewType = currentVisibleTabs[selectedIndex]
        }

        if isDirectConfigChangeOrInitialLoad {
            bindShowHideBar(isDirectConfigChangeOrInitialLoad: isDirectConfigChangeOrInitialLoad)
        }
    }

    @objc
    func bindShowHideBar(isDirectConfigChangeOrInitialLoad: Bool = false) {
        let hideTabBar = viewControllers?.count == 1 && model.metadata.hideTabBarIfOnlySingleTab

        

        if isDirectConfigChangeOrInitialLoad || hideTabBar != tabBar.isHidden {
            tabBar.isHidden = hideTabBar
        }
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let idx = tabBar.items?.firstIndex(of: item), let viewType = currentVisibleTabs[safe: idx] {
            model.metadata.browseViewType = viewType
        }
    }
}

extension BrowseTabViewController: UINavigationControllerDelegate {
    func navigationController(_: UINavigationController, willShow _: UIViewController, animated _: Bool) {
        swlog("🐞 BrowseTabViewController : UINavigationControllerDelegate didShow")
        bindShowHideBar()
    }
}
