/// How every field that takes a typed amount reads it: the ASCII digits of the text, at most `maximumDigits` of them,
/// and blank with none. A currency symbol, separators and letters are dropped, so no K or M is read: "40K" is 40, which
/// the field shows at once, since its text is the amount kept, written by `grouped`.
public enum TypedNumber {
    /// The most digits a field keeps: a rule about the text field, so that what is typed always fits a whole number.
    /// Digits beyond it are dropped.
    public static let maximumDigits = 12

    /// The digits kept from the text: its ASCII digits, the first `maximumDigits` of them; empty with none.
    public static func digits(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber }.prefix(maximumDigits))
    }

    /// What an amount's field shows: the digits kept from the text with a comma between each group of three, counted
    /// from the right, "2901084" as "2,901,084"; empty with none. Read back by `digits`, it is the same digits.
    public static func grouped(_ text: String) -> String {
        let kept = Array(digits(text))
        var out = ""
        for (index, digit) in kept.enumerated() {
            if index > 0, (kept.count - index) % 3 == 0 { out.append(",") }
            out.append(digit)
        }
        return out
    }

    /// The same for an amount kept as a whole number, never below 0: 40000 as "40,000".
    public static func grouped(_ amount: Int) -> String { grouped(String(amount)) }

    /// The number typed: its digits as a whole number, or nil with none.
    public static func value(_ text: String) -> Int? {
        let kept = digits(text)
        return kept.isEmpty ? nil : Int(kept)
    }
}
