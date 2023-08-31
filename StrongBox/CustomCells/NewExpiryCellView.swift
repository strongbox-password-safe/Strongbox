//
//  NewExpiryCellView.swift
//  Strongbox
//
//  Created by Strongbox on 10/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

struct NewExpiryCellView: View {
    @State
    var date: Date

    var body: some View {
        VStack(alignment: .leading) {
            Text("item_details_expires_field_title").font(.caption).foregroundColor(.secondary)
            Spacer()
            HStack {
                DatePicker(
                    "item_details_expires_field_title",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Button(action: {
                    
                    
                    
                    
                    
                }, label: {
                    Image(systemName: "x.circle").imageScale(.large)
                })
            }
        }
    }
}

struct NewExpiryCellView_Previews: PreviewProvider {
    static var previews: some View {
        NewExpiryCellView(date: Date())
    }
}
