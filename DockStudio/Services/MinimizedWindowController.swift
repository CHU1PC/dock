import AppKit
import ApplicationServices
import Observation
import SwiftUI

struct MinimizedWindow: Identifiable {
    let id: String
    let title: String
    let applicationName: String
    let applicationIcon: NSImage?
}

enum MinimizedWindowState {
    case notChecked
    case permissionDenied
    case available([MinimizedWindow])

    var windows: [MinimizedWindow] {
        guard case .available(let windows) = self else { return [] }
        return windows
    }
}

@MainActor
protocol MinimizedWindowProviding {
    func snapshot() -> MinimizedWindowState
    @discardableResult func restore(windowID: String) -> Bool
}

@MainActor
@Observable
final class MinimizedWindowController {
    private(set) var state: MinimizedWindowState = .notChecked
    private let provider: any MinimizedWindowProviding

    init(provider: any MinimizedWindowProviding) {
        self.provider = provider
    }

    var windows: [MinimizedWindow] { state.windows }

    func refresh() {
        state = provider.snapshot()
    }

    @discardableResult
    func restore(windowID: String) -> Bool {
        let restored = provider.restore(windowID: windowID)
        refresh()
        return restored
    }
}

@MainActor
final class AccessibilityMinimizedWindowProvider: MinimizedWindowProviding {
    private static let ownProcessID = ProcessInfo.processInfo.processIdentifier
    private static let windowsAttribute = kAXWindowsAttribute as CFString
    private static let minimizedAttribute = kAXMinimizedAttribute as CFString
    private static let titleAttribute = kAXTitleAttribute as CFString

    private var elements: [String: AXUIElement] = [:]

    func snapshot() -> MinimizedWindowState {
        guard AXIsProcessTrusted() else { return .permissionDenied }
        elements.removeAll(keepingCapacity: true)
        var windows: [MinimizedWindow] = []

        for application in NSWorkspace.shared.runningApplications
        where application.processIdentifier != Self.ownProcessID && application.activationPolicy == .regular
            && !application.isTerminated {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, Self.windowsAttribute, &value) == .success,
                  let appWindows = value as? [AXUIElement] else { continue }

            for (index, element) in appWindows.enumerated() {
                var minimizedValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, Self.minimizedAttribute, &minimizedValue) == .success,
                      (minimizedValue as? Bool) == true else { continue }
                var titleValue: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(element, Self.titleAttribute, &titleValue)
                let title = (titleValue as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "名称未設定のウインドウ"
                let id = "\(application.processIdentifier):\(index):\(title)"
                elements[id] = element
                windows.append(MinimizedWindow(id: id, title: title,
                                               applicationName: application.localizedName ?? "名称未設定のアプリ",
                                               applicationIcon: application.icon))
            }
        }
        return .available(windows.sorted {
            let appOrder = $0.applicationName.localizedStandardCompare($1.applicationName)
            return appOrder == .orderedSame
                ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                : appOrder == .orderedAscending
        })
    }

    @discardableResult
    func restore(windowID: String) -> Bool {
        guard let element = elements[windowID],
              AXUIElementSetAttributeValue(element, Self.minimizedAttribute, kCFBooleanFalse) == .success else {
            return false
        }
        return AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }
}

struct MinimizedWindowsDockSection: View {
    let vertical: Bool
    let iconSize: Double
    let iconStyle: DockAppearance.IconStyle
    @Bindable var controller: MinimizedWindowController
    let enabled: Bool

    var body: some View {
        Group {
            if enabled {
                let layout = vertical
                    ? AnyLayout(VStackLayout(spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .bottom, spacing: 0))
                layout {
                    switch controller.state {
                    case .notChecked:
                        EmptyView()
                    case .permissionDenied:
                        Button {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("アクセシビリティの許可が必要", systemImage: "lock.fill")
                                .font(.caption).padding(8)
                                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("システム設定のプライバシーとセキュリティを開きます")
                    case .available(let windows):
                        ForEach(windows) { window in
                            Button {
                                controller.restore(windowID: window.id)
                            } label: {
                                Group {
                                    if let icon = window.applicationIcon {
                                        Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
                                    } else {
                                        Image(systemName: "macwindow")
                                            .font(.system(size: iconSize * 0.5, weight: .medium))
                                            .foregroundStyle(iconStyle == .original ? StudioColor.accent : .primary)
                                    }
                                }
                                .frame(width: iconSize, height: iconSize)
                                .padding(vertical ? .vertical : .horizontal, 5)
                            }
                            .buttonStyle(.plain)
                            .help("\(window.title) — \(window.applicationName)")
                            .accessibilityLabel("\(window.title)、\(window.applicationName)")
                        }
                    }
                }
            }
        }
        .task(id: enabled) {
            guard enabled else { return }
            while !Task.isCancelled {
                controller.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
