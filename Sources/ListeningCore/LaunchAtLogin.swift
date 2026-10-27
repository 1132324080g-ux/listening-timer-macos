import Foundation
import ServiceManagement

public enum LoginItemState: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown(Int)

    public var isEnabled: Bool {
        self == .enabled
    }

    public var title: String {
        switch self {
        case .notRegistered: "未开启"
        case .enabled: "已开启"
        case .requiresApproval: "需要系统批准"
        case .notFound: "登录项不可用"
        case .unknown: "状态未知"
        }
    }

    public var detail: String {
        switch self {
        case .notRegistered:
            "开启后，登录 Mac 时会在菜单栏静默运行。"
        case .enabled:
            "下次登录 Mac 时将在菜单栏静默运行。"
        case .requiresApproval:
            "请在“系统设置 > 通用 > 登录项与扩展”中允许本应用。"
        case .notFound:
            "请先将“听鉴”放入“应用程序”文件夹，再重新开启。"
        case .unknown:
            "暂时无法读取登录项状态，可前往系统设置检查。"
        }
    }
}

public enum LaunchAtLoginError: LocalizedError, Sendable {
    case mustBeInApplications

    public var errorDescription: String? {
        switch self {
        case .mustBeInApplications:
            "请先将“听鉴”拖入“应用程序”文件夹，再开启登录时启动。"
        }
    }
}

public protocol LaunchAtLoginServing: AnyObject, Sendable {
    func currentState() -> LoginItemState
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

public final class SystemLaunchAtLoginService:
    LaunchAtLoginServing, @unchecked Sendable {
    public init() {}

    public func currentState() -> LoginItemState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unknown(Int(SMAppService.mainApp.status.rawValue))
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard currentState() != .enabled else {
                return
            }
            guard isInApplicationsFolder else {
                throw LaunchAtLoginError.mustBeInApplications
            }
            try SMAppService.mainApp.register()
        } else if currentState() != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private var isInApplicationsFolder: Bool {
        let appPath = Bundle.main.bundleURL.standardizedFileURL.path
        let userApplications =
            FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL.path
        return appPath.hasPrefix("/Applications/")
            || appPath.hasPrefix(userApplications + "/")
    }
}
