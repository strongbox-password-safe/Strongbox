//
//  CustomAppIcon.swift
//  Strongbox
//
//  Created by Strongbox on 16/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

public enum CustomAppIcon: CaseIterable {
    case spaceInvader
    case blueInvader
    case nuclear
    case biohazard
    case landscape
    case mountain
    case skiLift
    case ski
    case jollyRoger
    case multiColourJollyRoger

    case binary
    case code
    case weather
    case proBadge
    case regular
    case zero
    case black
    case bluey
    case iridescent
    case lightBlue
    case midnightFire
    case red
    case water
    case modernCalculator
    case lightBlueCalculator
    case oldSchoolCalculator
    case calendar1
    case calendar2
    case todoChecklist
    case notepad
    case original
    case white

    var isPro: Bool {
        switch self {
        case .original, .regular, .code, .binary, .bluey, .iridescent, .water, .lightBlue, .white, .calendar1:
            return false
        default:
            return true
        }
    }

    var image: UIImage {
        UIImage(named: plistKey)!
    }

    var category: CustomAppIconCategory {
        switch self {
        case .jollyRoger, .spaceInvader, .blueInvader, .skiLift, .multiColourJollyRoger, .ski, .binary, .code, .landscape, .mountain, .nuclear, .biohazard:
            return .fun
        case .weather, .modernCalculator, .lightBlueCalculator, .oldSchoolCalculator, .calendar1, .calendar2, .todoChecklist, .notepad:
            return .boringApp
        case .proBadge, .regular, .zero, .black, .bluey, .iridescent, .lightBlue, .midnightFire, .red, .water, .original, .white:
            return .strongbox
        }
    }

    var plistKey: String {
        switch self {
        case .jollyRoger:
            return "jolly-roger"
        case .multiColourJollyRoger:
            return "multi-colour-jr"
        case .spaceInvader:
            return "space-invader"
        case .blueInvader:
            return "blue-invader"
        case .weather:
            return "weather"
        case .original:
            return "original"
        case .proBadge:
            return "pro-badge"
        case .regular:
            return "regular"
        case .zero:
            return "zero"
        case .black:
            return "black"
        case .bluey:
            return "bluey"
        case .iridescent:
            return "iridescent"
        case .lightBlue:
            return "light-blue"
        case .midnightFire:
            return "midnight-fire"
        case .red:
            return "red"
        case .water:
            return "water"
        case .modernCalculator:
            return "modern-calculator"
        case .lightBlueCalculator:
            return "light-blue-calculator"
        case .oldSchoolCalculator:
            return "old-school-calculator"
        case .calendar1:
            return "calendar-1"
        case .calendar2:
            return "calendar-2"
        case .todoChecklist:
            return "todo-checklist"
        case .notepad:
            return "notepad"
        case .skiLift:
            return "ski-lift"
        case .ski:
            return "ski"
        case .binary:
            return "binary"
        case .code:
            return "code"
        case .landscape:
            return "landscape"
        case .mountain:
            return "mountains2"
        case .nuclear:
            return "nuclear-power3"
        case .biohazard:
            return "biohazard"
        case .white:
            return "white"
        }
    }
}

enum CustomAppIconCategory: CaseIterable {
    case strongbox
    case boringApp
    case fun

    var title: String {
        switch self {
        case .strongbox:
            return "Strongbox"
        case .fun:
            return NSLocalizedString("custom_app_icon_category_fun", comment: "Fun")
        case .boringApp:
            return NSLocalizedString("custom_app_icon_category_utilities", comment: "Utilities")
        }
    }
}

@objc
public class CustomAppIconObjCHelper: NSObject {
    @objc
    public static func downgradeProIconIfInUse() {
        guard !AppPreferences.sharedInstance().isPro,
              let iconName = UIApplication.shared.alternateIconName,
              let icon = CustomAppIcon.allCases.first(where: { $0.plistKey == iconName }) else { return }

        if icon.isPro {
            UIApplication.shared.setAlternateIconName(nil) { error in
                if let error {
                    swlog("🔴 Error = [%@]", String(describing: error))
                }
            }
        }
    }
}
