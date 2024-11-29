//
//  ContentView.swift
//  teleprompter
//
//  Created by Timmy Li on 11/28/24.
//

import SwiftUI
import MultipeerConnectivity
import Network

class ScriptManager: NSObject, ObservableObject {
    @Published var currentScript: String = "Welcome to Teleprompter\n\nThis is a sample script.\nYou can load your own script and control it from your Apple Watch."
    @Published var currentSection: Int = 0
    @Published var isConnected = false
    @Published var connectionStatus = "Not Connected"
    @Published var availableDevices: [MCPeerID] = []
    
    private var sections: [String] = []
    private var peerSession: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var monitor: NWPathMonitor?
    
    override init() {
        sections = ["Welcome to Teleprompter", "Load a script to begin"]
        super.init()
        setupNetworkMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setupMultipeer()
        }
    }
    
    private func setupNetworkMonitoring() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.connectionStatus = "Ready to connect"
                    self?.setupMultipeer()
                } else {
                    self?.connectionStatus = "Check network connection"
                }
            }
        }
        monitor?.start(queue: DispatchQueue.global())
    }
    
    private func setupMultipeer() {
        do {
            let peerID = try MCPeerID(displayName: "Mac-Teleprompter")
            peerSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
            peerSession?.delegate = self
            
            browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "teleprompter")
            browser?.delegate = self
            
            print("Setting up MultipeerConnectivity with peer ID: \(peerID.displayName)")
            startBrowsing()
            
        } catch {
            print("Error setting up MultipeerConnectivity: \(error.localizedDescription)")
        }
    }
    
    private func startBrowsing() {
        guard let browser = browser else { return }
        
        // Stop any existing browsing
        browser.stopBrowsingForPeers()
        
        // Start browsing with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("Starting to browse for peers...")
            browser.startBrowsingForPeers()
        }
    }
    
    func connectToDevice(_ peerID: MCPeerID) {
        guard let browser = browser, let session = peerSession else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        connectionStatus = "Connecting to \(peerID.displayName)..."
    }
    
    func disconnectFromDevice() {
        peerSession?.disconnect()
        isConnected = false
        connectionStatus = "Disconnected"
    }
    
    func loadScript(_ text: String) {
        currentScript = text
        sections = text.components(separatedBy: "\n\n")
        if sections.isEmpty {
            sections = ["No content available"]
        }
        currentSection = 0
    }
    
    func nextSection() {
        if currentSection < sections.count - 1 {
            currentSection += 1
        }
    }
    
    func previousSection() {
        if currentSection > 0 {
            currentSection -= 1
        }
    }
    
    func refreshConnections() {
        print("Refreshing connections...")
        // Stop current browsing
        browser?.stopBrowsingForPeers()
        peerSession?.disconnect()
        availableDevices.removeAll()
        
        // Wait a bit before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupMultipeer()
        }
    }
    
    var currentSectionText: String {
        return sections[currentSection]
    }
    
    deinit {
        monitor?.cancel()
        browser?.stopBrowsingForPeers()
        peerSession?.disconnect()
    }
}

extension ScriptManager: MCSessionDelegate, MCNearbyServiceBrowserDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.connectionStatus = "Connected to \(peerID.displayName)"
                // Remove the connected device from available devices
                self.availableDevices.removeAll { $0 == peerID }
            case .connecting:
                self.connectionStatus = "Connecting to \(peerID.displayName)..."
            case .notConnected:
                self.isConnected = false
                self.connectionStatus = "Not Connected"
                // Add the device back to available devices if disconnected
                if !self.availableDevices.contains(peerID) {
                    self.availableDevices.append(peerID)
                }
            @unknown default:
                self.connectionStatus = "Unknown State"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let command = json["command"] {
            DispatchQueue.main.async {
                switch command {
                case "next":
                    self.nextSection()
                case "previous":
                    self.previousSection()
                default:
                    break
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.availableDevices.contains(peerID) && peerID != self.peerSession?.myPeerID {
                print("Found peer: \(peerID.displayName)")
                self.availableDevices.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availableDevices.removeAll { $0 == peerID }
            if !self.isConnected {
                self.connectionStatus = "Lost connection to \(peerID.displayName)"
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var scriptManager = ScriptManager()
    @State private var fontSize: CGFloat = 32
    @State private var showingDeviceSelector = false
    @State private var scriptText: String = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack {
            HStack {
                Button(isEditing ? "Save Script" : "Edit Script") {
                    if isEditing {
                        scriptManager.loadScript(scriptText)
                    }
                    isEditing.toggle()
                }
                .padding()
                
                Slider(value: $fontSize, in: 16...72) {
                    Text("Font Size")
                }
                .frame(width: 200)
                Text("Font Size: \(Int(fontSize))")
                
                Spacer()
                
                // Connection controls
                HStack(spacing: 15) {
                    if scriptManager.isConnected {
                        Button("Disconnect") {
                            scriptManager.disconnectFromDevice()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Connect to iPhone") {
                            showingDeviceSelector = true
                        }
                    }
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(scriptManager.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(scriptManager.connectionStatus)
                            .foregroundColor(scriptManager.isConnected ? .green : .secondary)
                    }
                    
                    Button("Refresh") {
                        scriptManager.refreshConnections()
                    }
                }
                .padding()
            }
            .padding()
            
            if isEditing {
                TextEditor(text: $scriptText)
                    .font(.system(size: fontSize))
                    .padding()
                    .onChange(of: scriptText) { _ in
                        // Auto-save functionality could be added here
                    }
            } else {
                ScrollView {
                    Text(scriptManager.currentSectionText)
                        .font(.system(size: fontSize))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            
            if !isEditing {
                HStack {
                    Button("Previous") {
                        scriptManager.previousSection()
                    }
                    .padding()
                    
                    Text("\(scriptManager.currentSection + 1)")
                        .padding()
                    
                    Button("Next") {
                        scriptManager.nextSection()
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            scriptText = scriptManager.currentScript
        }
        .popover(isPresented: $showingDeviceSelector) {
            VStack(spacing: 15) {
                Text("Available iPhones")
                    .font(.headline)
                    .padding()
                
                ForEach(scriptManager.availableDevices, id: \.self) { device in
                    Button(device.displayName) {
                        scriptManager.connectToDevice(device)
                        showingDeviceSelector = false
                    }
                    .padding()
                }
                
                if scriptManager.availableDevices.isEmpty {
                    Text("No devices found")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(minWidth: 200)
        }
    }
}

#Preview {
    ContentView()
}
