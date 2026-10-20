# simge/ — UniveGame uygulama simgesi ("Yörünge")

Canlı tasarım: https://claude.ai/artifact/1cxoZkrhT5Arb4zFmYLLpm → "Marka — Simge ve DMG" sayfası.

## Fikir

Bir oyun kumandası ve çevresinde dönen bir yörünge. Kumanda platformdan bağımsız oyunu, yörünge evreni (universal) temsil ediyor: tüm platformlar ve tek tek oyunlar tek sistemde. Yörünge kumandanın arkasından geçip önünden döner. Üstündeki küçük gezegen tek bir oyunu anlatır.

- Zemin: grafit squircle `#18181B` (token `card`), 1 px beyaz %10 hairline.
- Kumanda: `#F4F4F5` (token `text-primary`), düğmeler zemin renginde boşluk.
- Yörünge ve gezegen: `#4D8EFF` (token `accent`, arayüzdeki tek vurgu rengi).
- Gradyan, mor, parlama yok. Gölge: `0 16 28 rgba(0,0,0,0.5)` (Apple simge ızgarasının 100 px kenar boşluğunun içinde).

## Dosyalar

| Dosya | Ne | Kullanım |
|---|---|---|
| `source/AppIcon.svg` | Ana çizim, 1024×1024 vektör | 64 px ve üstü için tek kaynak. Değişiklik buradan yapılır. |
| `source/AppIcon-small.svg` | Küçük boy varyantı | **Sadece** 16 ve 32 px çıktılar: hairline yok, yörünge 28→44, gezegen r 36→54, düğmeler büyük. |
| `source/MenuBarIconTemplate.svg` | Tek renk şablon glif, 18×18 pt | İsteğe bağlı; uygulama bir menü çubuğu öğesi gösterirse. |
| `AppIcon-1024.png` | 1024 px, gölgeli, saydam zemin | `scripts/bundle.sh`'in beklediği PNG. |
| `AppIcon.iconset/` | 10 PNG, Apple adlandırmasıyla | `iconutil` girdisi. 16, 16@2x ve 32 küçük varyanttan; diğerleri ana çizimden. |
| `AppIcon.icns` | Hazır macOS simge dosyası | Uygulama paketine giren dosya. |
| `MenuBarIconTemplate.png` / `@2x.png` | 18 / 36 px siyah şablon | `NSImage(named:)` + `isTemplate = true`. |

## Uygulamaya bağlama

`scripts/bundle.sh` simgeyi `docs/brand/` içinde arıyor (önce `AppIcon.icns`, yoksa `AppIcon-1024.png`'den üretir). İki seçenek:

1. **Önerilen:** dosyaları kopyala, betiğe dokunma:
   ```bash
   mkdir -p docs/brand && cp design/simge/AppIcon.icns design/simge/AppIcon-1024.png docs/brand/
   ```
2. Ya da `scripts/bundle.sh` içindeki `docs/brand/` yollarını `design/simge/` yap.

Sonra `scripts/bundle.sh release` → `build/UniveGame.app` yeni simgeyle gelir. Finder ve Dock simge önbelleğini tutabilir: uygulamayı başka bir klasöre taşı ya da `killall Dock`.

Menü çubuğu glifi kullanılacaksa `MenuBarIconTemplate.png` ve `@2x`'i `Sources/UniveGame/Resources/` altına koy ve şablon olarak yükle:
```swift
let image = Bundle.module.image(forResource: "MenuBarIconTemplate")
image?.isTemplate = true
```

## Yeniden üretme (SVG değişirse)

Bu klasördeki PNG'ler SVG'lerden üretildi. Gölge SVG filtresi her işleyicide çıkmadığı için ImageMagick ile ekleniyor. Herhangi bir SVG→PNG işleyiciyle (`rsvg-convert`, Inkscape, ya da macOS'ta `NSImage(contentsOf:)` ile çizen küçük bir Swift betiği):

```bash
# 1) 1024 düz çizim (gölgesiz)
rsvg-convert -w 1024 -h 1024 source/AppIcon.svg -o /tmp/flat.png
rsvg-convert -w 1024 -h 1024 source/AppIcon-small.svg -o /tmp/flat-small.png
# 2) gölge ekle, 1024 çerçeveye geri ortala
magick /tmp/flat.png \( +clone -background black -shadow 50x14+0+16 \) +swap -background none -layers merge +repage -gravity center -extent 1024x1024 AppIcon-1024.png
magick /tmp/flat-small.png \( +clone -background black -shadow 50x14+0+16 \) +swap -background none -layers merge +repage -gravity center -extent 1024x1024 /tmp/small-1024.png
# 3) iconset (16, 16@2x, 32 → küçük varyant; geri kalanı ana)
mkdir -p AppIcon.iconset
for spec in "small 16 icon_16x16" "small 32 icon_16x16@2x" "small 32 icon_32x32" \
            "main 64 icon_32x32@2x" "main 128 icon_128x128" "main 256 icon_128x128@2x" \
            "main 256 icon_256x256" "main 512 icon_256x256@2x" "main 512 icon_512x512" "main 1024 icon_512x512@2x"; do
  set -- ${=spec}; src=$([[ $1 == small ]] && echo /tmp/small-1024.png || echo AppIcon-1024.png)
  magick "$src" -filter Lanczos -resize ${2}x${2} -strip "AppIcon.iconset/$3.png"
done
# 4) icns
iconutil -c icns AppIcon.iconset -o AppIcon.icns
```

## Kurallar

- Simgenin içine yazı koyma; ad Finder ve Dock tarafından yazılır.
- Renkler değişmez; açık tema varyantı yok (simge her masaüstünde aynı).
- Çevresinde en az gezegen çapı kadar boşluk bırak (logo yanında kullanırken).
- Logo yazısı: "UniveGame", SF Pro Bold, harf arası −2 %, simgenin sağında, simge genişliğinin 1/6'sı kadar arayla.
