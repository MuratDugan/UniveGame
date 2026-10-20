# 05 — Kurulum akışı (Giriş / İlerleme / Program Seçimi)

Reference: `reference/V2Installer.dc.html` (etkileşimli; `step` 0/1/2). Sarmalayıcılar `V2InstallFile`, `V2InstallProgress`, `V2InstallChoose` başlangıç adımını seçer.
Swift: `InstallerSheet.swift` → `InstallerFlowView` (tam pencere). Mantık aynı: `InstallerSession` ve `session.phase`.

## Sunum

- Sheet değil: `model.installer != nil` iken `ContentView` Rail'i gizler ve `detail` yerine `InstallerFlowView(session:)` gösterir (`.transition(.opacity.combined(with: .move(edge: .bottom)))` yerine sadece `.opacity` + içerik `enterOnAppear` — sayfa kaymaz).
- Kapatma: üst çubuktaki "Kapat"; kurulum çalışıyorsa önce onay (`confirmationDialog`, mevcut iptal mantığı).

## Faz → adım eşlemesi

| `InstallerSession.Phase` | StepRail adımı | Sağ içerik |
|---|---|---|
| `.ready` | 1 Dosya (şimdi) | Giriş |
| `.preparing`, `.installingRuntime`, `.running`, `.finishing` | 2 Kurulum (şimdi), 1 bitti | İlerleme; günlük satırları faza göre |
| `.choosing` | 3 Başlatıcı (şimdi), 1–2 bitti | Program seçimi |
| `.failed(msg)` | o anki adım, daire `destructive` + `xmark` | Hata kutusu (NoticeBanner destructive) + "Tekrar Dene" Primary + "Başka Bir Dosya Seç…" |

## Yerleşim

```
VStack(spacing: 0)
├─ TopBar h52, alt 1pt border: [sol 200: trafik ışıkları alanı] · ortada "Oyun kur" 13/600 · [sağ 200: Secondary "Kapat" h30]
└─ HStack(spacing: 0)
   ├─ StepRail paneli 320 genişlik, iç boşluk 40×32, sağda 1pt border (02 → StepRail) + altta dosya kartı
   └─ İçerik: yatay ortalı, genişlik 620, üst 64
      ├─ Adım 1 — Giriş
      │  ├─ "Kurulum dosyası hazır" display + açıklama body textSecondary (1.55)
      │  ├─ Bilgi listesi (card, border, lg): Kurulacağı yer (mono "C:\Games\" + "Değiştir") · Motor ("Motor 1.0.0 · Wine 11.18") · Boş alan ("184 GB kullanılabilir"); satır iç boşluk 14×16, etiket sütunu 130
      │  └─ Eylemler: Secondary "Başka Bir Dosya Seç…" · Spacer · Primary "Kurulumu Başlat"
      ├─ Adım 2 — İlerleme
      │  ├─ "Kurulum programı açık" display + "Kurulum penceresinde Bitir'e bastığında burası kendiliğinden devam eder."
      │  ├─ Durum kartı (card, border, lg, iç boşluk 20, aralık 10)
      │  │  ├─ satır: nokta 8 accent .pulsing() + "Çalışıyor" 600 · Spacer · geçen süre caption monoDigit ("1 dk 12 sn", TimelineView ile her saniye)
      │  │  ├─ IndeterminateBar h6
      │  │  └─ günlük (mono 12 textSecondary, aralık 6): faz geçtikçe satır eklenir; son satır textPrimary + pulsing
      │  └─ Eylemler: Secondary "Kurulumu Durdur" (yazı destructive 600) · Spacer · Secondary "Kurulum Penceresini Göster"
      └─ Adım 3 — Program seçimi
         ├─ "Kurulum tamamlandı" display + "C:\Games\S2Rebirth klasörüne kuruldu. Oyunu hangi program başlatıyor?" (yol mono textPrimary)
         ├─ ProgramChoiceRow × n (aralık 8) — önerilen ilk ve seçili
         ├─ Ad TextField h32 + Secondary "Kapak Ekle" h32 (alt hizalı)
         └─ Eylemler: Secondary "Başka Bir Dosya Seç…" · Spacer · Primary "Kütüphaneye Ekle"
```

Günlük satırları (faz → metin): `.preparing` "Windows ortamı hazırlanıyor" → bitince "Windows ortamı hazır"; `.installingRuntime` "Wine Mono kuruluyor"; `.running` "<dosya> başlatıldı", "Kurulum penceresi açık…"; `.finishing` "Kurulum kapandı, son işlemler bekleniyor…".

## Animasyonlar

| Tetik | Öğe | Animasyon |
|---|---|---|
| adım içeriği görününce | başlık / kart / eylemler | `enterOnAppear(delay: 0 / 0.08 / 0.16)` — adım değişince içerik `.id(step)` ile yeniden kurulur, zincir yeniden oynar |
| adım ilerleyince | StepRail çizgisi | yükseklik `valueChange` (0.6 s) |
| adım ilerleyince | biten adımın dairesi | halka → dolu `success` + checkmark, easeOut 0.3; checkmark `.transition(.scale(0.6).combined(with: .opacity))` |
| Adım 2 | durum noktası, son günlük satırı | `.pulsing()` |
| Adım 2 | ilerleme | `IndeterminateBar` |
| Adım 2 | yeni günlük satırı | `.transition(.opacity.combined(with: .offset(y: 6)))`, `enter` eğrisi |
| Adım 3 | seçenek satırları | `enter(index: i, base: 0.08)`; seçim kenarı + radyo `quick` |

Reference'taki günlük gecikmeleri (300/700/1100 ms) demo; gerçekte satır faz değişince eklenir.

## Metinler

`installer.title`, `installer.close`, `installer.step.file`, `installer.step.file.detail`, `installer.step.run`, `installer.step.run.detail`, `installer.step.pick`, `installer.step.pick.detail`, `installer.ready.title`, `installer.ready.body`, `installer.info.location`, `installer.info.engine`, `installer.info.space`, `installer.running.title`, `installer.running.body`, `installer.running.state`, `installer.log.*`, `installer.done.title`, `installer.done.body` → 03-strings.md. Mevcut `installer.*` anahtarlarıyla çakışanlar mevcutları kullanır.
