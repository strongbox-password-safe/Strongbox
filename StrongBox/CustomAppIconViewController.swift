//
//  CustomAppIconViewController.swift
//  Strongbox
//
//  Created by Strongbox on 16/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class CustomAppIconViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    @objc
    class func fromStoryboard() -> UINavigationController {
        let storyboard = UIStoryboard(name: "CustomAppIconViewController", bundle: nil)
        return storyboard.instantiateInitialViewController() as! UINavigationController
    }

    @IBAction func onDone(_: Any) {
        dismiss(animated: true)
    }

    var icons: [[CustomAppIcon]] = []

    @IBOutlet var buttonReset: UIBarButtonItem!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if UIApplication.shared.alternateIconName == nil {
            buttonReset.isEnabled = false
            buttonReset.tintColor = UIColor.clear
            navigationController?.isToolbarHidden = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(UINib(nibName: CustomAppIconCellView.reuseIdentifier, bundle: nil), forCellWithReuseIdentifier: CustomAppIconCellView.reuseIdentifier)
        collectionView.register(UINib(nibName: CustomAppIconSectionHeader.reuseIdentifier, bundle: nil),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: CustomAppIconSectionHeader.reuseIdentifier)



        let allowedIcons: [CustomAppIcon] = [
            .proBadge,
            .regular,
            .zero,
            .black,
            .bluey,
            .iridescent,
            .lightBlue,
            .midnightFire,
            .red,
            .water,
            .original,
            .white,
        ]

        let grouped = Dictionary(grouping: allowedIcons, by: { $0.category })
        icons = CustomAppIconCategory.allCases.compactMap { grouped[$0] }

        let layout = UICollectionViewFlowLayout() 

        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        layout.itemSize = CGSize(width: 76.0, height: 76.0)

        collectionView.collectionViewLayout = layout
        collectionView.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView.dataSource = self
        collectionView.delegate = self
    }

    override func numberOfSections(in _: UICollectionView) -> Int {
        icons.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        icons[section].count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomAppIconCellView.reuseIdentifier, for: indexPath) as! CustomAppIconCellView

        let icon = icons[indexPath.section][indexPath.row]

        let showProLabel = AppPreferences.sharedInstance().isPro ? false : icon.isPro

        cell.setContent(icon.image, isPro: showProLabel)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForHeaderInSection _: Int) -> CGSize {
        CGSize(width: collectionView.frame.size.width * 0.8, height: 30)
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var reusableView: UICollectionReusableView

        let category = icons[indexPath.section].first!.category

        if kind == UICollectionView.elementKindSectionHeader {
            let collectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                                                                   withReuseIdentifier: CustomAppIconSectionHeader.reuseIdentifier,
                                                                                   for: indexPath) as! CustomAppIconSectionHeader

            collectionHeader.labelTitle?.text = category.title

            reusableView = collectionHeader
        } else {
            reusableView = UICollectionReusableView()
        }

        return reusableView
    }

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let icon = icons[indexPath.section][indexPath.row]

        if icon.isPro, !AppPreferences.sharedInstance().isPro {
            Alerts.info(self,
                        title: NSLocalizedString("mac_autofill_pro_feature_title", comment: "Pro Feature"),
                        message: NSLocalizedString("custom_app_icon_pro_only", comment: "This icon is only available for Pro users."))
        } else {
            setTheIcon(icon)
        }
    }

    @IBAction func onResetToDefault(_: Any) {
        Alerts.areYouSure(self, message: NSLocalizedString("are_you_sure_reset_to_default_app_icon",
                                                           comment: "Are you sure you want to reset to the default App Icon?"), action: { [weak self] response in
                if response {
                    self?.setTheIcon(nil)
                }
            })
    }

    func setTheIcon(_ icon: CustomAppIcon? = nil) {
        UIApplication.shared.setAlternateIconName(icon?.plistKey) { [weak self] error in
            if let error {
                swlog("🔴 Error setting alternate app icon [%@]", String(describing: error))
                Alerts.error(self, error: error)
            } else {
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}
