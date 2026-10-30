# Sığınak

Felaketten sonra yeraltında bir sığınağı yönetirsiniz. İnsanları odalara yerleştirin, yiyecek-su-elektrik dengesini tutun, dışarı sefer gönderin, telsizi onarıp kurtarılmayı bekleyin.

**Sürüm:** 0.2.0 · **Paket:** `com.siginak.game` · **Yön:** dikey (portrait)

## İndir (Android 16)

https://github.com/EkremTezcanSaridag/Iron_front/releases/download/v0.2.0/Siginak-v0.2.0-debug.apk

Telefonda **Bilinmeyen kaynaklardan yükleme** iznini açıp APK'yı kurun.

- minSdk 24 / targetSdk **36**
- ABI: **arm64-v8a** + x86_64 (emülatör için)
- 16 KB sayfa hizası, uncompressed native libs, imza v2+v3
- Godot 4.7.2 Gradle (AGP 8.6.1, NDK 29, JDK 17)

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
./export_android.sh Siginak-v0.2.0-debug.apk
```

Gradle çıktısı önce `/tmp` altına yazılır, sonra kopyalanır. `zipalign -P 16` ve ELF 16 KB doğrulanır. apktool yok.

Varlıkları yeniden üretmek: `python3 build_assets.py` (Kenney ayna + Barlow fontları gerekir).

Godot 4.7.2 ile `project.godot` dosyasını Import edin. Arayüz Türkçe, kod İngilizce.

## Lisans

Üçüncü taraf varlıklar **CREDITS.md** dosyasında. Kenney paketleri CC0, Barlow OFL 1.1.
