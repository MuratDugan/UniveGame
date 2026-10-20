# 08 — Ayarlar

Reference: `reference/V2Settings.dc.html` (etkileşimli: bölümler arasında geçiş, "Motoru İndir" → indirme durumu). Varsayılan açık bölüm DirectX 12.
Swift: `SettingsView.swift` (iki bölmeli), `D3DMetalSetup.swift` (`D3DMetalSetupPanel` → zaman çizgisi; `LicenseSheet` korunur).

## Yerleşim

```
HStack(spacing: 0)
├─ SectionNav 240 genişlik, iç boşluk üst 52 yatay 16, sağda 1pt border, aralık 4
│  ├─ "Ayarlar" display 30/700, sol 12, alt 16
│  └─ satır × 4: h40, iç boşluk 12, köşe md, simge 16 + 10 + etiket 13
│     Genel (globe) · Motor (cpu) · DirectX 12 (square.stack.3d.up) · Hakkında (info.circle)
│     seçili: zemin card, simge accent, yazı textPrimary 600 · değil: textSecondary 500, hover card
│     DirectX 12 satırında D3DMetal kurulu değilse sağda 8pt warning nokta (accessibilityLabel "Kurulum gerekiyor")
└─ İçerik: iç boşluk üst 112, yatay 56, en çok 640 genişlik
```

Bölüm seçimi `@State` (ya da `model.settingsSection`, oyun sayfasındaki "Kur" buraya `.directX12` ile gelir).

### Genel
- "Genel" title 20/600; "Dil" 13/600 + SegmentedPicker 420 genişlik (Sistem / Türkçe / English, h28, 13 pt) + "Değişiklik hemen uygulanır." caption. Bağlantı: mevcut `Localizer.language`.

### Motor
- "Motor" title. Kart (card, border, lg, iç boşluk 20, aralık 16): sürüm "1.0.0" display 30/700 monoDigit · [nokta success pulsing + "Hazır" 13/600 success / "Wine 11.18 (Staging) · DXVK" caption] · Spacer · Secondary "Yeni Motor Var mı Bak" h34 · Secondary "Yeniden Tara" h34.
- Altında açıklama caption textSecondary (mevcut `settings.engine.help`). Motor indirilirken nokta accent + IndeterminateBar.

### DirectX 12 (D3DMetal) — zaman çizgisi
- Başlık satırı: title "DirectX 12 (D3DMetal)" + durum çipi (h22 Capsule elevated): "Kurulmadı" textSecondary · indirirken "Adım 1 / 2" accent · hazır "Hazır" success + checkmark.
- Açıklama body textSecondary (1.55).
- Zaman çizgisi: dikey, adımlar arası 32. Sol: 32pt daire (şimdi: 2pt accent halka, numara accent 13/700; sırada: borderStrong halka, textSecondary; bitti: success dolu + checkmark), daire merkezinden aşağı 2pt `elevated` çizgi. Sağ: adım kartı (iç boşluk 16, köşe lg, border; şimdiki adım zemin card, diğeri surface), aralık 8.
  1. "D3DMetal motorunu indir" + açıklama + **Primary "Motoru İndir"** (h36). İndirme sürerken düğme yerine: satır [nokta accent pulsing + "İndiriliyor" 12/600 · Spacer · "182 / 290 MB · 40 sn kaldı" caption monoDigit], 6pt ölçü (accent dolgu = `EngineInstallProgress.fraction`, `valueChange`), Secondary "Vazgeç" h30.
  2. "Apple'ın Game Porting Toolkit'ini ekle" + açıklama + Secondary "Apple'ın İndirme Sayfasını Aç" + Secondary "İndirdiğim Dosyayı Seç…" (mevcut eylemler).
- Lisans notu caption `textTertiary`, sol 48 girintili.
- Ekrandaki tek Primary "Motoru İndir"; adım 1 bitince Primary adım 2'nin "İndirdiğim Dosyayı Seç…" düğmesine geçer.

### Hakkında
- "UniveGame" display + sürüm satırı caption.

## Animasyonlar

| Tetik | Öğe | Animasyon |
|---|---|---|
| bölüm açılınca | başlık / kart(lar) / not | `enterOnAppear(delay: 0 / 0.06–0.08 / 0.12–0.22)`; içerik `.id(section)` ile yeniden kurulur |
| SectionNav seçimi | satır zemini, simge rengi | `quick` |
| Dil seçimi | seçili parça | `matchedGeometryEffect` kayma `quick` |
| "Motoru İndir" | düğme → ilerleme bloğu | `.transition(.opacity)` + blok `enterOnAppear()`; ölçü dolgusu gerçek orana `valueChange` ile ilerler (reference'ta demo amaçlı %62'ye 2.4 s'de dolar) |
| indirme | nokta | `.pulsing()` |
| adım bitince | daire | halka → success dolgu + checkmark, easeOut 0.3; durum çipi metni `.contentTransition(.opacity)` |
| Motor hazır | nokta | `.pulsing()` |

## Metinler

`settings.section.general`, `settings.section.engine`, `settings.section.dx12`, `settings.section.about`, `settings.dx12.needsSetup`, `d3dmetal.step`, `d3dmetal.downloading`, `d3dmetal.progress` ("%1$@ / %2$@ MB · %3$@ kaldı"), `d3dmetal.status.notInstalled`, `d3dmetal.status.ready` → 03-strings.md. Adım başlıkları, açıklamalar ve düğmeler mevcut `d3dmetal.*` anahtarlarından.
