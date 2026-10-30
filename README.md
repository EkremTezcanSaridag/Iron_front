# Sığınak

Felaketten sonra yeraltında bir sığınağı yönetirsiniz. İnsanları odalara yerleştirin, yiyecek-su-elektrik dengesini tutun, dışarı sefer gönderin, telsizi onarıp kurtarılmayı bekleyin.

**Sürüm:** 0.3.0 · **Paket:** `com.siginak.game` · **Motor:** Flutter (Dart) · **Yön:** dikey (portrait)

Godot 4.7 sürümleri (v0.2.0 / v0.2.1) Nothing CMF Phone 1 / Android 16 üzerinde `"Paket geçersiz göründüğünden uygulama yüklenemedi"` ile reddedildi. Oyun **Flutter** ile yeniden yazıldı; imza ve yükleme Godot Gradle zincirine bağlı değil.

## İndir

### 1) hello-test (yan yükleme denemesi)

Stok Flutter sayaç uygulaması. Oyun değildir. Telefonda **herhangi bir** APK kuruluyor mu diye bakın:

https://github.com/EkremTezcanSaridag/Iron_front/releases/download/hello-test/Siginak-hello-test.apk

Paket: `com.siginak.hello` · ~15 MB · arm64 · yayın imzalı v2+v3

### 2) Sığınak v0.3.0

https://github.com/EkremTezcanSaridag/Iron_front/releases/download/v0.3.0/Siginak-v0.3.0.apk

Paket: `com.siginak.game` · arm64-v8a · Flutter `split-per-abi` yayın APK'sı

### Telefona kurulum

1. Ayarlar → Güvenlik → **Bilinmeyen uygulamalar** / **Bu kaynaktan yükle** iznini **Dosyalar** için açın.
2. Chrome / GitHub **İndirilenler** listesinden kurmayın. **Dosyalar** → İndirilenler → APK → Yükle.
3. Play Protect uyarı verirse **Yine de yükle**.
4. Eski Sığınak / Iron Fronts / Godot sürümü kuruluysa önce kaldırın (farklı imza).

USB:

```bash
adb install -r Siginak-v0.3.0.apk
```

- minSdk **24** / targetSdk Flutter varsayılanı (**36**)
- ABI: **yalnızca arm64-v8a**
- İmza: v2 + v3, `debuggable` kapalı
- Manifest sonradan yamalanmaz; standart Flutter Gradle

## Nasıl oynanır

1. **Yeni Oyun** — dört kurtulan, birkaç oda, ilk gün rehberi.
2. Bir kişiye dokunun, sonra bir odaya dokunun (görev).
3. Üst çubuktaki kaynaklar her vakit diliminde (Sabah / Öğlen / Akşam / Gece) değişir. **II / 1× / 2×** zamanı durdurur veya hızlandırır.
4. **Sefer** ile dışarı yağma. Metin kartlarında seçim yapın; yaralanma veya ölüm olabilir.
5. Sığınakta rastgele olaylar: yağmacı, yabancı, karartma, hastalık, telsiz sinyali…
6. Hurdayla boş oyuklara oda **İnşa** edin. **Telsiz Odası** kurtuluş içindir (ilerleme %100) veya 21 gün hayatta kalın.
7. Herkes ölürse ya da moral üç gün çökerse oyun biter. Otomatik kayıt vardır (`shared_preferences`); kapalıyken geçen süre sınırlı işlenir.

## Odalar

Yaşam alanı, hidroponik, su arıtma, jeneratör, depo, revir, atölye, telsiz.

## Geliştirici: APK

Flutter 3.47+ (stable), OpenJDK 17, Android SDK 36.

Yerel yayın keystore **repoda yoktur** (depo herkese açık). Üretim:

```bash
keytool -genkeypair -keystore ~/.android/siginak-release.jks -storetype PKCS12 \
  -alias siginak -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Siginak, OU=Games, O=Siginak, L=Istanbul, ST=Istanbul, C=TR"
```

`android/key.properties` (git dışı) örneği `keystore/README.md` içinde.

```bash
flutter build apk --release --split-per-abi
# çıktı: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Arayüz Türkçe, kod İngilizce. Kenney CC0 + Barlow OFL: **CREDITS.md**.
