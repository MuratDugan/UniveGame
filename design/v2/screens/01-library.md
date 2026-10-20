# 01 — Kütüphane (dolu)

Reference: `reference/V2Library.dc.html` (etkileşimli: bir kapağa tıklayınca Sahne değişir).
Swift: `LibraryView.swift` (yeniden yazılır), yeni `LibraryStage.swift`, `ShelfCover` (02).

## Yerleşim (1280×800, rail hariç içerik 1200 genişlik)

```
VStack(spacing: 0)
├─ TopBar  h52, yatay iç boşluk: sol 32, sağ 16, öğe aralığı 6
│  ├─ FilterChip × n   "Tümü 244" (seçili) · "Steam 196" · "Epic Games 47" · "Kendi Oyunlarım 1"
│  ├─ Spacer
│  └─ SearchPill 260×30 + ⌘K
└─ ScrollView(.vertical)  iç boşluk: üst 16, yatay 32; bölümler arası 32
   ├─ Stage   h280   Grid: [500 sabit | esnek], sütun aralığı 32
   │  ├─ Görsel  500×280, köşe lg, 1pt border, item.heroURL (yoksa coverURL büyütülmüş + kırpılmış)
   │  └─ Bilgi sütunu (dikey ortalı, aralık 12)
   │     ├─ raf adı        caption 12/600 textSecondary   ("Oynamaya hazır")
   │     ├─ oyun adı       display 30/700, satır 36
   │     ├─ meta           body textSecondary             ("Steam · Yüklü · 42 sa oynandı")
   │     ├─ puan bloğu     üst 4, aralık 8, en çok 420 genişlik
   │     │  ├─ HStack(baseline, 8): puan scoreStage 24/700 monoDigit · kademe simge+ad 13/600 tier.color · "· {neden}" caption textSecondary
   │     │  └─ ölçü: 6pt kapsül, iz elevated, dolgu tier.color %score; 20/40/60/80 değil → kademe eşiklerinde (25/45/65/80) 1pt × 10pt background renkli çentik
   │     └─ eylemler       üst 8, aralık 8
   │        ├─ PrimaryButtonStyle  h40: "Oyna" (play.fill) yüklüyse / "Yükle" (arrow.down.to.line) değilse
   │        └─ SecondaryButtonStyle h40: "Oyun sayfası" → oyun sayfasına git
   └─ Shelf × 3  (her biri: başlık satırı + 12 + yatay kapak sırası)
      ├─ başlık satırı (baseline, 8): section 13/600 ad · caption sayı monoDigit · caption "· ipucu" textSecondary
      └─ ScrollView(.horizontal, showsIndicators: false) → HStack(spacing: 16) ShelfCover × n (132 genişlik)
```

### Rafların tanımı (veri)

| Raf | Anahtar | İçerik | Sıralama |
|---|---|---|---|
| Oynamaya hazır | `shelf.ready` | `item.isInstalled` | son oynama (yeni → eski), sonra ad |
| Yükle ve oyna | `shelf.install` | yüklü değil **ve** tier ∈ {excellent, good} | puan (yüksek → düşük) |
| Mac'te zor | `shelf.hard` | yüklü değil **ve** tier ∈ {playable, poor, broken} | puan (yüksek → düşük) |
| Henüz incelenmedi | `shelf.unknown` | yüklü değil **ve** rapor yok / unknown | ad — **en sonda**, sadece doluysa |

- Boş raf gösterilmez. Arama metni (`model.searchText`) ve kaynak çipi tüm rafları süzer.
- Raf ipucu metinleri: "Yüklü oyunların" / "Mac'te iyi çalışanlar" / "Engel ya da bilinen sorun var" / "Puan için oyunu incele".
- Kütüphane sıralama menüsü (`LibrarySort`) v2'de raf sırasını değil raf içi sırayı etkiler; menü SearchPill'in soluna küçük `arrow.up.arrow.down` simge düğmesi olarak eklenebilir (tasarımda yok, isteğe bağlı).

### Sahne verisi

- Seçili oyun `@State var stageID: LibraryItem.ID?`. Başlangıç: "Oynamaya hazır" rafının ilki; o boşsa ilk rafın ilki.
- Neden metni (`· Steam Deck Doğrulandı`): raporun **en yüksek mutlak etkili** faktörü (`report.factors.max(by: abs(impact))`), `L(key)` ile; rapor yoksa gizli.
- Meta: kaynak · durum · (yüklüyse ve playTime > 0) "42 sa oynandı" / (yüklü değilse ve boyut biliniyorsa) boyut.
- CTA kuralları:
  - Yüklü + çalışır → Primary "Oyna".
  - Yüklü değil + tier ≥ playable → Primary "Yükle".
  - tier == broken → Primary **yok**; Secondary "Neden çalışmıyor?" (oyun sayfasına gider).
  - Rapor `compat.f.dx12noMetal` faktörünü içeriyor ve D3DMetal kurulu değil → Primary yok; Secondary "D3DMetal'i kur" → `model.selection = .settings`.

## Etkileşimler

- Kapak tek tık → `stageID = item.id` (Sahne değişir; sayfa kaymaz). Çift tık veya Return → oyun sayfası. Bağlam menüsü → `GameActionsMenu`.
- Sahnedeki "Oyun sayfası" → mevcut navigasyonla `GameDetailView(item)`.
- Klavye: kapaklar odaklanabilir; ←/→ raf içinde, ↑/↓ raflar arasında gezinir, odak değişince Sahne de değişir.

## Animasyon zaman çizelgesi

Ekran ilk açıldığında (t = 0):

| t (s) | Öğe | Animasyon |
|---|---|---|
| 0.00 | Sahne görseli | `enterOnAppear()` |
| 0.06 | raf adı | `enterOnAppear(delay: 0.06)` |
| 0.12 | oyun adı | `enterOnAppear(delay: 0.12)` |
| 0.18 | meta | `enterOnAppear(delay: 0.18)` |
| 0.24 | puan bloğu | `enterOnAppear(delay: 0.24)`; ölçü dolgusu `growOnAppear(delay: 0.24)` (1.0 s) |
| 0.30 | eylemler | `enterOnAppear(delay: 0.30)` |
| 0.20 + i×0.05 | her raftaki i. kapak | `enter(index: i, base: 0.2, step: 0.05)`; altındaki TierMeter aynı gecikmeyle dolar |

Sahne değişince (kapak tıklandı):

| Öğe | Animasyon |
|---|---|
| Görsel | yeni görsel `crossfade` (0.4 s, `.transition(.opacity)` + `.id(stageID)`) |
| Ad, meta, neden, CTA metni | `.contentTransition(.opacity)` + `crossfade` |
| Puan sayısı | `.contentTransition(.numericText(value: score))` + `valueChange` |
| Ölçü dolgusu ve rengi | genişlik + renk `valueChange` (0.6 s) |
| Seçim halkası | eski kapaktan kalkar, yenisinde belirir (`quick`) |

Hover: kapak `.coverHover()` (−4 pt, 1.02, hover-ring, gölge; `quick`). Çip, arama hapı: `hoverFill`.

Azaltılmış hareket: giriş ve dolum anlık; Sahne değişiminde yalnız opaklık geçişi (0.15 s) kalır.

## Metinler

`library.chip.all`, `library.search.v2`, `shelf.ready`, `shelf.ready.hint`, `shelf.install`, `shelf.install.hint`, `shelf.hard`, `shelf.hard.hint`, `shelf.unknown`, `shelf.unknown.hint`, `stage.playtime` ("%@ oynandı"), `stage.openPage`, `stage.whyBroken`, `stage.setUpD3DMetal`, `cover.notAnalyzed` → 03-strings.md. "Oyna", "Yükle" mevcut anahtarlar.

## Kabul

- 1280×800'de Sahne + ilk raf tam, ikinci raf başlığı ve kapakların üst kısmı görünüyor (reference ile aynı).
- 980 genişlikte Sahne görseli 500 → `min(500, genişlik × 0.45)` olur, bilgi sütunu sıkışmaz; raflar yatay kaydırılır.
- Kapak üstünde hiçbir metin ya da rozet yok.
- Tek Primary düğme Sahne'de; broken / D3DMetal eksik durumunda hiç Primary yok.
