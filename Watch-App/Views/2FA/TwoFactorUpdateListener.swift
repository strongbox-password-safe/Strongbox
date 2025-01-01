//
//  TwoFactorUpdateListener.swift
//  Strongbox
//
//  Created by Strongbox on 17/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Combine
import SwiftUI

@objc
enum TwoFactorUpdateMode: Int {
    case manual
    case automatic
    case centralTimerNotification
}

extension View {
    func centrallyTimedTwoFactorUpdater(_ onUpdate: @escaping (() -> Void)) -> some View {
        modifier(CentralTwoFactorUpdateListener(onUpdate: onUpdate))
    }

    func selfTimedTwoFactorUpdater(_ onUpdate: @escaping (() -> Void)) -> some View {
        modifier(SelfTimedTwoFactorUpdateListener(onUpdate: onUpdate))
    }

    func twoFactorUpdater(mode: TwoFactorUpdateMode = .automatic, onUpdate: @escaping (() -> Void)) -> some View {
        modifier(TwoFactorUpdateListener(mode: mode, onUpdate: onUpdate))
    }
}

struct TwoFactorUpdateListener: ViewModifier {
    let mode: TwoFactorUpdateMode
    let onUpdate: () -> Void

    func body(content: Content) -> some View {
        switch mode {
        case .manual:
            content
        case .automatic:
            content.modifier(SelfTimedTwoFactorUpdateListener(onUpdate: onUpdate))
        case .centralTimerNotification:
            content.modifier(CentralTwoFactorUpdateListener(onUpdate: onUpdate))
        }
    }
}

struct CentralTwoFactorUpdateListener: ViewModifier {
    let onUpdate: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .centralUpdateOtpUi, object: nil)) { _ in
                onUpdate()
            }
    }
}

struct SelfTimedTwoFactorUpdateListener: ViewModifier {
    let onUpdate: () -> Void
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .onReceive(timer, perform: { _ in
                onUpdate()
            })
    }
}
