//
//  DelegateMediator.swift
//  3332323
//
//  Created by dd on 29/7/2021.
//

import Foundation
import UIKit
import SwiftMediator

//@available(iOS 13.0, *)
//class SceneDe: SceneDelegateMediator{
//    var window: UIWindow?
//    init(_ win : UIWindow?) {
//        window = win
//    }
//    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
//        print("UIScene在这启动")
//        guard let _ = (scene as? UIWindowScene) else { return }
//    }
//
//    func sceneWillResignActive(_ scene: UIScene) {
//        print("UIScene在这将要进入后台")
//    }
//}


class AppDe: AppDelegateMediator{
    var window: UIWindow?
    init(_ win : UIWindow?) {
        window = win
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print(" UIApplication在这启动")
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("UIApplication在这将要进入后台")
    }
}
