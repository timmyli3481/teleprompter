//
//  TeleprompterApp.swift
//  Teleprompter Watch App
//
//  Created by Timmy Li on 11/28/24.
//

import SwiftUI

@main
struct TeleprompterApp: App {
    @StateObject private var viewModel = WatchViewModel.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
