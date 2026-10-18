import AppKit
import Carbon
import Observation

enum LoginLaunchPolicy {
    static func isLoginLaunch(eventID: AEEventID, propertyDataCode: OSType?) -> Bool {
        eventID == AEEventID(kAEOpenApplication)
            && propertyDataCode == OSType(keyAELaunchedAsLogInItem)
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
