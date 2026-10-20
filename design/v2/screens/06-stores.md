# 06 — Mağazalar

Reference: `reference/V2Stores.dc.html`. Swift: `StoresView.swift` (`StoreCard` → `StoreRow`). Giriş sheet'i (`StoreLoginSheet`) aynen kalır.

## Yerleşim

```
ScrollView, iç boşluk: üst 52, yatay 48, aralık 28
├─ Başlık satırı HStack(alignment: .bottom, spacing: 32)
│  ├─ PageHeader: "Mağazalar" + "Her mağaza kendi Windows ortamında çalışır. Girişi mağazanın kendi sayfasında yaparsın."
│  └─ ConnectionMeter 300 genişlik (aralık 8)
│     ├─ caption textSecondary: "**2 / 5** mağaza bağlı" (sayı textPrimary 600 monoDigit) · Spacer · "243 oyun" monoDigit
│     └─ 5 parça HStack(spacing: 4), her biri h6 köşe 3: bağlı → success, değil → elevated
└─ StoreRow × 5 (VStack aralık 8)
   HStack(spacing: 16), iç boşluk 16×20, köşe lg, 1pt border, hoverFill(card → cardHover)
   ├─ simge karosu 44×44 elevated köşe md, GameSource.symbol 20pt textPrimary
   ├─ metin 360 sabit: ad statSmall 15/600 + açıklama caption textSecondary (1.45)
   ├─ durum (esnek, aralık 6)
   │  ├─ nokta 8 + durum 12/600 (renk aşağıda)
   │  ├─ meta caption textSecondary monoDigit
   │  └─ (eşitleniyorsa) IndeterminateBar 160×3
   └─ eylemler HStack(spacing: 8), düğmeler h34
```

## Durum → görünüm

| `StoreConnection` / iş | Nokta + yazı | Meta | Düğmeler |
|---|---|---|---|
| eşitleniyor (refresh sürüyor) | accent, `.pulsing()`, "Eşitleniyor" | "196 oyun · 3 yeni bulundu" | ikincil (ör. "Steam'i Aç") |
| `.ready` | success, "Bağlı" | "47 oyun · 2 dk önce eşitlendi" | "Yenile", "Çıkış Yap" (mağazaya göre mevcut eylemler) |
| `.needsSignIn` | warning, "Giriş gerekli" | — | Primary "Giriş Yap" |
| `.notSetUp` | elevated renkli nokta (#3A3A40), "Kurulmadı" yazı textSecondary | yaklaşık indirme boyutu (biliniyorsa) | "Kur" / "Başlatıcıyı Kur" |

**Tek Primary kuralı**: ekrandaki Primary, listede **ilk** `.needsSignIn` ya da (yoksa) ilk `.notSetUp` mağazanın eylemidir; diğerleri Secondary. Reference'ta GOG "Kur" Primary.

Kurulum sürerken satırdaki eylemler yerine `IndeterminateBar` (indirme yüzdesi biliniyorsa 6pt dolu ölçü `valueChange`) + "Vazgeç".

## Animasyonlar

| t (s) | Öğe | Animasyon |
|---|---|---|
| 0.00 | PageHeader | `enterOnAppear()` |
| 0.08 | ConnectionMeter | `enterOnAppear(delay: 0.08)`; parçalar `growOnAppear(delay: 0.3)` |
| 0.14 + i×0.06 | StoreRow i | `enter(index: i, base: 0.14)` |
| durum değişince | nokta rengi, metin | `quick` + `.contentTransition(.opacity)`; bağlanan mağazanın meter parçası `success`'e `valueChange` ile döner |
| eşitleme | nokta + çubuk | `.pulsing()` + `IndeterminateBar` |

## Metinler

Yeni (→ 03-strings.md): `stores.v2.title`, `stores.v2.subtitle`, `stores.meter.connected` ("%1$@ / %2$@ mağaza bağlı"), `stores.status.syncing`, `stores.meta.synced` ("%1$@ oyun · %2$@ eşitlendi"), `stores.meta.found` ("%@ yeni bulundu"). Mevcut: `stores.gameCount` (meter'daki "243 oyun"), `stores.status.ready` ("Bağlı"), `stores.status.signIn`, `stores.status.notSetUp`. Mağaza açıklamaları mevcut `stores.<mağaza>.about` anahtarları; düğmeler `stores.setUp`, `stores.installLauncher`, `stores.signIn`, `stores.signOut`, `stores.openLauncher`.
