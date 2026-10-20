import SwiftUI

/// Flat segmented control whose selected background slides between segments.
struct SegmentedPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var segmentHeight: CGFloat = 26
    var fontSize: CGFloat = 12
    var fillsWidth = false
    var accessibilityTitle: String = ""
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    withAnimation(reduceMotion ? nil : Theme.Motion.quick) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: fontSize, weight: on ? .semibold : .medium))
                        .foregroundStyle(on ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: fillsWidth ? .infinity : nil)
                        .frame(height: segmentHeight)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Palette.segmentSelected)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
    }
}
