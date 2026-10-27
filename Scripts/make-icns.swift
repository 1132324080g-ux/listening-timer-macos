import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make-icns.swift <iconset> <output.icns>\n", stderr)
    exit(64)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let destination = URL(fileURLWithPath: CommandLine.arguments[2])

let entries: [(type: String, file: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianBytes(_ value: UInt32) -> [UInt8] {
    [
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ]
}

var output = Data("icns".utf8)
output.append(contentsOf: [0, 0, 0, 0])

for entry in entries {
    let data = try Data(contentsOf: source.appendingPathComponent(entry.file))
    let chunkLength = UInt32(data.count + 8)
    output.append(contentsOf: entry.type.data(using: .ascii) ?? Data())
    output.append(contentsOf: bigEndianBytes(chunkLength))
    output.append(data)
}

let totalLength = UInt32(output.count)
output.replaceSubrange(
    4..<8,
    with: bigEndianBytes(totalLength)
)
try output.write(to: destination, options: .atomic)
