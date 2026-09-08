# تسريع بناء iOS أثناء التطوير

المشروع يحمل 84 Pod، بينها WebRTC وLiveKit وML Kit. أول بناء بعد تغيير Podfile أو `flutter clean` سيظل طويلًا لأنه يبني الاعتماديات الأصلية. التعديل في `ios/Podfile` يعطّل Index Store لمشاريع Pods في **Debug فقط**؛ لا يغيّر Release أو signing أو محتوى التطبيق.

بعد سحب التعديلات أو تغيير `Podfile` نفّذ مرة واحدة:

```sh
cd bimobondapp
flutter pub get
cd ios && pod install && cd ..
```

للتطوير اليومي على الهاتف الموصول، استخدم نفس الجهاز بالمعرّف ولا تنظف المشروع بين التعديلات:

```sh
flutter devices
flutter run -d <ios-device-id> --debug
```

بعد أول تشغيل، استخدم Hot Reload من الطرفية (`r`) أو IDE. لا تستخدم `flutter clean` أو `pod install` إلا عند تغيير dependency أو تعطل caches؛ كلاهما يعيد بناء Pods ويعيد زمن البناء الطويل.

للتحقق من الإعداد الفعال على Pod معين:

```sh
xcodebuild -project ios/Pods/Pods.xcodeproj -target WebRTC-SDK -configuration Debug -showBuildSettings | rg COMPILER_INDEX_STORE_ENABLE
```

التحسين لا يلغي تكلفة أول build ولا يعالج بطء اتصال الهاتف اللاسلكي. عند الإمكان، وصل iPhone عبر USB؛ اكتشاف وتشغيل الأجهزة اللاسلكية أبطأ من الاتصال المباشر.

## قياس محلي — 2026-09-08

بعد `pod install`، نجح `flutter build ios --debug --no-codesign --no-pub` وبنى `build/ios/iphoneos/Runner.app`. استغرق أول بناء كامل **9:08**: منها **57.1 ثانية** لفحص CocoaPods و**176.8 ثانية** لبناء Xcode؛ بقية الوقت من Flutter وتجهيز build للجهاز. هذا قياس أولي بعد تغيير Podfile، وليس زمن Hot Reload أو البناء التزايدي.

إعادة الأمر نفسه فورًا، بلا تغيير مصدر وبلا `clean` أو `pod install`، نجحت في **1:38** وكان Xcode فيها **53.8 ثانية**. هذا هو المسار الذي ينبغي أن يستعمله التطوير اليومي قبل الانتقال إلى Hot Reload.
