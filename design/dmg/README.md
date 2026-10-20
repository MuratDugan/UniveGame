# dmg/ — UniveGame kurulum DMG'si (sürükle-bırak penceresi)

Canlı tasarım: https://claude.ai/artifact/1cxoZkrhT5Arb4zFmYLLpm → "Marka — Simge ve DMG" sayfası (`DmgBackground`, `DmgPreview`).

## Pencere

DMG açılınca 660×400 pt'lik koyu bir Finder penceresi görünür:

- Üstte iki dilli yönerge: "Kurmak için UniveGame'i Uygulamalar klasörüne sürükle" / "Drag UniveGame to Applications to install".
- Solda UniveGame simgesi, sağda Uygulamalar (Applications) kısayolu. Her biri kesik çizgili bir yuvanın içinde.
- Aralarında accent mavisi (`#4D8EFF`) kesik çizgili ok.
- Altta "UniveGame · macOS 15+" (Info.plist'teki `LSMinimumSystemVersion` 15.0 ile aynı).

**Finder neyi çizer, görsel neyi içerir:** Pencere çerçevesini, iki simgeyi ve adlarını Finder çizer. Arka plan görselinde sadece yönerge, yuvalar, ok ve alt satır var. Simgeler görselde olmamalı. Tuvaldeki ok akışı ve simge kayma animasyonu sadece tasarım önizlemesi; DMG arka planı durağandır.

## Dosyalar

| Dosya | Ne |
|---|---|
| `source/dmg-background.svg` | Arka planın vektör kaynağı (660×400). Değişiklik buradan. |
| `dmg-background.png` | 1× (660×400 px) |
| `dmg-background@2x.png` | 2× (1320×800 px) |
| `dmg-background.tiff` | 1× + 2× tek dosyada (`tiffutil -cathidpicheck`). `create-dmg` buna verilir; Retina ekranda keskin görünür. |
| `dmg-preview.png` | Simgenin yerleştiği hâlin kaba önizlemesi (2×). Sadece hizalama kontrolü için; DMG'ye girmez. Uygulamalar klasör simgesi bu önizlemede yok, gerçeğini macOS çizer. |
| `make-dmg.sh` | DMG'yi üreten betik. |

## Koordinatlar (değiştirme)

| Öğe | Değer |
|---|---|
| Pencere boyutu | 660 × 468 pt (tasarım alanı 660 × 400; macOS 26+ Finder araç çubuğu gizlenemiyor ve pencere boyutuna dahil) |
| Arka plan | 660 × 440 (alttaki 40 pt düz zemin; araç çubuğunu gizleyen eski sistemlerde görünür) |
| Ad plakaları | 104 × 23, sol üst (128, 272) ve (428, 272), köşe 11.5, `#E4E4E7`. Finder resimli arka planda simge adlarını her zaman siyah çizer; plakalar okunurluk için. |
| Simge boyutu | 128 pt, yazı 13 pt |
| UniveGame.app simge merkezi | (180, 200) |
| Applications kısayolu merkezi | (480, 200) |
| Yuvalar (görselde) | 176 × 192, sol üst (92, 108) ve (392, 108), köşe 16 |
| Ok | x 288 → 372, y 200 |

Simge merkezleri değişirse `source/dmg-background.svg` içindeki yuvalar ve ok da aynı miktarda kaydırılmalı, sonra PNG/TIFF yeniden üretilmeli.

## DMG üretme

```bash
scripts/bundle.sh release        # build/UniveGame.app
design/dmg/make-dmg.sh           # build/UniveGame-<sürüm>.dmg (sürüm Info.plist'ten)
design/dmg/make-dmg.sh 0.2.0     # ya da sürümü elle ver
```

`make-dmg.sh`, `create-dmg` kullanır (`brew install create-dmg`). Betik Finder'ı AppleScript ile sürer; çalışırken kısa süre bir Finder penceresi açılıp kapanır, bu normal. Dağıtım için DMG'yi imzala ve notarize et (bu betik yapmaz): `codesign --sign "Developer ID Application: …" build/UniveGame-*.dmg` ve `xcrun notarytool submit … --wait`, sonra `xcrun stapler staple`.

## Yeniden üretme (SVG değişirse)

```bash
cd design/dmg
rsvg-convert -w 660  -h 440 source/dmg-background.svg -o dmg-background.png
rsvg-convert -w 1320 -h 880 source/dmg-background.svg -o dmg-background@2x.png
tiffutil -cathidpicheck dmg-background.png dmg-background@2x.png -out dmg-background.tiff
```

Yazı tipi: başlıklar sistem fontu (SF Pro), alt satır SF Mono. İşleyici sistem fontunu bulamazsa metni Helvetica'ya düşürür; çıktıyı `dmg-preview.png` ile karşılaştır.
