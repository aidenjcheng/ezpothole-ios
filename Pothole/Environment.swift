import Foundation

class Environment {
    static let shared = Environment()

    private var environmentVariables: [String: String] = [:]

    private init() {
        loadEnvironmentVariables()
    }

    private func loadEnvironmentVariables() {
        if let path = Bundle.main.path(forResource: ".env", ofType: nil),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            parseEnvironmentFile(content)
        }

        loadFromInfoPlist()
    }

    private func parseEnvironmentFile(_ content: String) {
        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            let components = trimmedLine.split(separator: "=", maxSplits: 1)
            if components.count == 2 {
                let key = String(components[0]).trimmingCharacters(in: .whitespaces)
                let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                environmentVariables[key] = value
            }
        }
    }

    private func loadFromInfoPlist() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            if let hfToken = dict["HF_TOKEN"] as? String {
                environmentVariables["HF_TOKEN"] = hfToken
            }
            if let sessionId = dict["SESSION_ID"] as? String {
                environmentVariables["SESSION_ID"] = sessionId
            }
        }
    }

    func get(_ key: String) -> String? {
        return environmentVariables[key]
    }

    func get(_ key: String, defaultValue: String) -> String {
        return environmentVariables[key] ?? defaultValue
    }

    var hfToken: String {
        return get("HF_TOKEN", defaultValue: "hf_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    }

    var hfSpaceUrl: String {
        return get("HF_SPACE_URL", defaultValue: "https://awesomesauce10-pothole.hf.space")
    }

    var sessionId: String {
        return get("SESSION_ID", defaultValue: "CAR001")
    }

    var uploadInterval: TimeInterval {
        return TimeInterval(get("UPLOAD_INTERVAL", defaultValue: "2.0")) ?? 2.0
    }

    var minDistanceChange: Double {
        return Double(get("MIN_DISTANCE_CHANGE", defaultValue: "5.0")) ?? 5.0
    }
}

