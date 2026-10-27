import Foundation

public enum CSVExporter {
    public static func makeCSV(
        sessions: [ListeningSession],
        locale: Locale = Locale(identifier: "zh_CN")
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let header = [
            "会话 ID", "开始时间", "结束时间", "秒数", "播放器",
            "播放器 Bundle ID", "设备", "设备 UID", "传输类型", "恢复记录"
        ].joined(separator: ",")

        let rows = sessions
            .sorted { $0.startedAt < $1.startedAt }
            .map { session in
                [
                    session.id.uuidString,
                    formatter.string(from: session.startedAt),
                    formatter.string(from: session.endedAt),
                    String(format: "%.1f", session.duration),
                    session.players.map(\.displayName).joined(separator: " / "),
                    session.players.map(\.bundleID).joined(separator: " / "),
                    session.deviceName,
                    session.deviceUID,
                    session.transport.displayName,
                    session.wasRecovered ? "是" : "否"
                ].map(escape).joined(separator: ",")
            }
        _ = locale
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"")
            || field.contains("\n") || field.contains("\r") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
