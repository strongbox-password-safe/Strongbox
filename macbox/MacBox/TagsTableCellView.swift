//
//  TagsTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 21/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class TagsTableCellView: NSTableCellView, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()

        let flowLayout = NSCollectionViewFlowLayout()

        flowLayout.minimumInteritemSpacing = 4
        flowLayout.minimumLineSpacing = 8
        flowLayout.itemSize = NSSize(width: 140, height: 24) 



        collectionView.collectionViewLayout = flowLayout

        collectionView.register(TagItem.self, forItemWithIdentifier: TagItem.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.backgroundColors = [.clear]
        let scrollView = collectionView.enclosingScrollView!
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        updateHeightConstraint()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        updateHeightConstraint()
    }

    var tags: [String] = [] {
        didSet {
            collectionView.reloadData()
            updateHeightConstraint()
        }
    }

    func updateHeightConstraint() {
        guard let size = collectionView.collectionViewLayout?.collectionViewContentSize else {
            return
        }

        if size.height != heightConstraint.constant {


            heightConstraint.constant = size.height + 16 
        }
    }

    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        tags.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: TagItem.reuseIdentifier, for: indexPath) as! TagItem

        item.label.stringValue = tags[indexPath.item]

        return item
    }
}
