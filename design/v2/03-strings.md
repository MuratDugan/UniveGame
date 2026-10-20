# 03 — Yeni yerelleştirme anahtarları

Aşağıdaki iki bloğu `Sources/UniveGame/Resources/tr.lproj/Localizable.strings` ve `en.lproj/Localizable.strings` dosyalarının sonuna ekle. Her ekranın anahtarlarını o ekranla aynı commit'te ekle.

Zaten var olan ve **yeniden tanımlanmayacak** anahtarlar: `installer.title`, `installer.step.run`, `engine.ready`, `stores.status.ready`, `stores.status.signIn`, `stores.status.notSetUp`, `stores.gameCount`, `stores.<mağaza>.about`, `stores.setUp`, `stores.installLauncher`, `stores.signIn`, `stores.signOut`, `stores.openLauncher`, `settings.engine.help`, `compat.*` (kademe, güven, faktörler), `d3dmetal.*` (adım başlıkları, açıklamalar, düğmeler), `import.*`, `launch.*`.

Biçim belirteçleri mevcut dosyalardaki gibi `%@` / `%1$@`. İngilizce metinler Türkçeyle aynı alana sığacak uzunlukta yazıldı.

## tr.lproj

```
/* v2 — Rail */
"rail.library" = "Kütüphane";
"rail.discover" = "Keşfet";
"rail.stores" = "Mağazalar";
"rail.add" = "Ekle";
"rail.settings" = "Ayarlar";
"rail.engine" = "Motor";

/* v2 — Kütüphane */
"library.chip.all" = "Tümü";
"library.search.v2" = "Oyun, kaynak ya da durum ara";
"shelf.ready" = "Oynamaya hazır";
"shelf.ready.hint" = "Yüklü oyunların";
"shelf.install" = "Yükle ve oyna";
"shelf.install.hint" = "Mac'te iyi çalışanlar";
"shelf.hard" = "Mac'te zor";
"shelf.hard.hint" = "Engel ya da bilinen sorun var";
"shelf.unknown" = "Henüz incelenmedi";
"shelf.unknown.hint" = "Puan için oyunu incele";
"stage.playtime" = "%@ oynandı";
"stage.openPage" = "Oyun sayfası";
"stage.whyBroken" = "Neden çalışmıyor?";
"stage.setUpD3DMetal" = "D3DMetal'i kur";
"cover.notAnalyzed" = "Henüz incelenmedi";

/* v2 — Boş kütüphane */
"empty.v2.title" = "Rafların boş";
"empty.v2.body" = "Steam ya da Epic hesabını bağla; oyunların gelir ve Mac'te ne kadar iyi çalışacaklarına göre raflara dizilir.";
"empty.v2.connect" = "Mağaza Hesabı Bağla";
"empty.v2.drop" = "Ya da bir .exe ya da kurulum dosyasını pencereye sürükle";

/* v2 — Oyun sayfası */
"game.back" = "Kütüphane";
"game.installAnyway" = "Yine de Yükle";
"game.fact.status" = "Durum";
"game.fact.playtime" = "Oynama süresi";
"game.fact.lastPlayed" = "Son oynama";
"game.fact.location" = "Konum";
"game.fact.size" = "Tahmini boyut";
"game.fact.source" = "Kaynak";
"compat.notice.blocked" = "Mac'te açılmaz";
"compat.notice.blocked.body" = "Bu engel kalkana kadar yüklesen de oyun açılmaz.";
"compat.notice.track" = "Durumu takip et";
"compat.notice.d3d" = "Önce D3DMetal'i kur";
"compat.notice.d3d.body" = "Bu oyun DirectX 12 kullanıyor. Motor yaklaşık 290 MB; Apple'ın Game Porting Toolkit'i de gerekir.";
"launch.backend.manual" = "%@ elle seçildi. Sorun olursa Otomatik'e dön.";

/* v2 — Oyun ekle */
"add.title" = "Oyun ekle";
"add.subtitle" = "Bir Windows oyununu kütüphanene getirmenin üç yolu var. Dosyalar yerinde kalır.";
"add.method.installed" = "Kurulu bir oyun";
"add.method.installed.detail" = "Oyunun .exe dosyasını seç";
"add.method.setup" = "Kurulum dosyası";
"add.method.setup.detail" = "setup.exe çalıştır, sonra ekle";
"add.method.store" = "Mağaza hesabı";
"add.method.store.detail" = "Steam, Epic, GOG, Ubisoft, EA";
"add.cover.found" = "%@'den bulundu";
"add.cover.other" = "Başka kapak seç…";
"add.firstLook" = "İlk inceleme:";
"add.drop" = "Bir .exe dosyasını buraya bırak ya da seçmek için tıkla";

/* v2 — Kurulum */
"installer.close" = "Kapat";
"installer.step.file" = "Dosya";
"installer.step.file.detail" = "Kurulum dosyasını gözden geçir";
"installer.step.run.detail" = "Windows ortamında çalışır";
"installer.step.pick" = "Başlatıcı";
"installer.step.pick.detail" = "Oyunu açan programı seç";
"installer.ready.title" = "Kurulum dosyası hazır";
"installer.ready.body" = "Kurulum programı UniveGame'in Windows ortamında, ayrı bir pencerede açılır. Oradaki adımları izle; bitince oyunu kütüphanene eklemene yardım ederiz.";
"installer.info.location" = "Kurulacağı yer";
"installer.info.engine" = "Motor";
"installer.info.space" = "Boş alan";
"installer.info.spaceValue" = "%@ kullanılabilir";
"installer.running.title" = "Kurulum programı açık";
"installer.running.body" = "Kurulum penceresinde Bitir'e bastığında burası kendiliğinden devam eder.";
"installer.running.state" = "Çalışıyor";
"installer.log.preparing" = "Windows ortamı hazırlanıyor";
"installer.log.prepared" = "Windows ortamı hazır";
"installer.log.runtime" = "Wine Mono kuruluyor";
"installer.log.started" = "%@ başlatıldı";
"installer.log.windowOpen" = "Kurulum penceresi açık…";
"installer.log.finishing" = "Kurulum kapandı, son işlemler bekleniyor…";
"installer.done.title" = "Kurulum tamamlandı";
"installer.done.body" = "%@ klasörüne kuruldu. Oyunu hangi program başlatıyor?";

/* v2 — Mağazalar */
"stores.v2.title" = "Mağazalar";
"stores.v2.subtitle" = "Her mağaza kendi Windows ortamında çalışır. Girişi mağazanın kendi sayfasında yaparsın.";
"stores.meter.connected" = "%1$@ / %2$@ mağaza bağlı";
"stores.status.syncing" = "Eşitleniyor";
"stores.meta.synced" = "%1$@ oyun · %2$@ eşitlendi";
"stores.meta.found" = "%@ yeni bulundu";

/* v2 — Keşfet */
"discover.v2.subtitle" = "Steam'de öne çıkanlar, Mac'te ne kadar iyi çalışacaklarıyla birlikte. Fiyatlar Steam mağazasından.";
"discover.chip.featured" = "Öne çıkanlar";
"discover.chip.deals" = "İndirimde";
"discover.chip.macGreat" = "Mac'te mükemmel";
"discover.chip.new" = "Yeni çıkanlar";

/* v2 — Ayarlar */
"settings.section.general" = "Genel";
"settings.section.engine" = "Motor";
"settings.section.dx12" = "DirectX 12";
"settings.section.about" = "Hakkında";
"settings.dx12.needsSetup" = "Kurulum gerekiyor";
"d3dmetal.step" = "Adım %1$@ / %2$@";
"d3dmetal.downloading" = "İndiriliyor";
"d3dmetal.progress" = "%1$@ / %2$@ MB · %3$@ kaldı";
"d3dmetal.status.notInstalled" = "Kurulmadı";
"d3dmetal.status.ready" = "Hazır";
```

## en.lproj

```
/* v2 — Rail */
"rail.library" = "Library";
"rail.discover" = "Discover";
"rail.stores" = "Stores";
"rail.add" = "Add";
"rail.settings" = "Settings";
"rail.engine" = "Engine";

/* v2 — Library */
"library.chip.all" = "All";
"library.search.v2" = "Search games, sources or status";
"shelf.ready" = "Ready to play";
"shelf.ready.hint" = "Your installed games";
"shelf.install" = "Install and play";
"shelf.install.hint" = "Run well on Mac";
"shelf.hard" = "Hard on Mac";
"shelf.hard.hint" = "Blocked or known issues";
"shelf.unknown" = "Not analyzed yet";
"shelf.unknown.hint" = "Analyze a game to get a score";
"stage.playtime" = "%@ played";
"stage.openPage" = "Game page";
"stage.whyBroken" = "Why won't it run?";
"stage.setUpD3DMetal" = "Set up D3DMetal";
"cover.notAnalyzed" = "Not analyzed yet";

/* v2 — Empty library */
"empty.v2.title" = "Your shelves are empty";
"empty.v2.body" = "Connect Steam or Epic. Your games arrive and line up on shelves by how well they'll run on your Mac.";
"empty.v2.connect" = "Connect a Store";
"empty.v2.drop" = "Or drag an .exe or installer onto the window";

/* v2 — Game page */
"game.back" = "Library";
"game.installAnyway" = "Install Anyway";
"game.fact.status" = "Status";
"game.fact.playtime" = "Play time";
"game.fact.lastPlayed" = "Last played";
"game.fact.location" = "Location";
"game.fact.size" = "Estimated size";
"game.fact.source" = "Source";
"compat.notice.blocked" = "Won't open on Mac";
"compat.notice.blocked.body" = "Until this block is lifted, the game won't open even if you install it.";
"compat.notice.track" = "Track status";
"compat.notice.d3d" = "Set up D3DMetal first";
"compat.notice.d3d.body" = "This game uses DirectX 12. The engine is about 290 MB, and Apple's Game Porting Toolkit is also needed.";
"launch.backend.manual" = "%@ chosen manually. If anything breaks, switch back to Automatic.";

/* v2 — Add game */
"add.title" = "Add a game";
"add.subtitle" = "Three ways to bring a Windows game into your library. Files stay where they are.";
"add.method.installed" = "An installed game";
"add.method.installed.detail" = "Choose the game's .exe";
"add.method.setup" = "An installer";
"add.method.setup.detail" = "Run setup.exe, then add";
"add.method.store" = "A store account";
"add.method.store.detail" = "Steam, Epic, GOG, Ubisoft, EA";
"add.cover.found" = "Found on %@";
"add.cover.other" = "Choose another cover…";
"add.firstLook" = "First look:";
"add.drop" = "Drop an .exe here or click to choose one";

/* v2 — Installer */
"installer.close" = "Close";
"installer.step.file" = "File";
"installer.step.file.detail" = "Review the installer";
"installer.step.run.detail" = "Runs in the Windows environment";
"installer.step.pick" = "Launcher";
"installer.step.pick.detail" = "Choose what opens the game";
"installer.ready.title" = "Installer ready";
"installer.ready.body" = "The installer opens in a separate window inside UniveGame's Windows environment. Follow its steps; when it's done, we'll help you add the game.";
"installer.info.location" = "Install to";
"installer.info.engine" = "Engine";
"installer.info.space" = "Free space";
"installer.info.spaceValue" = "%@ available";
"installer.running.title" = "Installer is open";
"installer.running.body" = "Click Finish in the installer window and this continues on its own.";
"installer.running.state" = "Running";
"installer.log.preparing" = "Preparing the Windows environment";
"installer.log.prepared" = "Windows environment ready";
"installer.log.runtime" = "Installing Wine Mono";
"installer.log.started" = "Started %@";
"installer.log.windowOpen" = "Installer window is open…";
"installer.log.finishing" = "Installer closed, waiting for it to finish…";
"installer.done.title" = "Installation complete";
"installer.done.body" = "Installed to %@. Which program starts the game?";

/* v2 — Stores */
"stores.v2.title" = "Stores";
"stores.v2.subtitle" = "Each store runs in its own Windows environment. You sign in on the store's own page.";
"stores.meter.connected" = "%1$@ / %2$@ stores connected";
"stores.status.syncing" = "Syncing";
"stores.meta.synced" = "%1$@ games · synced %2$@";
"stores.meta.found" = "%@ new found";

/* v2 — Discover */
"discover.v2.subtitle" = "Featured on Steam, with how well each will run on your Mac. Prices from the Steam store.";
"discover.chip.featured" = "Featured";
"discover.chip.deals" = "On sale";
"discover.chip.macGreat" = "Great on Mac";
"discover.chip.new" = "New releases";

/* v2 — Settings */
"settings.section.general" = "General";
"settings.section.engine" = "Engine";
"settings.section.dx12" = "DirectX 12";
"settings.section.about" = "About";
"settings.dx12.needsSetup" = "Setup needed";
"d3dmetal.step" = "Step %1$@ of %2$@";
"d3dmetal.downloading" = "Downloading";
"d3dmetal.progress" = "%1$@ / %2$@ MB · %3$@ left";
"d3dmetal.status.notInstalled" = "Not installed";
"d3dmetal.status.ready" = "Ready";
```

Not: `add.cover.found` Türkçede kaynak adına göre ek alır ("Steam'den", "GOG'dan"). Türkçe için `%@` yerine kaynağa özel anahtar kullan: `add.cover.found.steam` = "Steam'den bulundu", `add.cover.found.gog` = "GOG'dan bulundu"; İngilizce genel anahtarla kalabilir.
