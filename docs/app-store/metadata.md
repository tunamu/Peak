# App Store metadata (1.0)

Copy-paste source for App Store Connect. Field limits are in brackets; every field below was counted against them.

## App Information

| Field | Value |
| --- | --- |
| Name (EN) [30] | Peak: Workout Log |
| Name (TR) [30] | Peak: Antrenman Günlüğü |
| Subtitle (EN) [30] | Progressive overload tracker |
| Subtitle (TR) [30] | Progressive overload takibi |
| Bundle ID | com.tunamu.peak |
| SKU | peak-ios |
| Primary language | English (U.S.); Turkish added as a localization |
| Primary category | Health & Fitness |
| Secondary category | none |
| Home Screen name | Peak (`CFBundleName`; the store name only needs to start with it) |

## URLs

| Field | Value |
| --- | --- |
| Privacy Policy URL | https://github.com/tunamu/Peak/blob/main/docs/privacy.md |
| Support URL | https://github.com/tunamu/Peak/issues |
| Marketing URL | https://github.com/tunamu/Peak (optional) |

## App Privacy

Data collection: **No, we do not collect data from this app.** Nothing leaves the device except what the user exports
or writes to Apple Health, and Apple Health is not collection by the developer.

## Pricing and availability

Free, all countries and regions.

## Keywords [100, comma-separated, no spaces]

The name's words (peak, workout, log) are indexed already and are not repeated.

- **EN:** `gym,strength,lifting,weight,training,tracker,routine,sets,reps,planner,fitness,overload,progress`
- **TR:** `spor,fitness,ağırlık,salon,güç,program,rutin,set,tekrar,kas,takip,gelişim,vücut,overload`

## Promotional text [170]

- **EN:** Know exactly what to lift next. Peak sets every target from your last workout, so each session moves you
  forward. Free, no account, no ads.
- **TR:** Bir sonraki antrenmanda ne kaldıracağını bil. Peak her hedefi son antrenmanından hesaplar, her seans seni
  ileri taşır. Ücretsiz, hesap yok, reklam yok.

## Description (EN) [4000]

```text
Peak is a simple strength training log that tells you what to lift next.

Log a workout set by set, and Peak works out your next targets from what you just did. Hit the top of your rep range and the weight goes up; otherwise the reps do. Progressive overload, without the spreadsheet.

TRAIN WITH A PLAN
• Build your workouts and put them on a routine: fixed weekdays or every few days, with the workouts rotating in order
• Home shows today's workout, your week at a glance, and what is next on rest days
• Every set shows last time's weight and reps next to today's target
• Set your own overload rules for the whole app, one workout or a single movement
• Notes for each movement: seat height, grip, how it felt last time
• Forgot to start a workout? Log it afterwards, on any past day

SEE YOUR PROGRESS
• Volume, sets and targets hit for the last 4 weeks, 3 or 6 months, a year or all time
• Every movement with its trend and a chart of its estimated one-rep max, weight, reps and volume, with your records
• A calendar of every workout you have done

APPLE HEALTH
• Steps, water and an Energy Level built from your sleep, heart rate variability and resting heart rate
• Finished workouts and water are saved to Apple Health
• Everything still works without Health access

ON YOUR IPHONE, NOT IN THE APP
• Home Screen and Lock Screen widgets for steps, water, energy, today's workout and your week
• A Live Activity with the current movement and the clock, in the Dynamic Island too
• Log water from a widget, Control Center or Siri without opening the app
• A morning reminder on workout days

YOUR DATA STAYS YOURS
• No account, no ads, no analytics, no tracking
• Everything is stored on your iPhone
• Import your history from Excel, CSV or JSON, and export it any time

Peak is free and open source (MIT).

Energy Level is an estimate to help you plan your training. It is not medical advice.
```

## Description (TR) [4000]

```text
Peak, bir sonraki antrenmanda ne kaldıracağını söyleyen sade bir güç antrenmanı günlüğü.

Antrenmanını set set kaydet; Peak bir sonraki hedeflerini az önce yaptığından hesaplar. Tekrar aralığının üstüne çıktıysan ağırlık artar, çıkmadıysan tekrar. Excel tablosu olmadan progressive overload.

PLANLA ÇALIŞ
• Antrenmanlarını kur ve bir rutine bağla: haftanın belirli günleri ya da birkaç günde bir, antrenmanlar sırayla döner
• Ana Sayfa'da bugünün antrenmanı, haftanın özeti ve dinlenme günlerinde sıradaki antrenman
• Her sette geçen seferki ağırlık ve tekrar, bugünün hedefinin yanında
• Overload kurallarını tüm uygulama, tek bir antrenman ya da tek bir hareket için ayarla
• Her hareket için not: koltuk yüksekliği, tutuş, geçen seferki his
• Antrenmanı başlatmayı mı unuttun? Sonradan, geçmiş bir güne de girebilirsin

GELİŞİMİNİ GÖR
• Son 4 hafta, 3 ya da 6 ay, bir yıl ya da tüm zamanlar için hacim, set ve tutturulan hedefler
• Her hareketin trendi; tahmini tek tekrar maksimumu, ağırlık, tekrar ve hacim grafiği, rekorlarınla
• Yaptığın her antrenmanın takvimi

APPLE SAĞLIK
• Adımlar, su ve uykundan, kalp atış hızı değişkenliğinden ve dinlenik nabzından hesaplanan Enerji Seviyesi
• Tamamlanan antrenmanlar ve su Sağlık uygulamasına kaydedilir
• Sağlık izni vermesen de her şey çalışır

UYGULAMAYI AÇMADAN
• Adım, su, enerji, bugünün antrenmanı ve haftan için ana ekran ve kilit ekranı widget'ları
• Mevcut hareket ve süreyle Canlı Etkinlik, Dynamic Island'da da
• Widget'tan, Denetim Merkezi'nden ya da Siri'yle su ekle
• Antrenman günlerinde sabah hatırlatması

VERİN SENİN
• Hesap yok, reklam yok, analiz yok, takip yok
• Her şey iPhone'unda saklanır
• Geçmişini Excel, CSV ya da JSON'dan içe aktar, istediğin zaman dışa aktar

Peak ücretsiz ve açık kaynaklıdır (MIT).

Enerji Seviyesi antrenmanını planlamana yardım eden bir tahmindir, tıbbi tavsiye değildir.
```

## Screenshots

6.9" (iPhone 17 Pro Max simulator, 1320 × 2868), dark appearance, status bar 9:41, English and Turkish, in this order:
Home (today's planned workout), the running workout, Analysis › Performance, a movement's chart (Bench Press),
Analysis › History. Data from `make-sample-data.py`; Health from `-PeakMockHealth YES`; the workout opened through
`-PeakOpenLink peak://workout/start`, so it is today's planned one. Shot last, because a running workout shows on every
tab afterwards.

## Age rating

Every content question: None / No. Expected rating: 4+.

## App Review notes

App Review asked for this on 2026-10-03 (new developer account, limited review history). The same text goes to the
Resolution Center reply and to the Notes field of App Review Information, with the screen recording attached to the
reply.

```text
1. Screen recording
Attached: a recording from a physical iPhone on the latest iOS. It starts on the Home Screen by launching the app and
shows the typical flow: onboarding, the Apple Health permission, starting with the sample program, logging sets,
finishing a workout and its summary, Analysis, logging a past workout, widgets, and import/export in Settings.
Peak has no account registration, login or account deletion, no user-generated content visible to other people, and no
paid content or In-App Purchases.

2. Purpose and audience
Peak is a strength training log for people who lift weights, from beginners to experienced lifters. To keep making
progress you have to add weight or reps over time (progressive overload); most people track this in notes or
spreadsheets and guess their next targets. Peak records each workout set by set and calculates the next target weight
and reps from the last session, so the user always knows what to lift next. It also shows progress charts and reads
steps, sleep and heart rate data from Apple Health for an Energy Level estimate. The app is free, with no account, no
ads and no tracking; all data stays on the device.

3. How to access the main features
No login or demo account is needed.
- First launch: choose "Start with a Sample Program". This creates a weekly routine with ready workouts.
- Home: today's workout is shown. Tap Start, enter weight and reps for each set, then finish the workout to see the
  summary and the new targets.
- Analysis: Performance shows volume and progress charts; History shows a calendar of past workouts.
- Logging a workout afterwards: select a past day on Home and tap "Log Workout".
- Settings: "Import Workout Data" (Excel, CSV or JSON) and data export. No sample files are needed; the sample program
  is enough to use every feature.
- Apple Health access is optional. Without it the steps, water and Energy Level cards show a "Connect Apple Health"
  button and the rest of the app works.

4. External services
Peak has no backend server and uses no third-party services, analytics, ads, payment processors, authentication
services or AI services. It only uses Apple frameworks on the device: HealthKit (reads steps, sleep, heart rate
variability and resting heart rate; writes workouts and water), WidgetKit and ActivityKit (widgets and Live Activity),
App Intents (Siri and Control Center) and local notifications. ZIPFoundation, an open-source library, is used on the
device to read and create Excel files for import. The iCloud entitlement is present for a future sync feature, but
sync is turned off in version 1.0 and no data is sent to iCloud.

5. Regional differences
The app works the same in all regions. It is available in English and Turkish, with the same features and content in
both languages.

6. Regulated industry or third-party material
Not applicable. Peak is not a medical app and contains no protected third-party material. Energy Level is presented
as an estimate to help plan training, and the app states that it is not medical advice.
```
