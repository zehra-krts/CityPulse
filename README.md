# CityPulse

Şehir sorunlarını raporlamak için Flutter uygulaması.

- `citypulse/` — ana uygulama (kullanıcı girişi, admin paneli, harita, raporlar)
- `citypulse_new/` — yeni sürüm denemesi

## Çalıştırmak için

Anahtarlar repoda yoktur, kendi anahtarlarınla doldurmalısın:

1. Firebase projesi oluşturup `citypulse/android/app/google-services.json` dosyasını ekle (repoya girmez, `.gitignore`'dadır).
2. Google Maps API anahtarını şuralara yaz:
   - `citypulse/android/app/src/main/AndroidManifest.xml` → `YOUR_GOOGLE_MAPS_API_KEY`
   - `citypulse/ios/Runner/AppDelegate.swift` → `YOUR_GOOGLE_MAPS_API_KEY`
3. `cd citypulse && flutter pub get && flutter run`
