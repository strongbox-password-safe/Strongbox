//
//  MyFirstSwiftUIView.swift
//  MacBox
//
//  Created by Strongbox on 26/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import SwiftUI

@available(OSX 10.15.0, *)
struct ContentView: View {
    var body: some View {
        NavigationView {
            SidebarView()
            Text("No Sidebar Selection") // You won't see this in practice (default selection)
            Text("No Message Selection") 
        }
    }
}

@available(OSX 10.15.0, *)
struct SidebarView: View {
    @State private var isDefaultItemActive = true

    var body: some View {
        List {



            
        }.listStyle(SidebarListStyle()) 
    }
}







@available(OSX 10.15.0, *)
struct MyFirstSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
