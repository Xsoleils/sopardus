# SOPARDUS: Ana Durum Belgesi

> Sürüm: v0.3 | Tarih: 2026-10-02 | Durum: Mimari kesinleşti, **Aşama 0 (install.sh)** tasarlandı, açık sorular karara bağlandı, kod henüz yok.
> Kural: Her mesaj sonunda bu dosya güncellenir. Bir şey kaybolmasın.

---

## 1. Proje özeti

- **Ad:** Sopardus (SO = Soleil, PARDUS = Pardus Linux)
- **Amaç:** Pardus tabanlı, modern, hızlı, estetik, **KDE Plasma 6 merkezli** masaüstü deneyimi.
- **İlkeler:** Wayland birinci sınıf (X11 yalnızca uyumluluk), düşük RAM, gereksiz ağır servis yok, NVIDIA + AMD desteği, açık kaynak, özgün görsel kimlik (Catppuccin vb. yalnızca ilham, kopya yok), sıfır telemetri.
- **Konumlandırma:** Pardus'un fork'u değil, **türevi/uzantısı**. Pardus ve Debian depoları üstüne ince bir katman.

---

## 2. Kesinleşen kararlar (karar günlüğü)

| # | Karar | Seçim |
|---|---|---|
| 1 | Taban sürüm | **Pardus 25.2 GNOME** ("Bilge") |
| 2 | Dosya sistemi | **Btrfs** (+ Snapper + grub-btrfs) |
| 3 | Plasma stratejisi | MVP'de taban deponun Plasma'sı, v1.0'da kendi backport hattı |
| 4 | Uygulama dili | MVP arka uçlar **Python**, kritik servisler sonra Rust/C++ |
| 5 | Lisans | Kod **GPL-3.0-or-later**, görsel varlıklar **CC-BY-SA 4.0** |
| 6 | Süreç kuralı | Her mesaj sonunda bu `.md` güncellenir |
| 7 | **Aşama 0** | İlk aşama bir **install.sh**: mevcut Pardus 25.2 GNOME kurulumunu Sopardus'a dönüştürür (ISO sonra) |
| 8 | **Ad** | **Sopardus.** Repo, script, paket öneki hep `sopardus`. "BetterPardus" kullanılmaz (Pardus adını öne çıkarır, marka riski). Her yerde "Pardus tabanlı, resmi olmayan türev" ibaresi; Pardus adı/logosu TÜBİTAK'a aittir, logo kullanılmaz. |
| 9 | **Hedef kitle** | Script baştan **genel kullanım** için yazılır. Kendi makinen ilk test ortamıdır ama güvenlik titizliği (`--dry-run`, `--revert`, idempotency, snapshot kontrolü) düşürülmez. Gerekçe: Aşama 1'de paketlere bölünecek kod zaten bu standartta olmalı. |
| 10 | **`--remove-gnome`** | **Aşama 0 kapsamı dışı.** Aşama 0'da GNOME yalnızca gizlenir/devre dışı bırakılır. Bayrak ayrılmış kalır, çağrılırsa "henüz desteklenmiyor" hatası verir. Aşama 1 sonrası, Pardus araçlarının bağımlılık analiziyle eklenir. |
| 11 | **Btrfs düzeni** | Düzen bilinmediği için script **algılar ve uyarlanır** (bkz. §5.6): `@` düzeni, düz düzen, Btrfs olmayan. Kesin karar gerçek çıktıya göre güncellenir ama kod üç yolu da taşır. |

**Kapanan açık:** Ad sorusu (karar 8).

---

## 3. Doğrulanmış gerçekler (kaynaklı arama sonucu)

- Pardus 25 = **Debian 13 "Trixie"** tabanlı. Pardus 25 GNOME 48.4 ve XFCE 4.20 ile geliyor. Çekirdek 6.12 serisi.
- Pardus 25.2 güncel masaüstü sürümü ("Bilge"), 25.0 serisinin ikinci ara güncellemesi.
- Pardus'un öncelikli desteklediği sürümler **XFCE ve Sunucu**. GNOME sürümü topluluk ekosistemine katkı için yayınlanıyor. (Sopardus için sorun değil ama bilinmeli.)
- Debian 13 deposunda **KDE Plasma 6.3.x** (6.3.6 olarak kabul edildi), Frameworks 6.13, Qt 6.8.2, Gear 25.04.2. Upstream Plasma bunun çok ilerisinde. **Plasma gerisinde kalma riski gerçek** ve v1.0 backport hattının gerekçesi bu.
- Debian 13 desteği: normal destek Ağustos 2028'e, LTS Haziran 2030'a kadar.

Doğrulanmamış / test edilecek: Pardus 25.2 GNOME'un Btrfs alt birim düzeni, Trixie'deki tam paket adları (aşağıdaki liste taslak).

---

## 4. Aşama planı (revize)

| Aşama | Çıktı | Not |
|---|---|---|
| **0** | `install.sh`: Pardus 25.2 GNOME → Sopardus (Plasma 6 Wayland + tema + tuning) | Hızlı doğrulama, ISO'suz |
| 1 | Script adımlarının `.deb` paketlerine taşınması (`sopardus-*`), kendi APT deposu | Script ince bir önyükleyiciye döner |
| 2 | Live-build ISO + Calamares | Paketler hazır olduğu için kolay |
| 3 | v1.0: Settings KCM'leri, Snapshots GUI, Driver Manager, Gaming Hub, backport hattı | |
| 4 | v1.x / v2: immutable mod, kendi çekirdek varyantı vb. | |

**Süreklilik ilkesi:** install.sh'taki her adım ileride bir pakete karşılık gelir. Script atılmaz, paketlere bölünür.

---

## 5. AŞAMA 0: install.sh tasarımı

### 5.1 Hedef
Temiz bir Pardus 25.2 GNOME kurulumunda tek komutla: Plasma 6 + SDDM + Wayland oturumu + Sopardus Ember teması + performans ayarları. **Geri alınabilir.**

### 5.2 Güvenlik ilkeleri
- `curl | sudo bash` **önerilmez.** Akış: `git clone` → incele → `sudo ./install.sh`.
- `set -Eeuo pipefail`, `trap ERR`, `eval` yok, tüm değişkenler tırnaklı, ShellCheck CI'da zorunlu.
- **İdempotent:** iki kez çalıştırmak zarar vermez.
- Her şey `/var/log/sopardus/install-<zaman>.log`'a yazılır.
- Yaptığı her değişiklik `/etc/sopardus/install.state` dosyasına kaydedilir (geri alma bunu kullanır).
- **GNOME varsayılan olarak silinmez** (Pardus'un kendi araçları GNOME parçalarına bağlı olabilir). Yalnızca gizlenir/devre dışı bırakılır. Kaldırma ayrı ve isteğe bağlı bayrak, önce `apt -s` önizlemesi.
- **İdempotency gerçek sistem durumuna bakar**, yalnızca state dosyasına değil: `dpkg -s`, `systemctl is-enabled`, `debconf-show`, dosya karşılaştırması. State dosyası geri alma içindir, "yapıldı mı" kararı için değil.
- `/etc/os-release` **değiştirilmez** (Aşama 0'da `ID=pardus` kalır, araçlar bozulmasın). Kimlik `/etc/sopardus-release`'te.

### 5.3 Akış (fazlar)
1. **Preflight:** root kontrolü, `apt-cache policy plasma-desktop` ile gerçek Plasma sürümünü loglama, Pardus güncelleme aracı ve güç aracı paketlerinin varlığı (çakışma uyarısı), `ID=pardus` ve sürüm 25.x, Debian trixie, amd64, ≥ 6 GB boş alan, ağ erişimi, kök dosya sistemi türü (`findmnt -no FSTYPE /`), GPU tespiti (`lspci`), VM tespiti.
2. **Snapshot:** Btrfs + snapper varsa `pre-sopardus` snapshot'ı. Btrfs değilse uyar, `/etc` yedeği al, kullanıcıdan açık onay iste. (Dönüştürme yapılmaz, riskli.)
3. **Paketler:** `apt-get install --no-install-recommends` ile seçilmiş Plasma seti (aşağıda).
4. **Oturum geçişi:** SDDM varsayılan DM yapılır (debconf preseed ile `shared/default-x-display-manager`), `gdm3` `systemctl disable` ile devre dışı (silinmez), `display-manager.service` bağı SDDM'e çevrilir. **Eski değerler (önceki DM, önceki bağ hedefi) state dosyasına yazılır**, `--revert` bunları kullanır. Plasma Wayland varsayılan oturum, X11 yedek.
5. **Tuning:** zram (systemd-zram-generator, zstd), `fstrim.timer`, makul sysctl, Baloo yalnızca dosya adı indeksleme.
6. **Tema ve varsayılanlar:** Ember renk şeması, Plasma/KWin/panel varsayılanları `/etc/xdg` ve `/etc/skel` altına, wallpaper'lar `/usr/share/wallpapers/Sopardus`.
7. **Opsiyoneller:** `--gaming`, `--nvidia`, `--remove-gnome`.
8. **Finalize:** state dosyası, özet, yeniden başlatma önerisi.

### 5.4 Bayraklar
```
--dry-run          Hiçbir şey değiştirme, ne yapılacağını göster
--yes              Onay sorma (snapshot yoksa bile DEĞİL, o ayrı bayrak)
--no-snapshot      Snapshot atlamayı açıkça kabul et
--gaming           gamemode, mangohud, gamescope, 32-bit Mesa, Vulkan araçları
--nvidia           NVIDIA sürücüsü (non-free, Secure Boot/MOK uyarısıyla)
--remove-gnome     (Aşama 0'da DESTEKLENMİYOR, ayrılmış bayrak; çağrılırsa hata verir)
--revert           Kaydedilen state'e göre geri al (gdm3'e dön, eklenenleri kaldır)
--profile NAME     desktop | laptop | gaming
```

### 5.5 Taslak paket listesi (Trixie'de adlar doğrulanacak)
`plasma-desktop`, `plasma-workspace`, `kwin-wayland`, `kwin-x11`, `sddm`, `qt6-wayland`, `plasma-nm`, `plasma-pa`, `bluedevil`, `powerdevil`, `kscreen`, `kde-gtk-config`, `breeze-gtk-theme`, `xdg-desktop-portal-kde`, `plasma-systemmonitor`, `plasma-firewall`, `dolphin`, `konsole`, `kate`, `ark`, `spectacle`, `gwenview`, `okular`, `power-profiles-daemon`, `systemd-zram-generator`.
**Hariç tutulanlar:** kdepim/Akonadi, `kde-full`, `task-kde-desktop`, Discover/PackageKit (Pardus kendi güncelleyicisini kullanıyor).

### 5.6 Btrfs notları
Pardus 25.2 GNOME kurulumunun gerçek düzeni doğrulanmadı. Script `findmnt -no FSTYPE,OPTIONS /` ve `btrfs subvolume show /` ile algılar ve üç yoldan birini izler:

| Durum | Davranış |
|---|---|
| **A) Btrfs + `/` bir alt birimde** (`subvol=/@` gibi) | Tam yol: `snapper -c root create-config /`, `pre-sopardus` snapshot'ı, `grub-btrfs`, APT kancası. |
| **B) Btrfs + `/` üst düzeyde (subvolid=5, düz düzen)** | Snapshot alınır (Snapper `.snapshots` iç alt birimi oluşturur) ama **rollback/grub-btrfs ile açılış garanti edilmez**. Kullanıcıya açıkça uyarı verilir, `/etc` yedeği ek olarak alınır. Düzen dönüştürme yapılmaz. |
| **C) Btrfs değil (ext4 vb.)** | Snapshot yok. `/etc` ve `/var/lib/dpkg` yedeği alınır, kullanıcıdan açık onay istenir (`--no-snapshot` ile geçilir, `--yes` ile geçilmez). |

Doğrulama için yine de şu çıktılar test makinesinden alınmalı (kodu bloklamaz, A/B/C kararını teyit eder):
```
findmnt /
sudo btrfs subvolume list /
```
- `grub-btrfs` ile snapshot'tan açılış ve APT öncesi/sonrası otomatik snapshot kancası yalnızca A yolunda kurulur.

### 5.7 Repo yapısı (Aşama 0)
```
sopardus/
├── install.sh              # ince giriş noktası
├── lib/                    # common.sh, 00-preflight ... 90-finalize
├── packages/               # core.list, gaming.list, nvidia.list
├── assets/                 # tema, wallpaper, xdg/skel varsayılanları
├── docs/                   # bu belge, ADR kayıtları
├── tests/                  # bats + VM senaryoları
├── LICENSE  (GPL-3.0-or-later)
└── SOPARDUS.md
```

### 5.8 Test planı
- ShellCheck + `bats` birim testleri (CI).
- **VM testi (elle, ilk etapta):** temiz Pardus 25.2 GNOME kurulumunun VM snapshot'ı → script → reboot → Plasma Wayland açıldı mı → script'i 2. kez çalıştır (idempotency) → `--revert` → GNOME'a dönüldü mü.
- `--dry-run` çıktısı gerçek çalıştırmayla karşılaştırılır.
- Gerçek donanım: en az bir NVIDIA ve bir AMD makine.

### 5.9 Bilinen riskler
- GNOME'dan Plasma'ya geçişte GDM/SDDM çakışması, Wayland'de NVIDIA, Pardus'a özgü GNOME eklentilerinin takılı kalması.
- Pardus güncelleme aracının Plasma altında çalışması (test edilecek).
- Debian'ın Plasma 6.3'ü yeni donanımda hata içerebilir (backport v1.0'da).

---

## 6. Mimari özeti (35 başlık)

1. **Genel mimari:** Katmanlar: Sopardus uygulamaları / kimlik katmanı (tema, KWin, plasmoid) / KDE Plasma 6 (upstream, yamasız) / sistem katmanı (sopardus-base, tuning) / Pardus-Debian tabanı. İlke: upstream'i yama yapma, üstüne ekle.
2. **Pardus ilişkisi:** Türev. Pardus+Debian depoları + ayrı `sopardus` deposu (apt pin ile). GNOME varsayılandan çıkar. `ID_LIKE="pardus debian"` (Aşama 2+).
3. **Plasma 6 entegrasyonu:** Minimal paket seti, Baloo hafif, Akonadi yok, SDDM + Wayland, varsayılanlar `/etc/xdg`.
4. **Shell/widget/KWin/tema/kısayol:** Look-and-Feel `org.sopardus.desktop`, Sopardus kısayol önayarları (Windows / GNOME / Klasik KDE benzeri).
5. **Kendi uygulamalar:** Settings (KCM), Welcome, Update, CLI, Installer (Calamares), sonra Gaming Hub, Snapshots, Driver Manager. Qt6 + QML + Kirigami.
6. **Settings:** System Settings içinde "Sopardus" kategorisi, ayrıcalıklı işler polkit korumalı `sopardus-helper`.
7. **Welcome:** İlk girişte profil, tema, sürücü, gizlilik (telemetri yok) adımları.
8. **Installer:** Calamares + özel modüller (btrfs düzeni, gpu-detect, profil, postinstall), LUKS opsiyonu.
9. **Update:** APT + Flatpak, güncelleme öncesi otomatik snapshot, kanallar: stable/testing/nightly.
10. **CLI:** `sopardus update|rollback|gpu|profile|game|theme|config|doctor|info`, `--json`.
11. **Tema:** *Sopardus Ember* (Dark varsayılan, Light, OLED). Sıcak kehribar vurgu, füme/mürekkep zemin, leopar rozeti deseni. Tasarım tokenları tek kaynaktan tüm temalara üretilir.
12. **İkon:** Lisansı uygun tabandan miras + kendi öncelikli ikonlar.
13. **İmleç:** SVG kaynaklı, xcursorgen boru hattı.
14. **Wallpaper:** 8-12 özgün, gün saatine göre dinamik (güneş teması).
15. **KWin efektleri:** Az ve hızlı, Minimal/Dengeli/Gösterişli önayarı, oyunlarda kompozisyon istisnası, özel efekt = KWin script.
16. **Panel/dock:** Yüzen ince panel, alternatif düzen şablonları, ayrı dock uygulaması yok.
17. **Bildirim:** Plasma'nın yerlisi, Odak/Oyun profilleri.
18. **Güç:** powerdevil + power-profiles-daemon (TLP ile birlikte kullanılmaz).
19. **Ağ:** NetworkManager + plasma-nm, ufw, WireGuard/OpenVPN.
20. **Bluetooth:** BlueZ + bluedevil.
21. **Ses:** PipeWire + WirePlumber.
22. **GPU:** NVIDIA (non-free, açık modül tercihli, DRM modeset), AMD (Mesa/RADV), hibrit için switcheroo-control, Driver Manager v1.0.
23. **Laptop:** PPD, thermald, fstrim, zram, dokunmatik yüzey, donanım uyumluluk listesi.
24. **Gaming:** gamemode, mangohud, gamescope, Steam/Heroic (Flatpak), geri alınabilir şeffaf tweak'ler, Oyun Modu tek düğme.
25. **Paket yönetimi:** APT + Flatpak (Flathub). Snap yok. `sopardus-main`, `-backports`, `-drivers` depoları.
26. **Dotfiles/config:** `/etc/skel`, `/etc/xdg`, sürümlü şema, `sopardus config export/import`.
27. **ISO sistemi:** live-build, tekrarlanabilir, imzalı.
28. **Live ISO:** Plasma Wayland, SquashFS zstd, "Dene / Kur" ekranı.
29. **Installer ISO:** Aynı imajın kurulum modu, Standard ve Minimal varyant.
30. **Güncelleme/rollback:** Btrfs + Snapper + grub-btrfs, test→stable terfisi, önceki çekirdek korunur.
31. **Güvenlik:** AppArmor, ufw, root kilitli, polkit, Flatpak sandbox, imzalı paket/ISO, SBOM (v1.0), sıfır telemetri, Secure Boot/MOK sihirbazı.
32. **Dosya yapısı:** `/usr/share/sopardus`, `/usr/lib/sopardus`, `/etc/sopardus`, `/var/lib/sopardus`, `~/.config/sopardus`.
33. **GitHub:** Başta monorepo, büyüdükçe bölünür. CONTRIBUTING, SECURITY, lisans tablosu.
34. **CI/CD:** ShellCheck/lint, tasarım boru hattı, paket derleme (sbuild), depo yayını, ISO derleme, VM duman testi.
35. **Test:** pytest/QtTest, lintian/piuparts/autopkgtest, QEMU duman testi, rollback testi, RAM/boot performans bütçesi, donanım matrisi.

---

## 7. Yol haritası

- **Aşama 0 (şimdi):** install.sh, Ember Dark teması (temel), zram/tuning, snapper entegrasyonu, `--revert`. Çıkış ölçütü: VM'de ve en az 1 gerçek makinede kur / tekrar çalıştır / geri al.
- **Aşama 1:** `sopardus-*` .deb paketleri + APT deposu + `sopardus` CLI (update/rollback/doctor/info).
- **Aşama 2 (MVP ISO):** live-build ISO + Calamares, Welcome, imzalama, gece derlemesi, QEMU testi.
- **v1.0:** Settings KCM, Snapshots GUI, Driver Manager, Gaming Hub, Ember Light/OLED, Plasma backport hattı, laptop profili, Secure Boot sihirbazı, TR+EN, performans bütçesi.
- **v1.x:** Live kalıcılık, iwd değerlendirmesi, ek profiller, widget kütüphanesi, tema mağazası.
- **v2.0:** Immutable/atomik mod araştırması, tekrarlanabilir derleme, kendi çekirdek varyantı.

---

## 8. Açık sorular

Önceki dört soru kapandı (karar 8-11). Kalanlar kodu bloklamaz:

1. **Gerçek Btrfs düzeni:** Test makinesinde `findmnt /` ve `sudo btrfs subvolume list /` çıktısı alınınca §5.6'daki A/B/C yolu teyit edilir, gerekirse tablo sadeleşir.
2. **Trixie paket adları:** §5.5 listesi `apt-cache show` ile tek tek doğrulanacak (özellikle `kwin-wayland`, `kwin-x11`, `plasma-firewall`).
3. **Pardus araçları:** Güncelleme aracı ve güç aracının Plasma altında davranışı VM testinde bakılacak.

---

## 9. Değişiklik günlüğü

- **v0.3 (2026-10-02):** Açık sorular karara bağlandı: ad Sopardus, hedef kitle genel, `--remove-gnome` Aşama 0 dışı, Btrfs için algıla-uyarla (A/B/C) stratejisi. Idempotency gerçek sistem durumuna bağlandı, SDDM geçişinde eski değerlerin state'e yazılması eklendi, preflight'a Plasma sürüm loglama ve Pardus araç çakışma kontrolü eklendi.
- **v0.2 (2026-10-02):** Taban Pardus 25.2 GNOME, Btrfs, kararlar 3-5 onaylandı, süreç kuralı eklendi. Aşama 0 = install.sh eklendi ve tasarlandı. Pardus 25 / Debian 13 / Plasma 6.3.x gerçekleri doğrulandı. Yol haritası revize edildi.
- **v0.1 (2026-10-02):** 35 başlıklı ilk mimari taslağı.
