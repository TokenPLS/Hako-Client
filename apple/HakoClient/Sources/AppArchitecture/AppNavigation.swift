import SwiftUI
import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home
    case utilities
    case more
}
typealias AppNavigationDestination = HakoClientUI.AppleClientDestination

enum AppShellLayout: Equatable, Sendable {
    case compactTabs
    case regularSidebar
}

 
 
 
 
 
 
 
 
 
 
 
struct HakoShellLayoutKey: EnvironmentKey {
    static let defaultValue: AppShellLayout = .compactTabs
}

extension EnvironmentValues {
    var hakoShellLayout: AppShellLayout {
        get { self[HakoShellLayoutKey.self] }
        set { self[HakoShellLayoutKey.self] = newValue }
    }
}

enum AppShellLayoutSelector {
    static func layout(
        isPad: Bool,
        hasRegularHorizontalSize: Bool
    ) -> AppShellLayout {
        isPad && hasRegularHorizontalSize ? .regularSidebar : .compactTabs
    }

     
     
     
     
     
     
     
     
     
    static func compactHandoff(
        for selectedRoot: HakoClientUI.HakoRootDestination
    ) -> AppShellCompactHandoff? {
        switch selectedRoot {
        case .proxies: .proxiesSheet
        case .rules: .rulesSheet
        case .profiles: .profileCenter
         
         
         
        case .home, .utilities, .more, .connections, .requests, .logs, .dns, .about:
            nil
        }
    }
}

 
enum AppShellCompactHandoff: Equatable, Sendable {
    case proxiesSheet
    case rulesSheet
    case profileCenter
}

extension AppShellLayoutSelector {
     
     
     
     
     
     
     
     
    static func regularHandoff(
        for profileCenter: AppNavigationDestination?,
        sessionPage: HakoClientUI.HakoRootDestination?
    ) -> HakoClientUI.HakoRootDestination? {
         
         
        if let sessionPage { return sessionPage }
        return profileCenter == .profiles ? .profiles : nil
    }
}

 
 
 
 
 
enum AppShellNavigationRouter {
    static func navigate(
        to destination: AppNavigationDestination,
        layout: AppShellLayout,
        navigationState: inout HakoClientUI.AppleClientNavigationState,
        profileCenterDestination: inout AppNavigationDestination?
    ) {
        switch destination {
         
         
         
         
        case .profiles where layout == .regularSidebar:
            profileCenterDestination = nil
            navigationState.navigate(to: destination)
        case .profiles, .profileImport, .profileDetail:
            profileCenterDestination = destination
        default:
            profileCenterDestination = nil
            navigationState.navigate(to: destination)
        }
    }
}

extension HakoSystemRoute {
     
     
    var navigationDestination: AppNavigationDestination {
        switch self {
        case .vpn, .mode:
            return .home
        case .open(let destination):
            switch destination {
            case .overview, .home:
                return .home
            case .profiles:
                return .profiles
            case .nodes, .proxies:
                return .proxies
            case .logs:
                return .utilities(.logs)
            case .tools, .utilities:
                return .utilities(.root)
            case .more:
                return .more(.root)
            }
        }
    }
}
