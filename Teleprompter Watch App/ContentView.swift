//
//  ContentView.swift
//  Teleprompter Watch App
//
//  Created by Timmy Li on 11/28/24.
//

import SwiftUI
import WatchKit
import WatchConnectivity

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchViewModel()
    @Published var isConnected = false
    @Published var hasError = false
    @Published var errorMessage = ""
    
    private var session: WCSession?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func reconnect() {
        if let session = session, !session.isReachable {
            session.activate()
        }
    }
    
    func sendCommand(_ command: String) {
        guard let session = session, session.isReachable else {
            hasError = true
            errorMessage = "iPhone not reachable"
            return
        }
        
        session.sendMessage(["command": command], replyHandler: nil) { error in
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.hasError = true
                self.errorMessage = error.localizedDescription
            }
            self.isConnected = session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            // Handle any messages from iPhone if needed
            if let status = message["status"] as? String {
                print("Received status: \(status)")
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @State private var showingAlert = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isConnected {
                Text("Connected")
                    .foregroundColor(.green)
                
                VStack(spacing: 15) {
                    Button(action: {
                        viewModel.sendCommand("previous")
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.sendCommand("next")
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    // Set this as primary action for double tap
                    .handGestureShortcut(.primaryAction)
                }
            } else {
                Text("Not Connected")
                    .foregroundColor(.red)
                
                Button("Reconnect") {
                    viewModel.reconnect()
                    WKInterfaceDevice.current().play(.notification)
                }
                .buttonStyle(.bordered)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.reconnect()
            }
        }
        .alert("Connection Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.hasError) { newValue in
            if newValue {
                showingAlert = true
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchViewModel.shared)
}
