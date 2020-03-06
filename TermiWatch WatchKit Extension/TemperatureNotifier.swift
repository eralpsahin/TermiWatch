import CoreLocation
import Foundation
import PMKCoreLocation
import PMKFoundation
import PromiseKit

func OpenWeatherMapAPIKey() -> String {
  return Bundle.main.object(
    forInfoDictionaryKey: "OpenWeatherMapAPIKey"
  ) as! String
}

func OpenWeatherMapURL(
  coordinate: CLLocationCoordinate2D,
  apiKey: String = OpenWeatherMapAPIKey()
) -> URL {
  return URL(
    string: "https://api.openweathermap.org/data/2.5/weather?"
      + "lat=\(coordinate.latitude)"
      + "&lon=\(coordinate.longitude)"
      + "&APPID=\(apiKey)"
  )!
}

func OpenWeatherIconToSystemIcon(icon: String) -> String {
    switch icon {
    case "01d":
        return "sun.max"
    case "02d":
        return "cloud.sun"
    case "03d":
        return "cloud"
    case "04d":
        return "cloud.fog"
    case "09d":
        return "cloud.sun.rain"
    case "10d":
        return "cloud.rain"
    case "11d":
        return "cloud.sun.bolt"
    case "13d":
        return "snow"
    case "50d":
        return "smoke"
        
    case "01n":
        return "sun.haze"
    case "02n":
        return "cloud.moon"
    case "03n":
        return "cloud"
    case "04n":
        return "cloud.fog"
    case "09n":
        return "cloud.moon.rain"
    case "10n":
        return "cloud.rain"
    case "11n":
        return "cloud.moon.bolt"
    case "13n":
        return "snow"
    case "50n":
        return "smoke"
    default:
        return "sparkles"
    }
}

let disabledCachingConfig: (URLSessionConfiguration) -> Void = {
  $0.requestCachePolicy = .reloadIgnoringLocalCacheData
  $0.urlCache = nil
}

struct OpenWeatherMapResponse: Codable {
  struct MainResponse: Codable {
    let temp: Double
  }
  
  struct WeatherResponse: Codable {
      let main: String
      let icon: String
      let description: String
  }

  let main: MainResponse
  let weather: [WeatherResponse]
  let name: String
}

func temperatureInKelvin(at coordinate: CLLocationCoordinate2D)
  -> Promise<OpenWeatherMapResponse> {
  return Promise { seal in
    let sessionConfig = URLSessionConfiguration.default
    disabledCachingConfig(sessionConfig)

    URLSession(configuration: sessionConfig).dataTask(
      .promise,
      with: OpenWeatherMapURL(coordinate: coordinate)
    ).compactMap {
      try JSONDecoder().decode(OpenWeatherMapResponse.self, from: $0.data)
    }.done {
     seal.fulfill($0)
    }.catch {
      print("Error:", $0)
    }
  }
}

public class TemperatureNotifier {
  public static let TemperatureDidChangeNotification = Notification.Name(
    rawValue: "TemperatureNotifier.TemperatureDidChangeNotification"
  )

  public static let shared = TemperatureNotifier()
  private init() {
    currentWeather = ["" : ""]
}

  public private(set) var currentWeather: [String: Any]
  private var timer: Timer?

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 1800) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      CLLocationManager.requestLocation().lastValue.then {
        temperatureInKelvin(at: $0.coordinate)
      }.done { weatherInfo in
      
        let currentTemperature = Measurement(
         value: weatherInfo.main.temp,
          unit: UnitTemperature.kelvin
        )
      
        self?.currentWeather["temp"] = currentTemperature
        self?.currentWeather["icon"] = OpenWeatherIconToSystemIcon(icon: weatherInfo.weather.first!.icon)
        self?.currentWeather["desc"] = weatherInfo.weather.first!.main
        self?.currentWeather["name"] = weatherInfo.name

        NotificationCenter.default.post(
          Notification(
            name: TemperatureNotifier.TemperatureDidChangeNotification,
            object: self?.currentWeather,
            userInfo: nil
          )
        )
      }.catch {
        print("Error:", $0.localizedDescription)
      }
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}
