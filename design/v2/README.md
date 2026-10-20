# UniveGame v2 — Handoff

v2 tasarımını SwiftUI'a uygulayacak kişi (insan ya da yapay zeka) için tek giriş noktası. Okuma sırası:

1. Bu dosya: kapsam, kurallar, dosya haritası, uygulama sırası.
2. [`01-foundations.md`](01-foundations.md): token'lar, yeni hareket token'ları ve **kopyalanıp yapıştırılabilir** `Motion.swift`.
3. [`02-components.md`](02-components.md): yeni ve değişen bileşenler; ölçüler, durumlar, animasyonlar, SwiftUI iskeletleri.
4. `screens/`: her ekran için yerleşim ağacı, veri bağlantısı, etkileşimler, animasyon zaman çizelgesi ve kabul ölçütleri.
5. [`03-strings.md`](03-strings.md): yeni yerelleştirme anahtarları (TR + EN), `Localizable.strings` dosyalarına eklenecek.
6. `reference/`: tasarımın kaynak dosyaları (`*.dc.html`, HTML + inline CSS). Piksel ölçüsünde emin olmadığın her şeyin **gerçek kaynağı** bunlar. `reference/tokens.json` tasarım sisteminin token dosyası.

Canlı tasarım: https://claude.ai/artifact/1cxoZkrhT5Arb4zFmYLLpm → "v2 — Yeni yerleşim" sayfası.

---

## Değişmeyen kurallar (tasarım sistemi)

- Sadece koyu tema. Renkler yalnızca `Theme.Palette`'ten; ham hex yok (yeni token gerekirse önce `Theme.swift`'e ekle).
- Tek vurgu rengi `accent` (#4D8EFF): seçim, anahtar, bağlantı, ilerleme. Büyük alanları onunla doldurma.
- Her ekranda en fazla bir `cta` (`PrimaryButtonStyle`). Bilinçli istisnalar ekran dosyalarında yazılı.
- Gradyan, parlama (glow), mor yok. Derinlik `border` çizgisiyle; gölge sadece kapaklarda.
- Yazı asla görselin (kapak, banner) üstüne binmez.
- Anlam taşıyan renk (kademe, durum) her zaman simge ya da kelimeyle birlikte.
- Simgeler SF Symbols. Tasarımdaki Lucide simgelerinin karşılıkları her ekran dosyasında verildi.
- Tüm metinler `L("anahtar")` üzerinden; TR ve EN aynı alana sığmalı.
- Değişen sayılar (puan, sayaç, fiyat, süre) `.monospacedDigit()`.
- **Azaltılmış hareket**: `@Environment(\.accessibilityReduceMotion)` açıkken tüm giriş, döngü ve ölçek animasyonları kapanır; renk/opaklık geçişleri anlık olur. `Motion.swift` bunu tek yerden yapıyor.

## v1'den v2'ye büyük değişiklikler

| Alan | v1 (şu anki uygulama) | v2 |
|---|---|---|
| Gezinme | `NavigationSplitView` + `SidebarView` (source list) | 80 pt simge rayı (`Rail`). Kaynak filtreleri üst çubukta çip olur. |
| Kütüphane | Kaldığın yerden + düz ızgara | Üstte **Sahne** (seçili oyun) + uyumluluğa göre 3 **raf** |
| Kapak puanı | Kapak üstünde rozet | Kapağın altında 3 pt ölçü çizgisi + "92 · Mükemmel" |
| Oyun sayfası | Banner + iki panel | Sol sütun (kapak, CTA, bilgiler) + sağ sütun (başlık, uyarı, uyumluluk ölçeği, başlatma ayarları) |
| Grafik seçimi | Menü `Picker` | Bölmeli seçici (segmented) |
| Ayar anahtarları | Satır + `Toggle` | 2 sütun **ToggleTile** |
| Oyun ekle | Sheet | Rayda "Ekle" sayfası: 3 yol + satır içi form |
| Kurulum | Sheet | Tam pencere akış, solda **StepRail** |
| Mağazalar | 3 sütun kart | Satır listesi + "2 / 5 bağlı" ölçeği |
| Keşfet | 3 sütun eşit kart | Bento ızgara (bir büyük karo) + filtre çipleri |
| Ayarlar | Tek sütun paneller | İki bölme: bölüm listesi + içerik; D3DMetal zaman çizgisi |

> **Onay gerektiren sapmalar** (brief'teki "kenar çubuğu" ve "diyaloglar sheet" kuralından): simge rayı, tam sayfa Oyun Ekle, tam pencere Kurulum. Ürün sahibi onayladı; v2 bunlarla uygulanır. Kurulum yine de mevcut `model.installer` oturumuna bağlı kalır (bkz. ekran dosyası).

## Dosya haritası (ekran → kaynak → Swift)

| # | Ekran | Spec | Reference | Swift dosyası |
|---|---|---|---|---|
| 0 | Uygulama kabuğu + Rail | [screens/00-shell.md](screens/00-shell.md) | `V2Rail.dc.html` | `ContentView.swift`, **yeni** `Views/RailView.swift` (SidebarView'in yerini alır) |
| 1 | Kütüphane — dolu | [screens/01-library.md](screens/01-library.md) | `V2Library.dc.html` | `LibraryView.swift`, `GameCard.swift` → **yeni** `ShelfCover` |
| 2 | Kütüphane — boş | [screens/02-library-empty.md](screens/02-library-empty.md) | `V2LibraryEmpty.dc.html` | `LibraryView.swift` (boş durum), `Components.swift` `EmptyStateView` |
| 3 | Oyun sayfası (3 durum) | [screens/03-game.md](screens/03-game.md) | `V2GamePage.dc.html` (+ Hades/Apex/Cyberpunk sarmalayıcıları) | `GameDetailView.swift`, `CompatibilityViews.swift` |
| 4 | Oyun Ekle | [screens/04-add-game.md](screens/04-add-game.md) | `V2AddGame.dc.html` | **yeni** `Views/AddGameView.swift` (`ImportGameSheet` mantığını kullanır) |
| 5 | Kurulum (3 adım) | [screens/05-installer.md](screens/05-installer.md) | `V2Installer.dc.html` | `InstallerSheet.swift` → tam pencere `InstallerFlowView` |
| 6 | Mağazalar | [screens/06-stores.md](screens/06-stores.md) | `V2Stores.dc.html` | `StoresView.swift` |
| 7 | Keşfet | [screens/07-discover.md](screens/07-discover.md) | `V2Discover.dc.html` | `DiscoverView.swift` |
| 8 | Ayarlar | [screens/08-settings.md](screens/08-settings.md) | `V2Settings.dc.html` | `SettingsView.swift`, `D3DMetalSetup.swift` |

## Uygulama sırası

Her adımdan sonra derle, uygulamayı çalıştır, ekran görüntüsünü `reference/` ile karşılaştır.

1. `01-foundations.md` → `Theme.swift`'e yeni token'ları ekle, `Theme/Motion.swift` dosyasını oluştur.
2. `02-components.md` → `Views/Components/` altında bileşenleri oluştur (önce `Rail`, `FilterChip`, `SearchPill`, `TierMeter`, `TierScale`).
3. Kabuk (00) → Kütüphane (01, 02) → Oyun sayfası (03) → Ayarlar (08) → Mağazalar (06) → Keşfet (07) → Oyun Ekle (04) → Kurulum (05).
4. `03-strings.md` anahtarlarını her ekranla birlikte ekle (TR ve EN aynı commit'te).
5. Eski `SidebarView`, `RecentTile`, `CompatBadge` (kapak üstü rozet) yalnızca kullanılmadıklarında silinir.

## Reference dosyalarını okuma

- Her `.dc.html` dosyası tek bir 1280×800 pencere. Ölçüler CSS px = SwiftUI pt.
- `style="…"` içindeki değerler kesin ölçüdür. `{{isim}}` delikleri dosyanın altındaki `renderVals()` içinde hesaplanır; örnek veri de orada.
- `<helmet><style>` içindeki `@keyframes` ve `.ug-*` sınıfları animasyonların kaynağıdır; her birinin SwiftUI karşılığı `01-foundations.md`'de.
- `<sc-for>` = `ForEach`, `<sc-if>` = `if`, `<dc-import name="X">` = `X` bileşenini göm.
- Kapaklar ve görseller tasarımda renkli yer tutucudur; uygulamada `CoverArt` / `item.coverURL` / `item.heroURL` kullanılır.
- Örnek fiyatlar ve oyuncu sayıları gerçek değil; gerçek veri `SteamStoreAPI` / `LibraryItem`'dan gelir.

## Kabul ölçütleri (tüm ekranlar)

- 1280×800'de reference ile hizalama, boşluk ve yazı ölçüsü eşleşiyor (±2 pt).
- 980×620 en küçük pencerede taşma, üst üste binme ve kırpılan metin yok; ızgaralar sütun sayısını düşürüyor.
- Her ekranda en fazla bir `PrimaryButtonStyle`.
- Azaltılmış hareket açıkken hiçbir şey kaymıyor, zıplamıyor ya da döngüde dönmüyor.
- VoiceOver: simge-only düğmelerin etiketi var; puanlar "92, Mükemmel" diye okunuyor; Rail öğeleri seçili durumunu bildiriyor.
- TR ve EN arasında geçişte düzen bozulmuyor.
