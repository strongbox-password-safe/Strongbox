//
//  TagsTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 21/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

private final class TagFlowLayout: NSCollectionViewFlowLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        guard let collectionView else { return true }
        return abs(collectionView.bounds.width - newBounds.width) > 0.5 || abs(collectionView.bounds.height - newBounds.height) > 0.5
    }
}

class TagsTableCellView: NSTableCellView, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!

    private let verticalPadding: CGFloat = 16.0
    private var lastMeasuredWidth: CGFloat = 0.0
    private var pendingRowHeightInvalidation = false

    override func awakeFromNib() {
        super.awakeFromNib()

        let flowLayout = TagFlowLayout()

        flowLayout.minimumInteritemSpacing = 4
        flowLayout.minimumLineSpacing = 8
        flowLayout.itemSize = NSSize(width: 1, height: TagItem.itemHeight)

        collectionView.collectionViewLayout = flowLayout
        collectionView.register(TagItem.self, forItemWithIdentifier: TagItem.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isSelectable = false

        collectionView.backgroundColors = [.clear]
        let scrollView = collectionView.enclosingScrollView!
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        refreshLayout(force: true)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        refreshLayout(force: true)
    }

    override func layout() {
        super.layout()

        refreshLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        lastMeasuredWidth = 0.0
        pendingRowHeightInvalidation = false
    }

    var tags: [String] = [] {
        didSet {
            collectionView.reloadData()
            refreshLayout(force: true)
        }
    }

    private func refreshLayout(force: Bool = false) {
        let width = collectionView.bounds.width
        guard width > 0 else { return }

        if force || abs(width - lastMeasuredWidth) > 0.5 {
            lastMeasuredWidth = width
            collectionView.collectionViewLayout?.invalidateLayout()
        }

        collectionView.layoutSubtreeIfNeeded()
        updateHeightConstraint()
    }

    private func updateHeightConstraint() {
        guard let size = collectionView.collectionViewLayout?.collectionViewContentSize else {
            return
        }

        let newHeight = size.height + verticalPadding
        if abs(newHeight - heightConstraint.constant) > 0.5 {
            heightConstraint.constant = newHeight
            scheduleEnclosingRowHeightInvalidation()
        }
    }

    private func scheduleEnclosingRowHeightInvalidation() {
        guard !pendingRowHeightInvalidation else { return }
        pendingRowHeightInvalidation = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingRowHeightInvalidation = false

            guard let tableView = self.enclosingTableView() else { return }
            let row = tableView.row(for: self)
            guard row >= 0 else { return }

            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        }
    }

    private func enclosingTableView() -> NSTableView? {
        var currentView: NSView? = self

        while let view = currentView {
            if let tableView = view as? NSTableView {
                return tableView
            }

            currentView = view.superview
        }

        return nil
    }

    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        tags.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        layout _: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize
    {
        TagItem.preferredSize(for: tags[indexPath.item], maxWidth: collectionView.bounds.width)
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: TagItem.reuseIdentifier, for: indexPath) as! TagItem

        item.label.stringValue = tags[indexPath.item]

        return item
    }
}
