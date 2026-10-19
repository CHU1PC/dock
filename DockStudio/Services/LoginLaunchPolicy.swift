import AppKit
import Carbon
import Observation

enum LoginLaunchPolicy {
    struct EventState: Equatable {
        private(set) var isLoginLaunch: Bool?

        var usesLoginLaunchBehavior: Bool { isLoginLaunch ?? false }

        mutating func record(isLoginLaunch: Bool) {
            self.isLoginLaunch = isLoginLaunch
        }
    }

    struct Decision: Equatable {
        let showDock: Bool
        let showStudio: Bool
    }

    static func isLoginLaunch(eventID: AEEventID, propertyDataCode: OSType?) -> Bool {
        eventID == AEEventID(kAEOpenApplication)
            && propertyDataCode == OSType(keyAELaunchedAsLogInItem)
    }

    static func decision(isLoginLaunch: Bool, dockVisible: Bool) -> Decision {
        Decision(showDock: dockVisible, showStudio: !isLoginLaunch)
    }
}

@MainActor
@Observable
final class LoginLaunchState {
    private var eventState = LoginLaunchPolicy.EventState()

    var isLoginLaunch: Bool { eventState.usesLoginLaunchBehavior }

    func recordLoginLaunch(_ isLoginLaunch: Bool) {
        eventState.record(isLoginLaunch: isLoginLaunch)
    }
}
