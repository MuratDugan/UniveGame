import AppKit
import SwiftUI

/// Capsule filter: library sources and Discover categories.
struct FilterChip: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected || hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                if let count {
                    Text("\(count)")
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(isSelected ? Theme.Palette.elevated : (hovering ? Theme.Palette.card : .clear), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .animation(Theme.Motion.quick, value: isSelected)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Capsule search field. In the library it shows a ⌘K badge and ⌘K focuses it.
struct SearchPill: View {
    @Binding var text: String
    let prompt: String
    var width: CGFloat = 260
    var height: CGFloat = 30
    var showsShortcut = true
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.Palette.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textPrimary)
                .focused($focused)
                .accessibilityLabel(prompt)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.Palette.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "Clear"))
            } else if showsShortcut {
                Text(verbatim: "⌘K")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: width, height: height)
        .background(Theme.Palette.card, in: Capsule())
        .overlay(Capsule().strokeBorder(focused ? Theme.Palette.accent.opacity(0.6) : Theme.Palette.border))
        .animation(Theme.Motion.quick, value: focused)
        .onAppear {
            // macOS gives the first text field focus when a page opens; a search field shouldn't take it.
            DispatchQueue.main.async { if focused { focused = false } ; NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .background {
            if showsShortcut {
                Button("") { focused = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
    }
}
