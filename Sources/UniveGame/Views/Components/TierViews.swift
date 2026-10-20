import SwiftUI

/// Thin 3 pt meter under a shelf cover.
struct TierMeter: View {
    let score: Int
    let tier: CompatTier
    var delay: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.elevated)
                Capsule().fill(tier.color)
                    .frame(width: geo.size.width * CGFloat(tier == .unknown ? 0 : score) / 100)
                    .growOnAppear(delay: delay)
            }
            .clipShape(Capsule())
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// The stage's 6 pt meter, notched at the tier thresholds.
struct StageMeter: View {
    let score: Int
    let tier: CompatTier
    var delay: Double = 0.24

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.elevated)
                Capsule().fill(tier.color)
                    .frame(width: geo.size.width * CGFloat(tier == .unknown ? 0 : score) / 100)
                    .animation(Theme.Motion.valueChange, value: score)
                    .growOnAppear(delay: delay)
                ForEach([25, 45, 65, 80], id: \.self) { mark in
                    Rectangle().fill(Theme.Palette.background)
                        .frame(width: 1, height: 10)
                        .offset(x: geo.size.width * CGFloat(mark) / 100)
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Five proportional bands (25:20:20:15:20) with a pin at the score, on the game page.
struct TierScale: View {
    let score: Int
    let tier: CompatTier
    @Environment(Localizer.self) private var L

    static let bands: [(CompatTier, ClosedRange<Int>)] = [
        (.broken, 0...25), (.poor, 25...45), (.playable, 45...65), (.good, 65...80), (.excellent, 80...100),
    ]
    private let gap: CGFloat = 3

    var body: some View {
        let bands = Self.bands
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let usable = geo.size.width - gap * CGFloat(bands.count - 1)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: gap) {
                        ForEach(bands, id: \.0) { _, range in
                            let w = usable * CGFloat(range.upperBound - range.lowerBound) / 100
                            let filled = min(max(Double(score - range.lowerBound) / Double(range.upperBound - range.lowerBound), 0), 1)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Theme.Palette.elevated)
                                Rectangle().fill(tier.color).frame(width: w * filled)
                            }
                            .frame(width: w, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .growOnAppear(delay: 0.3)
                    RoundedRectangle(cornerRadius: 2).fill(Theme.Palette.textPrimary)
                        .frame(width: 3, height: 16)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.Palette.card).padding(-2))
                        .offset(x: pinX(usable: usable) - 1.5, y: -4)
                        .enterOnAppear(delay: 0.9)
                }
            }
            .frame(height: 8)
            GeometryReader { geo in
                let usable = geo.size.width - gap * CGFloat(bands.count - 1)
                HStack(spacing: gap) {
                    ForEach(bands, id: \.0) { band, range in
                        Text(L("compat.tier.\(band.rawValue)"))
                            .font(.system(size: 11, weight: band == tier ? .semibold : .regular))
                            .foregroundStyle(band == tier ? tier.color : Theme.Palette.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(width: usable * CGFloat(range.upperBound - range.lowerBound) / 100, alignment: .leading)
                    }
                }
            }
            .frame(height: 14)
        }
        .animation(Theme.Motion.valueChange, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L("compat.title")) \(score), \(L("compat.tier.\(tier.rawValue)"))")
    }

    private func pinX(usable: CGFloat) -> CGFloat {
        var x: CGFloat = 0
        for (i, (_, r)) in Self.bands.enumerated() {
            let w = usable * CGFloat(r.upperBound - r.lowerBound) / 100
            if score <= r.upperBound || i == Self.bands.count - 1 {
                return x + w * CGFloat(max(score - r.lowerBound, 0)) / CGFloat(r.upperBound - r.lowerBound)
            }
            x += w + gap
        }
        return x
    }
}

/// A filled circle with a dark glyph, like the reference's tier and factor marks.
struct TierGlyph: View {
    let tier: CompatTier
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: tier.symbol)
            .font(.system(size: size))
            .foregroundStyle(tier.color)
            .accessibilityHidden(true)
    }
}
