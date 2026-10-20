# 02 — Kütüphane (boş)

Reference: `reference/V2LibraryEmpty.dc.html`. Swift: `LibraryView.swift` boş dalı; `EmptyStateView` yerine yeni `EmptyLibraryView`.

Ne zaman: kütüphanede hiç oyun yok (mağaza bağlı değil, kendi oyunu yok). Arama/çip sonucu boşsa bu ekran **değil**, küçük bir "Sonuç yok" satırı gösterilir.

## Yerleşim

Üst çubuk yok. İçerik tam alan, dikey ve yatay ortalı, öğeler arası 40, iç boşluk 48.

```
VStack(spacing: 40)
├─ Hayalet kapaklar  h230, HStack(alignment: .bottom, spacing: 20)   [accessibilityHidden]
│  ├─ GhostCover 120×180, rotation −6°, bob delay 0
│  ├─ GhostCover 140×210, offset y −16, ortada plus 28pt textTertiary, zemin card, bob delay 0.65
│  └─ GhostCover 120×180, rotation +6°, bob delay 1.3
├─ Metin bloğu (en çok 460, ortalı metin, aralık 12)
│  ├─ "Rafların boş"  display 30/700
│  ├─ açıklama body textSecondary satır aralığı 1.55
│  └─ eylemler (üst 12, aralık 8): Primary "Mağaza Hesabı Bağla" h40 → .stores · Secondary "Oyun Ekle" h40 → .addGame
└─ DropHint  (02-components): arrow.down.to.line + "Ya da bir .exe ya da kurulum dosyasını pencereye sürükle" (".exe" mono 12 textPrimary)
```

## Etkileşim

- Pencereye `.exe` bırakılırsa → `.addGame` sayfası o dosyayla açılır; `.msi`/setup → kurulum akışı (05). Mevcut sürükle-bırak mantığı (`ImportGameSheet` / `AppModel`) yeniden kullanılır.

## Animasyonlar

| t (s) | Öğe | Animasyon |
|---|---|---|
| 0 → sonsuz | 3 hayalet kapak | `bobbing(delay: 0 / 0.65 / 1.3)` (4 s döngü, y 0↔−8) |
| 0.00 | başlık | `enterOnAppear()` |
| 0.08 | açıklama | `enterOnAppear(delay: 0.08)` |
| 0.16 | düğmeler | `enterOnAppear(delay: 0.16)` |
| 0.24 | DropHint | `enterOnAppear(delay: 0.24)` + kenar `edgePulse` sonsuz |
| sürükleme sırasında | DropHint | kenar sabit `accent`, zemin `card`, `quick` |

Azaltılmış hareket: salınım ve kenar nabzı yok; kapaklar sabit durur.

## Metinler

`empty.v2.title`, `empty.v2.body`, `empty.v2.connect`, `empty.v2.drop` → 03-strings.md. "Oyun Ekle" mevcut.
