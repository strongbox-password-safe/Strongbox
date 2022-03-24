//
//  LeftAlignedCollectionViewFlowLayout.swift
//  Strongbox
//
//  Created by Strongbox on 16/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

// H/T https://stackoverflow.com/questions/22539979/left-align-cells-in-uicollectionview

class LeftAlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0

        let attributes = super.layoutAttributesForElements(in: rect)?.map { $0.copy() as! UICollectionViewLayoutAttributes }

        attributes?.forEach { layoutAttribute in
            guard layoutAttribute.representedElementCategory == .cell else {
                return
            }

            if layoutAttribute.frame.origin.y >= maxY {
                leftMargin = sectionInset.left
            }

            layoutAttribute.frame.origin.x = leftMargin

            leftMargin += layoutAttribute.frame.width + minimumInteritemSpacing
            maxY = max(layoutAttribute.frame.maxY, maxY)
        }

        return attributes
    }
}
