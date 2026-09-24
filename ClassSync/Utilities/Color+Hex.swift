import SwiftUI

extension Color {
    init?(hex: String?) {
        guard let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum CourseColorPalette {
    static let choices: [(name: String, hex: String)] = [
        ("Purple", "7C3AED"),
        ("Blue", "2563EB"),
        ("Green", "059669"),
        ("Orange", "EA580C"),
        ("Pink", "DB2777"),
        ("Teal", "0F766E")
    ]

    static func defaultHex(for identifier: String) -> String {
        let checksum = identifier.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7fffffff }
        return choices[checksum % choices.count].hex
    }
}

