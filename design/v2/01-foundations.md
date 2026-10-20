# 01 — Foundations: token'lar ve hareket

v2 yeni renk ya da yazı ölçüsü getirmiyor; mevcut `Theme` aynen kalıyor. Eklenenler: birkaç adlandırılmış ara renk (şu an view'larda inline duranlar), düzen sabitleri ve **hareket sistemi**.

## 1. `Theme.swift`'e eklenecekler

```swift
// Theme.Palette içine
static let segmentSelected = Color(hex: 0x3A3A40)   // bölmeli seçicide seçili parça
static let elevatedHover = Color(hex: 0x2A2A30)     // ikincil düğme hover (SecondaryButtonStyle zaten bunu inline kullanıyor; ona bağla)
static let tierGood = Color(hex: 0x86D96B)          // CompatTier.good (CompatibilityViews.swift'teki inline değeri buna bağla)
static let tierPoor = Color(hex: 0xFF8A3D)          // CompatTier.poor
static let successTint = Color(hex: 0x30D158, opacity: 0.14)   // "Önerilen", indirim çipi zemini (yazı: success)
static func edge(_ c: Color) -> Color { c.opacity(0.35) }      // uyarı kutusu kenarı (warning/destructive)

// Yeni
enum Layout {
    static let railWidth: CGFloat = 80
    static let toolbarHeight: CGFloat = 52
    static let pageInsetX: CGFloat = 48      // Oyun Ekle, Mağazalar, Keşfet, Ayarlar içerik kenar boşluğu
    static let libraryInsetX: CGFloat = 32   // Kütüphane ve oyun sayfası
    static let pageTitleTop: CGFloat = 52    // büyük sayfa başlığının üstü (toolbar yüksekliği kadar)
}
```

Yazı: v2 ek olarak iki ara boy kullanıyor. İkisini de `Theme.Font`'a ekle:

```swift
static let stat = SwiftUI.Font.system(size: 17, weight: .semibold)       // Keşfet'teki büyük karonun oyun adı
static let statSmall = SwiftUI.Font.system(size: 15, weight: .semibold)  // mağaza adı, fiyat, oyun sayfasında kademe etiketi
static let scoreHero = SwiftUI.Font.system(size: 44, weight: .bold)      // oyun sayfasındaki büyük puan
static let scoreStage = SwiftUI.Font.system(size: 24, weight: .bold)     // Sahne'deki puan
static let micro = SwiftUI.Font.system(size: 11, weight: .medium)        // rail etiketi, sayaç, kademe ölçeği etiketi
```

## 2. Hareket token'ları

| Token | Değer | Kullanım | Reference karşılığı |
|---|---|---|---|
| `quick` | easeOut 0.15 s | hover, basma, renk değişimi | `transition: … .15s ease-out` |
| `enter` | timingCurve(0.2, 0.7, 0.2, 1) 0.55 s | ekrana giriş (opaklık 0→1, y +10→0) | `.ug-in` / `@keyframes ugUp` |
| `stagger` | 0.06 s (kütüphane kapakları 0.05 s) | sıradaki öğenin gecikmesi | `animation-delay` |
| `fill` | timingCurve(0.2, 0.7, 0.2, 1) 1.0 s | ölçek, çizgi, ilerleme dolumu (scaleX 0→1, sol çapa) | `.ug-grow` / `ugGrow` |
| `valueChange` | timingCurve(0.2, 0.7, 0.2, 1) 0.6 s | değer değişince genişlik/yükseklik (Sahne ölçeği, adım çizgisi) | `.ug-fill`, step line `transition: height .6s` |
| `crossfade` | easeOut 0.4 s | Sahne görselinin renk/görsel değişimi | `.ug-swap` |
| `zoom` | timingCurve(0.2, 0.7, 0.2, 1) 0.5 s | Keşfet karosunda görselin 1.04 yakınlaşması | `.ug-zoom` |
| `pop` | timingCurve(0.2, 0.7, 0.2, 1) 0.5 s | kapak önerisi belirmesi (ölçek 0.94→1 + opaklık) | `.ug-pop` |
| `pulse` | easeInOut 0.8 s, sonsuz, geri dönüşlü (1.6 s döngü) | canlı durum noktası (opaklık 1↔0.4) | `.ug-pulse` |
| `indeterminate` | easeInOut 1.4 s, sonsuz, geri dönüşsüz | belirsiz ilerleme (%34 genişlikte parça soldan sağa) | `.ug-slide` |
| `bob` | easeInOut 2.0 s, sonsuz, geri dönüşlü (4 s döngü) | boş kütüphanedeki hayalet kapaklar (y 0↔−8) | `.ug-bob` |
| `edgePulse` | easeInOut 1.2 s, sonsuz, geri dönüşlü | sürükle-bırak kutusunun kenarı (borderStrong ↔ accent %60) | `.ug-edge` |

Genlik sınırları: en çok 10 pt kayma, 1.02 ölçek (hover), 1.04 (görsel yakınlaşma). Hiçbir şey dönmez, sekmez, ekran dışından gelmez.

## 3. `Sources/UniveGame/Theme/Motion.swift` (olduğu gibi ekle)

```swift
import SwiftUI

extension Theme.Motion {
    private static func curve(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.7, 0.2, 1, duration: duration)
    }
    static let enter = curve(0.55)
    static let fill = curve(1.0)
    static let valueChange = curve(0.6)
    static let zoom = curve(0.5)
    static let pop = curve(0.5)
    static let crossfade = Animation.easeOut(duration: 0.4)
    static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    static let indeterminate = Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: false)
    static let bob = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let edgePulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    static let stagger: Double = 0.06
}

// MARK: Enter: fade + rise once on appear (.ug-in)

struct EnterOnAppear: ViewModifier {
    var delay: Double = 0
    var distance: CGFloat = 10
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : distance)
            .onAppear {
                guard !reduceMotion, !shown else { return }
                withAnimation(Theme.Motion.enter.delay(delay)) { shown = true }
            }
    }
}

// MARK: Grow: scaleX 0 → 1 from the leading edge (.ug-grow)

struct GrowOnAppear: ViewModifier {
    var delay: Double = 0
    var animation: Animation = Theme.Motion.fill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: grown || reduceMotion ? 1 : 0, y: 1, anchor: .leading)
            .onAppear {
                guard !reduceMotion, !grown else { return }
                withAnimation(animation.delay(delay)) { grown = true }
            }
    }
}

// MARK: Pop: scale 0.94 → 1 + fade (.ug-pop)

struct PopOnAppear: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .onAppear {
                guard !reduceMotion, !shown else { return }
                withAnimation(Theme.Motion.pop.delay(delay)) { shown = true }
            }
    }
}

// MARK: Loops

struct Pulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(dim ? 0.4 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.pulse) { dim = true }
            }
    }
}

struct Bob: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -8 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.bob.delay(delay)) { up = true }
            }
    }
}

extension View {
    func enterOnAppear(delay: Double = 0, distance: CGFloat = 10) -> some View { modifier(EnterOnAppear(delay: delay, distance: distance)) }
    /// Index-based stagger: `.enter(index: i)` = delay base + i × step.
    func enter(index: Int, base: Double = 0, step: Double = Theme.Motion.stagger) -> some View {
        modifier(EnterOnAppear(delay: base + Double(index) * step))
    }
    func growOnAppear(delay: Double = 0, animation: Animation = Theme.Motion.fill) -> some View { modifier(GrowOnAppear(delay: delay, animation: animation)) }
    func popOnAppear(delay: Double = 0) -> some View { modifier(PopOnAppear(delay: delay)) }
    func pulsing() -> some View { modifier(Pulse()) }
    func bobbing(delay: Double = 0) -> some View { modifier(Bob(delay: delay)) }
}

// MARK: Indeterminate bar (.ug-slide)

/// A 34%-wide accent segment sliding across an elevated track. Used where progress can't be known (an external installer, store sync).
struct IndeterminateBar: View {
    var height: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travelling = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.34
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.elevated)
                Capsule().fill(Theme.Palette.accent)
                    .frame(width: w)
                    .offset(x: reduceMotion ? (geo.size.width - w) / 2 : (travelling ? geo.size.width : -w))
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Theme.Motion.indeterminate) { travelling = true }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: Cover hover (.ug-cover / .ug-pick:hover)

/// Hover on a cover: lift 4 pt, scale 1.02, 1 pt hover ring, cover shadow. Reduced motion keeps the ring only.
struct CoverHoverEffect: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.md
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func body(content: Content) -> some View {
        let lift = hovering && !reduceMotion
        content
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(hovering ? Theme.Palette.hoverRing : Theme.Palette.border, lineWidth: 1))
            .shadow(color: .black.opacity(hovering ? 0.4 : 0), radius: 12, y: 6)   // shadow-cover-hover: 0 6 24 → radius = blur/2
            .scaleEffect(lift ? 1.02 : 1)
            .offset(y: lift ? -4 : 0)
            .animation(Theme.Motion.quick, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Accent selection ring drawn 2 pt outside the shape with a 2 pt gap (CSS: 0 0 0 2px bg, 0 0 0 4px accent).
struct SelectionRing: ViewModifier {
    var isOn: Bool
    var cornerRadius: CGFloat = Theme.Radius.md

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius + 4)
                .strokeBorder(Theme.Palette.accent, lineWidth: 2)
                .padding(-4)
                .opacity(isOn ? 1 : 0)
                .animation(Theme.Motion.quick, value: isOn)
        )
    }
}

extension View {
    func coverHover(cornerRadius: CGFloat = Theme.Radius.md) -> some View { modifier(CoverHoverEffect(cornerRadius: cornerRadius)) }
    func selectionRing(_ isOn: Bool, cornerRadius: CGFloat = Theme.Radius.md) -> some View { modifier(SelectionRing(isOn: isOn, cornerRadius: cornerRadius)) }
}

// MARK: Hover fill for rows/tiles (.ug-tile, .ug-rail, .ug-chip, .ug-opt)

struct HoverFill: ViewModifier {
    var normal: Color
    var hover: Color
    var cornerRadius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(hovering ? hover : normal, in: RoundedRectangle(cornerRadius: cornerRadius))
            .animation(Theme.Motion.quick, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverFill(_ normal: Color, hover: Color, cornerRadius: CGFloat) -> some View {
        modifier(HoverFill(normal: normal, hover: hover, cornerRadius: cornerRadius))
    }
}
```

## 4. CSS sınıfı → SwiftUI eşlemesi

Reference dosyalarındaki her `class="ug-…"` için:

| CSS | SwiftUI |
|---|---|
| `ug-in` + `animation-delay: Nms` | `.enterOnAppear(delay: N/1000)` ya da `.enter(index:base:)` |
| `ug-grow` | `.growOnAppear(delay:)` |
| `ug-pop` | `.popOnAppear(delay:)` |
| `ug-pulse` | `.pulsing()` |
| `ug-bob` + `animation-delay: -1.3s / -2.6s` | `.bobbing(delay: 0 / 0.65 / 1.3)` (SwiftUI negatif gecikme almaz; faz farkı yeterli) |
| `ug-slide` | `IndeterminateBar()` |
| `ug-edge` | `edgePulse` ile `strokeBorder` rengi `borderStrong ↔ accent.opacity(0.6)` (bkz. 02-components → DropHint) |
| `ug-cover` + `ug-pick:hover` | `.coverHover()` |
| `ug-tile` (Mağazalar) | `.hoverFill(card, hover: cardHover, cornerRadius: lg)` |
| `ug-tile` (Keşfet) | kenar `border → hoverRing` + içteki görsel `.scaleEffect(hover ? 1.04 : 1)` `zoom` ile, `clipped()` |
| `ug-rail`, `ug-chip`, `ug-nav` | `.hoverFill(.clear, hover: card, cornerRadius: md)` + yazı `textSecondary → textPrimary` |
| `ug-opt` | `.hoverFill(surface, hover: cardHover, cornerRadius: md)` |
| `ug-btn` | mevcut `SecondaryButtonStyle` |
| `ug-cta` | mevcut `PrimaryButtonStyle` (hover'da opaklık 0.88 ekle) |
| `ug-swap` | `.animation(Theme.Motion.crossfade, value: selectedID)` |
| `ug-fill` | `.animation(Theme.Motion.valueChange, value: score)` |
| `@media (prefers-reduced-motion)` | yukarıdaki modifier'lar kendi kontrol ediyor; elle yazılan `withAnimation` çağrılarında `reduceMotion ? nil : anim` kullan |

## 5. Kademe eşikleri — önemli

Tasarımda kademe ölçeği 5 eşit parça (20'şer puan) çizildi. **Uygulamada `CompatTier(score:)` eşikleri geçerli**: 0–25 Çalışmaz, 25–45 Zayıf, 45–65 Oynanabilir, 65–80 İyi, 80–100 Mükemmel. `TierScale` parçalarının genişliği bu aralıklarla orantılı olur (25 : 20 : 20 : 15 : 20). Örnek veri (Cyberpunk 72 = İyi, S2 Rebirth 38 = Zayıf, ELDEN RING 46 = Oynanabilir) bu eşiklerle de aynı kademeye düşüyor.
