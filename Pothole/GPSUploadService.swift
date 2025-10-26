import Foundation
import CoreLocation
import Combine

class GPSUploadService: ObservableObject {
    private var serverURL: String { Environment.shared.hfSpaceUrl + "/upload" }
    private var hfToken: String { Environment.shared.hfToken }
    private var sessionId: String { Environment.shared.sessionId }

    private var uploadTimer: Timer?
    private var lastLocation: CLLocation?
    private var uploadInterval: TimeInterval { Environment.shared.uploadInterval }

    @Published var uploadCount = 0
    @Published var isConnected = false
    @Published var lastUploadTime: Date?

    func startUploading(locationManager: LocationManager) {
        uploadTimer = Timer.scheduledTimer(withTimeInterval: uploadInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let location = locationManager.location else { return }

            if self.shouldUploadLocation(location) {
                self.uploadGPSData(location: location)
                self.lastLocation = location
            }
        }
    }

    func stopUploading() {
        uploadTimer?.invalidate()
        uploadTimer = nil
    }

    private func shouldUploadLocation(_ location: CLLocation) -> Bool {
        guard let lastLocation = lastLocation else { return true }

        let distance = location.distance(from: lastLocation)
        return distance > Environment.shared.minDistanceChange
    }

    private func uploadGPSData(location: CLLocation) {
        guard let url = URL(string: serverURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(hfToken)", forHTTPHeaderField: "Authorization")

        let timestamp = Int(Date().timeIntervalSince1970)

        let payload: [String: Any] = [
            "session_id": sessionId,
            "type": "gps",
            "timestamp": timestamp,
            "lat": location.coordinate.latitude,
            "lon": location.coordinate.longitude
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Error encoding JSON: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    print("Upload error: \(error.localizedDescription)")
                    self.isConnected = false
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("GPS Upload Status: \(httpResponse.statusCode)")

                    if httpResponse.statusCode == 200 {
                        self.isConnected = true
                        self.lastUploadTime = Date()
                        self.uploadCount += 1
                    } else {
                        self.isConnected = false
                    }

                    if let data = data,
                       let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                }
            }
        }

        task.resume()

        print("📍 Uploaded GPS: \(location.coordinate.latitude), \(location.coordinate.longitude) @ \(timestamp)")
    }
}
