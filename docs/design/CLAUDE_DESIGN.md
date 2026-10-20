# UniveGame ekranlarını Claude Design ile tasarlatma

## 1. Hazırlık

- Tasarım sistemi: **UniveGame** — https://claude.ai/artifact/4GcHQvdnYXZEdHT1YWCcmg
  Uygulamadaki gerçek renkler, yazı ölçeği, boşluklar, köşe yarıçapları, 11 bileşen ve
  "Screens and layout" bölümü (her ekranın yerleşim kuralları) burada.
- Mevcut ekran görüntüleri: `docs/screenshots/` (library, game, compat-*, stores, discover,
  import, installer, settings-d3dmetal).

## 2. Claude Design'da

1. Yeni bir **Design** aç, tasarım sistemi olarak **UniveGame**'i seç.
2. `docs/screenshots/` içindeki görüntüleri ekle (mevcut hâli görsün diye).
3. Aşağıdaki promptu yapıştır.

```
UniveGame için macOS uygulama ekranlarını tasarla. UniveGame tasarım sistemini kullan: README'deki kurallar, tokens ve bileşenler bağlayıcı; "Screens and layout" bölümü her ekranın içeriğini tanımlıyor. Eklediğim ekran görüntüleri uygulamanın şu anki hâli; amaç düzeni, hiyerarşiyi ve okunabilirliği iyileştirmek, kimliği değiştirmek değil.

Ürün: Windows oyunlarını Mac'te çalıştıran evrensel bir oyun kütüphanesi. Steam, Epic, GOG, Ubisoft, EA ve kullanıcının kendi .exe oyunları tek yerde; her oyun için bir uyumluluk puanı var.

Kısıtlar:
- Yerel bir macOS (SwiftUI) uygulaması: solda kenar çubuğu (source list), üstte birleşik araç çubuğu, diyaloglar sayfa (sheet) olarak açılır. Web'e özgü kalıplar (hamburger menü, alt gezinme, sabit hero) kullanma.
- Sadece koyu tema. Tek vurgu rengi `accent`; her ekranda tek bir `cta` ana düğme. Gradyan, mor, parlama yok. Yazı asla görselin üstüne binmez.
- Metinler Türkçe, gerçek içerikle (gerçek oyun adları: Hades, Cyberpunk 2077, Stardew Valley, Hollow Knight, Apex Legends, S2 Rebirth). İngilizcesi aynı alana sığmalı.
- Simgeler için SF Symbols karşılığı olarak Lucide kullan.
- 1280 × 800 pencere; en küçük 980 × 620'de de bozulmamalı.

Her ekranı ayrı bir artboard olarak, adlarını aynen şöyle koy:
1. Kütüphane — Tüm Oyunlar (dolu; bir kapak üzerinde hover hâli; uyumluluk rozetleri)
2. Kütüphane — Boş
3. Oyun Sayfası — Yüklü oyun (Hades: Oyna, Uyumluluk 92 Mükemmel)
4. Oyun Sayfası — Çalışmaz (Apex Legends: anti-cheat engeli)
5. Oyun Sayfası — DirectX 12, D3DMetal kurulu değil (Cyberpunk 2077: "Kur" düğmesi)
6. Oyun Ekle sayfası (kapak önerisi "Steam'den bulundu" ile)
7. Kurulum — Giriş, İlerleme ve Program Seçimi (üç artboard)
8. Mağaza Hesapları
9. Keşfet
10. Ayarlar (Dil, Motor, DirectX 12 / D3DMetal iki adımlı kurulum)

Her artboard'da boşlukları ve bileşenleri token adlarıyla etiketle (ör. space-xl, radius-lg, GameCard, CompatibilityPanel). Tasarım sisteminde olmayan yeni bir bileşen gerekiyorsa ayrıca bir "Yeni bileşenler" artboard'unda göster ve neden gerektiğini yaz.
```

## 3. Teslim (handoff)

Tasarım bitince Claude Code'daki oturuma Design'ın linkini yapıştır ("tasarım hazır" demen yeter).
Claude linki okur ve ekranları sırayla SwiftUI'a uygular:

- Token değişiklikleri → `Sources/UniveGame/Theme/Theme.swift` ve tasarım sistemi birlikte güncellenir.
- Her ekran → ilgili `Views/*.swift` dosyası.
- Her ekrandan sonra uygulamanın ekran görüntüsü tasarımla karşılaştırılır.

Yeni bir logo gelirse: `docs/brand/AppIcon-1024.png` olarak koy; `scripts/bundle.sh` `.icns`'i üretip uygulamaya ekler.
