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

struct ContentView: View {
    @State var wifis: [CWNetwork] = []
    @State var adpts: [CWInterface] = []
    @State private var defAdpt: CWInterface?
    
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
            Section(header: Text("Access point detected: \(wifis.count)").bold()) {
                ScrollView {
                    ForEach(wifis) {
                        row in
                        VStack(alignment: .leading) {
                            Text(row.ssid ?? "Read Error")
                                .bold()
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("[\(row.bssid ?? "00:00:00:00:00")] RSSI: \(row.rssiValue) dBm")
                            if let wchannel = row.wlanChannel {
                                Text("Band: \(wchannel.channelNumber > 13 ? "5GHz" : "2.4GHz") Channel: \(wchannel.channelNumber)")
                            }
                        }
                        .frame(maxWidth: .infinity)
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
                var w: [CWNetwork] = try Array(adpt.scanForNetworks(withName: nil))
                for i in 0..<w.count {
                    for j in stride(from: i + 1, to: w.count, by: 1) {
                        if w[j].rssiValue > w[i].rssiValue {
                            let jRow = w[j]
                            w[j] = w[i]
                            w[i] = jRow
                        }
                    }
                }
                wifis = w
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ContentView()
}
