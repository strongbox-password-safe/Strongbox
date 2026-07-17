import Foundation
import SwiftUI

extension Font {
    static func expanded(
        size: CGFloat,
        weight: UIFont.Weight
    ) -> Font {
        if #available(iOS 16.0, *) {
            return Font(
                UIFont.systemFont(
                    ofSize: size,
                    weight: weight,
                    width: .expanded
                )
            )
        } else {
            return Font(
                UIFont.systemFont(
                    ofSize: size,
                    weight: weight
                )
            )
        }
    }
}
