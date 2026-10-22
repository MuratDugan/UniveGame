<p align="center">
  <img src="docs/brand/banner.jpg" alt="UniveGame: Steam, Epic, GOG, Ubisoft, EA ve kendi .exe oyunlarını Apple Silicon Mac'lerde çalıştıran ücretsiz, açık kaynak oyun başlatıcı" width="100%">
</p>

<h1 align="center">UniveGame</h1>

<p align="center">
  <strong>Windows oyunlarını Mac'te oyna.</strong><br>
  Apple Silicon için ücretsiz ve açık kaynak oyun başlatıcı. Steam, Epic Games, GOG, Ubisoft Connect, EA app ve kendi
  <code>.exe</code> oyunların tek kütüphanede, her biri Mac'te ne kadar iyi çalışacağına göre dizili.
</p>

<p align="center">
  <a href="https://github.com/MuratDugan/UniveGame/releases/latest"><img alt="macOS için indir" src="https://img.shields.io/github/v/release/MuratDugan/UniveGame?label=macOS%20i%C3%A7in%20indir&color=4D8EFF&style=for-the-badge"></a>
</p>

<p align="center"><a href="README.md">English</a></p>

---

UniveGame, Windows oyunlarını [Wine](https://www.winehq.org), [DXVK](https://github.com/doitsujin/dxvk) ve Apple'ın
D3DMetal'i ile macOS'ta çalıştırır. Önce Wine ortamı kurmakla ya da forum okumakla uğraşmazsın: mağazalarını bağlarsın,
kütüphane hangi oyunların oynamaya hazır olduğunu, hangilerinin yüklemeye değdiğini ve hangilerinin Mac'te neden
açılmayacağını söyler. Ücretsizdir ve öyle kalacak.

<p align="center">
  <img src="docs/screenshots/library.jpg" alt="UniveGame kütüphanesi: seçili oyun için uyumluluk puanlı sahne ve raflar" width="100%">
</p>

## Özellikler

- **Her mağaza tek kütüphanede.** Steam (sadece yüklü olanlar değil, sahip olduğun bütün oyunlar), Legendary ile
  Epic Games Store, gogdl ile GOG, Ubisoft Connect, EA app ve elindeki her Windows `.exe` dosyası.
- **Çalışma durumuna göre raflar.** *Oynamaya hazır*, *Yükle ve oyna*, *Mac'te zor*, *Henüz incelenmedi*.
- **Her oyun için uyumluluk puanı.** 0–100 puan, Mükemmel'den Çalışmaz'a bir seviye, güven derecesi ve her gerekçe:
  DirectX sürümü, 32/64-bit, oyun motoru, anti-cheat, Steam Deck sonucu, ProtonDB raporları.
- **Windows'taki gibi kurulum.** `setup.exe` ya da `.msi` dosyasını pencereye bırak. Kendi Windows ortamında çalışır,
  `C:\Games\...` yolları olduğu gibi işler, kurulum kapanınca UniveGame oyunun başlatıcısını bulur. Kurulum programı
  Wine'da çalışmazsa UniveGame paketi doğrudan açar (Inno Setup, NSIS, MSI, 7z, ZIP, RAR, CAB).
- **DirectX 9'dan 12'ye.** DirectX 10/11 için DXVK, eski oyunlar için WineD3D, DirectX 12 için Apple'ın D3DMetal'i
  (kendi indirdiğin Game Porting Toolkit'ten iki adımda kurulur).
- **Oyun başına ayarlar.** Grafik katmanı, Retina, MetalFX, performans göstergesi, Command → Control.
- **Kapaklar kendiliğinden bulunur.** Elle eklediğin oyunun kapağını ve görselini adından, kendi dilinde arar.
- **Keşfet.** Steam'in öne çıkanları ve indirimleri, sahip olduğun oyunlar için Mac puanıyla.
- **Türkçe ve İngilizce**, yeniden başlatmadan değişir.

## İndirme

1. [Releases](https://github.com/MuratDugan/UniveGame/releases/latest) sayfasından son **UniveGame-x.y.z.dmg**
   dosyasını indir.
2. Aç ve UniveGame'i Uygulamalar klasörüne sürükle.
3. Başlat; bir mağaza bağla ya da bir Windows oyununu pencereye bırak.

Uygulama Developer ID ile imzalı ve Apple tarafından notarize edilmiştir; Gatekeeper uyarısı vermez.
**Apple Silicon Mac'te macOS 15 ya da üstü** gerekir. İlk açılışta Wine motorunu (yaklaşık 140 MB) indirir.

## Uyumluluk puanı nasıl hesaplanır?

Oyun sayfasında **İncele**, kütüphane menüsünde **Tüm Kütüphaneyi İncele** var.

| Kaynak | Ne söylüyor |
|---|---|
| Oyun dosyaları (yüklüyse) | PE başlıkları ve içe aktarımlar: 32/64-bit, DirectX 8/9/10/11/12, OpenGL, Vulkan; motor (Unity, Unreal 4/5, Source…), anti-cheat dosyaları, başlatıcılar, .NET, Media Foundation, Chromium |
| Steam önbelleği (yerel) | Steam Deck sonucu ve sebebi, macOS sürümü, çıkış yılı |
| Steam mağazası | Sistem gereksinimlerindeki DirectX sürümü, yoksa ekran kartından tahmin |
| [ProtonDB](https://www.protondb.com) | Linux'ta Wine ile oyuncu puanları |
| [AreWeAntiCheatYet](https://areweanticheatyet.com) | Anti-cheat türü ve durumu (Steam/Epic kimliğiyle eşleşir) |

Ağırlıklar Mac'e göre: çekirdek seviyesi anti-cheat (EAC, BattlEye, Vanguard…) Linux'ta desteklense bile her zaman
**Çalışmaz**; DirectX 11/10 DXVK ile hızlı; DirectX 12 D3DMetal ister; DirectX 9 OpenGL üzerinden yavaş. Raporlar
kanıtlarıyla saklanır; kurallar değişince puanlar internet olmadan yeniden hesaplanır. Puan bir tahmindir, söz değil.

## Steam senkronizasyonu

Mağazalar'dan Steam'i kurup Steam penceresinde giriş yaptıktan sonra UniveGame'e dönmen yeterli. Kütüphane, uygulama
her öne geldiğinde ve Steam kapandığında yenilenir. Sahip olunan bütün oyunlar, Steam'in önbelleğindeki kapaklar ve
oynama süreleri Steam'in kendi dosyalarından (`appinfo.vdf`, `librarycache`, `localconfig.vdf`) okunur.

## Kurulum dosyasıyla gelen oyunlar (setup.exe / .msi)

1. UniveGame kendi oyunların için ayrı bir Windows ortamı hazırlar; istersen .NET çalışma zamanını (Wine Mono) da kurar.
2. Kurulum, Windows'taki gibi kendi penceresinde açılır.
3. Kurulum kapanınca UniveGame, başlattığı programların bitmesini bekler ve C: sürücüsünde yeni çıkan `.exe`
   dosyalarını bulur. Başlatıcıyı öne alır, kaldırıcıları ve yardımcı programları eler.
4. Oyunu başlatan programı onaylarsın. Kaldırıcı hatırlanır; **Kaldır…** oyunun kendi kaldırma programını çalıştırır.

## Kaynaktan derleme

macOS 15+, Apple Silicon ve **Xcode 16 ya da üstü** gerekir (SwiftUI makroları Command Line Tools'ta yok).

```bash
git clone https://github.com/MuratDugan/UniveGame.git
cd UniveGame
scripts/bundle.sh debug                      # build/UniveGame.app
open build/UniveGame.app
open -n build/UniveGame.app --args --demo    # motor ve hesap olmadan arayüzü dene
swift test
```

Swift Package Manager motor kütüphanesi [UniveEngine](https://github.com/MuratDugan/UniveEngine)'i sabit bir
commit'ten indirir. Geliştirme parametreleri: `--section discover|stores|add|settings|dx12`, `--open steam:1145360`,
`--install <setup.exe> [--no-runtime] [--start]`, `-appLanguage tr|en|system`.

### Sürüm ve dağıtım

- Sürüm numarası [`VERSION`](VERSION) dosyasında. Build numarası git commit sayısından gelir.
- `scripts/bundle.sh release`: bu Mac için ad-hoc imzalı `build/UniveGame.app`.
- `scripts/release.sh`: Developer ID ile imzalı (hardened runtime), notarize edilmiş ve staple'lanmış
  `build/UniveGame-<sürüm>.dmg`. Tek seferlik hazırlık:
  1. Xcode › Settings › Accounts › takım › Manage Certificates › + › **Developer ID Application**.
  2. account.apple.com'dan uygulamaya özel parola al, sonra
     `xcrun notarytool store-credentials UniveGame --apple-id <Apple ID> --team-id <Takım ID>`.

### Yapı

| Klasör | İçerik |
|---|---|
| `Sources/UniveGame/App/` | Uygulama girişi, `AppModel` (durum ve MacadeKit çağrıları), `Localizer` |
| `Sources/UniveGame/Models/` | `LibraryItem`, `CustomGame`, demo verisi |
| `Sources/UniveGame/Services/` | Kalıcı veri, Steam hesabı ve mağaza API'si, kurulum tarayıcı, uyumluluk puanlayıcı |
| `Sources/UniveGame/Views/` | Rail, kütüphane, oyun sayfası, oyun ekle, kurulum akışı, mağazalar, keşfet, ayarlar |
| `Sources/UniveGame/Theme/` | Renk, boşluk, yazı ve hareket token'ları |
| `Sources/UniveGame/Resources/` | Çeviriler (`en`, `tr`) ve uygulama simgesi |
| `design/` | v2 arayüz handoff'u, simge ve DMG tasarımı |
| `scripts/` | Paketleme ve release betikleri |

UniveGame kendi klasörünü (`~/Library/Application Support/UniveGame`) kullanır. Kendi eklediğin oyunlar mağaza
oyunlarından ayrı bir Wine ortamında çalışır.

Yeni bir dil eklemek için `Resources/en.lproj/Localizable.strings` dosyasını `xx.lproj` klasörüne kopyalayıp çevir ve
`AppLanguage`'a bir durum ekle.

## Yol haritası

- **UniveEngine:** Motor artık kendi reposunda: [UniveEngine](https://github.com/MuratDugan/UniveEngine). Kendi motor
  listesi ve release'leri var (her Wine derlemesinin tam kaynağıyla). Sıradaki adım: motorların CI'da sabit
  kaynaklardan derlenmesi, daha yeni Wine ve DXVK.
- Daha fazla mağaza ve oyun başına düzeltmeler.
- Uygulama içinden topluluk uyumluluk raporları.

## Lisans ve teşekkürler

UniveGame [Apache License 2.0](LICENSE) ile yayımlanır; atıflar [NOTICE](NOTICE) dosyasında.
[UniveEngine](https://github.com/MuratDugan/UniveEngine) (MacadeKit'ten türetildi, Apache 2.0; bkz.
[NOTICE](NOTICE)), [Wine](https://www.winehq.org),
[DXVK](https://github.com/doitsujin/dxvk), [MoltenVK](https://github.com/KhronosGroup/MoltenVK), Wine Mono,
[Legendary](https://github.com/derrod/legendary) ve gogdl üzerine kuruludur.

UniveGame; Valve, Epic Games, GOG, Ubisoft, Electronic Arts, Apple, CodeWeavers ya da Steale LLC ile bağlantılı
değildir. Adı geçen markalar sahiplerine aittir. Yazılım "olduğu gibi", garantisiz sunulur.
