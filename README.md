# Sığınak

Felaketten sonra yeraltında bir sığınağı yönetirsiniz. İnsanları odalara yerleştirin, yiyecek-su-elektrik dengesini tutun, dışarı sefer gönderin, telsizi onarıp kurtarılmayı bekleyin.

**Sürüm:** 0.2.1 · **Paket:** `com.siginak.game` · **Yön:** dikey (portrait)

## İndir (Nothing CMF Phone 1 / Android 16)

https://github.com/EkremTezcanSaridag/Iron_front/releases/download/v0.2.1/Siginak-v0.2.1.apk

Dosya yaklaşık **80 MB** olmalı (yalnızca arm64). Daha küçükse indirme yarım kalmıştır — silip tekrar indirin.

### Telefona kurulum

v0.2.0 ve önceki Iron Fronts APK'ları **hata ayıklama (debug)** imzalıydı. Nothing OS 3 / Android 16 **İndirilenler** yükleyicisi bunları `"Paket geçersiz göründüğünden uygulama yüklenemedi"` diye reddediyor. Bu sürüm **yayın imzalı**, `debuggable` kapalı, v2+v3 imza.

1. Ayarlar → Güvenlik → **Bilinmeyen uygulamalar** / **Bu kaynaktan yükle** iznini **Dosyalar** (Files) için açın.
2. Chrome / GitHub'ın **İndirilenler** listesinden kurmayın. **Dosyalar** uygulamasını açın → İndirilenler → `Siginak-v0.2.1.apk` → Yükle.
3. Play Protect uyarı verirse **Yine de yükle**.
4. Eski Sığınak / Iron Fronts kuruluysa önce kaldırın (farklı imza).

Hâlâ olmazsa USB:

```bash
adb install -r Siginak-v0.2.1.apk
```

Geliştirici seçenekleri + USB hata ayıklama açık olmalı. `adb` gerçek `INSTALL_*` kodunu yazar; İndirilenler uygulaması onu gizler.

- minSdk 24 / targetSdk **36**
- ABI: **yalnızca arm64-v8a** (CMF Phone 1)
- 16 KB sayfa hizası, uncompressed `.so`, imza **v2 + v3**
- Godot 4.7.2 Gradle (AGP 8.6.1, NDK 29, JDK 17)
- Tek `MAIN`/`LAUNCHER` etkinliği: `com.godot.game.GodotApp`

## Nasıl oynanır

1. **Yeni Oyun** — dört kurtulan, birkaç oda, ilk gün rehberi.
2. Bir kişiye dokunun, sonra bir odaya dokunun (görev).
3. Üst çubuktaki kaynaklar her vakit diliminde (Sabah / Öğlen / Akşam / Gece) değişir. **II / 1x / 2x** zamanı durdurur veya hızlandırır.
4. **Sefer** ile dışarı yağma. Metin kartlarında seçim yapın; yaralanma veya ölüm olabilir.
5. Sığınakta rastgele olaylar: yağmacı, yabancı, karartma, hastalık, telsiz sinyali…
6. Hurdayla boş oyuklara oda **İnşa** edin. **Telsiz Odası** kurtuluş içindir (ilerleme %100) veya 21 gün hayatta kalın.
7. Herkes ölürse ya da moral üç gün çökerse oyun biter. Otomatik kayıt vardır; kapalıyken geçen süre sınırlı işlenir.

## Odalar

Yaşam alanı, hidroponik, su arıtma, jeneratör, depo, revir, atölye, telsiz.

## Geliştirici: APK

```bash
# Godot 4.7.2 + OpenJDK 17 + Android SDK 36 / NDK 29
./export_android.sh /tmp/Siginak-v0.2.1.apk
```

Yayın keystore: `keystore/siginak-upload.jks` (şifre `keystore/README.md` içinde). Gradle çıktısı `/tmp` altına yazılır. `zipalign -P 16`, ELF 16 KB ve arm64-only doğrulanır.

Varlıkları yeniden üretmek: `python3 build_assets.py` (Kenney ayna + Barlow fontları gerekir).

Godot 4.7.2 ile `project.godot` dosyasını Import edin. Arayüz Türkçe, kod İngilizce.

## Lisans

Üçüncü taraf varlıklar **CREDITS.md** dosyasında. Kenney paketleri CC0, Barlow OFL 1.1.
