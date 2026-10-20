import SwiftUI

extension CompatTier {
    /// Functional colors, always shown with a label (never color alone).
    var color: Color {
        switch self {
        case .excellent: Theme.Palette.success
        case .good: Theme.Palette.tierGood
        case .playable: Theme.Palette.warning
        case .poor: Theme.Palette.tierPoor
        case .broken: Theme.Palette.destructive
        case .unknown: Theme.Palette.textTertiary
        }
    }

    var symbol: String {
        switch self {
        case .excellent: "checkmark.seal.fill"
        case .good: "checkmark.circle.fill"
        case .playable: "exclamationmark.circle.fill"
        case .poor: "exclamationmark.triangle.fill"
        case .broken: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}
