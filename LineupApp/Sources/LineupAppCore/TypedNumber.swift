/// How every field that takes a typed amount reads it: the ASCII digits of the text, at most `maximumDigits` of them,
/// and blank with none. A currency symbol, separators and letters are dropped, so no K or M is read: "40K" is 40, which
/// the reading beside the field shows at once.
public enum TypedNumber {
    /// The most digits a field keeps: a rule about the text field, so that what is typed always fits a whole number.
    /// Digits beyond it are dropped.
    public static let maximumDigits = 12

    /// The digits kept from the text: its ASCII digits, the first `maximumDigits` of them; empty with none.
    public static func digits(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber }.prefix(maximumDigits))
    }

    /// The number typed: its digits as a whole number, or nil with none.
    public static func value(_ text: String) -> Int? {
        let kept = digits(text)
        return kept.isEmpty ? nil : Int(kept)
    }
}
