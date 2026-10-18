import Foundation
import Observation
import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

enum LoginItemState: Equatable {
    case enabled, disabled, disabledBySystem, requiresApproval

    var shouldOpenSystemSettings: Bool {
        self == .disabledBySystem || self == .requiresApproval
    }

    static func resolve(status: SMAppService.Status, userEnabled: Bool) -> Self {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: userEnabled ? .disabledBySystem : .disabled
        case .notFound: .disabled
        }
    }
}

@MainActor
@Observable
final class LoginItemController {
    private(set) var state: LoginItemState
    private(set) var message: String?
    @ObservationIgnored private let service: LoginItemService
    @ObservationIgnored private let preferences: UserDefaults
    private static let userEnabledKey = "loginItemUserEnabled"

    init(service: LoginItemService = SMAppService.mainApp, preferences: UserDefaults = .standard) {
        self.service = service
        self.preferences = preferences
        state = Self.currentState(status: service.status, preferences: preferences)
        message = Self.notice(for: state)
    }

    var isOn: Bool { state == .enabled || state == .requiresApproval }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func refresh() {
        state = Self.currentState(status: service.status, preferences: preferences)
        message = Self.notice(for: state)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
            preferences.set(enabled, forKey: Self.userEnabledKey)
            refresh()
        } catch {
            state = Self.currentState(status: service.status, preferences: preferences)
            let action = enabled ? "登録" : "解除"
            message = "ログイン項目の\(action)に失敗しました。\(error.localizedDescription)"
        }
    }

    private static func currentState(status: SMAppService.Status, preferences: UserDefaults) -> LoginItemState {
        LoginItemState.resolve(status: status, userEnabled: preferences.bool(forKey: userEnabledKey))
    }

    private static func notice(for state: LoginItemState) -> String? {
        switch state {
        case .requiresApproval: "システム設定の「ログイン項目」で Dock Studio を許可してください。許可するまでログイン時には起動しません。"
        case .disabledBySystem: "システム設定で Dock Studio のログイン項目がオフになっています。ログイン時に起動するには、設定を確認してください。"
        default: nil
        }
    }
}
