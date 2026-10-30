# Yayın imzası (yerel — repoda yok)

Bu depo herkese açıktır. PKCS12 keystore (`.jks`) ve `key.properties`
**asla commit edilmez**.

## Keystore üret

```bash
keytool -genkeypair -keystore ~/.android/siginak-release.jks -storetype PKCS12 \
  -alias siginak -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Siginak, OU=Games, O=Siginak, L=Istanbul, ST=Istanbul, C=TR"
```

Şifreleri `keytool` sorunca girin; argv üzerine yazmayın.

## `android/key.properties` (git dışı)

```
storePassword=<sizin-sifreniz>
keyPassword=<sizin-sifreniz>
keyAlias=siginak
storeFile=/home/<user>/.android/siginak-release.jks
```

Flutter `android/.gitignore` zaten `key.properties` ve `*.jks` yok sayar.
Kök `.gitignore` da `*.jks` / `key.properties` içerir.

Play Store'a çıkmadan önce kendi anahtarınızı kullanın.
