# 07 — Keşfet

Reference: `reference/V2Discover.dc.html`. Swift: `DiscoverView.swift` (`ListingCard` → `BentoTile`; `SkeletonCard` korunur, bento şekline uyarlanır).

## Yerleşim

```
ScrollView, iç boşluk: üst 52, yatay 48, aralık 20
├─ PageHeader + sağ yuva SearchPill 260×32 ("Steam mağazasında ara")
│  açıklama: "Steam'de öne çıkanlar, Mac'te ne kadar iyi çalışacaklarıyla birlikte. Fiyatlar Steam mağazasından."
├─ FilterChip satırı: "Öne çıkanlar" (seçili) · "İndirimde" · "Mac'te mükemmel" · "Yeni çıkanlar"
└─ Bento ızgara: 4 sütun, satır yüksekliği 210, aralık 16
   ├─ 0: büyük karo 2×2
   ├─ 1–4: 1×1
   ├─ 5: geniş karo 2×1
   └─ 6–7: 1×1  (sonra desen tekrarlar: her 8 öğede bir büyük, bir geniş)
```

SwiftUI'da bento: `Grid` satır yüksekliği sabit değilse zor; önerilen yol özel `Layout` (`BentoLayout`) ya da 2 sütunluk `HStack` blokları. Desen sabit: [B(2×2) | 1 1 / 1 1], [W(2×1) | 1 1]. 980 genişlikte 2 sütuna düş: büyük karo 2×1, diğerleri 1×1.

### BentoTile

- `Link`/`Button` → Steam mağaza sayfası (mevcut davranış). Köşe lg, zemin card, 1pt border, `clipped()`.
- Üst: görsel (esnek yükseklik), `AsyncImage` capsule/header, `.scaledToFill()`.
- Alt şerit (iç boşluk 12×14; büyük karoda 16×20), HStack(spacing: 12):
  - ad (13/600; büyükte `stat` 17/600) tek satır + altında kademe simgesi 12pt `tier.color` + "90 · Mükemmel" caption textSecondary monoDigit (rapor yoksa satır gizli)
  - indirim çipi h22 Capsule `successTint` + `success` 12/600 monoDigit (indirim yoksa gizli)
  - fiyat sütunu: eski fiyat 11 textSecondary üstü çizili, yeni fiyat statSmall 15/600 monoDigit
- Hover: kenar `border → hoverRing` (`quick`), görsel `.scaleEffect(1.04)` `zoom` eğrisiyle (kırpılmış kalır). Azaltılmış harekette yalnız kenar.
- Yazı görselin üstüne binmez: alt şerit ayrı zemin üzerinde.

Kademe: mağaza öğesi için uyumluluk puanı yoksa (`model.compatReport` sadece kütüphane öğesi için) satırı gizle; ileride Steam appID ile önbellekten getirilebilir — bu sürümde zorunlu değil.

## Animasyonlar

| t (s) | Öğe | Animasyon |
|---|---|---|
| 0.00 | PageHeader + arama | `enterOnAppear()` |
| 0.06 | çip satırı | `enterOnAppear(delay: 0.06)` |
| 0.12 + i×0.05 | karo i | `enter(index: i, base: 0.12, step: 0.05)` |
| yükleme | iskelet karolar | mevcut `SkeletonCard` nabzı yerine `.pulsing()` |
| çip değişince | ızgara | öğeler `.transition(.opacity)` `crossfade`; yeni liste aynı stagger ile girer |

## Metinler

`discover.v2.subtitle`, `discover.chip.featured`, `discover.chip.deals`, `discover.chip.macGreat`, `discover.chip.new` → 03-strings.md. Arama yer tutucu ve başlık mevcut.
