import AppKit
import Carbon
import Observation

enum LoginLaunchPolicy {
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
    private(set) var isLoginLaunch = false

    func recordOpenApplicationEvent(_ event: NSAppleEventDescriptor) {
        let propertyDataCode = event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        isLoginLaunch = LoginLaunchPolicy.isLoginLaunch(
            eventID: event.eventID,
            propertyDataCode: propertyDataCode
        )
    }
}
