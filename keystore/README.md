# Sığınak upload keystore

PKCS12 keystore used to **release-sign** sideload APKs. This is not the
well-known Android debug cert (`CN=Android Debug`), which PackageInstaller
on some Android 16 / Nothing OS builds treats as an invalid package.

| Field | Value |
| --- | --- |
| File | `siginak-upload.jks` |
| Store type | PKCS12 |
| Alias | `siginak` |
| Store / key password | `siginakupload` |
| Algorithm | RSA 2048 |
| Validity | 10000 days |

Checked into the repo on purpose so CI and `./export_android.sh` can produce
the same signature. Rotate it before any Play Store listing.
