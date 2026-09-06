# تدقيق مهام LIVE — بشار — 2026-09-07

هذا سجل عمل يتحدث أثناء التنفيذ. الحالات النهائية في تقرير التسليم؛ لا يمثل وجود عقد مكتوب اختبار بيئة.

## البداية

- الجذر: `bimobondapp`؛ البرانش `bashar`؛ `git status --short` فارغ قبل العمل، ولا ملفات جديدة أو diff سابق.
- لم يوجد AGENTS.md في الجذر أو آبائه أو المشروع في البحث المحلي.
- Flutter 3.44.8؛ Dart 3.12.2؛ entrypoint الإنتاج `lib/main.dart`؛ لم يظهر flavor منفصل معتمد.
- baseline: `flutter test --no-pub --reporter expanded`: 285 Passed / 6 Failed؛ exit 1. `flutter analyze --no-pub`: 415 ملاحظة دون errors؛ exit 1.
- الأدلة الكاملة: `/tmp/bimobond-live-audit-20260907/` (baseline-tests.log وbaseline-analyze.log وJSON للأوامر).
- الجهاز: Bashar’s iPhone، `00008130-00027DE21191001C`، iOS 26.6.1 23G83؛ الوصول USB محلي. لم تنفذ سيناريوهات الجهاز بعد.
- مصادر العقد المقروءة: `../lives/mobile-api.md` و`endpoints2.md` و`logic.md` و`live-promotions.md` وP0/P1/P2/P3 و`tasks.md` في الأقسام المرتبطة.
- Archive(3).zip فُحص وفُك توثيقه فقط في مجلد مؤقت منفصل. لا parity ولا features-ar داخله. لم يُستبدل كود المشروع.
- features-ar وحزمتا lives 2 غير موجودة في مواقع البحث الحالية؛ طُلب المسار. المرجع المجاور يتضمن parity لكن مصدر الحزمة غير مؤكد.
- جميع أمثلة JSON حتى الآن عينات داخل التوثيق؛ لا عينة معتمدة من Backend ولا ملاحظة API حيّة.

## مصفوفة واحدة للمتطلبات

| الرقم | الميزة | المتطلبات الفرعية | المدخل/الملفات | حالة البداية والعقد |
|---|---|---|---|---|
| 30 | الترويج | النموذج والقائمة والإحصاءات والأهلية والدفع | lib/app/live_promotions | UnverifiedLivePromotionContract؛ عينات الأظرف والأهلية ناقصة |
| 20 | PK | 1v1 وTEAM والمقاعد وBO3 والقدرات والوسائط | lib/core/models/live_battle.dart؛ live_room؛ live_viewer | المسار الحالي غرفتان؛ يلزم تدقيق الفريق ودورة حياة الوسائط |
| 14 | الكوهوست | دعوات وجلسات و3 غرف ثانوية | live_session_repository؛ lives_media_datasource | P1/P2 يثبتان التوكنات؛ لا عينات كاملة لقائمة الجلسات وتحديثاتها |
| 15 | الهدايا | كتالوج ومحفظة ومستلم وكومبو وعدم التكرار | lib/app/gifts؛ real_gift_repository؛ LiveGiftSheet | UI الحقيقي يستخدم lib/app/gifts؛ المسار البديل يحتوي mock وتسريب ونجاح وهمي |
| 16 | الهدف | تهيئة المضيف والمشاهد والتحديث والإزالة | live_room_page؛ LiveInteractiveBloc؛ LiveGiftGoalBar | العينة مثبتة؛ المشاهد لا يمرر الهدف |
| 29 | الترتيب | الساعي والدوري والقلوب وPopular | ranking_sheet؛ LiveHostExtrasMapper؛ live_mapper | القراءات الجديدة غير مربوطة؛ Popular مستنتج من رتبة محليًا |
| 28 | النادي | الشرائح والسعر والتأكيد والعضوية والإيموجي والإدارة | fan_club_* | P0 يثبت tierSlug؛ استجابة tiers/membership كاملة مفقودة |
| 10 | التذاكر | إنشاء وإعدادات وقراءة وشراء واستحقاق قبل الوسائط | live_settings؛ joinLive؛ live_feed | P3 لا يحتوي response كامل أو مصالحة الشراء |
| 21 | التفاعل | poll وQA والكنز والحالة المالية والوقت | live_interactive_*؛ live_interactive_viewer_panel | الصفر والحماية وتبديل البث وpatch عيوب مثبتة |
| 22 | الألعاب | QUIZ/WHEEL/LUCKY_DRAW والنتيجة وصلاحيات المضيف | P3؛ لا مسار Flutter رسمي متكامل | الطلبات موثقة؛ الاستجابات ودلالة liveGame ناقصة |
| 17 | المزادات | إنشاء بائع ومساهمة هدية ونتائج السيرفر | live_interactive؛ lib/app/auctions؛ lib/app/gifts | targetPrice fiat؛ UI/mapper يفترضان حقول تقدم؛ مراجع auctions الخارجية غائبة |
| 18 | الحقيبة | إضافة وحذف وترتيب وفلاش وكوبون وتسعير ودفع | lib/app/shop | P0 يثبت bag؛ يلزم دمج واجهة وسياق checkout |
| 19 | المعرض | عرض وتثبيت وترتيب وتحديث مشاهِد | live_room_gallery_sheet؛ reorderGalleryItems | ترتيب المستودع موجود غير موصول بالشاشة |
| 3 | الاكتشاف | For You/Following/category/Nearby/audio/topic/mine | live_feed_screen؛ FakeLiveRepository | Nearby/audio غير موصولين؛ يجب عزل الحساب والسطح |
| 24 | الإعادة | recording/replay وحالة وتشغيل وإزالة | live_replay؛ LiveHostExtrasMapper؛ شاشة النهاية | GET replay يعد مشاهدة؛ عينة التشغيل الكاملة ناقصة |
| 25 | القصاصات | اختيار ومعاينة وإنشاء وحالة وفحص ملف ونشر | createClip/loadClips/postClip | POSTED فقط مثبت؛ envelope ومدة الملف يتطلبان عينة |
| 26 | التقرير | مصدر join وتقرير ومشاهدون ووقت ومتابعون ومشاركة ومتجر | LiveSummary؛ LiveSummaryPage؛ joinLive | مصدر الزيارة ينقطع في repository؛ حقول P0 غائبة |

## أدلة مصدر العقود

- `../lives/endpoints2.md` SHA256 `8e4414f3555f2082a4e7286aecd8547203789d2a4eb713f2071d9ba8e141cc40`
- `../lives/live-p0-parity.md` SHA256 `aabbe7af891dda7bea91df56c74b94be8b51ac87d35247126aa163ca3d2c4f0c`
- `../lives/live-p1-parity.md` SHA256 `86a2774f9d63357056cf388b8ed58f887092d7cca0f2f0242b051f87abfdc4a2`
- `../lives/live-p2-parity.md` SHA256 `384ee1189b3d90cd44814e382b86e5f7d1819f01f4c2275a52d457f0d580abc0`
- `../lives/live-p3-parity.md` SHA256 `a6eabc59a3b43c0ce0024b83562b3412779f8f7e7a4c38c93c4198fdf57aae07`
- `../lives/live-promotions.md` SHA256 `dbfaaeba1977778ffea941c249947ced826932e35317320469a521af07a90948`
- `../lives/logic.md` SHA256 `5dbe84eb2602df1e74a9e02c3d2abb6bf68e9fc6fe7d381a416c1b7fbbd07154`
- `../lives/mobile-api.md` SHA256 `7f204a658e24a8bf5c8a3cd5627508484a1f0a6014024dbfd1ad4eb369fedb12`
- `../lives/tasks.md` SHA256 `d84c4a41d28891692a98af001026498ecd88720256382061f42c00a21dd486b0`

## سجل أسباب التغيير

- 21: حفظ الصفر والغياب، منع REST القديم ونتائج بث سابق من الكتابة، وعدم محو QA/auction عند patch جزئي. لا يوجد في العقد حدث poll بلا id يعني الحذف؛ الإنهاء الموثق status=ENDED.
- سلامة المال: حفظ العملية قبل الإرسال لكل حساب/بث/نوع/كيان. فشل النقل لا يثبت عدم التنفيذ؛ لا تسمح إعادة إرسال حتى حسم رسمي. قائمة الكنوز العامة وحدها لا تثبت استحقاق المطالب.
- 10: أضيفت بوابة تذكرة للمشاهد قبل `join`: قراءة جذرية صارمة لـ`hasTicket` و`ticketPriceCoins`، ثم POST واحد محفوظ دائمًا يتبعه GET تأكيدي. لا يفتح البث من الرصيد المحلي أو socket. أضيفت حقول التذكرة إلى إعدادات المضيف (`PATCH /settings`) مع اشتراط سعر موجب محليًا عند تفعيل الدخول المدفوع.
- 10: إعادة فتح صفحة البث نفسها بعد فك الاتصال تسمح بتفعيل جديد بعد أن يزول اتصال الغرفة فعليًا؛ لا تعيد تنشيط غرفة ما زالت هي الغرفة المتصلة.
- 18/19: أضيف سياق `bag` الموثق (سعر الأساس/البث، flash، coupon، المبيعات) إلى بطاقة المنتج، ويمرر checkout preview كلًا من `liveId` و`couponCode` ثم يرسل نفسهما إلى الدفع. لا تنشأ قيمة تخفيض محليًا.
- 18/19: طلب checkout المالي يحمل `noAutomaticRetry`؛ تجديد Firebase لا يعيد إرسال الدفع. عناصر الحقيبة التي لا تحتوي منتجًا فعليًا تُهمل بدل إنشاء منتج افتراضي بسعر صفر.
- شريط المشاهدة: اسم المضيف يأخذ عرضه الطبيعي، ولا يظهر زر `Follow` إلا حين تتسع المساحة له وللاسم؛ لا يُضغط الاسم الطويل لإظهار الزر.

## تحقق لاحق

- `flutter test --no-pub test/live_ticket_service_test.dart test/live_operation_guard_test.dart test/live_poll_treasure_test.dart`: 16 Passed.
- `flutter test --no-pub --reporter expanded`: 297 Passed؛ exit 0.
- `flutter analyze --no-pub` للملفات المعدلة في التذاكر وإعدادات المضيف والحقيبة: لا errors؛ ثلاث ملاحظات style سابقة في `shop_remote_data_source.dart`.
