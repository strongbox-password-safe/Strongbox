//
//  ConfigureTabsViewController.swift
//  Strongbox
//
//  Created by Strongbox on 26/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

extension Notification.Name {
    enum ConfigureTabs {
        static let tabsChanged = Notification.Name("VisibleTabsConfigurationChanged")
    }
}

class ConfigureTabsViewController: UITableViewController, UIAdaptivePresentationControllerDelegate {
    let allTabs: [BrowseViewType] = [.favourites, .tags, .hierarchy, .list, .totpList]

    var visibleTabs: [BrowseViewType] = []
    var hiddenTabs: [BrowseViewType] = []

    @objc var model: Model!

    @objc
    class func fromStoryboard(model: Model) -> UINavigationController {
        let storyboard = UIStoryboard(name: "ConfigureTabs", bundle: nil)

        let nav = storyboard.instantiateInitialViewController() as! UINavigationController
        let me = nav.topViewController as! Self

        me.model = model

        return nav
    }

    override func viewDidLoad() {
        super.viewDidLoad()



        navigationController?.presentationController?.delegate = self

        let numeric = model.metadata.visibleTabs

        visibleTabs = numeric.compactMap { num in
            BrowseViewType(rawValue: num.uintValue)
        }

        hiddenTabs = Set(allTabs).subtracting(Set(visibleTabs)).sorted(by: { v1, v2 in
            v1.rawValue > v2.rawValue
        })

        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setEditing(true, animated: false)
    }

    override func tableView(_: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        (indexPath.section == 1 && hiddenTabs.count > 0) || (indexPath.section == 0 && visibleTabs.count > 1)
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath.section == destinationIndexPath.section, sourceIndexPath.row == destinationIndexPath.row {
            return
        }
        if sourceIndexPath.section == 0, destinationIndexPath.section == 1, visibleTabs.count < 2 {
            return
        }
        if sourceIndexPath.section > 1 {
            return
        }



        let tab: BrowseViewType
        if sourceIndexPath.section == 0 {
            tab = visibleTabs.remove(at: sourceIndexPath.row)
        } else {
            tab = hiddenTabs.remove(at: sourceIndexPath.row)
        }

        if destinationIndexPath.section == 0 {
            visibleTabs.insert(tab, at: destinationIndexPath.row)
        } else {
            if hiddenTabs.count == 0 { 
                hiddenTabs.insert(tab, at: 0)
            } else {
                hiddenTabs.insert(tab, at: destinationIndexPath.row)
            }
        }

        tableView.reloadData()
    }

    override func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(_: UITableView, shouldIndentWhileEditingRowAt _: IndexPath) -> Bool {
        false
    }

    override func numberOfSections(in _: UITableView) -> Int {
        3 
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 2, visibleTabs.count > 1 {
            return 0.0
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

















    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        } else if section == 1 {
            return NSLocalizedString("generic_item_is_hidden", comment: "Hidden")
        } else {
            return visibleTabs.count == 1 ? NSLocalizedString("generic_settings", comment: "Settings") : nil
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("configure_tabs_footer_visible_tabs", comment: "These tabs will be visible in this order, providing there are eligible items to display. You must always have at least one visible tab.")
        } else if section == 1 {
            return NSLocalizedString("configure_tabs_footer_hidden_tabs", comment: "These tabs will remain hidden.")
        } else {
            return visibleTabs.count == 1 ? NSLocalizedString("configure_tabs_footer_text_hide_tab_bar", comment: "You can choose to completely hide the bottom tab bar since you have only a single visible tab. Tap to toggle.") : nil
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return visibleTabs.count
        } else if section == 1 {
            return hiddenTabs.count == 0 ? 1 : hiddenTabs.count 
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConfigureTabsCellIdentifier", for: indexPath)

        if indexPath.section == 0 || indexPath.section == 1 {
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.editingAccessoryType = .none

            var viewType: BrowseViewType? = nil

            if indexPath.section == 0 {
                viewType = visibleTabs[indexPath.row]
            } else if indexPath.section == 1 {
                if hiddenTabs.count != 0 {
                    viewType = hiddenTabs[indexPath.row]
                }
            }

            if let viewType {
                cell.textLabel?.text = titleForViewType(viewType: viewType)
                cell.imageView?.image = imageForViewType(viewType: viewType)
                cell.imageView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .large)
                cell.imageView?.tintColor = imageTintForViewType(viewType: viewType)
            } else {
                cell.textLabel?.text = NSLocalizedString("configure_tabs_drag_tabs_to_hide", comment: "Drag tabs here to hide them")

                cell.textLabel?.textColor = .secondaryLabel
                
                cell.tintColor = .secondaryLabel
            }

            return cell
        } else {
            cell.textLabel?.text = NSLocalizedString("configure_tabs_option_hide_tab_bar_completely", comment: "Hide Tab Bar Completely")

            cell.textLabel?.textColor = .label
            cell.imageView?.image = nil
            cell.accessoryType = model.metadata.hideTabBarIfOnlySingleTab ? .checkmark : .none
            cell.editingAccessoryType = model.metadata.hideTabBarIfOnlySingleTab ? .checkmark : .none
            cell.selectionStyle = .default

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 {
            model.metadata.hideTabBarIfOnlySingleTab = !model.metadata.hideTabBarIfOnlySingleTab
        }

        tableView.deselectRow(at: indexPath, animated: true)

        tableView.reloadSections([2], with: .automatic)
    }

    func titleForViewType(viewType: BrowseViewType) -> String {
        switch viewType {
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

    func imageTintForViewType(viewType: BrowseViewType) -> UIColor? {
        if viewType == .favourites {
            return UIColor.systemYellow
        }

        return nil
    }

    func imageForViewType(viewType: BrowseViewType) -> UIImage {
        var imageName: String

        switch viewType {
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

        return UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(scale: .small))!
    }

    @IBAction func onDone(_: Any?) {
        let numeric = visibleTabs.map { tab in
            NSNumber(value: tab.rawValue)
        }

        model.metadata.visibleTabs = numeric
        NotificationCenter.default.post(name: .ConfigureTabs.tabsChanged, object: nil)

        dismiss(animated: true)
    }

    func presentationControllerDidDismiss(_: UIPresentationController) {
        onDone(nil)
    }
}
