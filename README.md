# Iron Fronts - Birinci Dünya Savaşı Stratejisi

**Versiyon:** 0.1.1 (İlk oynanabilir sürüm — Android kurulum düzeltmesi)

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
- Android 5.0 (Lollipop) veya üstü
- ~100 MB boş alan
- Yatay ekran önerilir

### APK indir (telefonunuzdan)
**v0.1.1 (kurulabilir):** https://github.com/EkremTezcanSaridag/Iron_front/releases/download/v0.1.1/IronFronts-v0.1.1-debug.apk

v0.1 APK'sı modern Android'de "Paket geçersiz göründüğünden uygulama yüklenemedi" hatası veriyordu. Godot 4.3 klasik (Gradle'sız) dışa aktarma, iki `provider` öğesine aynı `android:authorities` değerini yazıyor ve vulkan `uses-feature` özniteliklerini string olarak kodluyor; PackageManager paketi reddediyor. v0.1.1 bu manifest'i düzeltip **apksigner v2+v3** ile imzalar.

### Kurulum Adımları
1. Telefon ayarlarından **"Bilinmeyen kaynaklardan yükleme"** izni verin
2. Yukarıdaki `IronFronts-v0.1.1-debug.apk` dosyasını indirin
3. Dosyayı açın ve yüklemeyi onaylayın
4. Oyunu başlatın

### Geliştirici: APK nasıl üretilir
Godot Editor'dan ham "Export" modern Android'de kurulmayan bir APK üretebilir. Bunun yerine:

```bash
./export_android.sh /opt/cursor/artifacts/IronFronts-v0.1.1-debug.apk
```

Betik Godot ile debug APK üretir, manifest'teki yinelenen provider authority'yi ayırır, `zipalign` uygular ve `apksigner` ile v1+v2+v3 imzalar.

## Godot'ta Açma

### Gereksinimler
- Godot Engine 4.3 veya üstü
- GDScript desteği

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
1. Godot Engine 4.3'ü açın
2. **"Import"** butonuna tıklayın
3. `project.godot` dosyasını seçin
4. Projeyi açın ve oynatın

### Android'e Dışa Aktarma
Godot'un klasik APK şablonu (Gradle kapalı) modern Android'de geçersiz paket üretir. Kurulu bir APK için `./export_android.sh` kullanın (apktool + zipalign + apksigner). Gradle şablonunu kurduysanız Godot Editor'dan da Gradle build ile dışa aktarabilirsiniz.

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

- **Motor**: Godot Engine 4.3
- **Dil**: GDScript
- **Platform**: Android (API 21+)
- **Boyut**: ~46 MB
- **UI Dili**: Türkçe
- **Kod/Yorumlar**: İngilizce

## Lisans ve Telif Hakkı

Bu oyun orijinal bir projedir. Tüm varlıklar (grafikler, ikonlar, kod) özel olarak bu proje için oluşturulmuştur.

## Sorun Bildirme

Oyunda sorun yaşarsanız veya önerileriniz varsa lütfen bildirin!

---

**İyi Oyunlar! 🎮⚔️**

*"Tarih yazmaya hazır mısınız?"*
