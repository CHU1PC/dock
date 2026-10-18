import Intents

enum FocusStatusAuthorization: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

protocol FocusStatusProviding {
    var authorization: FocusStatusAuthorization { get }
    var isFocused: Bool? { get }
    func requestAuthorization(completion: @escaping (FocusStatusAuthorization) -> Void)
}

final class AttentionBounceFocusStatus {
    private let provider: any FocusStatusProviding
    private var didRequestAuthorization = false

    init(provider: any FocusStatusProviding = SystemFocusStatusProvider()) {
        self.provider = provider
    }

    var shouldSuppressBounce: Bool {
        provider.authorization == .authorized && provider.isFocused == true
    }

    func requestAuthorizationIfNeeded() {
        guard !didRequestAuthorization, provider.authorization == .notDetermined else { return }
        didRequestAuthorization = true
        provider.requestAuthorization { _ in }
    }
}

private struct SystemFocusStatusProvider: FocusStatusProviding {
    var authorization: FocusStatusAuthorization {
        guard #available(macOS 12.0, *) else { return .unavailable }
        return Self.authorization(for: INFocusStatusCenter.default.authorizationStatus)
    }

    var isFocused: Bool? {
        guard #available(macOS 12.0, *), authorization == .authorized else { return nil }
        return INFocusStatusCenter.default.focusStatus.isFocused
    }

    func requestAuthorization(completion: @escaping (FocusStatusAuthorization) -> Void) {
        guard #available(macOS 12.0, *) else {
            completion(.unavailable)
            return
        }
        INFocusStatusCenter.default.requestAuthorization { status in
            completion(Self.authorization(for: status))
        }
    }

    private static func authorization(for status: INFocusStatusAuthorizationStatus) -> FocusStatusAuthorization {
        switch status {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .unavailable
        }
    }
}
