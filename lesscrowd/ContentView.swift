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

enum WifiBands: String {
    case Both = "2.4GHz + 5GHz", GHz2_4 = "2.4GHz", GHz5 = "5GHz"
}

struct ContentView: View {
    @State var wifis: [CWNetwork] = []
    @State var adpts: [CWInterface] = []
    @State private var defAdpt: CWInterface?
    @State private var scanBand: WifiBands = .Both
    
    var body: some View {
        Form {
            Section(header: Text("Wifi Adapter").bold()) {
                HStack {
                    Picker("", selection: $defAdpt) {
                        ForEach(adpts, id: \.interfaceName) {
                            row in Text(row.interfaceName ?? "").tag(row)
                        }
                    }
                    Button {
                        Task { await scanWifi() }
                    } label: {
                        Text("Scan wifi")
                    }
                }
            }
            Section(header: Text("Scan options. Selected band: \(scanBand.rawValue)").bold()) {
                HStack {
                    Button {
                        scanBand = .Both
                    } label: {
                        Text("Scan Both: 2.4GHz + 5GHz")
                    }
                    Button {
                        scanBand = .GHz2_4
                    } label: {
                        Text("2.4GHz")
                    }
                    Button {
                        scanBand = .GHz5
                    } label: {
                        Text("5GHz")
                    }
                }
            }
            Section(header: Text("Access point detected: \(wifis.count)").bold()) {
                ScrollView {
                    ForEach(wifis.filter {
                        row in
                        if let c = row.wlanChannel?.channelNumber {
                            switch scanBand {
                            case .Both:
                                return true
                            case .GHz2_4:
                                if c <= 13 {
                                    return true
                                }
                            case .GHz5:
                                if c > 13 {
                                    return true
                                }
                            }
                            return false
                        } else {
                            return false
                        }
                    }) {
                        row in
                        HStack(spacing: 20) {
                            if let c = row.wlanChannel?.channelNumber {
                                Text("CH\n\(c)")
                                    .font(.system(size: 12))
                                    .bold()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(Color.white)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .circular))
                            }
                            VStack(alignment: .leading) {
                                Text(row.ssid ?? "Read Error")
                                    .bold()
                                    .font(.system(size: 16))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("[\(row.bssid ?? "00:00:00:00:00")]")
                            }
                            Spacer()
                            if let c = row.wlanChannel {
                                Text("\(c.channelNumber > 13 ? "5GHz" : "2.4GHz")")
                                    .bold()
                                    .font(.system(size: 14))
                            }
                            Text("\(row.rssiValue) dBm")
                                .bold()
                                .font(.system(size: 14))
                        }
                        .padding(10)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            let locMan = CLLocationManager()
            if locMan.authorizationStatus == .notDetermined {
                locMan.requestWhenInUseAuthorization()
            }
            let c: CWWiFiClient = CWWiFiClient()
            defAdpt = c.interface()
            if let adapters = c.interfaces() {
                adpts = adapters
            }
        }
    }
    
    private func scanWifi() async {
        if let adpt = defAdpt {
            do {
                let w: [CWNetwork] = try Array(adpt.scanForNetworks(withName: nil))
                wifis = w.sorted { $1.rssiValue < $0.rssiValue }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ContentView()
}
