import Foundation
import PMKFoundation
import PromiseKit
import Alamofire
import SwiftyJSON

public class DataNotifier {
  public static let DataDidChangeNotification = Notification.Name(
    rawValue: "DataNotifier.DataDidChangeNotification"
  )

  public static let shared = DataNotifier()
  private init() {}

  public private(set) var remaining: Double?
  private var timer: Timer?
  private var id: String?
  private var token: String?
  private var refreshToken: String?
  private var headers: HTTPHeaders = [
    "Content-Type" : "application/json"
  ]
  // TODO: Enter your phone number here
  private var msiDict: [String: String] = [
      "msisdn" : ""
  ]
  
  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }
  
  private func login() {
    // TODO: Enter your password here
    let password = ["password": ""]
    let parameters = msiDict.merging(password) { (_, new) in new }
    Alamofire.request("https://api.mintsim.com/v1/mint/login", method: HTTPMethod.post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
       switch response.result {
       case .success:
           if let json = response.data {
               do{
                   let data = try JSON(data: json)
                   let id = data["id"].string
                   let token = data["token"].string
                   let refreshToken = data["refreshToken"].string
                   self.id = id
                   self.token = token
                   self.refreshToken = refreshToken
                   self.getData()
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
  
  private func refresh() {
  let refresh = ["refreshToken": self.refreshToken]
    let parameters = msiDict.merging(refresh as! [String : String]) { (_, new) in new }
  Alamofire.request("https://api.mintsim.com/v1/mint/refresh", method: HTTPMethod.post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
      switch response.result {
      case .success:
          if let json = response.data {
              do{
                  let data = try JSON(data: json)
                  let token = data["token"].string
                  
                  if token == self.token {
                    return
                  }
                  self.token = token
                  self.getData()
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
    
    
  private func getData() {
    let headerAuth = ["Authorization" : "Bearer " + self.token!]
    let customHeaders = headers.merging(headerAuth) { (_, new) in new }
    Alamofire.request("https://api.mintsim.com/v1/mint/account/"+self.id!+"/data", method: HTTPMethod.get, headers: customHeaders).validate().responseJSON { response in
      switch response.result {
      case .success:
          if let json = response.data {
              do{
                  let data = try JSON(data: json)
                  let remaining = data["remaining4G"].double
                  
                  if remaining == self.remaining {
                    return
                  }
                  
                  self.remaining = remaining
                  
                  NotificationCenter.default.post(
                    Notification(
                      name: DataNotifier.DataDidChangeNotification,
                      object: self.remaining,
                      userInfo: nil
                    )
                  )
              }
              catch{
              debugPrint("JSON Error")
              }
          }
      case .failure(let error):
          self.refresh()
          debugPrint(error)
      }
    }
    }

  public func start(withTimeInterval interval: TimeInterval = 3600) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      
      if self?.refreshToken == nil {
        self?.login()
      }
    
      if self?.token != nil {
        self?.getData()
      }
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}
