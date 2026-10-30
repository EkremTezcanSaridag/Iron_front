# Iron Fronts - Birinci Dünya Savaşı Stratejisi

**Versiyon:** 0.1.2 (Godot 4.7.2 Gradle APK — Android 16 / 16 KB sayfa boyutu)

## Oyun Hakkında

Iron Fronts, Birinci Dünya Savaşı'nı tema alan, tur tabanlı bir mobil büyük strateji oyunudur. 1914 yılında başlayan oyunda Avrupa ve Orta Doğu'nun kaderi sizin ellerinizde!

## Özellikler

### ✨ Temel Oynanış
- **8 Oynanabilir Ülke**: Osmanlı İmparatorluğu, Almanya, Avusturya-Macaristan, Fransa, Birleşik Krallık, Rusya, İtalya ve Sırbistan
- **Tur Tabanlı Strateji**: Her turda birliklerinizi yönetin, diplomasi yapın ve kararlar alın
- **İttifak Sistemi**: Merkezi Güçler, İtilaf ve Tarafsızlar
- **Ekonomi Yönetimi**: Para, insan gücü ve sanayi kaynaklarını dengeleyin

### 🎮 Savaş Sistemi
- **Sipergâh Savaşı**: Savunan taraf siperlerde avantaj kazanır
- **Birim Çeşitleri**: Piyade, süvari ve topçu birimleri
- **Teknoloji Araştırması**: Makineli tüfekler, tanklar, zehirli gaz, uçaklar ve ağır topçu

### 🛤️ Kader Yolları Sistemi
Hearts of Iron'dan esinlenilmiş ama farklı bir sistem:
- Her ülke için 3-4 ana yol
- Dünya olaylarına göre açılan kararlar (örn: Çanakkale'yi kazanmak yeni seçenekler açar)
- Oyun her defasında farklı gelişir
- İstikrar ve savaş yorgunluğu mekanikleri

**Osmanlı Yolları Örneği:**
- 🤝 Merkezi Güçlere Katıl
- 🕊️ Tarafsızlık ve Reform
- ⚔️ Doğu Seferi (Çanakkale zaferi sonrası)
- 🏴 Arap İttifakı

### 📱 Mobil Deneyim
- Yatay ekran optimizasyonu
- Dokunmatik kontroller: Haritada kaydırma ve yakınlaştırma
- Büyük, okunabilir butonlar
- Otomatik kayıt/devam et özelliği

## Nasıl Oynanır

### İlk Başlangıç
1. Ana menüden **"Yeni Oyun"** seçin
2. Oynamak istediğiniz ülkeyi seçin
3. Oyuna başlayın!

### Oyun İçi Kontroller
- **Haritada Gezinme**: Parmağınızla sürükleyin
- **Yakınlaştırma**: İki parmakla sıkıştırın/genişletin
- **Eyalet Seçimi**: Bir eyalete dokunun
- **Bilgi Panelleri**: Sol alttaki "Paneller" düğmesine dokunun

### Tur Mekanikleri
Her turda yapabilecekleriniz:
1. **Birlik İşe Alma**: Eyaletlerde yeni birlikler oluşturun
2. **Hareket ve Saldırı**: Birlikleri komşu eyaletlere taşıyın
3. **Diplomasi**: İttifaklar kurun, ilişkileri geliştirin
4. **Kader Yolları**: Ülkenizin geleceğini şekillendirecek kararlar alın
5. **Araştırma**: Yeni teknolojiler geliştirin
6. **Turu Bitir**: Değişikliklerinizi onaylayın

### Kaynaklar
- **💰 Para**: Birim işe almak için gerekli
- **👥 İnsan Gücü**: Orduları büyütmek için gerekli
- **🏭 Sanayi**: Teknoloji araştırmak için gerekli
- **🏛️ İstikrar**: Düşerse ülke yıkılır
- **😰 Savaş Yorgunluğu**: Uzun savaşlar halkı yorar

### Kazanma Koşulları
- Düşman ülkelerin çekirdek eyaletlerini işgal edin
- Düşmanları teslim olmaya zorlayın
- 200 tura kadar hayatta kalın

## Android'e Kurulum

### Gereksinimler
- Android 7.0 (API 24) veya üstü — **Android 16 (API 36) desteklenir**
- ~80 MB boş alan (arm64 APK ~77 MB)
- Yatay ekran önerilir
- Android 15+ cihazlar 16 KB bellek sayfası kullanabilir; bu sürüm native kütüphaneleri 16 KB hizalıdır

### APK indir (telefonunuzdan)
**v0.1.2 (Android 16 kurulumu):** https://github.com/EkremTezcanSaridag/Iron_front/releases/download/v0.1.2/IronFronts-v0.1.2-debug.apk

v0.1 / v0.1.1 modern telefonlarda (özellikle Android 15/16) **"Paket geçersiz göründüğünden uygulama yüklenemedi"** verebiliyordu. Godot 4.3 klasik (Gradle'sız) şablon:
- iki `provider` öğesine aynı `android:authorities` değerini yazıyordu
- native `.so` dosyalarını 4 KB ELF hizasıyla paketliyordu (Android 15+ 16 KB sayfa boyutu bunu reddeder)

v0.1.2 **Godot 4.7.2 Gradle** ile üretilir (`targetSdk 36`, `minSdk 24`, uncompressed arm64 `.so`, `zipalign -P 16`, APK Signature Scheme **v2+v3**). `armeabi-v7a` bilerek yoktur: 32-bit Godot kütüphaneleri hâlâ 4 KB hizalıdır.

### Kurulum Adımları
1. Telefon ayarlarından **"Bilinmeyen kaynaklardan yükleme"** izni verin
2. Yukarıdaki `IronFronts-v0.1.2-debug.apk` dosyasını indirin
3. Dosyayı açın ve yüklemeyi onaylayın
4. Oyunu başlatın

### Geliştirici: APK nasıl üretilir
Godot 4.3 klasik export veya apktool yamaları kullanmayın. Temiz Gradle çıktısı için:

```bash
# Godot 4.7.2 + OpenJDK 17 + Android SDK platform 36 / NDK 29
./export_android.sh IronFronts-v0.1.2-debug.apk
```

Betik Gradle debug APK'yı önce `/tmp` altına yazar (bazı FUSE bağları ~100 MB kopyayı reddeder), sonra hedefe kopyalar; `apksigner` v2+v3, `zipalign -P 16` ve ELF 16 KB hizasını doğrular.

## Godot'ta Açma

### Gereksinimler
- Godot Engine **4.7.2** (4.4+ 16 KB native hiza için; 4.3 klasik şablon Android 15/16'da kurulmaz)
- GDScript desteği
- Android dışa aktarma: OpenJDK 17, Android SDK platform 36, build-tools 36.1.0, NDK 29

### Proje Yapısı
```
IronFronts/
├── project.godot          # Ana proje dosyası
├── scenes/                # Oyun sahneleri
│   ├── MainMenu.tscn
│   ├── CountryPicker.tscn
│   └── GameMap.tscn
├── scripts/               # GDScript dosyaları
│   ├── GameManager.gd     # Ana oyun yöneticisi
│   ├── MainMenu.gd
│   ├── CountryPicker.gd
│   ├── GameMap.gd
│   └── MapView.gd
├── data/                  # Oyun verileri (JSON)
│   ├── countries.json
│   └── provinces.json
├── assets/                # Grafikler ve ikonlar
│   ├── icons/
│   ├── flags/
│   └── ui/
└── export_presets.cfg     # Android dışa aktarma ayarları
```

### Godot'ta Açma
1. Godot Engine 4.7.2'yi açın
2. **"Import"** butonuna tıklayın
3. `project.godot` dosyasını seçin
4. Projeyi açın ve oynatın

### Android'e Dışa Aktarma
Klasik (Gradle kapalı) şablon ve apktool yamaları kullanmayın. `./export_android.sh` Godot 4.7.2 Gradle build çalıştırır (`use_gradle_build=true`, `compress_native_libraries=false`, `target_sdk=36`). Editor'dan dışa aktarırken de aynı Android preset'i kullanın ve "Install Android Build Template" ile `android/build` kurulu olsun.

## Bilinen Kısıtlamalar (v0.1)

Bu ilk sürümde basitleştirilmiş veya eksik olan özellikler:

### Yapay Zeka
- Temel AI (işe alma, saldırı, savunma)
- Daha gelişmiş strateji ve taktikler eksik
- Diplomasi AI basit

### Harita
- ~40 eyalet ile sınırlı (tam Avrupa yerine ana bölgeler)
- Basitleştirilmiş harita geometrisi
- Deniz savaşları yok

### Diplomasi
- Temel ilişki sistemi
- Barış görüşmeleri basit
- Ekonomik anlaşmalar yok

### Kader Yolları
- Her ülke için 3-4 yol
- Bazı tarihi olaylar eksik
- Dallanma ağacı daha da genişletilebilir

### Grafikler
- Prosedürel üretilmiş basit harita
- Minimal animasyonlar
- Yer tutucu ikonlar

## Gelecek Sürümler İçin Planlar

- 🗺️ Daha detaylı harita ve daha fazla eyalet
- 🤖 Gelişmiş yapay zeka
- 🚢 Deniz savaşları ve donanma yönetimi
- 🎨 Geliştirilmiş grafikler ve animasyonlar
- 🎵 Müzik ve ses efektleri
- 📊 Detaylı istatistikler ve grafikler
- 🌍 Daha fazla olaylar ve tarihi senaryo
- 💾 Bulut kayıt desteği
- 🏆 Başarımlar sistemi

## Teknik Bilgiler

- **Motor**: Godot Engine 4.7.2
- **Dil**: GDScript
- **Platform**: Android (minSdk 24 / targetSdk 36, arm64-v8a)
- **Boyut**: ~77 MB (uncompressed 16 KB-aligned native libs)
- **UI Dili**: Türkçe
- **Kod/Yorumlar**: İngilizce

## Lisans ve Telif Hakkı

Bu oyun orijinal bir projedir. Tüm varlıklar (grafikler, ikonlar, kod) özel olarak bu proje için oluşturulmuştur.

## Sorun Bildirme

Oyunda sorun yaşarsanız veya önerileriniz varsa lütfen bildirin!

---

**İyi Oyunlar! 🎮⚔️**

*"Tarih yazmaya hazır mısınız?"*
