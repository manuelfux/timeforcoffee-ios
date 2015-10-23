//
//  AppDelegate.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit
import CoreLocation
import Fabric
import Crashlytics
import CoreSpotlight
import MobileCoreServices
import CoreData


@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // when the app starts from scratch, we can't move to favorites
    //  from the AppDelegate but have to do it later in the ViewController
    //
    var startedWithShortcut: String?
    var launchedShortcutItem: AnyObject?

    enum ShortcutIdentifier: String {
        case favorites
        case search
        case station

        // MARK: Initializers

        init?(fullType: String) {
            guard let last = fullType.componentsSeparatedByString(".").last else { return nil }

            self.init(rawValue: last)
        }

        // MARK: Properties

        var type: String {
            return NSBundle.mainBundle().bundleIdentifier! + ".\(self.rawValue)"
        }
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Override point for customization after application launch.
        var shouldPerformAdditionalDelegateHandling = true

        // If a shortcut was launched, display its information and take the appropriate action
        if #available(iOS 9.0, *) {
            if let shortcutItem = launchOptions?[UIApplicationLaunchOptionsShortcutItemKey] as? UIApplicationShortcutItem {
    
                launchedShortcutItem = shortcutItem
    
                // This will block "performActionForShortcutItem:completionHandler" from being called.
                shouldPerformAdditionalDelegateHandling = false
            }
        }


        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerForNotifications()
            TFCDataStore.sharedInstance.synchronize()
            TFCDataStore.sharedInstance.registerWatchConnectivity()
        }

        let gtracker = GAI.sharedInstance()
        gtracker.trackUncaughtExceptions = true
        gtracker.dispatchInterval = 20;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtracker.trackerWithTrackingId("UA-37092982-2")
        #if !((arch(i386) || arch(x86_64)) && os(iOS))
        Fabric.with([Crashlytics()])
        #endif
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            #if !((arch(i386) || arch(x86_64)) && os(iOS))
            let settings = SKTSettings(appToken: "7n3aaqyp9fr5kr7y1wjssd231")
            settings.knowledgeBaseURL = "https://timeforcoffee.zendesk.com"
            SupportKit.initWithSettings(settings)
            #endif
            let userdefaults = TFCDataStore.sharedInstance.getUserDefaults()
            let lastusedTodayScreen: NSDate? = userdefaults?.objectForKey("lastUsedViewUpdate") as! NSDate?
            var recommendations: [String] = []
            recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202701502-How-to-use-the-favourite-station-feature-")
            recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202701512-Can-I-exclude-some-destinations-from-a-station-")
            recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202775921-Is-there-a-map-view-somewhere-")
            recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202772511-Who-is-behind-Time-for-Coffee-")

            if (lastusedTodayScreen != nil) {
                SKTUser.currentUser().addProperties(["usedTodayScreen": true])
            }
            if (SKTUser.currentUser().signedUpAt == nil) {
                SKTUser.currentUser().signedUpAt = NSDate()
                SKTUser.currentUser().addProperties(["signedUpDate" : NSDate()])
                if let lang =  NSLocale.preferredLanguages().first {
                    SKTUser.currentUser().addProperties(["language": lang])
                }
                if (userdefaults?.objectForKey("favorites2") != nil) {
                    SKTUser.currentUser().addProperties(["usedFavorites": true])
                } else {
                    SKTUser.currentUser().addProperties(["usedFavorites": false])
                }
                if (lastusedTodayScreen != nil) {
                    SKTUser.currentUser().addProperties(["lastUsedTodayScreen": lastusedTodayScreen!])
                    SKTUser.currentUser().addProperties(["usedTodayScreen": true])
                } else {
                    SKTUser.currentUser().addProperties(["usedTodayScreen": false])
                }
            }

            SupportKit.setDefaultRecommendations(recommendations)
            if (lastusedTodayScreen == nil) {
                SupportKit.setTopRecommendation("https://timeforcoffee.zendesk.com/hc/en-us/articles/202698032-How-to-add-Time-for-Coffee-to-the-Today-Screen-")

            }
        }
        return shouldPerformAdditionalDelegateHandling
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        TFCDataStore.sharedInstance.saveContext()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if #available(iOS 9.0, *) {
            guard let shortcut = launchedShortcutItem else { return }
            handleShortCutItem(shortcut as! UIApplicationShortcutItem)
            launchedShortcutItem = nil
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        TFCDataStore.sharedInstance.saveContext()
    }

    @available(iOS 9.0, *)
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {

        let handledShortCutItem = handleShortCutItem(shortcutItem)
        completionHandler(handledShortCutItem)
    }

    @available(iOS 9.0, *)
    func handleShortCutItem(shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Verify that the provided `shortcutItem`'s `type` is one handled by the application.
        var handled = false
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else { return false }

        guard let shortCutType = shortcutItem.type as String? else { return false }
        startedWithShortcut = shortCutType
        switch (shortCutType) {
        case ShortcutIdentifier.favorites.type:
            // Handle shortcut 1 (static).
            if let rootView = self.window?.rootViewController as! UINavigationController? {
                rootView.dismissViewControllerAnimated(false, completion: nil)
                rootView.popToRootViewControllerAnimated(true)
                if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                    pagedView.moveToFavorites()
                }
            }
            handled = true
            break
        case ShortcutIdentifier.search.type:
            // Handle shortcut 2 (static).
            if let rootView = self.window?.rootViewController as! UINavigationController? {
                rootView.dismissViewControllerAnimated(false, completion: nil)
                rootView.popToRootViewControllerAnimated(true)
                if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                   pagedView.searchClicked()
                }
            }
            handled = true
            break
        case ShortcutIdentifier.station.type:
            // Handle shortcut 3 (dynamic).
            handled = true
            if let ua: [String: String] = shortcutItem.userInfo as? [String: String] {
                if (ua["st_id"] != nil) {
                    let station = TFCStation.initWithCache(ua)
                    popUpStation(station)
                }
            }

            break
        default:
            break
        }
        return handled

    }


    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {

        if (url.host == "nearby") {
            if let rootView = self.window?.rootViewController as! UINavigationController? {
                rootView.dismissViewControllerAnimated(false, completion: nil)
                rootView.popToRootViewControllerAnimated(false)
                if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                    pagedView.moveToNearbyStations()
                }
            }

        } else if (url.host == "station" && url.query != nil) {
         
            var queryStrings = [String: String]()
            if let query = url.query {
                for qs in query.componentsSeparatedByString("&") {
                    // Get the parameter name
                    let key = qs.componentsSeparatedByString("=")[0]
                    // Get the parameter name
                    var value = qs.componentsSeparatedByString("=")[1]
                    value = value.stringByReplacingOccurrencesOfString("+", withString: " ")
                    value = value.stringByRemovingPercentEncoding!

                    
                    queryStrings[key] = value
                }
            }
            if let name = queryStrings["name"] as String? {
                var Clocation: CLLocation? = nil
                if (queryStrings["lat"] != nil) {
                    Clocation = CLLocation(latitude: NSString(string: queryStrings["lat"]!).doubleValue, longitude: NSString(string: queryStrings["long"]!).doubleValue)
                }
                let station = TFCStation.initWithCache(name, id: queryStrings["id"]!, coord: Clocation)
                popUpStation(station)
            }
        }
        return true
    }
    func application(_: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: [AnyObject]? -> Void) -> Bool {
        if #available(iOS 9, *) {

            if userActivity.activityType == "ch.opendata.timeforcoffee.station" {
                DLog("here")
                if let ua: [String: String] = userActivity.userInfo as? [String: String] {
                    if (ua["st_id"] != nil) {
                        let station = TFCStation.initWithCache(ua)
                        popUpStation(station)
                    }
                }

            }
            if userActivity.activityType == CSSearchableItemActionType {
                // This activity represents an item indexed using Core Spotlight, so restore the context related to the unique identifier.
                // Note that the unique identifier of the Core Spotlight item is set in the activity’s userInfo property for the key CSSearchableItemActivityIdentifier.
                if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                // Next, find and open the item specified by uniqueIdentifer.
                    let station = TFCStation.initWithCache("", id: uniqueIdentifier, coord: nil)
                    popUpStation(station)

                }
            }


        }
        return true

    }

    private func popUpStation(station: TFCStation) {
        let rootView = self.window?.rootViewController as! UINavigationController
        let detailViewController = rootView.storyboard?.instantiateViewControllerWithIdentifier("DeparturesViewController") as! DeparturesViewController

        rootView.dismissViewControllerAnimated(false, completion: nil)
        rootView.popToRootViewControllerAnimated(false)
        detailViewController.setStation(station: station)
        rootView.pushViewController(detailViewController, animated: false)
    }

}
