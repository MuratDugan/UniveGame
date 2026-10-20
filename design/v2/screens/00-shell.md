# 00 — Uygulama kabuğu ve Rail

Reference: `reference/V2Rail.dc.html` (rail), her ekran dosyası (kabuk içinde nasıl durduğu).

## Yerleşim

```
Window 1280×800 (min 980×620), .windowStyle(.hiddenTitleBar) değil — unified toolbar, başlık görünmez
└─ HStack(spacing: 0)
   ├─ RailView                       80 × tam yükseklik  (02-components → Rail)
   └─ detail                         kalan genişlik, zemin background
      ├─ (sayfaya göre) üst çubuk    52 yükseklik — kütüphane ve oyun sayfasında; diğer sayfalarda yok, onun yerine PageHeader
      └─ içerik
```

- `NavigationSplitView` kaldırılır; kabuk `HStack { RailView(); detail }`. Kütüphane → oyun sayfası geçişi için `NavigationStack` detail içinde kalır (mevcut `LibraryView` zaten kullanıyorsa koru).
- Trafik ışıkları rayın üstündeki 52 pt bölgeye düşer. Pencere araç çubuğu görünmez olmalı (`.toolbar(removing: .title)`, `.toolbarBackground(.hidden)`); üst çubuklar view içinde çizilir.
- Kurulum akışı (05) açıkken Rail gizlenir: `detail` tam pencere `InstallerFlowView` olur (bkz. 05).

## Model değişiklikleri

```swift
enum SidebarItem: Hashable {
    case library(LibraryFilter)
    case discover
    case stores
    case addGame      // yeni: Rail "Ekle"
    case settings
}
```

- `ContentView.detail` switch'ine `.addGame: AddGameView()` eklenir.
- `model.showImport = true` çağıran yerler (menü komutu, toolbar `+`, boş durum) `model.selection = .addGame` yapar. Düzenleme (`editingCustomGame`) şimdilik sheet olarak kalabilir; v2 tasarımı yalnızca ekleme akışını kapsıyor.
- Sol menüdeki Yüklü / Favoriler / Son Oynananlar filtreleri v2'de **raflar ve çipler** ile karşılanır: "Yüklü" = "Oynamaya hazır" rafı, "Favoriler" çip olarak eklenebilir (ikinci sürüm). `LibraryFilter.installed/.favorites/.recent` case'leri silinmez; ⌘1–⌘4 kısayolları çip seçimine bağlanır.

## Animasyonlar

| Öğe | Tetik | Animasyon |
|---|---|---|
| Rail öğesi hover | onHover | zemin `clear → card`, yazı `textSecondary → textPrimary`, `quick` |
| Rail seçimi | tık | zemin + simge rengi `quick`; içerik değişimi: yeni sayfa kendi `enterOnAppear` zincirini oynatır (sayfa geçişinde ayrıca kayma yok) |
| Motor noktası | sürekli | `.pulsing()` (motor hazırsa) |

## Metinler

`rail.library`, `rail.discover`, `rail.stores`, `rail.add`, `rail.settings`, `rail.engine` → bkz. 03-strings.md.

## Kabul

- Rail genişliği her pencere boyutunda 80; etiketler TR ve EN'de tek satır ("Kütüphane"/"Library", "Mağazalar"/"Stores").
- Klavye: Tab ile rail öğeleri gezilebiliyor, Return seçiyor.
