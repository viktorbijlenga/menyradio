import AppKit

/// Bound native menu labels by rendered width, rather than character count.
@MainActor func menuText(_ text: String, width: CGFloat, font: NSFont = .menuFont(ofSize: 0)) -> String {
    func fits(_ value: String) -> Bool {
        (value as NSString).size(withAttributes: [.font: font]).width <= width
    }
    if fits(text) { return text }
    guard fits("…") else { return "" }
    let characters = Array(text)
    var low = 0
    var high = characters.count
    while low < high {
        let middle = (low + high + 1) / 2
        if fits(String(characters.prefix(middle)) + "…") { low = middle }
        else { high = middle - 1 }
    }
    return String(characters.prefix(low)) + "…"
}
