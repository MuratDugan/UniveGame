# 02 — Bileşenler

Konum önerisi: `Sources/UniveGame/Views/Components/` (yeni klasör). Her bileşen kendi dosyasında. Ölçüler pt. Renkler `Theme.Palette`, boşluklar `Theme.Spacing`, köşeler `Theme.Radius`, hareket `Theme.Motion` (bkz. 01).

## SF Symbols karşılıkları (reference'taki Lucide simgeleri)

| Lucide (reference) | SF Symbol |
|---|---|
| library (rail Kütüphane) | `books.vertical` |
| compass (rail Keşfet) | `safari` |
| link (rail Mağazalar, mağaza yolu) | `link` |
| plus (rail Ekle) | `plus` |
| settings (rail alt) | `gearshape` |
| search | `magnifyingglass` |
| chevron-left (geri) | `chevron.left` |
| heart / dolu | `heart` / `heart.fill` (renk `favorite`) |
| more-horizontal | `ellipsis` |
| rotate-cw (Yeniden İncele) | `arrow.clockwise` |
| play | `play.fill` |
| download | `arrow.down.to.line` |
| file-check (kurulu oyun yolu) | `doc.badge.checkmark` |
| package (kurulum dosyası) | `shippingbox` |
| check | `checkmark` |
| kademe: Mükemmel / İyi | `checkmark.seal.fill` / `checkmark.circle.fill` (mevcut `CompatTier.symbol`) |
| kademe: Oynanabilir / Zayıf / Çalışmaz | `exclamationmark.circle.fill` / `exclamationmark.triangle.fill` / `xmark.octagon.fill` |
| faktör: + / − / engel / bilgi | `plus.circle.fill` / `minus.circle.fill` / `xmark.octagon.fill` / `info.circle.fill` (mevcut `factorRow` ile aynı) |
| cpu (Motor) | `cpu` |
| globe (Genel) | `globe` |
| DirectX 12 bölümü | `square.stack.3d.up` |
| info (Hakkında) | `info.circle` |
| image (Kapak Ekle) | `photo` |
| mağaza glifleri | mevcut `GameSource.symbol` (mağaza logosu yok) |

---

## Rail (yeni) — `RailView.swift`

Reference: `V2Rail.dc.html`. `SidebarView`'in yerini alır.

- Genişlik `Layout.railWidth` (80), tam yükseklik, zemin `background`, sağda 1 pt `border`.
- Üstte 52 pt boşluk (pencere trafik ışıkları buraya düşer; `.windowToolbarStyle(.unifiedCompact)` + `ignoresSafeArea` ile hizala, trafik ışıkları sistemden gelir, çizme).
- Üst grup (üstten 16 pt, aralarında 6 pt): 4 öğe — Kütüphane, Keşfet, Mağazalar, Ekle.
  - Öğe: 64 × 56, köşe `md`, dikey yığın: simge 20 pt (weight `.regular`) + 4 pt + etiket `micro` (11/500).
  - Normal: zemin yok, yazı `textSecondary`. Hover: zemin `card`, yazı `textPrimary` (`quick`).
  - Seçili: zemin `card`, simge `accent`, etiket `textPrimary` 600, `.accessibilityAddTraits(.isSelected)`.
- Alt grup: Ayarlar düğmesi 44 × 44 (simge-only, `.help` + `accessibilityLabel("Ayarlar")`, seçiliyken simge `accent`), altında motor durumu: 8 pt nokta (`success`, `.pulsing()`) + "Motor" 10 pt `textSecondary`; tooltip `L("engine.ready")`. Motor hazır değilse nokta `warning` ve pulse yok.
- Seçim → `model.selection`. Eşleme: Kütüphane `.library(.all)` (kaynak filtresi çiplerden gelir), Keşfet `.discover`, Mağazalar `.stores`, Ekle `.addGame` (**yeni case**), Ayarlar `.settings`.

```swift
struct RailItem: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : (hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary))
                Text(title).font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected || hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(width: 64, height: 56)
            .background(isSelected || hovering ? Theme.Palette.card : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

## PageHeader (yeni)

Büyük sayfa başlığı: Oyun Ekle, Mağazalar, Keşfet, Ayarlar, boş kütüphane.
- `display` (30/700) başlık + 6 pt + `body` `textSecondary` açıklama (en çok 640 genişlik).
- Üst boşluk `Layout.pageTitleTop` (52), yatay `Layout.pageInsetX` (48).
- Giriş: `.enterOnAppear()`.
- İsteğe bağlı sağ yuva (`trailing`): arama hapı veya bağlantı ölçeği, başlığın alt çizgisine hizalı (`alignment: .bottom`).

## FilterChip (yeni)

Kütüphane üst çubuğu (kaynaklar) ve Keşfet (kategoriler).
- Yükseklik 28, yatay iç boşluk 12, `Capsule`, aralarında 6 pt.
- Etiket 13 pt; seçili 600 + zemin `elevated` + yazı `textPrimary`; değilse 500 + zemin yok + `textSecondary`; hover zemin `card`.
- Kütüphanede etiketin sağında 6 pt boşluk + sayaç `micro` `textSecondary` `.monospacedDigit()`.
- Kütüphane çipleri: Tümü, sonra `GameSource` değerlerinden sadece oyunu olanlar (Steam, Epic Games, GOG, Kendi Oyunlarım…). Seçim `LibraryFilter.all` / `.source(…)`.

## SearchPill (yeni)

- 260 × 30 (Keşfet'te 32), `Capsule`, zemin `card`, 1 pt `border`.
- Sol 10 pt: `magnifyingglass` 14 pt `textSecondary`; `TextField` (plain) 13 pt, yer tutucu `textTertiary`.
- Kütüphanede sağda `⌘K` rozeti: 20 yükseklik, iç boşluk 6, köşe `sm`, zemin `elevated`, 11 pt `textSecondary`. ⌘K kısayolu alana odaklanır (`.keyboardShortcut("k")` + `@FocusState`).
- Kütüphane yer tutucu: `L("library.search.v2")` = "Oyun, kaynak ya da durum ara".

## TierMeter (yeni) — kapak altı ince ölçü

- Yükseklik 3, `Capsule`, iz `elevated`, dolgu `tier.color` genişliği `score/100`.
- Giriş: dolgu `.growOnAppear(delay: kapağın giriş gecikmesi)`.
- Erişilebilirlik: kendisi gizli (`accessibilityHidden(true)`); puan altındaki metinde okunur.

```swift
struct TierMeter: View {
    let score: Int
    let tier: CompatTier
    var delay: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.elevated)
                Capsule().fill(tier.color)
                    .frame(width: geo.size.width * CGFloat(score) / 100)
                    .growOnAppear(delay: delay)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
```

## TierScale (yeni) — oyun sayfasında kademe ölçeği

Reference: `V2GamePage.dc.html`, "Uyumluluk" bölümü.

- 5 parça yan yana, aralarında 3 pt, yükseklik 8, köşe 3. Parça genişlikleri `CompatTier` aralıklarıyla orantılı (25 : 20 : 20 : 15 : 20; bkz. 01 §5).
- Her parçanın izi `elevated`; dolgu = puanın o parçayı kapladığı oran × genişlik, renk **mevcut kademenin rengi** (tüm dolu parçalar aynı renk).
- İşaret (pin): puan konumunda 3 × 16 dikey çubuk, köşe 2, renk `textPrimary`, çevresinde 2 pt `card` halka (parçaların üstünden taşar, −4 pt yukarıdan başlar).
- Altında etiketler (6 pt aralık): her parçanın altında, parça genişliğinde, `micro`; mevcut kademe `tier.color` 600, diğerleri `textSecondary` 400.
- Animasyon: tüm parça satırı `.growOnAppear(delay: 0.3)`; pin `.enterOnAppear(delay: 0.9)`. Puan değişirse dolgular `valueChange` ile.
- Erişilebilirlik: tek öğe, etiket "Uyumluluk 92, Mükemmel".

```swift
struct TierScale: View {
    let score: Int
    let tier: CompatTier
    @Environment(Localizer.self) private var L

    private let bands: [(CompatTier, ClosedRange<Int>)] = [
        (.broken, 0...25), (.poor, 25...45), (.playable, 45...65), (.good, 65...80), (.excellent, 80...100)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let gap: CGFloat = 3
                let usable = geo.size.width - gap * CGFloat(bands.count - 1)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: gap) {
                        ForEach(bands, id: \.0) { band, range in
                            let w = usable * CGFloat(range.upperBound - range.lowerBound) / 100
                            let filled = min(max(Double(score - range.lowerBound) / Double(range.upperBound - range.lowerBound), 0), 1)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Theme.Palette.elevated)
                                RoundedRectangle(cornerRadius: 3).fill(tier.color).frame(width: w * filled)
                            }
                            .frame(width: w, height: 8)
                        }
                    }
                    .growOnAppear(delay: 0.3)
                    RoundedRectangle(cornerRadius: 2).fill(Theme.Palette.textPrimary)
                        .frame(width: 3, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.Palette.card, lineWidth: 2))
                        .offset(x: pinX(usable: usable, gap: gap) - 1.5, y: -4)
                        .enterOnAppear(delay: 0.9)
                }
            }
            .frame(height: 8)
            HStack(spacing: 3) { /* her band için Text(L("compat.tier.\(band.rawValue)")) aynı genişlikte, .font(.system(size: 11)) */ }
        }
        .animation(Theme.Motion.valueChange, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L("compat.title")) \(score), \(L("compat.tier.\(tier.rawValue)"))")
    }

    private func pinX(usable: CGFloat, gap: CGFloat) -> CGFloat {
        var x: CGFloat = 0
        for (i, (_, r)) in bands.enumerated() {
            let w = usable * CGFloat(r.upperBound - r.lowerBound) / 100
            if score <= r.upperBound || i == bands.count - 1 {
                return x + w * CGFloat(score - r.lowerBound) / CGFloat(r.upperBound - r.lowerBound)
            }
            x += w + gap
        }
        return x
    }
}
```

## ShelfCover (yeni) — raf kapağı

Reference: `V2Library.dc.html`, `sc-for list="{{sh.games}}"`.

- Bir `Button` (tıklayınca Sahne'yi bu oyuna çevirir; çift tık oyun sayfasını açar). Genişlik 132, dikey yığın 8 pt aralık:
  1. Kapak 132 × 198, köşe `md`, `CoverArt(item)`, `.coverHover()`, seçiliyse `.selectionRing(true)`. Kapağın üstünde **yazı yok**.
  2. `TierMeter` (genişlik 132).
  3. Ad `cardTitle` tek satır kırpma; altında `caption` `textSecondary` "92 · Mükemmel" `.monospacedDigit()`. Analiz yoksa "Henüz incelenmedi".
- Giriş: `.enter(index: rafTakiIndex, base: 0.2, step: 0.05)`; ölçü çizgisi aynı gecikmeyle dolar.
- Bağlam menüsü: mevcut `GameActionsMenu`.
- Erişilebilirlik: tek öğe, etiket "Hades, 92, Mükemmel, yüklü"; seçiliyse `.isSelected`.

## Stage (yeni) — Kütüphane sahnesi

Bkz. [screens/01-library.md](screens/01-library.md); kendi dosyası `LibraryStage.swift`.

## NoticeBanner (yeni)

Oyun sayfasında oyunu durduran tek sorun.
- Tam genişlik, iç boşluk 14 × 16, köşe `lg`, zemin `card`, kenar `Palette.edge(renk)` (warning ya da destructive, %35).
- Sol: 20 pt dolu simge (`xmark.octagon.fill` destructive / `exclamationmark.triangle.fill` warning). 12 pt boşluk.
- Orta: başlık 13/600 + 2 pt + açıklama `caption` `textSecondary` (satır aralığı 1.45).
- Sağ (biri): `PrimaryButtonStyle` küçük düğme (yükseklik 32, iç boşluk 20) **ya da** bağlantı `caption` 500 `accent`.
- Giriş: `.enterOnAppear(delay: 0.06)`. `role`: `.accessibilityElement(children: .contain)`, başlık `isHeader` değil.

## SegmentedPicker (yeni) — grafik ve dil seçimi

- İz: zemin `elevated`, iç boşluk 2, köşe `md`.
- Parça: yükseklik 26 (dilde 28), iç boşluk 12, köşe `sm`, 12 pt (dilde 13). Seçili: zemin `segmentSelected`, `textPrimary` 600. Değil: zemin yok, `textSecondary` 500. Geçiş `quick`.
- Seçili zemin `matchedGeometryEffect` ile kayar (`quick`), azaltılmış harekette anlık.
- Erişilebilirlik: `.accessibilityElement(children: .contain)` + her parça `.isSelected`; ya da doğrudan `Picker(...).pickerStyle(.segmented)` görünümü özelleştirilebiliyorsa onu kullan.
- Grafik seçeneklerinin kaynağı `GraphicsBackend.allCases`; etiketler `.auto → L("launch.backend.auto")`, diğerleri `displayName`.

## ToggleTile (yeni) — başlatma ayarları

Reference: `V2GamePage.dc.html`, "Başlatma ayarları" ızgarası. 2 sütun, 8 pt aralık.
- Bütün karo tıklanabilir (`Button` + `role switch` davranışı; `Toggle` ile `.toggleStyle(TileToggleStyle())` en temiz yol).
- İç boşluk 10 × 12, köşe `md`, zemin `surface` (hover `cardHover`), kenar: açık `accent.opacity(0.45)`, kapalı `border`.
- Sol: başlık 13 + 2 pt + açıklama `caption` `textSecondary`. Sağ: anahtar 34 × 20 kapsül, açık `accent` + düğme sağda `textPrimary`, kapalı `elevated` + düğme solda `textSecondary`; düğme 16 pt. Geçiş `quick` (düğme `spring(response: 0.25, dampingFraction: 0.85)` olabilir).
- Dört karo: Retina, MetalFX, Performans göstergesi, Command → Control. `verboseLogs` v2'de görünmüyor: "Diğer eylemler" (`ellipsis`) menüsüne taşı.

## FactList (yeni) — oyun sayfası sol sütun

- `dl` benzeri satırlar, aralarında 10 pt; her satır alt çizgisi 1 pt `border`, satır altı boşluk 10.
- Sol `caption` `textSecondary`, sağ 13/500 `.monospacedDigit()`.
- Yüklü oyun: Durum ("Yüklü · 15 GB"), Oynama süresi, Son oynama, Konum (kısaltılmış yol). Yüklü değil: Durum, Tahmini boyut (varsa), Kaynak.

## MethodTile (yeni) — Oyun Ekle yolları

- 3 sütun, 16 pt aralık. Karo: iç boşluk 16, köşe `lg`, 14 pt yatay aralık.
- Simge karosu 40 × 40 `elevated` köşe `md`, simge 20 pt (seçili `accent`, değil `textSecondary`).
- Başlık 13/600 + açıklama `caption` `textSecondary`.
- Seçili: zemin `card`, kenar 1 pt `accent`. Değil: zemin `surface`, kenar `border`, hover `cardHover`.
- Giriş: `.enter(index: i, base: 0.06)`.

## StepRail (yeni) — kurulum adımları

Reference: `V2Installer.dc.html` `<aside>`.
- 3 adım, dikey, adımlar arası 36 pt. Adım: 28 pt daire + 14 pt + (başlık 13/600, alt yazı `caption` `textSecondary`), metin üstten 4 pt.
- Daire: bitti → dolu `success`, içinde `checkmark` 14 pt `onCTA`; şimdi → 2 pt `accent` halka, numara `accent` 12/700; sırada → 2 pt `borderStrong` halka, numara `textSecondary`.
- Bağlantı çizgisi: dairelerin merkezinden (x = 13), 2 pt; iz `elevated`, dolu kısım `accent`, yüksekliği `adım / 2 × toplam` → `valueChange` ile uzar. Daire renk geçişi easeOut 0.3.
- Alt kısımda dosya kartı: 36 pt `shippingbox` karosu + dosya adı `mono` + "412 MB · İndirilenler" `caption`.
- `accessibilityElement(children: .contain)`, şimdiki adım `.isSelected` ve "Adım 2 / 3" etiketi.

## ProgramChoiceRow (değişiyor)

`InstallerSheet` içindeki mevcut satırın v2 hâli: radyo noktası 16 pt (seçili: 5 pt `accent` kenar; değil: 2 pt `white.opacity(0.3)`), ad 13/600, "Önerilen" çipi (20 yükseklik, `successTint` zemin, `success` 11/600), yol `mono` `textSecondary`, sağda boyut. Satır `hoverFill(surface → cardHover)`, kenar seçili `accent`. Giriş `.enter(index:i, base: 0.08)`.

## StoreRow + ConnectionMeter (yeni)

Bkz. [screens/06-stores.md](screens/06-stores.md).

## BentoTile (yeni)

Bkz. [screens/07-discover.md](screens/07-discover.md).

## SectionNav + TimelineStep (yeni)

Bkz. [screens/08-settings.md](screens/08-settings.md).

## GhostCover + DropHint (yeni) — boş kütüphane

- GhostCover: kesik çizgili (1 pt `borderStrong`, `StrokeStyle(dash: [4, 3])`) köşe `md` dikdörtgen, zemin `surface`; ortadaki büyük olanda `plus` 28 pt `textTertiary`. Boyutlar 120×180, 140×210 (−16 pt yukarıda), 120×180; dönüş −6°, 0°, +6°; 20 pt aralık. Her biri `.bobbing(delay: 0 / 0.65 / 1.3)` — döndürme dış katmanda, salınım iç katmanda.
- DropHint: iç boşluk 14 × 20, köşe `lg`, kesik çizgili kenar; kenar rengi `edgePulse` ile `borderStrong ↔ accent.opacity(0.6)`. İçerik: `arrow.down.to.line` 18 pt + metin. Pencereye `.onDrop(of: [.fileURL])` bağlanır; sürükleme sırasında kenar sabit `accent`.
