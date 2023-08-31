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
            return NSLocalizedString("browse_prefs_view_as_totp_list", comment: "TOTPs")
        case .favourites:
            return NSLocalizedString("browse_vc_section_title_pinned", comment: "Favourites")
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
        @unknown default:
            imageName = "questionmark.circle.fill"
        }

        return UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(scale: large ? .default : .small))!
    }

    var currentVisibleTabs: [BrowseViewType] = []

    var configuredVisibleTabs: [BrowseViewType] {
        model.metadata.visibleTabs.compactMap { num in
            BrowseViewType(rawValue: num.uintValue)
        }
    }

    fileprivate func customizeUI() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        tabBar.standardAppearance = appearance

        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLog("BrowseTabViewController::viewDidLoad")

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

                if AppPreferences.sharedInstance().shadeFavoriteTag {
                    tags.remove(kCanonicalFavouriteTag)
                }

                if tags.isEmpty {
                    continue
                }
            }

            if tab == .totpList, model.database.totpEntries.isEmpty {
                continue
            }

            ret.append(tab)
        }

        return ret
    }

    func onTabsChanged(_ isDirectConfigChange: Bool) {
        refreshVisibleTabs(isDirectConfigChange)
    }

    func refreshVisibleTabs(_ isDirectConfigChangeOrInitialLoad: Bool = false) {
        
        
        
        

        var newEffectivelyVisible = computeEffectivelyVisibleTabs()

        

        if newEffectivelyVisible.count == 0 {
            NSLog("⚠️ WARNWARN - Cannot display configured tab because there are no relevant items defaulting to hierarchy view...")
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
            if let oldIdx = currentVisibleTabs.firstIndex(of: tab), let viewControllers {
                
                newVcs.append(viewControllers[oldIdx])
            } else {
                

                let vc = BrowseSafeView.fromStoryboard(tab, model: model)
                let nav = UINavigationController(rootViewController: vc)

                newVcs.append(nav)
            }
        }

        setViewControllers(newVcs, animated: true)

        let showLabels = newVcs.count < 4
        for vc in newVcs {
            let nav = vc as! UINavigationController
            let browse = nav.viewControllers[0] as! BrowseSafeView

            browse.tabBarItem = UITabBarItem(title: showLabels ? getTabTitle(tab: browse.viewType) : "", image: getTabImage(tab: browse.viewType, large: !showLabels), tag: 0)
        }

        currentVisibleTabs = newEffectivelyVisible

        

        let selected = model.metadata.browseViewType
        if let idx = currentVisibleTabs.firstIndex(of: selected) {
            NSLog("Found selected view type => making sure tab is selected")
            selectedIndex = idx
        } else {
            NSLog("Could not find selected view type => updating selected to current selection")
            model.metadata.browseViewType = currentVisibleTabs[selectedIndex]
        }

        if isDirectConfigChangeOrInitialLoad {
            bindShowHideBar()
        }
    }

    func bindShowHideBar() {
        let hideTabBar = viewControllers?.count == 1 && model.metadata.hideTabBarIfOnlySingleTab

        

        if hideTabBar != tabBar.isHidden {
            tabBar.isHidden = hideTabBar
        }
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let idx = tabBar.items?.firstIndex(of: item), let viewType = currentVisibleTabs[safe: idx] {
            model.metadata.browseViewType = viewType
        }
    }
}
