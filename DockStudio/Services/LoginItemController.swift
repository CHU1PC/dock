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
    case enabled, disabled, requiresApproval, unavailable

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled: self = .enabled
        case .requiresApproval: self = .requiresApproval
        case .notFound: self = .unavailable
        default: self = .disabled
        }
    }
}

@MainActor
@Observable
final class LoginItemController {
    private(set) var state: LoginItemState
    private(set) var message: String?
    @ObservationIgnored private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        state = LoginItemState(service.status)
        message = Self.notice(for: state)
    }

    var isOn: Bool { state == .enabled || state == .requiresApproval }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func refresh() {
        state = LoginItemState(service.status)
        message = Self.notice(for: state)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
            refresh()
        } catch {
            state = LoginItemState(service.status)
            let action = enabled ? "登録" : "解除"
            message = "ログイン項目の\(action)に失敗しました。\(error.localizedDescription)"
        }
    }

    private static func notice(for state: LoginItemState) -> String? {
        switch state {
        case .requiresApproval: "システム設定の「ログイン項目」で Dock Studio を許可してください。許可するまでログイン時には起動しません。"
        case .unavailable: "このビルドはログイン項目として登録できません。/Applications などに置いたアプリで試してください。"
        default: nil
        }
    }
}
