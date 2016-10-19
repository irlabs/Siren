//
//  Siren.swift
//  Siren
//
//  Created by Arthur Sabintsev on 1/3/15.
//  Copyright (c) 2015 Sabintsev iOS Projects. All rights reserved.
//

import UIKit


// MARK: - SirenDelegate Protocol

public protocol SirenDelegate: class {
    func sirenDidShowUpdateDialog(alertType: SirenAlertType)   // User presented with update dialog
    func sirenUserDidLaunchAppStore()                          // User did click on button that launched App Store.app
    func sirenUserDidSkipVersion()                             // User did click on button that skips version update
    func sirenUserDidCancel()                                  // User did click on button that cancels update dialog
    func sirenDidCheckNoUpdateNecessary()                      // Siren performed version check and did not find an update necessary
    func sirenDidFailVersionCheck(error: NSError)              // Siren failed to perform version check (may return system-level error)
    func sirenDidDetectNewVersionWithoutAlert(message: String) // Siren performed version check and did not display alert
}

/**
    Determines the type of alert to present after a successful version check has been performed.
    
    There are four options:

    - .Force: Forces user to update your app (1 button alert)
    - .Option: (DEFAULT) Presents user with option to update app now or at next launch (2 button alert)
    - .Skip: Presents user with option to update the app now, at next launch, or to skip this version all together (3 button alert)
    - .None: Doesn't show the alert, but instead returns a localized message for use in a custom UI within the sirenDidDetectNewVersionWithoutAlert() delegate method

*/
public enum SirenAlertType {
    case force        // Forces user to update your app (1 button alert)
    case option       // (DEFAULT) Presents user with option to update app now or at next launch (2 button alert)
    case skip         // Presents user with option to update the app now, at next launch, or to skip this version all together (3 button alert)
    case none         // Doesn't show the alert, but instead returns a localized message for use in a custom UI within the sirenDidDetectNewVersionWithoutAlert() delegate method
}

/**
    Determines the frequency in which the the version check is performed
    
    - .Immediately: Version check performed every time the app is launched
    - .Daily: Version check performedonce a day
    - .Weekly: Version check performed once a week

*/
public enum SirenVersionCheckType: Int {
    case immediately = 0    // Version check performed every time the app is launched
    case daily = 1          // Version check performed once a day
    case weekly = 7         // Version check performed once a week
}

/**
    Determines the available languages in which the update message and alert button titles should appear.
    
    By default, the operating system's default lanuage setting is used. However, you can force a specific language
    by setting the forceLanguageLocalization property before calling checkVersion()

*/
public enum SirenLanguageType: String {
    case Arabic = "ar"
    case Armenian = "hy"
    case Basque = "eu"
    case ChineseSimplified = "zh-Hans"
    case ChineseTraditional = "zh-Hant"
    case Croatian = "hr"
    case Danish = "da"
    case Dutch = "nl"
    case English = "en"
    case Estonian = "et"
    case French = "fr"
    case Hebrew = "he"
    case Hungarian = "hu"
    case German = "de"
    case Italian = "it"
    case Japanese = "ja"
    case Korean = "ko"
    case Latvian = "lv"
    case Lithuanian = "lt"
    case Malay = "ms"
    case Polish = "pl"
    case PortugueseBrazil = "pt"
    case PortuguesePortugal = "pt-PT"
    case Russian = "ru"
    case Slovenian = "sl"
    case Spanish = "es"
    case Swedish = "sv"
    case Thai = "th"
    case Turkish = "tr"
    case Vietnamese = "vi"
}

/**
 Siren-specific Error Codes
 */
fileprivate enum SirenErrorCode: Int {
    case malformedURL = 1000
    case recentlyCheckedAlready
    case noUpdateAvailable
    case appStoreDataRetrievalFailure
    case appStoreJSONParsingFailure
    case appStoreOSVersionNumberFailure
    case appStoreOSVersionUnsupported
    case appStoreVersionNumberFailure
    case appStoreVersionArrayFailure
    case appStoreAppIDFailure
    case customDataRetrievalFailure
    case customJSONParsingFailure
    case customDataHasNoVersions
    case customNoUpdateAvailable
}

/**
 Siren-specific Error Throwable Errors
 */
fileprivate enum SirenError: Error {
    case malformedURL
}

/** 
    Siren-specific NSUserDefault Keys
*/
fileprivate enum SirenUserDefaults: String {
    case StoredVersionCheckDate     // NSUserDefault key that stores the timestamp of the last version check
    case StoredSkippedVersion       // NSUserDefault key that stores the version that a user decided to skip
}


// MARK: - Siren

/**
    The Siren Class.
    
    A singleton that is initialized using the sharedInstance() method.
*/
public final class Siren: NSObject {

    /**
        Current installed version of your app
     */
    fileprivate var currentInstalledVersion: String? = {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }()

    /**
        The error domain for all errors created by Siren
     */
    public let SirenErrorDomain = "Siren Error Domain"

    /**
        The SirenDelegate variable, which should be set if you'd like to be notified:
    
            - When a user views or interacts with the alert
                - sirenDidShowUpdateDialog(alertType: SirenAlertType)
                - sirenUserDidLaunchAppStore()
                - sirenUserDidSkipVersion()     
                - sirenUserDidCancel()
            - When a new version has been detected, and you would like to present a localized message in a custom UI
                - sirenDidDetectNewVersionWithoutAlert(message: String)
    
    */
    public weak var delegate: SirenDelegate?

    /**
        The debug flag, which is disabled by default.
    
        When enabled, a stream of println() statements are logged to your console when a version check is performed.
    */
    public lazy var debugEnabled = false

    /**
        Determines the type of alert that should be shown.
    
        See the SirenAlertType enum for full details.
    */
    public var alertType = SirenAlertType.option {
        didSet {
            majorUpdateAlertType = alertType
            minorUpdateAlertType = alertType
            patchUpdateAlertType = alertType
            revisionUpdateAlertType = alertType
        }
    }
    
    /**
    Determines the type of alert that should be shown for major version updates: A.b.c
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    public lazy var majorUpdateAlertType = SirenAlertType.option
    
    /**
    Determines the type of alert that should be shown for minor version updates: a.B.c
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    public lazy var minorUpdateAlertType  = SirenAlertType.option
    
    /**
    Determines the type of alert that should be shown for minor patch updates: a.b.C
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    public lazy var patchUpdateAlertType = SirenAlertType.option
    
    /**
    Determines the type of alert that should be shown for revision updates: a.b.c.D
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    public lazy var revisionUpdateAlertType = SirenAlertType.option
    
    // Optional Vars
    /**
        The name of your app. 
    
        By default, it's set to the name of the app that's stored in your plist.
    */
    public lazy var appName: String = (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? ""
    
    /**
        The region or country of an App Store in which your app is available.
        
        By default, all version checks are performed against the US App Store.
        If your app is not available in the US App Store, you should set it to the identifier 
        of at least one App Store within which it is available.
    */
    public var countryCode: String?
    
    /**
        The custom URL to the (json) version file.
     
        The version file is expected to contain the minimum required version and the version from which a notification should be presented.

        Example json:
         {
             "notice": "2.0.1",
             "minimal": "2.0"
         }
        
        This json contains two keys: *notice* and *minimal*. Based on these versions and the current version of the app
        it will behave as follows:
            - if the current version is older than the minimal version: display an alert which requires an update
            - if the current version is the notice version or older: display an alert with two button: next time and update
            - if the current version is newer than the notice version: do nothing
            - if the json file was empty: do nothing
     
        If the customVersionFileURLPath is provided, then it will use this json file to check the current version against. 
        If it is not provided it will check the version on iTunes App Store.
    */
    public var customVersionFileURLPath: String?
    
    /**
        Overrides the default localization of a user's device when presenting the update message and button titles in the alert.
    
        See the SirenLanguageType enum for more details.
    */
    public var forceLanguageLocalization: SirenLanguageType?
    
    /**
        Overrides the tint color for UIAlertController.
    */
    public var alertControllerTintColor: UIColor?

    /**
     The current version of your app that is available for download on the App Store
     */
    public fileprivate(set) var currentAppStoreVersion: String?

    // Fileprivate
    fileprivate var requiredMinimalVersion: String?
    fileprivate var noticeNewerFromVersion: String?
    fileprivate var appID: Int?
    fileprivate var lastVersionCheckPerformedOnDate: Date?
    fileprivate var updaterWindow: UIWindow?

    // Initialization
    public static let sharedInstance = Siren()
    
    override init() {
        lastVersionCheckPerformedOnDate = UserDefaults.standard.object(forKey: SirenUserDefaults.StoredVersionCheckDate.rawValue) as? Date
    }

    /**
        Checks the currently installed version of your app against the App Store.
        The default check is against the US App Store, but if your app is not listed in the US,
        you should set the `countryCode` property before calling this method. Please refer to the countryCode property for more information.
    
        - parameter checkType: The frequency in days in which you want a check to be performed. Please refer to the SirenVersionCheckType enum for more details.
    */
    public func checkVersion(checkType: SirenVersionCheckType) {

        guard let _ = Bundle.bundleID() else {
            printMessage(message: "Please make sure that you have set a `Bundle Identifier` in your project.")
            return
        }

        if checkType == .immediately {
            performVersionCheck()
        } else {
            guard let lastVersionCheckPerformedOnDate = lastVersionCheckPerformedOnDate else {
                performVersionCheck()
                return
            }
            
            if daysSince(lastVersionCheckPerformed: lastVersionCheckPerformedOnDate) >= checkType.rawValue {
                performVersionCheck()
            } else {
                postError(.recentlyCheckedAlready, underlyingError: nil)
            }
        }
    }
    
    private func performVersionCheck() {
        
        // If the customVersionFileURLPath is provided, check that json for the version. Otherwise use the App Store
        if let customVersionFileURLPath = customVersionFileURLPath {
            performCustomRequest(customVersionFileURL: customVersionFileURLPath)
        } else {
            performAppStoreRequest()
        }
    }
    
    private func performAppStoreRequest() {
        
        // Create Request
        do {
            let url = try iTunesURLFromString()
            let request = URLRequest(url: url)

            // Perform Request
            let session = URLSession.shared
            let task = session.dataTask(with: request, completionHandler: { [unowned self] (data, response, error) in

                if let error = error {
                    self.postError(.appStoreDataRetrievalFailure, underlyingError: error)
                } else {

                    guard let data = data else {
                        self.postError(.appStoreDataRetrievalFailure, underlyingError: nil)
                        return
                    }

                    // Convert JSON data to Swift Dictionary of type [String: AnyObject]
                    do {

                        let jsonData = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)

                        guard let appData = jsonData as? [String: AnyObject],
                            self.isUpdateCompatibleWithDeviceOS(appData: appData) else {

                            self.postError(.appStoreJSONParsingFailure, underlyingError: nil)
                            return
                        }

                        DispatchQueue.main.async {

                            // Print iTunesLookup results from appData
                            self.printMessage(message: "JSON results: \(appData)")

                            // Process Results (e.g., extract current version that is available on the AppStore)
                            self.processAppStoreVersion(withResults: appData)

                        }

                    } catch let error as NSError {
                        self.postError(.appStoreDataRetrievalFailure, underlyingError: error)
                    }
                }

                })
            
            task.resume()

        } catch let error as NSError {
            postError(.malformedURL, underlyingError: error)
        }

    }

    private func performCustomRequest(customVersionFileURL: String) {
        
        // Create Request
        guard let url = NSURL(string: customVersionFileURL) else {
            self.postError(.malformedURL, underlyingError: nil)
            return
        }
        
        let request = URLRequest(url: url as URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60.0)
        
        // Perform Request
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { [unowned self] (data, response, error) in
            
            if let error = error {
                self.postError(.customDataRetrievalFailure, underlyingError: error)
            } else {
                
                guard let data = data else {
                    self.postError(.customDataRetrievalFailure, underlyingError: nil)
                    return
                }
                
                // Convert JSON data to Swift Dictionary of type [String: AnyObject]
                do {
                    
                    let jsonData = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
                    
                    guard let versionData = jsonData as? [String: AnyObject] else {
                        self.postError(.customJSONParsingFailure, underlyingError: nil)
                        return
                    }
                    
                    // Print JSON results from versionData
                    self.printMessage(message: "Custom JSON results: \(versionData)")

                    // Process Results (e.g., extract mininum and notice version from the custom json)
                    self.processCustomVersion(withResults: versionData)
                    
                } catch let error as NSError {
                    self.postError(.customDataRetrievalFailure, underlyingError: error)
                }
            }
            
            })
        
        task.resume()
    }

    private func processAppStoreVersion(withResults results: [String: AnyObject]) {
        
        // Store version comparison date
        storeVersionCheckDate()

        guard let allResults = results["results"] as? [[String: AnyObject]] else {
            self.postError(.appStoreVersionNumberFailure, underlyingError: nil)
            return
        }
        
        if allResults.isEmpty == false { // Conditional that avoids crash when app not in App Store

            guard let appID = allResults.first?["trackId"] as? Int else {
                self.postError(.appStoreAppIDFailure, underlyingError: nil)
                return
            }

            self.appID = appID

            currentAppStoreVersion = allResults.first?["version"] as? String
            guard let _ = currentAppStoreVersion else {
                self.postError(.appStoreVersionArrayFailure, underlyingError: nil)
                return
            }
            
            if let _ = customVersionFileURLPath {
                // Use the custom version file to check
                
                if isAppStoreVersionNewer() {
                    showAlertForCustomVersionFile()
                } else {
                    delegate?.sirenDidCheckNoUpdateNecessary()
                    postError(.noUpdateAvailable, underlyingError: nil)
                }
                
            } else {
                // Use the app store version to check

                if isAppStoreVersionNewer() {
                    showAlertIfCurrentAppStoreVersionNotSkipped()
                } else {
                    delegate?.sirenDidCheckNoUpdateNecessary()
                    postError(.noUpdateAvailable, underlyingError: nil)
                }

            }
           
        } else { // lookupResults does not contain any data as the returned array is empty
            postError(.appStoreDataRetrievalFailure, underlyingError: nil)
        }

    }
    
    private func processCustomVersion(withResults results: [String: AnyObject]) {

        // Get the minimal version
        if let minimalVersion = results["minimal"] as? String {
            requiredMinimalVersion = minimalVersion
        }
        
        // Get the notice version
        if let noticeVersion = results["notice"] as? String {
            noticeNewerFromVersion = noticeVersion
        }
        
        if requiredMinimalVersion == nil && noticeNewerFromVersion == nil {
            // If both keys were not present, do nothing
            delegate?.sirenDidCheckNoUpdateNecessary()
            self.postError(.customDataHasNoVersions, underlyingError: nil)
            return
        }
        
        // Check the version. Continue if it needs to notify or require
        if let alertTypeForCustom = setAlertTypeForCustomVersionFile(), alertTypeForCustom != .none {
            alertType = alertTypeForCustom
            
            // Call app store to find the current app store version
            performAppStoreRequest()
        } else {
            delegate?.sirenDidCheckNoUpdateNecessary()
            self.postError(.customNoUpdateAvailable, underlyingError: nil)
            return
        }
    }
}


// MARK: - Alert Helpers

fileprivate extension Siren {

    func showAlertIfCurrentAppStoreVersionNotSkipped() {
        alertType = setAlertType()
        
        guard let previouslySkippedVersion = UserDefaults.standard.object(forKey: SirenUserDefaults.StoredSkippedVersion.rawValue) as? String else {
            showAlert()
            return
        }
        
        if let currentAppStoreVersion = currentAppStoreVersion, currentAppStoreVersion != previouslySkippedVersion {
                showAlert()
        }
    }
    
    func showAlertForCustomVersionFile() {
        
        if alertType != .none {
            showAlert()
        }
    }
    
    func showAlert() {
        let updateAvailableMessage = Bundle().localizedString(stringKey: "Update Available", forceLanguageLocalization: forceLanguageLocalization)
        let newVersionMessage = localizedNewVersionMessage()

        let alertController = UIAlertController(title: updateAvailableMessage, message: newVersionMessage, preferredStyle: .alert)

        if let alertControllerTintColor = alertControllerTintColor {
            alertController.view.tintColor = alertControllerTintColor
        }

        switch alertType {
        case .force:
            alertController.addAction(updateAlertAction())
        case .option:
            alertController.addAction(nextTimeAlertAction())
            alertController.addAction(updateAlertAction())
        case .skip:
            alertController.addAction(nextTimeAlertAction())
            alertController.addAction(updateAlertAction())
            alertController.addAction(skipAlertAction())
        case .none:
            delegate?.sirenDidDetectNewVersionWithoutAlert(message: newVersionMessage)
        }
        
        if alertType != .none {
            alertController.show()
            delegate?.sirenDidShowUpdateDialog(alertType: alertType)
        }
    }
    
    func updateAlertAction() -> UIAlertAction {
        let title = localizedUpdateButtonTitle()
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) in
            self.hideWindow()
            self.launchAppStore()
            self.delegate?.sirenUserDidLaunchAppStore()
            return
        }
        
        return action
    }
    
    func nextTimeAlertAction() -> UIAlertAction {
        let title = localizedNextTimeButtonTitle()
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) in
            self.hideWindow()
            self.delegate?.sirenUserDidCancel()
            return
        }
        
        return action
    }
    
    func skipAlertAction() -> UIAlertAction {
        let title = localizedSkipButtonTitle()
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) in

            if let currentAppStoreVersion = self.currentAppStoreVersion {
                UserDefaults.standard.set(currentAppStoreVersion, forKey: SirenUserDefaults.StoredSkippedVersion.rawValue)
                UserDefaults.standard.synchronize()
            }

            self.hideWindow()
            self.delegate?.sirenUserDidSkipVersion()
            return
        }
        
        return action
    }
}


// MARK: - Localization Helpers

fileprivate extension Siren {

    func localizedNewVersionMessage() -> String {

        let newVersionMessageToLocalize = "A new version of %@ is available. Please update to version %@ now."
        let newVersionMessage = Bundle().localizedString(stringKey: newVersionMessageToLocalize, forceLanguageLocalization: forceLanguageLocalization)

        guard let currentAppStoreVersion = currentAppStoreVersion else {
            return String(format: newVersionMessage, appName, "Unknown")
        }

        return String(format: newVersionMessage, appName, currentAppStoreVersion)
    }

    func localizedUpdateButtonTitle() -> String {
        return Bundle().localizedString(stringKey: "Update", forceLanguageLocalization: forceLanguageLocalization)
    }

    func localizedNextTimeButtonTitle() -> String {
        return Bundle().localizedString(stringKey: "Next time", forceLanguageLocalization: forceLanguageLocalization)
    }

    func localizedSkipButtonTitle() -> String {
        return Bundle().localizedString(stringKey: "Skip this version", forceLanguageLocalization: forceLanguageLocalization)
    }
}


// MARK: - Misc. Helpers

fileprivate extension Siren {

    func iTunesURLFromString() throws -> URL {

        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"

        var items: [URLQueryItem] = [URLQueryItem(name: "bundleId", value: Bundle.bundleID())]

        if let countryCode = countryCode {
            let item = URLQueryItem(name: "country", value: countryCode)
            items.append(item)
        }

        components.queryItems = items

        guard let url = components.url, !url.absoluteString.isEmpty else {
            throw SirenError.malformedURL
        }

        return url
    }

    func daysSince(lastVersionCheckPerformed lastCheckDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastCheckDate, to: Date())
        return components.day!
    }

    func isUpdateCompatibleWithDeviceOS(appData: [String: AnyObject]) -> Bool {

        guard let results = appData["results"] as? [[String: AnyObject]],
            let requiredOSVersion = results.first?["minimumOsVersion"] as? String else {
                postError(.appStoreOSVersionNumberFailure, underlyingError: nil)
            return false
        }

        let systemVersion = UIDevice.current.systemVersion

        if systemVersion.compare(requiredOSVersion, options: .numeric) == .orderedDescending ||
            systemVersion.compare(requiredOSVersion, options: .numeric) == .orderedSame {
            return true
        } else {
            postError(.appStoreOSVersionUnsupported, underlyingError: nil)
            return false
        }

    }

    func isAppStoreVersionNewer() -> Bool {

        var newVersionExists = false

        if let currentInstalledVersion = currentInstalledVersion,
            let currentAppStoreVersion = currentAppStoreVersion,
            (currentInstalledVersion.compare(currentAppStoreVersion, options: .numeric) == .orderedAscending) {

            newVersionExists = true
        }

        return newVersionExists
    }

    func storeVersionCheckDate() {
        lastVersionCheckPerformedOnDate = Date()
        if let lastVersionCheckPerformedOnDate = lastVersionCheckPerformedOnDate {
            UserDefaults.standard.set(lastVersionCheckPerformedOnDate, forKey: SirenUserDefaults.StoredVersionCheckDate.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    func setAlertType() -> SirenAlertType {

        guard let currentInstalledVersion = currentInstalledVersion,
            let currentAppStoreVersion = currentAppStoreVersion else {
            return .option
        }

        let oldVersion = (currentInstalledVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}
        let newVersion = (currentAppStoreVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}

        guard let newVersionFirst = newVersion.first, let oldVersionFirst = oldVersion.first else {
            return alertType // Default value is .Option
        }

        if newVersionFirst > oldVersionFirst { // A.b.c.d
            alertType = majorUpdateAlertType
        } else if newVersion.count > 1 && (oldVersion.count <= 1 || newVersion[1] > oldVersion[1]) { // a.B.c.d
            alertType = minorUpdateAlertType
        } else if newVersion.count > 2 && (oldVersion.count <= 2 || newVersion[2] > oldVersion[2]) { // a.b.C.d
            alertType = patchUpdateAlertType
        } else if newVersion.count > 3 && (oldVersion.count <= 3 || newVersion[3] > oldVersion[3]) { // a.b.c.D
            alertType = revisionUpdateAlertType
        }

        return alertType
    }
    
    /**
        Returns nil     if there is no custom version file (and should use the App Store version)
        Returns .none   if it doesn't need to show an alert (because the current version is new enough)
        Returns .option if the current version needs to show a notification which can be dismissed
        Returns .force  if the current version is older than the minimum required version
     */
    func setAlertTypeForCustomVersionFile() -> SirenAlertType? {
        
        if let _ = customVersionFileURLPath {
            if isOlderThanRequiredMinimum() {
                return .force
            }
            if isEqualOrOlderThanNoticeVersion() {
                return .option
            }
            return .none
        }
        return nil
    }

    func isOlderThanRequiredMinimum() -> Bool {
        
        if let currentInstalledVersion = currentInstalledVersion, let requiredMinimalVersion = requiredMinimalVersion {
            // return current < minimal
            return currentInstalledVersion.compare(requiredMinimalVersion, options: .numeric) == .orderedAscending
        }
        return false
    }
    
    func isEqualOrOlderThanNoticeVersion() -> Bool {
        
        if let currentInstalledVersion = currentInstalledVersion, let noticeNewerFromVersion = noticeNewerFromVersion {
            // return current =< notice
            return currentInstalledVersion.compare(noticeNewerFromVersion, options: .numeric) != .orderedDescending
        }
        return false
    }
    
    func hideWindow() {
        if let updaterWindow = updaterWindow {
            updaterWindow.isHidden = true
            self.updaterWindow = nil
        }
    }

    func launchAppStore() {
        guard let appID = appID else {
            return
        }

        let iTunesString =  "https://itunes.apple.com/app/id\(appID)"
        let iTunesURL = URL(string: iTunesString)

        DispatchQueue.main.async {
            UIApplication.shared.openURL(iTunesURL!)
        }

    }

    func printMessage(message: String) {
        if debugEnabled {
            print("[Siren] \(message)")
        }
    }

}


// MARK: - UIAlertController Extensions

fileprivate extension UIAlertController {

    func show() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.windowLevel = UIWindowLevelAlert + 1
        
        Siren.sharedInstance.updaterWindow = window
        
        window.makeKeyAndVisible()
        window.rootViewController!.present(self, animated: true, completion: nil)
    }

}


// MARK: - NSBundle Extension

fileprivate extension Bundle {

    class func bundleID() -> String? {
        return Bundle.main.bundleIdentifier
    }

    func sirenBundlePath() -> String {
        return Bundle(for: Siren.self).path(forResource: "Siren", ofType: "bundle") as String!
    }

    func sirenForcedBundlePath(forceLanguageLocalization: SirenLanguageType) -> String {
        let path = sirenBundlePath()
        let name = forceLanguageLocalization.rawValue
        return Bundle(path: path)!.path(forResource: name, ofType: "lproj")!
    }

    func localizedString(stringKey: String, forceLanguageLocalization: SirenLanguageType?) -> String {
        var path: String
        let table = "SirenLocalizable"
        if let forceLanguageLocalization = forceLanguageLocalization {
            path = sirenForcedBundlePath(forceLanguageLocalization: forceLanguageLocalization)
        } else {
            path = sirenBundlePath()
        }
        
        return Bundle(path: path)!.localizedString(forKey: stringKey, value: stringKey, table: table)
    }

}


// MARK: - Error Handling

fileprivate extension Siren {

    func postError(_ code: SirenErrorCode, underlyingError: Error?) {

        let description: String

        switch code {
        case .malformedURL:
            description = "The iTunes URL is malformed. Please leave an issue on http://github.com/ArtSabintsev/Siren with as many details as possible."
        case .recentlyCheckedAlready:
            description = "Not checking the version, because it already checked recently."
        case .noUpdateAvailable:
            description = "No new update available."
        case .appStoreDataRetrievalFailure:
            description = "Error retrieving App Store data as an error was returned."
        case .appStoreJSONParsingFailure:
            description = "Error parsing App Store JSON data."
        case .appStoreOSVersionNumberFailure:
            description = "Error retrieving iOS version number as there was no data returned."
        case .appStoreOSVersionUnsupported:
            description = "The version of iOS on the device is lower than that of the one required by the app verison update."
        case .appStoreVersionNumberFailure:
            description = "Error retrieving App Store version number as there was no data returned."
        case .appStoreVersionArrayFailure:
            description = "Error retrieving App Store verson number as results.first does not contain a 'version' key."
        case .appStoreAppIDFailure:
            description = "Error retrieving trackId as results.first does not contain a 'trackId' key."
        case .customDataRetrievalFailure:
            description = "Error retrieving Custom JSON data as an error was returned."
        case .customJSONParsingFailure:
            description = "Error parsing Custom Version File JSON data."
        case .customDataHasNoVersions:
            description = "There were no versions found in the Custom Version File"
        case .customNoUpdateAvailable:
            description = "No new update necessary from the Custom Version File"
        }

        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: description]
        
        if let underlyingError = underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }

        let error = NSError(domain: SirenErrorDomain, code: code.rawValue, userInfo: userInfo)

        delegate?.sirenDidFailVersionCheck(error: error)

        printMessage(message: error.localizedDescription)
    }

}


// MARK: - SirenDelegate 

// Empty implementation as an extension on SirenDelegate to allow for optional implemenation of its methods

public extension SirenDelegate {

    func sirenDidShowUpdateDialog(alertType: SirenAlertType) {}
    func sirenUserDidLaunchAppStore() {}
    func sirenUserDidSkipVersion() {}
    func sirenUserDidCancel() {}
    func sirenDidCheckNoUpdateNecessary() {}
    func sirenDidFailVersionCheck(error: NSError) {}
    func sirenDidDetectNewVersionWithoutAlert(message: String) {}
}


// MARK: - Testing Helpers 

extension Siren {

    func testSetCurrentInstalledVersion(version: String) {
        currentInstalledVersion = version
    }

    func testSetAppStoreVersion(version: String) {
        currentAppStoreVersion = version
    }

    func testIsAppStoreVersionNewer() -> Bool {
        return isAppStoreVersionNewer()
    }
    
}

extension Bundle {

    func testLocalizedString(stringKey: String, forceLanguageLocalization: SirenLanguageType?) -> String {
        return Bundle().localizedString(stringKey: stringKey, forceLanguageLocalization: forceLanguageLocalization)
    }

}
