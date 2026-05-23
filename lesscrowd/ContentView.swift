//
//  ContentView.swift
//  lesscrowd
//
//  Created by Akiem Moo on 16/01/2025.
//

import SwiftUI
import CoreWLAN
import CoreLocation

extension CWNetwork: Identifiable {}
extension CWInterface: Identifiable {}

extension Color {
    static let customRed = Color(red: 0.9, green: 0.15, blue: 0.2)
}

// MARK: - Themes & Styling
struct Theme {
    static let background = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.18).opacity(0.7)
    static let accent = Color.customRed
    static let secondaryAccent = Color(red: 0.6, green: 0.05, blue: 0.1)
}

enum WifiBands: String {
    case both = "All Bands", ghz2_4 = "2.4GHz", ghz5 = "5GHz"
}

enum WifiOrderBy: String, CaseIterable, Identifiable {
    case channel, rssi
    
    var id: String {
        return self.rawValue
    }
}

// MARK: - Modern Decoupled Model
struct WiFiNetwork: Identifiable, Hashable {
    let id: String // bssid
    let ssid: String
    let bssid: String
    let channel: Int
    let band: WifiBands
    let rssi: Int
    
    var rssiDescription: String {
        return "\(rssi) dBm"
    }
    
    var signalQuality: Double {
        let minRSSI = -100.0
        let maxRSSI = -30.0
        let clamped = max(minRSSI, min(maxRSSI, Double(rssi)))
        return (clamped - minRSSI) / (maxRSSI - minRSSI)
    }
    
    var signalColor: Color {
        let q = signalQuality
        if q > 0.75 {
            return Color.green
        } else if q > 0.4 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
}

extension WiFiNetwork {
    init(from cwNetwork: CWNetwork) {
        self.id = cwNetwork.bssid ?? UUID().uuidString
        self.ssid = cwNetwork.ssid ?? "Hidden Network"
        self.bssid = cwNetwork.bssid ?? "00:00:00:00:00:00"
        let chNum = cwNetwork.wlanChannel?.channelNumber ?? 0
        self.channel = chNum
        self.band = chNum > 13 ? .ghz5 : .ghz2_4
        self.rssi = cwNetwork.rssiValue
    }
}

// MARK: - Mocks for Canvas Previews
extension WiFiNetwork {
    static let mocks: [WiFiNetwork] = [
        WiFiNetwork(id: "1", ssid: "Quantum_Fiber_5G", bssid: "E4:8D:8C:1A:2B:3C", channel: 149, band: .ghz5, rssi: -42),
        WiFiNetwork(id: "2", ssid: "Home_Sweet_Home", bssid: "88:AE:07:9F:88:12", channel: 6, band: .ghz2_4, rssi: -55),
        WiFiNetwork(id: "3", ssid: "Coffee_Shop_FreeWiFi", bssid: "A4:93:4C:E3:D2:11", channel: 1, band: .ghz2_4, rssi: -78),
        WiFiNetwork(id: "4", ssid: "Nest_Cam_External", bssid: "F0:9F:C2:11:22:33", channel: 11, band: .ghz2_4, rssi: -82),
        WiFiNetwork(id: "5", ssid: "Enterprise_Guest_Secure", bssid: "00:25:90:3A:4B:5C", channel: 36, band: .ghz5, rssi: -65),
        WiFiNetwork(id: "6", ssid: "Direct-HP-Printer", bssid: "28:80:23:4E:5F:60", channel: 6, band: .ghz2_4, rssi: -70),
        WiFiNetwork(id: "7", ssid: "Linksys_Velop_Node", bssid: "34:6B:46:12:34:56", channel: 44, band: .ghz5, rssi: -48)
    ]
}

// MARK: - Channel Congestion Logic
func getBestChannels(networks: [WiFiNetwork]) -> (ch24: Int?, ch5: Int?) {
    let standard24 = [1, 6, 11]
    let standard5 = [36, 40, 44, 48, 149, 153, 157, 161]
    
    func scoreForChannel(_ ch: Int, is5G: Bool) -> Double {
        var score = 0.0
        for net in networks {
            if is5G {
                if net.channel == ch {
                    score += net.signalQuality + 0.5
                }
            } else {
                let diff = abs(net.channel - ch)
                if diff <= 2 {
                    let weight = 1.0 - (Double(diff) * 0.4)
                    score += (net.signalQuality + 0.5) * weight
                }
            }
        }
        return score
    }
    
    var best24: Int = 6
    var min24Score = Double.infinity
    for ch in standard24 {
        let score = scoreForChannel(ch, is5G: false)
        if score < min24Score {
            min24Score = score
            best24 = ch
        }
    }
    
    var best5: Int = 149
    var min5Score = Double.infinity
    for ch in standard5 {
        let score = scoreForChannel(ch, is5G: true)
        if score < min5Score {
            min5Score = score
            best5 = ch
        }
    }
    
    let has24 = networks.contains { $0.band == .ghz2_4 }
    let has5 = networks.contains { $0.band == .ghz5 }
    
    return (has24 ? best24 : 6, has5 ? best5 : 149)
}

// MARK: - Reusable UI Components
struct WaveIconView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Image(systemName: "wifi")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.5), radius: 8)
            
            Circle()
                .stroke(Theme.accent.opacity(0.3), lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.5 : 0.8)
                .opacity(isAnimating ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(gradientColors.first)
                
                Spacer()
                
                Circle()
                    .fill(gradientColors.first?.opacity(0.1) ?? Color.clear)
                    .frame(width: 16, height: 16)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.2) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct SignalMeterView: View {
    let quality: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Double(index) / 5.0 < quality ? color : Color.white.opacity(0.15))
                    .frame(width: 3, height: CGFloat(6 + index * 4))
            }
        }
    }
}

struct WiFiNetworkCard: View {
    let network: WiFiNetwork
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Text("CH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(network.channel)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
            }
            .frame(width: 48, height: 48)
            .background(
                LinearGradient(
                    colors: network.band == .ghz5 ? [Color.customRed, Color(red: 0.6, green: 0.05, blue: 0.1)] : [Color.orange, Color.pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .shadow(color: (network.band == .ghz5 ? Color(red: 0.6, green: 0.05, blue: 0.1) : Color.orange).opacity(0.3), radius: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(network.ssid)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(network.bssid)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(network.band.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(network.band == .ghz5 ? Color.customRed.opacity(0.15) : Color.orange.opacity(0.15))
                )
                .foregroundColor(network.band == .ghz5 ? Color.customRed : Color.orange)
                .overlay(
                    Capsule()
                        .stroke(network.band == .ghz5 ? Color.customRed.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
            
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(network.rssiDescription)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(network.signalColor)
                    
                    Text(network.rssi > -60 ? "Strong" : (network.rssi > -80 ? "Moderate" : "Weak"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(width: 70, alignment: .trailing)
                
                SignalMeterView(quality: network.signalQuality, color: network.signalColor)
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color.white.opacity(0.06) : Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Theme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct CongestionSpectrumView: View {
    let networks: [WiFiNetwork]
    
    private var channelCounts: [Int: Int] {
        var counts: [Int: Int] = [:]
        for net in networks {
            counts[net.channel, default: 0] += 1
        }
        return counts
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Channel Activity Spectrum")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(alignment: .bottom, spacing: 6) {
                let activeChannels = Array(channelCounts.keys).sorted()
                
                if activeChannels.isEmpty {
                    Text("No activity detected yet. Run a scan to populate spectrum.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(activeChannels.prefix(15), id: \.self) { ch in
                        let count = channelCounts[ch] ?? 0
                        let is5G = ch > 13
                        
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: is5G ? [Color.customRed, Color(red: 0.6, green: 0.05, blue: 0.1)] : [Color.orange, Color.pink],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 22, height: CGFloat(min(50, 10 + count * 8)))
                                .overlay(
                                    Text("\(count)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .offset(y: -12),
                                    alignment: .top
                                )
                            
                            Text("CH\(ch)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var rawWifis: [CWNetwork] = []
    @State private var adpts: [CWInterface] = []
    @State private var defAdpt: CWInterface?
    @State private var scanBand: WifiBands = .both
    @State private var orderBy: WifiOrderBy = .channel
    @State private var orderByAsc = true
    @State private var isScanning = false
    
    @State private var mockWifis: [WiFiNetwork] = []
    
    private var allNetworks: [WiFiNetwork] {
        if rawWifis.isEmpty && !mockWifis.isEmpty {
            return mockWifis
        }
        return rawWifis.map { WiFiNetwork(from: $0) }
    }
    
    private var sortedAndFilteredNetworks: [WiFiNetwork] {
        var result = allNetworks
        
        if scanBand != .both {
            result = result.filter { $0.band == scanBand }
        }
        
        result.sort { a, b in
            if orderBy == .channel {
                return orderByAsc ? a.channel < b.channel : a.channel > b.channel
            } else {
                return orderByAsc ? a.rssi < b.rssi : a.rssi > b.rssi
            }
        }
        
        return result
    }
    
    // Stats Calculations
    private var totalDetected: Int {
        allNetworks.count
    }
    
    private var bandBreakdown: String {
        let ghz5Count = allNetworks.filter { $0.band == .ghz5 }.count
        if totalDetected == 0 { return "0% / 0%" }
        let p5G = Int(Double(ghz5Count) / Double(totalDetected) * 100)
        let p24 = 100 - p5G
        return "5G: \(p5G)% | 2.4G: \(p24)%"
    }
    
    private var recommended24Str: String {
        let recs = getBestChannels(networks: allNetworks)
        return recs.ch24 != nil ? "CH \(recs.ch24!)" : "N/A"
    }
    
    private var recommended5Str: String {
        let recs = getBestChannels(networks: allNetworks)
        return recs.ch5 != nil ? "CH \(recs.ch5!)" : "N/A"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // SIDEBAR CONTROLS
            VStack(alignment: .leading, spacing: 24) {
                // Header Logo
                HStack(spacing: 12) {
                    WaveIconView()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LessCrowd")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Wi-Fi Analyzer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                }
                .padding(.top, 10)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Adapter picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wi-Fi Interface")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(Theme.accent)
                            .font(.system(size: 12))
                        
                        Picker("", selection: $defAdpt) {
                            if adpts.isEmpty {
                                Text("Offline (Simulation)").tag(nil as CWInterface?)
                            } else {
                                ForEach(adpts, id: \.interfaceName) { row in
                                    Text(row.interfaceName ?? "Unknown").tag(row as CWInterface?)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        
                        Button {
                            Task { await getAdapters() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.accent)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                
                // Band Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scan Range")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 0) {
                        ForEach([WifiBands.both, WifiBands.ghz2_4, WifiBands.ghz5], id: \.self) { band in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scanBand = band
                                }
                            } label: {
                                Text(band.rawValue)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(scanBand == band ? .white : .gray)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        ZStack {
                                            if scanBand == band {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Theme.accent, Theme.secondaryAccent],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .shadow(color: Theme.accent.opacity(0.3), radius: 4)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Sorting options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sorting & Filter")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Sort By")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $orderBy) {
                                ForEach(WifiOrderBy.allCases) { row in
                                    Text(row.rawValue.capitalized).tag(row)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 90)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.04))
                        
                        Toggle(isOn: $orderByAsc) {
                            Text("Ascending")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Scan Button
                Button {
                    Task {
                        isScanning = true
                        await scanWifi()
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        isScanning = false
                    }
                } label: {
                    HStack {
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        Text(isScanning ? "Scanning..." : "Scan Environment")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: isScanning ? [Color.gray, Color.gray.opacity(0.6)] : [Theme.accent, Theme.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: isScanning ? Color.clear : Theme.accent.opacity(0.3), radius: 6)
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            }
            .padding(20)
            .frame(width: 260)
            .background(
                Color(red: 0.08, green: 0.08, blue: 0.1)
                    .opacity(0.95)
                    .ignoresSafeArea()
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // MAIN DASHBOARD (RIGHT)
            VStack(alignment: .leading, spacing: 20) {
                // Header block
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Looking for that bad shit wifis")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.white)
                        
                        Text("Real-time network congestion and channel optimization insights.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if !rawWifis.isEmpty {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .shadow(color: Color.green.opacity(0.5), radius: 3)
                            Text("Live")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("Simulation Mode")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                // Stats Grid
                HStack(spacing: 12) {
                    StatCard(
                        title: "Detected Access Points",
                        value: "\(totalDetected)",
                        icon: "antenna.radiowaves.left.and.right",
                        gradientColors: [.customRed, Color(red: 0.6, green: 0.05, blue: 0.1)]
                    )
                    
                    StatCard(
                        title: "Recommended 2.4G",
                        value: recommended24Str,
                        icon: "sparkles",
                        gradientColors: [.orange, .pink]
                    )
                    
                    StatCard(
                        title: "Recommended 5G",
                        value: recommended5Str,
                        icon: "bolt.fill",
                        gradientColors: [.customRed, .pink]
                    )
                    
                    StatCard(
                        title: "Band Distribution",
                        value: bandBreakdown,
                        icon: "chart.bar.fill",
                        gradientColors: [.orange, .customRed]
                    )
                }
                
                // Live Activity Spectrum chart
                CongestionSpectrumView(networks: allNetworks)
                
                // Access Points List Header
                HStack {
                    Text("Access Points (\(sortedAndFilteredNetworks.count))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Filtered: \(scanBand.rawValue)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
                
                // Access Points List
                ScrollView {
                    VStack(spacing: 10) {
                        if sortedAndFilteredNetworks.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                
                                Text("No Wi-Fi Networks Found")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Click 'Scan Environment' to start analyzing local signals.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                        } else {
                            ForEach(sortedAndFilteredNetworks) { network in
                                WiFiNetworkCard(network: network)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                        .ignoresSafeArea()
                    
                    // Background soft glow
                    Circle()
                        .fill(Theme.accent.opacity(0.08))
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: 200, y: -200)
                    
                    Circle()
                        .fill(Theme.secondaryAccent.opacity(0.06))
                        .frame(width: 450, height: 450)
                        .blur(radius: 90)
                        .offset(x: -150, y: 200)
                }
            )
        }
        .frame(minWidth: 950, minHeight: 650)
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await getAdapters() }
        }
    }
    
    private func scanWifi() async {
        if let adpt = defAdpt {
            do {
                let w: [CWNetwork] = try Array(adpt.scanForNetworks(withName: nil))
                rawWifis = w
            } catch {
                print("Scanning failed: \(error.localizedDescription)")
            }
        } else {
            // Simulated scan - shuffle and update RSSI slightly for realism!
            #if DEBUG
            let baseMocks = WiFiNetwork.mocks
            mockWifis = baseMocks.map { net in
                // Add some small random RSSI variation for scanning realism!
                let variation = Int.random(in: -3...3)
                let newRSSI = max(-100, min(-30, net.rssi + variation))
                return WiFiNetwork(
                    id: net.id,
                    ssid: net.ssid,
                    bssid: net.bssid,
                    channel: net.channel,
                    band: net.band,
                    rssi: newRSSI
                )
            }.shuffled()
            #endif
        }
    }
    
    private func getAdapters() async {
        let locMan = CLLocationManager()
        if locMan.authorizationStatus == .notDetermined {
            locMan.requestWhenInUseAuthorization()
        }
        let c: CWWiFiClient = CWWiFiClient()
        defAdpt = c.interface()
        if let adapters = c.interfaces() {
            adpts = adapters
        }
        
        // Canvas preview simulation default populator
        #if DEBUG
        if adpts.isEmpty {
            mockWifis = WiFiNetwork.mocks
        }
        #endif
    }
}

// MARK: - Previews
#Preview {
    ContentView()
}
