/// A colour written as a 24-bit hex value, 0xRRGGBB, in sRGB.
public struct HexColour: Hashable, Sendable {
    public let value: UInt32

    public init(_ value: UInt32) {
        self.value = value & 0xFFFFFF
    }

    public var red: UInt32 { (value >> 16) & 0xFF }
    public var green: UInt32 { (value >> 8) & 0xFF }
    public var blue: UInt32 { value & 0xFF }

    public var redFraction: Double { Double(red) / 255 }
    public var greenFraction: Double { Double(green) / 255 }
    public var blueFraction: Double { Double(blue) / 255 }

    /// The colour with each channel scaled down by `fraction` (0.06 is 6% darker), rounded to
    /// the nearest whole step.
    public func darkened(by fraction: Double) -> HexColour {
        func scaled(_ channel: UInt32) -> UInt32 {
            UInt32((Double(channel) * (1 - fraction)).rounded())
        }
        return HexColour(scaled(red) << 16 | scaled(green) << 8 | scaled(blue))
    }
}
