import SwiftUI
import CoreLocation

struct DevLogsSheet: View {
    let logs: [String]
    let onClear: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    if logs.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No logs yet")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Connect to ESP32 and interact to see logs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(logs.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .trailing)

                                        Text(logs[index])
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationTitle("Developer Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !logs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onClear) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var uploadService = GPSUploadService()
    @StateObject private var bleManager = BLEManager()

    @State private var sessionId = "CAR001"
    @State private var showingDevLogs = false
    @State private var devLogs: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                            .font(.system(size: 60))
                            .foregroundColor(locationManager.isTracking ? .green : .gray)
                            .padding(.top, 20)

                        Text(locationManager.isTracking ? "Tracking Active" : "Session Stopped")
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack {
                            Circle()
                                .fill(uploadService.isConnected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(uploadService.isConnected ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    .padding()

                    if let location = locationManager.location {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Latitude:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "%.6f", location.coordinate.latitude))
                                    .foregroundColor(.blue)
                            }

                            HStack {
                                Text("Longitude:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "%.6f", location.coordinate.longitude))
                                    .foregroundColor(.blue)
                            }

                            HStack {
                                Text("Accuracy:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "±%.0f m", location.horizontalAccuracy))
                                    .foregroundColor(.orange)
                            }

                            HStack {
                                Text("Speed:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "%.1f km/h", location.speed * 3.6))
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("Session ID:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(sessionId)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Uploads:")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(uploadService.uploadCount)")
                                .foregroundColor(.green)
                        }

                        if let lastUpload = uploadService.lastUploadTime {
                            HStack {
                                Text("Last Upload:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(lastUpload, style: .time)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    VStack(spacing: 10) {
                        HStack {
                            Text("Connected")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            Circle()
                                .fill(bleManager.isConnected ? Color.blue : Color.gray)
                                .frame(width: 12, height: 12)
                        }

                        Text(bleManager.connectionStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !bleManager.receivedData.isEmpty {
                            HStack {
                                Text("ESP32:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(bleManager.receivedData)
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
Spacer()
                    VStack(spacing: 15) {
                        if locationManager.authorizationStatus == .notDetermined {
                            Button(action: {
                                locationManager.requestPermission()
                            }) {
                                Label("Start Session", systemImage: "location.circle")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        } else if locationManager.authorizationStatus == .authorizedAlways ||
                                  locationManager.authorizationStatus == .authorizedWhenInUse {

                            if locationManager.isTracking {
                                Button(action: {
                                    stopTracking()
                                }) {
                                    Label("Stop Tracking", systemImage: "stop.circle.fill")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            } else {
                                Button(action: {
                                    startTracking()
                                }) {
                                    Label("Start Tracking", systemImage: "play.circle.fill")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            Text("Location permission denied. Please enable in Settings.")
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                }.frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            .navigationTitle("Pothole Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDevLogs.toggle()
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        bleManager.sendControlToESP32("sleep")
                        addDevLog("Sent sleep command to ESP32")
                    }) {
                        Image(systemName: "power.circle.fill")
                            .foregroundColor(bleManager.isConnected ? .red : .gray)
                    }
                    .disabled(!bleManager.isConnected)
                }
            }
            .sheet(isPresented: $showingDevLogs) {
                DevLogsSheet(logs: devLogs, onClear: {
                    devLogs.removeAll()
                })
            }
            .onAppear {
                bleManager.logCallback = { [self] message in
                    addDevLog(message)
                }
            }
        }.frame(maxHeight: .infinity)
    }

    private func startTracking() {
        locationManager.startTracking()
        uploadService.startUploading(locationManager: locationManager)
        bleManager.startScanning()
        addDevLog("Started GPS tracking and BLE scanning")
    }

    private func stopTracking() {
        locationManager.stopTracking()
        uploadService.stopUploading()
        bleManager.stopScanning()
        if bleManager.isConnected {
            bleManager.disconnect(peripheral: bleManager.thermometer)
        }
        addDevLog("Stopped GPS tracking and BLE connection")
    }

    private func addDevLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        devLogs.append("[\(timestamp)] \(message)")
        if devLogs.count > 100 {
            devLogs.removeFirst()
        }
    }
}

#Preview {
    ContentView()
}
