import Foundation
import AppKit

enum TrashEmptyResult: Equatable, Sendable {
    case emptied
    case cancelled
    case automationDenied
    case failed(String)
}

struct TrashEmptyService: Sendable {
    let executeScript: @Sendable () -> (Int?, String?)

    init(executeScript: @escaping @Sendable () -> (Int?, String?) = Self.executeFinderScript) {
        self.executeScript = executeScript
    }

    func empty() -> TrashEmptyResult {
        let (errorNumber, message) = executeScript()
        guard let errorNumber else { return .emptied }
        return Self.result(errorNumber: errorNumber, message: message)
    }

    static func result(errorNumber: Int?, message: String?) -> TrashEmptyResult {
        guard let errorNumber else { return .emptied }
        switch errorNumber {
        case -128:
            return .cancelled
        case -1743:
            return .automationDenied
        default:
            return .failed(message ?? "Finder でゴミ箱を空にできませんでした。")
        }
    }

    private static func executeFinderScript() -> (Int?, String?) {
        guard let script = NSAppleScript(source: "tell application \"Finder\" to empty trash") else {
            return (0, "Finder にゴミ箱を空にするよう依頼できませんでした。")
        }
        var errorInfo: NSDictionary?
        if script.executeAndReturnError(&errorInfo) != nil { return (nil, nil) }
        let number = (errorInfo?[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
        let message = errorInfo?[NSAppleScript.errorMessage] as? String
        return (number, message)
    }
}
