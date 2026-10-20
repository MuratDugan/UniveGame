# 03 — Oyun sayfası (Yüklü / Çalışmaz / D3DMetal eksik)

Reference: `reference/V2GamePage.dc.html` (tek bileşen, `game` prop'u ile 3 durum); sarmalayıcılar `V2GameHades`, `V2GameApex`, `V2GameCyberpunk` sadece örnek veri seçer. Örnek verinin tamamı dosyanın altındaki `data(id)` içinde.
Swift: `GameDetailView.swift` (yeniden düzenlenir), `CompatibilityViews.swift` (`CompatibilityPanel` → v2 hâli), `LaunchSettingsPanel` → ToggleTile ızgarası. `KnownIssueBanner` korunur (NoticeBanner'ın altında).

## Yerleşim

```
VStack(spacing: 0)
├─ TopBar h52, iç boşluk sol 24 sağ 16
│  ├─ Geri: "‹ Kütüphane" metinli düğme h30, köşe md, hoverFill(clear→card), 13/500 textSecondary
│  ├─ Spacer
│  ├─ Favori 32×32 SecondaryButton simge-only (heart / heart.fill favorite renkli)
│  └─ Diğer 32×32 SecondaryButton (ellipsis) → GameActionsMenu + "Ayrıntılı günlük" (verboseLogs) burada
└─ ScrollView → Grid [260 sabit | esnek], sütun aralığı 40, üst 8, yatay 32, üst hizalı
   ├─ Sol sütun (aralık 16)
   │  ├─ Kapak 260×390, köşe md, 1pt borderStrong, gölge shadow-cover-hero (0 6 32 / %45 → radius 16)
   │  ├─ CTA tam genişlik h44 (aşağıdaki kurallar)
   │  └─ FactList (02)
   └─ Sağ sütun (aralık 16)
      ├─ Başlık bloğu (aralık 6): kicker caption 12/600 textSecondary "Steam · Supergiant Games · 2020" · ad display 30/700
      ├─ NoticeBanner (varsa)
      ├─ Uyumluluk paneli  (Panel: card, border, lg, iç boşluk 16, aralık 16)
      │  ├─ Üst satır (aralık 16, ortalı): puan scoreHero 44/700 monoDigit · [kademe simge+ad "Mükemmel · Sorunsuz çalışmalı" 15/600 tier.color / güven + "İncelendi 2 gün önce" caption textSecondary] · Spacer · SecondaryButton h30 "Yeniden İncele" (arrow.clockwise; analiz sırasında ProgressView)
      │  ├─ TierScale (02)
      │  └─ Faktörler: 2 sütunlu LazyVGrid, sütun aralığı 24, satır 10; satır = simge 14 + metin caption 12 + etki mono textSecondary
      └─ Başlatma ayarları paneli (aralık 12)
         ├─ Üst satır: section "Başlatma ayarları" · Spacer · SegmentedPicker (grafik)
         ├─ yardım metni caption textSecondary (Otomatik ise launch.backend.help, değilse "X elle seçildi. Sorun olursa Otomatik'e dön.")
         └─ ToggleTile 2×2
```

Reference'taki uyumluluk özeti yan yana "Mükemmel · Sorunsuz çalışmalı": `L("compat.tier.\(tier)")` + " · " + `L("compat.tier.\(tier).help")` (mevcut anahtarlar). Güven satırı: `L("compat.confidence.\(c)")` + " " + `L("compat.analyzedAt")` + göreli tarih (mevcut `footnote` mantığı; kaynak listesi tooltip'e taşınır).

## Üç durum

| | Hades (yüklü, 92) | Apex Legends (yüklü değil, 10) | Cyberpunk 2077 (yüklü, 72, D3DMetal yok) |
|---|---|---|---|
| CTA | Primary "Oyna" (play.fill) | Secondary "Yine de Yükle" (arrow.down.to.line) — **bilinçli: ekranda Primary yok** | Secondary "Oyna", disabled (%40) |
| NoticeBanner | yok | destructive: "Easy Anti-Cheat engelliyor" + açıklama + bağlantı "Durumu takip et" (AreWeAntiCheatYet sayfası) | warning: "Önce D3DMetal'i kur" + açıklama + **Primary "Kur"** → `model.selection = .settings` (Ayarlar DirectX 12 bölümü seçili açılır) |
| FactList | Durum · Oynama süresi · Son oynama · Konum | Durum · Tahmini boyut · Kaynak | Durum · Oynama süresi · Son oynama · Konum |
| Grafik | Otomatik | Otomatik | D3DMetal |

Durum kuralları (koddan):
- Banner destructive: raporda `kind == .blocker` faktör var. Başlık o faktörün kısa başlığı (`\(key).title`, yoksa `compat.notice.blocked`), açıklama `compat.notice.blocked.body`.
- Banner warning + Kur: raporda `compat.f.dx12noMetal` var ve `model.d3dMetalReady == false`. Bu durumda faktör satırındaki eski "Kur" düğmesi **gösterilmez** (tek CTA banner'da).
- CTA: yüklü + engel yok + D3DMetal sorunu yok → Primary "Oyna"; yüklü değil + engel yok → Primary "Yükle"; engel var → Secondary "Yine de Yükle"; D3DMetal eksik → disabled Secondary "Oyna". Kurulum sürüyorsa (`installProgress`) CTA yerine ilerleme çubuğu (mevcut davranış) — 6pt kapsül `accent` dolgu, `valueChange`.

## Animasyon zaman çizelgesi (sayfa açılışı)

| t (s) | Öğe | Animasyon |
|---|---|---|
| 0.00 | kapak | `enterOnAppear()` |
| 0.00 | başlık bloğu | `enterOnAppear()` |
| 0.06 | NoticeBanner | `enterOnAppear(delay: 0.06)` |
| 0.08 | CTA | `enterOnAppear(delay: 0.08)` |
| 0.12 | uyumluluk paneli | `enterOnAppear(delay: 0.12)` |
| 0.14 | FactList | `enterOnAppear(delay: 0.14)` |
| 0.18 | başlatma paneli | `enterOnAppear(delay: 0.18)` |
| 0.30 → 1.30 | TierScale parçaları | `growOnAppear(delay: 0.3)` |
| 0.90 | TierScale pini | `enterOnAppear(delay: 0.9)` |

Etkileşim animasyonları:
- Yeniden İncele bitince: puan `.contentTransition(.numericText(value:))`, ölçek dolguları + pin konumu + kademe rengi `valueChange`; faktör listesi `.transition(.opacity)` `crossfade`.
- SegmentedPicker seçimi: seçili zemin `matchedGeometryEffect` ile kayar (`quick`); yardım metni `crossfade`.
- ToggleTile: anahtar düğmesi yana kayar, zemin ve kenar rengi `quick`.
- Favori: kalp `heart → heart.fill` `.symbolEffect(.bounce, value: isFavorite)` (azaltılmış harekette yok).

## Veri bağlantısı

- `model.compatReport(for:)`, `model.isAnalyzing(_:)`, `model.analyze(_:)` (mevcut).
- Başlatma ayarları: mevcut `Binding<LaunchProfile>` (`model.profile(for:)` / `setProfile`), alanlar `backend`, `retina`, `metalFX`, `performanceHUD`, `commandAsControl`.
- Kicker: kaynak adı + (varsa) geliştirici · çıkış yılı. Bu bilgi `Game` modelinde yoksa yalnızca kaynak adı gösterilir; yeni alan zorunlu değil.

## Metinler

`game.back`, `game.installAnyway`, `game.fact.status`, `game.fact.playtime`, `game.fact.lastPlayed`, `game.fact.location`, `game.fact.size`, `game.fact.source`, `compat.notice.blocked`, `compat.notice.blocked.body`, `compat.notice.track`, `compat.notice.d3d`, `compat.notice.d3d.body`, `launch.backend.manual` → 03-strings.md.

## Kabul

- Üç durumun her biri reference sarmalayıcısıyla eşleşiyor; her durumda en çok bir Primary (Apex'te sıfır).
- 980×620'de sağ sütun daralır, faktör ızgarası tek sütuna düşer (`ViewThatFits` ya da genişlik < 560 → 1 sütun), ToggleTile ızgarası 2 sütun kalır.
- Kapağın ya da görselin üstünde metin yok.
