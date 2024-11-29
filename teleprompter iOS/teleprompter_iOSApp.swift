//
//  teleprompter_iOSApp.swift
//  teleprompter iOS
//
//  Created by Timmy Li on 11/28/24.
//

import SwiftUI
import WatchConnectivity
import MultipeerConnectivity
import Network

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    @Published var isReachable = false
    @Published var isConnectedToWatch = false
    @Published var isConnectedToMac = false
    @Published var isAdvertising = false
    @Published var connectionStatus = "Disconnected"
    @Published var hasLocalNetworkAuthorization = false
    
    private var wcSession: WCSession?
    private var peerSession: MCSession?
    private var serviceBrowser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var watchConnectionTimer: Timer?
    private var localNetworkAuthorization: LocalNetworkAuthorization?
    private let serviceType = "teleprompter"
    
    override init() {
        super.init()
        
        if #available(iOS 14.0, *) {
            localNetworkAuthorization = LocalNetworkAuthorization()
            checkLocalNetworkAuthorization()
        } else {
            hasLocalNetworkAuthorization = true
            setupConnections()
        }
        
        // Start watch session
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }
    
    func checkLocalNetworkAuthorization() {
        guard #available(iOS 14.0, *) else { return }
        
        localNetworkAuthorization?.requestAuthorization { [weak self] authorized in
            DispatchQueue.main.async {
                self?.hasLocalNetworkAuthorization = authorized
                if authorized {
                    self?.setupConnections()
                }
            }
        }
    }
    
    func setupConnections() {
        print("Setting up connections...")
        setupMultipeerConnectivity()
        startAdvertising()
        startBrowsing()
        
        // Setup Watch connectivity
        if WCSession.isSupported() {
            // Start periodic check for watch reachability
            watchConnectionTimer?.invalidate()
            watchConnectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let isReachable = self.wcSession?.isReachable ?? false
                if self.isReachable != isReachable {
                    self.isReachable = isReachable
                    self.isConnectedToWatch = isReachable
                    
                    // Provide haptic feedback on connection change
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(isReachable ? .success : .warning)
                }
            }
        }
    }
    
    private func setupMultipeerConnectivity() {
        let peerID = MCPeerID(displayName: UIDevice.current.name)
        peerSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        peerSession?.delegate = self
        
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        serviceBrowser?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
    }
    
    func startAdvertising() {
        advertiser?.startAdvertisingPeer()
        isAdvertising = true
        print("Started advertising")
    }
    
    func startBrowsing() {
        serviceBrowser?.startBrowsingForPeers()
        print("Started browsing for peers")
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        isAdvertising = false
        print("Stopped advertising")
    }
    
    func stopBrowsing() {
        serviceBrowser?.stopBrowsingForPeers()
        print("Stopped browsing")
    }
    
    func sendCommandToMac(_ command: String) {
        guard let session = peerSession, session.connectedPeers.count > 0 else {
            print("No connected peers to send command to")
            return
        }
        
        do {
            let commandDict = ["command": command]
            let data = try JSONSerialization.data(withJSONObject: commandDict)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("Sent command to Mac: \(command)")
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            print("Error sending command to Mac: \(error.localizedDescription)")
        }
    }
    
    func refreshConnections() {
        stopBrowsing()
        stopAdvertising()
        if #available(iOS 14.0, *) {
            checkLocalNetworkAuthorization()
        } else {
            setupConnections()
        }
    }
    
    deinit {
        watchConnectionTimer?.invalidate()
        stopAdvertising()
        stopBrowsing()
        peerSession?.disconnect()
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
            return
        }
        print("WCSession activated with state: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        WCSession.default.activate()
    }
    
    // Handle dictionary messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from Watch: \(message)")
        if let command = message["command"] as? String {
            sendCommandToMac(command)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message with reply handler from Watch: \(message)")
        if let command = message["command"] as? String {
            sendCommandToMac(command)
            // Send acknowledgment back to Watch
            replyHandler(["status": "received"])
        } else {
            replyHandler(["error": "Invalid command"])
        }
    }
    
    // Handle application context updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received application context: \(applicationContext)")
        DispatchQueue.main.async {
            if let status = applicationContext["status"] as? String {
                self.connectionStatus = status
            }
        }
    }
    
    // Handle file transfers
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Received file from Watch")
    }
    
    // Handle user info transfers
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("Received user info from Watch: \(userInfo)")
    }
    
    // Handle watch state changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isConnectedToWatch = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(session.isReachable ? .success : .warning)
        }
    }
}

// MARK: - MCSessionDelegate
extension WatchConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("Connected to: \(peerID.displayName)")
                self.isConnectedToMac = true
                self.connectionStatus = "Connected to \(peerID.displayName)"
                
                // Provide haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
            case .connecting:
                print("Connecting to: \(peerID.displayName)")
                self.connectionStatus = "Connecting to \(peerID.displayName)..."
                
            case .notConnected:
                print("Not connected to: \(peerID.displayName)")
                self.isConnectedToMac = false
                self.connectionStatus = "Not Connected"
                
                // Provide haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                
            @unknown default:
                print("Unknown state")
                self.connectionStatus = "Unknown State"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let command = json["command"] {
            print("Received command from Mac: \(command)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension WatchConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: peerSession!, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
        DispatchQueue.main.async {
            if self.peerSession?.connectedPeers.contains(peerID) == true {
                self.isConnectedToMac = false
                self.connectionStatus = "Lost connection to \(peerID.displayName)"
                
                // Provide haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.connectionStatus = "Failed to start browsing"
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension WatchConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("Received invitation from: \(peerID.displayName)")
        invitationHandler(true, peerSession)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.connectionStatus = "Failed to start advertising"
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

@main
struct teleprompter_iOSApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
