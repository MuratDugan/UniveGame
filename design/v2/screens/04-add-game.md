# 04 — Oyun Ekle

Reference: `reference/V2AddGame.dc.html` ("Kurulu bir oyun" seçili, dosya seçilmiş, kapak bulunmuş hâl).
Swift: yeni `Views/AddGameView.swift`. Dosya seçme, kapak bulma (`CoverFinder`), kaydetme mantığı `ImportGameSheet`'ten taşınır/paylaşılır (ortak bir `ImportDraft` modeli önerilir; sheet ve sayfa aynı modeli kullanır).

Açılış: Rail "Ekle" (`.addGame`), menü komutu, boş kütüphane, pencereye `.exe` bırakma.

## Yerleşim

```
ScrollView, iç boşluk: üst 52, yatay 48, aralık 24
├─ PageHeader: "Oyun ekle" + "Bir Windows oyununu kütüphanene getirmenin üç yolu var. Dosyalar yerinde kalır."
├─ MethodTile × 3 (3 sütun, aralık 16)   [radiogroup]
│  ├─ "Kurulu bir oyun" · "Oyunun .exe dosyasını seç"  (doc.badge.checkmark)  ← bu sayfanın formu
│  ├─ "Kurulum dosyası" · "setup.exe çalıştır, sonra ekle" (shippingbox)        → dosya seç → kurulum akışı (05)
│  └─ "Mağaza hesabı" · "Steam, Epic, GOG, Ubisoft, EA" (link)                 → .stores
└─ Form paneli (card, border, lg, iç boşluk 24) Grid [180 | esnek], aralık 32
   ├─ Sol (aralık 10, sola hizalı)
   │  ├─ Kapak 180×270, köşe md, borderStrong, gölge cover-hero
   │  ├─ çip "Steam'den bulundu" (h22, Capsule, elevated, checkmark success 12 + 12/500)
   │  └─ bağlantı "Başka kapak seç…" caption 500 accent
   └─ Sağ (aralık 18)
      ├─ Dosya satırı: iç boşluk 14, köşe md, zemin surface, kesik kenar 1pt accent %50
      │  36pt karo (dosya seçildiyse checkmark.circle.fill success) · ad mono 12 · "~/Oyunlar/Hollow Knight/ · 64-bit · DirectX 11" mono textSecondary · "Değiştir…" bağlantı
      ├─ İki sütun (aralık 16): Ad (TextField h32) + yardım · Başlatma seçenekleri (mono TextField h32, yer tutucu "-windowed -dx11") + yardım
      ├─ İlk inceleme satırı: iç boşluk 12×14, köşe md, zemin surface: checkmark.circle.fill success 16 + caption "İlk inceleme: **96 · Mükemmel** · Steam Deck Doğrulandı, DXVK ile çalışır."
      └─ Eylemler sağa: Secondary "Vazgeç" h40 · Primary "Kütüphaneye Ekle" h40
```

### Durumlar

| Durum | Sol | Dosya satırı | İlk inceleme | Primary |
|---|---|---|---|---|
| Dosya yok | Kapak yer tutucu (elevated, `photo` simgesi, "Kapak eklenecek") | Büyük bırakma alanı: kesik kenar `edgePulse`, "Bir .exe dosyasını buraya bırak ya da seçmek için tıkla", sağda "Seç…" | gizli | disabled |
| Dosya seçildi, kapak aranıyor | Kapak yer tutucu + 6pt `IndeterminateBar` altta | dolu | "İnceleniyor…" + ProgressView | enabled |
| Kapak bulundu (reference) | Kapak `popOnAppear`, çip `popOnAppear(delay: 0.2)` | dolu | puan | enabled |
| Kapak bulunamadı | Yer tutucu + "Kapak ekle…" düğmesi | dolu | puan | enabled |

İlk inceleme: dosya seçilince `GameFileAnalyzer` ile yerel tarama (mevcut uyumluluk servisi); çevrimiçi kaynaklar eklendikten sonra kaydedilir. Bu satır isteğe bağlı bir iyileştirme — servis hızlı sonuç veremiyorsa satırı gizle.

## Animasyonlar

| t (s) | Öğe | Animasyon |
|---|---|---|
| 0.00 | PageHeader | `enterOnAppear()` |
| 0.06 / 0.12 / 0.18 | MethodTile 1–3 | `enter(index: i, base: 0.06)` |
| 0.24 | Form paneli | `enterOnAppear(delay: 0.24)` |
| kapak bulununca | kapak | `popOnAppear()` (ölçek 0.94→1, 0.5 s) |
| +0.20 | "Steam'den bulundu" çipi | `popOnAppear(delay: 0.2)` |
| dosya bırakılırken | bırakma alanı | kenar sabit `accent`, zemin `card` (`quick`) |

Reference'taki 700/900 ms gecikmeler "arama sürdü" hissi için demo; uygulamada gecikme yok, animasyon sonuç geldiği an başlar.

MethodTile hover `cardHover`; seçim kenarı `quick`.

## Metinler

`add.title`, `add.subtitle`, `add.method.installed`, `add.method.installed.detail`, `add.method.setup`, `add.method.setup.detail`, `add.method.store`, `add.method.store.detail`, `add.cover.found` ("%@'den bulundu"), `add.cover.other`, `add.firstLook`, `add.drop` → 03-strings.md. Ad/Başlatma seçenekleri/Vazgeç/Kütüphaneye Ekle mevcut `import.*` anahtarlarından.
