//
//  SwiftUIView.swift
//  MacBox
//
//  Created by Strongbox on 12/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import SwiftUI

@available(OSX 10.15.0, *)

class
SwiftUIController: NSHostingController<SwiftUIView>
{
    @objc
    required
    dynamic
    init?(coder: NSCoder)
    {
        weak var parent: NSViewController? = nil // avoid reference cycling
        super.init(rootView:
            SwiftUIView(parent: Binding(
                get: { parent },
                set: { parent = $0 })
            )
        )

        parent = self // self usage not allowed till super.init
    }
}

@available(OSX 10.15.0, *)
struct SwiftUIView: View {
//  var dismiss: () -> Void = {}
    @Binding var parent: NSViewController?
//    @Binding var isOn: Bool
    
  var body: some View {
    VStack(spacing: 8) {
      Text("SwiftUI View 🎉")
        .font(.title)
        .bold()
//        Toggle(title: "Yo", isOn: $isOn)
      Button(action: {
        self.parent?.dismiss(nil)
//        dismiss()
      }, label: {
        Text("Close")
      })
    }.toggleStyle(SwitchToggleStyle())
    .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
  }
}
