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
        weak var parent: NSViewController? = nil 
        super.init(rootView:
            SwiftUIView(parent: Binding(
                get: { parent },
                set: { parent = $0 })
            )
        )

        parent = self 
    }
}

@available(OSX 10.15.0, *)
struct SwiftUIView: View {

    @Binding var parent: NSViewController?

    
  var body: some View {
    VStack(spacing: 8) {
      Text("SwiftUI View 🎉")
        .font(.title)
        .bold()

      Button(action: {
        self.parent?.dismiss(nil)

      }, label: {
        Text("Close")
      })
    }.toggleStyle(SwitchToggleStyle())
    .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
  }
}
