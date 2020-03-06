import Foundation
import PMKFoundation
import PromiseKit
import Alamofire
import SwiftyJSON

public class CurrencyNotifier {
  public static let CurrencyDidChangeNotification = Notification.Name(
    rawValue: "CurrencyNotifier.CurrencyDidChangeNotification"
  )

  public static let shared = CurrencyNotifier()
  private init() {}

  public private(set) var currency: String?
  private var timer: Timer?

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 1800) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      
      Alamofire.request("http://165.22.13.59:3000/usd").validate().responseJSON { response in
          switch response.result {
          case .success:
              if let json = response.data {
                  do{
                      let data = try JSON(data: json)
                      let currency = data["rate"].string
                      
                      if currency == self?.currency {
                        return
                      }
                      
                      self?.currency = currency
                      
                      NotificationCenter.default.post(
                        Notification(
                          name: CurrencyNotifier.CurrencyDidChangeNotification,
                          object: self?.currency,
                          userInfo: nil
                        )
                      )
                  }
                  catch{
                  debugPrint("JSON Error")
                  }

              }
          case .failure(let error):
              debugPrint(error)
          }
      }
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}
