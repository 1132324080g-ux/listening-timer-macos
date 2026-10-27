import Foundation
import Testing
@testable import ListeningCore

@Suite struct CSVTests {
    @Test func csvQuotesCommasAndQuotes() {
        let session = ListeningSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_060),
            duration: 60,
            players: [
                PlayerIdentity(
                    bundleID: "com.example.Player",
                    displayName: "My, \"Music\""
                )
            ],
            deviceUID: "usb,device",
            deviceName: "DAC, Pro",
            transport: .usb
        )
        let csv = CSVExporter.makeCSV(sessions: [session])
        #expect(csv.contains("\"My, \"\"Music\"\"\""))
        #expect(csv.contains("\"DAC, Pro\""))
        #expect(csv.contains("\"usb,device\""))
        #expect(csv.hasSuffix("\r\n"))
    }
}
