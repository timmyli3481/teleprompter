//
//  ContentView.swift
//  teleprompter iOS
//
//  Created by Timmy Li on 11/28/24.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Teleprompter")
                .font(.largeTitle)
                .padding()
            
            // Local Network Status
            VStack {
                Image(systemName: connectivityManager.hasLocalNetworkAuthorization ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(connectivityManager.hasLocalNetworkAuthorization ? .green : .red)
                    .font(.system(size: 50))
                
                Text("Local Network Access")
                    .font(.headline)
                
                if !connectivityManager.hasLocalNetworkAuthorization {
                    Button("Request Access") {
                        connectivityManager.checkLocalNetworkAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            // Connection Status
            VStack {
                HStack {
                    Image(systemName: connectivityManager.isConnectedToWatch ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                        .foregroundColor(connectivityManager.isConnectedToWatch ? .green : .red)
                    Text("Watch Connection: \(connectivityManager.isConnectedToWatch ? "Connected" : "Disconnected")")
                }
                
                HStack {
                    Image(systemName: connectivityManager.isConnectedToMac ? "laptopcomputer.and.iphone" : "laptopcomputer.slash")
                        .foregroundColor(connectivityManager.isConnectedToMac ? .green : .red)
                    Text("Mac Connection: \(connectivityManager.isConnectedToMac ? "Connected" : "Disconnected")")
                }
            }
            .font(.headline)
            .padding()
            
            // Refresh Button
            Button(action: {
                connectivityManager.refreshConnections()
            }) {
                Label("Refresh Connections", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // Status Text
            Text(connectivityManager.connectionStatus)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}
