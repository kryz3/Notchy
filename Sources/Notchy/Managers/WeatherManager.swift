import Foundation

@Observable
final class WeatherManager {
    var temperature: String = ""
    var icon: String = "cloud.fill" // SF Symbol
    var condition: String = ""
    var city: String = ""
    var isLoading = false

    private var refreshTimer: Timer?

    init() {
        fetch()
        // Refresh every 15 min
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func fetch() {
        guard !isLoading else { return }
        isLoading = true

        // wttr.in returns weather in JSON, no API key needed
        guard let url = URL(string: "https://wttr.in/?format=j1") else { isLoading = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                // Parse current condition
                if let current = (json["current_condition"] as? [[String: Any]])?.first {
                    let tempC = current["temp_C"] as? String ?? ""
                    self?.temperature = "\(tempC)°"

                    let code = Int(current["weatherCode"] as? String ?? "0") ?? 0
                    self?.icon = Self.sfSymbol(for: code)

                    if let desc = (current["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String {
                        self?.condition = desc
                    }
                }

                if let nearest = (json["nearest_area"] as? [[String: Any]])?.first,
                   let area = (nearest["areaName"] as? [[String: Any]])?.first?["value"] as? String {
                    self?.city = area
                }

                Log.info("[Weather] \(self?.temperature ?? "") \(self?.condition ?? "") (\(self?.city ?? ""))")
            }
        }.resume()
    }

    private static func sfSymbol(for code: Int) -> String {
        switch code {
        case 113: return "sun.max.fill"
        case 116: return "cloud.sun.fill"
        case 119, 122: return "cloud.fill"
        case 143, 248, 260: return "cloud.fog.fill"
        case 176, 263, 266, 293, 296: return "cloud.drizzle.fill"
        case 179, 323, 326, 329, 332: return "cloud.snow.fill"
        case 182, 185, 281, 284, 311, 314, 317, 350: return "cloud.sleet.fill"
        case 200, 386, 389, 392, 395: return "cloud.bolt.rain.fill"
        case 227, 230: return "wind.snow"
        case 299, 302, 305, 308, 356, 359: return "cloud.rain.fill"
        case 335, 338, 368, 371, 374, 377: return "cloud.snow.fill"
        default: return "cloud.fill"
        }
    }
}
