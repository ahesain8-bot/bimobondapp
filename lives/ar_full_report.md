# التقرير الكامل — توثيق مجلد `lives`، مشروع العينة، ومشروع `bimobondapp`

> **الفرع:** `bashar` (مسحوب من `live-merge`)
> **المستودع:** `ahesain8-bot/bimobondapp`
> **التاريخ:** 2026-08-19

هذا التقرير يشرح ثلاثة أشياء بالترتيب:

1. محتوى مجلد التوثيق `lives/` ملفاً ملفاً.
2. مشروع العينة `samble_we_need_same_camera_resulutions` وما أخذناه منه بالضبط.
3. بنية مشروعنا `bimobondapp`، ثم **ما نفّذته وما عدّلته فعلياً** مع أسباب كل تعديل.

---

## الجزء الأول: مجلد التوثيق `lives/`

المجلد يوثّق وحدة LIVE في الخادم (NestJS + Prisma + PostgreSQL + LiveKit + Socket.IO). تسعة ملفات، مجموعها ~6,650 سطراً.

### 1. `logic.md` — المنطق والمعمارية (276 سطراً)

الملف المرجعي الأول. يجب قراءته قبل أي ملف آخر.

- **مصفوفة الميزات:** جدول يقارن كل ميزة في TikTok LIVE بحالتها عندنا (بث فردي، ضيوف حتى 8، معارك PK، صناديق كنز، استطلاعات، Q&A، أهداف هدايا، تسوّق مباشر، ترتيب كل ساعة، نوادي المعجبين).
- **المعمارية:** ثلاثة أنظمة منفصلة لا يجوز الخلط بينها:
  - `LiveKit SFU` للفيديو والصوت فقط (WebRTC).
  - `Socket.IO` على غرفة `live_{id}` للتعليقات والهدايا وعدّاد المشاهدين وHUD.
  - `Nest + Postgres` هو **المصدر الوحيد للحقيقة** في المال والمقاعد والحالة.
- **آلات الحالة:** `PLANNED → LIVE → ENDED` (أو `BANNED`)، حالات مقاعد الضيوف، حالات المعركة، صناديق الكنز، الاستطلاعات.
- **رموز LiveKit:** الخادم وحده يصدر JWT قصير العمر (TTL = 6 ساعات). التطبيق لا يملك `LIVEKIT_API_SECRET` إطلاقاً.
- **الثوابت (Invariants):** خمس قواعد يجب أن تبقى صحيحة، أهمها أن `end` و`ban` ينهيان المعارك ويلغيان المزادات ويحذفان غرفة LiveKit ويمسحان الضيوف والجلسات معاً.

### 2. `mobile-api.md` — دليل مطوّر التطبيق (1,700 سطراً)

الملف الأهم لنا كفريق موبايل. يشرح:

- **ما تستخدمه ولماذا:** جدول يحدد متى تستخدم HTTP ومتى LiveKit ومتى Socket.
- **المصادقة:** `Authorization: Bearer <Firebase ID token>` على كل المسارات المحمية، وشكل غلاف الخطأ الموحّد.
- **التدفقات الكاملة:** بث المضيف، مشاهدة المشاهد، تعدد الضيوف، التسوّق المباشر، معركة PK، الإشراف على الدردشة — كل واحد بخطوات مرقّمة.
- **مرجع كائن `Live`:** الحقول التي يعيدها الخادم (`id`, `roomName`, `streamUrl`, `status`, `viewers`, `likeCount`, `totalEarnedCoins`, `guestsEnabled`, `maxGuests`, `layout`, …).
- **واجهات المضيف والاكتشاف والتفاعل والإشراف والضيوف والمعارك والأدوات التفاعلية.**
- قائمة فحص LiveKit وقائمة فحص Socket.IO، وشارات مستوى المُهدي.

### 3. `endpoints.md` — المرجع الكامل للمسارات (1,925 سطراً)

توثيق تفصيلي لكل مسار: الطريقة، المسار، الصلاحية، جسم الطلب، الاستجابة، الأخطاء الممكنة. مقسّم إلى عشرة أقسام: دورة حياة البث، الاكتشاف، الحضور، الدردشة والإعجاب، إشراف المشاهدين، المسرح متعدد الضيوف، مشرفو الغرفة، معارك PK، الأدوات التفاعلية، ثم المزادات والهدايا.

### 4. `database.md` — مخطط قاعدة البيانات (426 سطراً)

مخطط ERD بصيغة Mermaid مع شرح كل جدول: `Live`, `LiveViewerSession`, `LiveLike`, `LiveComment`, `LiveGuest`, `LiveModerator`, `LiveViewerRestriction`, `LiveBattle`, `LivePoll`, `LivePollVote`, `LiveQA`, `LiveTreasureBox`, `LiveTreasureBoxClaim`, `LiveProductPin`، بالإضافة إلى حقول LIVE داخل `User` و`GiftTransaction` و`Auction`.

### 5. `live-database.md` — نسخة موسّعة من المخطط (624 سطراً)

نفس الجداول بتفصيل أعمق: الفهارس، القيود الفريدة، سلوك الحذف المتتالي، والتكامل مع `Wallet`. عند وجود اختلاف بين هذا الملف و`database.md` فالأشمل هو هذا.

### 6. `admin-api.md` — دليل لوحة الإدارة (434 سطراً)

مسارات `/lives/admin/*` المحمية بـ RBAC (`lives.admin.read`, `lives.admin.moderate`): سرد كل البثوث، الإنهاء القسري، الحظر، تعزيز الظهور في الخلاصة، طرد ضيف قسراً. لا يخصّنا مباشرة في تطبيق الموبايل لكنه يفسّر لماذا قد ينتهي بث فجأة من طرف الإدارة.

### 7. `tasks.md` — مهام التنفيذ (542 سطراً)

مقسّم إلى `PART 1` لتطبيق الموبايل (المهام M1–M12) و`PART 2` للوحة الإدارة (D1–D4). كل مهمة تحتوي على الهدف، مخطط تسلسل Mermaid، جدول واجهات وأحداث Socket، وقائمة فحص UI/UX. هذا هو الملف الذي نقيس عليه اكتمال العمل.

### 8. `production.md` — النشر والاختبار (272 سطراً)

متغيرات البيئة، تشغيل LiveKit عبر Docker، فتح منافذ UDP `50000–50100`، إعداد Nginx لـ`wss://`، الويب-هوكس المطلوبة، واختبارات الدخان عبر `curl`.

### 9. `PERFORMANCE.md` — مشاكل الأداء (448 سطراً)

**12 مشكلة أداء في الخادم، مُعرَّفة وغير مُصلَحة بعد**، مرتّبة بالخطورة: استعلامان لقاعدة البيانات عند كل انضمام مشاهد، مسح ترتيب كامل عند كل هدية، ترتيب الخلاصة في الذاكرة من تجمّع كبير، تسريب ذاكرة في `likeAttempts`، فهارس ناقصة، وغياب طبقة Redis. **كلها في الخادم — لا شيء منها يخصّ التطبيق.**

---

## الجزء الثاني: مشروع العينة `samble_we_need_same_camera_resulutions`

مشروع Flutter منفصل اسمه `apex_camera`، معماريته **GetX + Clean Architecture**، وهدفه إثبات أن الوصول إلى جودة كاميرا مماثلة لـTikTok ممكن.

### الدرس الجوهري الذي أخذناه

مذكور في `CAMERA_QUALITY_REPORT_AR.md` و`ANDROID_CAMERA_QUALITY_REPORT_AR.md`:

> النسخة القديمة كانت تعرض `4032 × 3024`، لكن هذا الرقم لم يكن دليلاً على جودة المعاينة. ملحق Flutter كان يختار أعلى صيغة من حيث عدد البكسلات (`ResolutionPreset.max`) وهي صيغة **4:3** أقرب لمسار الصور الثابتة، ثم يكبّرها ويقصّها لتملأ شاشة 9:19.5 — فتظهر أنعم وأقل حدّة.

الخلاصة في ثلاث نقاط:

1. **أعلى رقم ليس أفضل جودة.** المطلوب هو أعلى صيغة **فيديو 16:9 حقيقية** يعالجها الجهاز بثبات، وليس أكبر صيغة مستشعر.
2. **لا تدّعِ دقة لم تحصل عليها.** إذا رفض الجهاز الصيغة، انزل درجة معلنة بدل عرض شارة كاذبة.
3. **افصل مسار الصورة عن مسار الفيديو.** صيغة 4:3 الكبيرة تبقى للصور فقط.

### الملفات التي درستها من العينة

| الملف | ما فيه |
|---|---|
| `lib/core/services/resolution_selection_service.dart` | يرتّب الصيغ الخام ويفضّل أعلى صيغة `isVideoAspect` بـFPS ≥ 24 على أعلى صيغة خام |
| `lib/features/camera/domain/entities/camera_resolution_entity.dart` | `isVideoAspect` (فرق أقل من 0.12 عن 16:9)، `label`، `bitrateFor(fps)` |
| `ios/Runner/AppDelegate.swift` (965 سطراً) | محرّك AVFoundation كامل: `bestFormat` يطابق الأبعاد وFPS بالضبط، و`formatScore` يرجّح HDR والتثبيت |
| `android/.../NativeCameraEngine.kt` (444 سطراً) | CameraX مع `ResolutionSelector` وتحقّق من الدقة الفعلية بعد `bind` |
| `lib/features/camera/presentation/widgets/resolution_bottom_sheet.dart` | ورقة اختيار الدقة (النمط الذي بنيت عليه ورقة جودة الفيديو عندنا) |

### ما لم آخذه من العينة ولماذا

العينة تستخدم **GetX** ومحرّك كاميرا أصلياً بالكامل عبر `MethodChannel` و`PlatformView`. مشروعنا يستخدم **BLoC + get\_it + go\_router**، ومسار البث عندنا يمرّ عبر LiveKit (`flutter_webrtc`) وليس عبر ملحق `camera`. نسخ محرّك العينة كما هو كان سيكسر تتبّع الوجوه والمؤثرات والنشر على LiveKit دفعة واحدة. لذلك **أخذت المنطق والمبدأ، لا الكود**، وأعدت كتابته بنمط مشروعنا.

---

## الجزء الثالث: بنية مشروع `bimobondapp`

### الشكل العام

```
lib/
├── app/          23 وحدة أعمال (auth, posts, chats, gifts, wallets, shop, calls, ar_camera, camera_studio, …)
├── core/         constants · data · error · navigation · network · routes · services · theme · usecases · utils · widgets
├── features/     live · live_source · live_viewer
├── l10n/         app_ar.arb · app_en.arb (عربي/إنجليزي)
└── main.dart     تهيئة Firebase → حقن التبعيات → MultiBlocProvider → MaterialApp.router
```

1,196 ملف Dart. كل وحدة تتبع **Clean Architecture** بصرامة:

```
<feature>/
├── data/         datasources · models · repositories (impl)
├── domain/       entities · repositories (abstract interface class) · usecases
└── presentation/ bloc · di · pages · widgets · utils
```

**الأنماط المتّبعة في المشروع (التزمت بها حرفياً):**

- إدارة الحالة: `flutter_bloc` — `Bloc` للأحداث، `Cubit` للحالات البسيطة.
- الحقن: `get_it` عبر `<feature>_injector.dart` يُستدعى من `main.dart`.
- التنقّل: `go_router` في `core/routes/app_router.dart`.
- العقود: `abstract interface class` للمستودعات.
- حالات الـBloc: `sealed class` + `copyWith` + `operator ==` + `hashCode` يدوياً.
- الثوابت: `AppSpacing` / `AppColors` / `AppSizes` / `AppTextStyles` — لا أرقام سحرية في الواجهة.
- التعليقات: `///` على مستوى الصنف والدالة تشرح **لماذا** لا **ماذا**، وتعليق سطري قصير عند القرارات غير البديهية فقط.
- الخدمات المفردة: `class X extends ChangeNotifier { X._(); static final X instance = X._(); }`.

### وحدات LIVE الثلاث

| الوحدة | الدور | الحالة قبل عملي |
|---|---|---|
| `features/live` | المضيف: غرفة البث، الكاميرا، LiveKit، الهدايا، الضيوف، المعارك | كاملة ومربوطة بالخادم |
| `features/live_source` | شاشة "بدء البث" الأحدث تصميماً | **واجهة فقط — بدون كاميرا** |
| `features/live_viewer` | المشاهد: الخلاصة، المشاهدة، الاشتراك على LiveKit | كاملة (Riverpod) |

### مسارات الكاميرا الثلاثة في التطبيق

من المهم عدم الخلط بينها:

1. **مسار البث المباشر** — `features/live`: ملحق `camera` للمعاينة المحلية + `livekit_client` للنشر. **هنا كانت المشكلة.**
2. **مسار كاميرا المنشور** — `app/home` + `app/ar_camera`: `camerawesome` + محرّك Kotlin أصلي (`ArCameraController.kt`) مع تعليقات مفصّلة عن سقوف الأجهزة. **مضبوط سلفاً على 1080p — لم ألمسه.**
3. **مسار استوديو الكاميرا** — `app/camera_studio` + `camera_engine/NativeCameraEngine.kt`: CameraX → GPU → Flutter Texture. **مضبوط سلفاً — لم ألمسه.**

---

## الجزء الرابع: ما نفّذته وما عدّلته

### التشخيص قبل التعديل

قرأت المسار كاملاً من الشاشة حتى النشر قبل تغيير أي سطر، ووجدت ثلاث مشاكل حقيقية:

| # | المشكلة | الموقع | الأثر |
|---|---|---|---|
| 1 | المعاينة المحلية تفتح على `ResolutionPreset.medium` = **480p**، وعند أي فشل تسقط مباشرة إلى `low` = **240p** | `camera_repository_impl.dart:72,100` | المضيف يرى نفسه بدقة منخفضة |
| 2 | النشر على LiveKit مثبّت على **720p** التقاطاً، وسلّم Simulcast من طبقتين 720p/480p | `lives_media_datasource.dart` (٥ مواضع) | المشاهد لا يمكنه استقبال أعلى من 720p مهما كانت شبكته |
| 3 | شاشة "بدء البث" المربوطة فعلياً بزر LIVE تعرض **مستطيلاً أسود** بدل الكاميرا | `live_source/.../camera_preview_layer.dart` | أوضح فجوة UX مقابل TikTok |

المشكلة الثالثة كانت مخفية: `features/live/.../live_start_page.dart` (النسخة الكاملة بالكاميرا) **غير مربوطة بأي مسار**، بينما `add_post_camera_screen.dart:1860` يفتح نسخة `live_source` التي تعليقها الحرفي كان: *"UI-only version: always shows a black background (no camera controller)"*.

### التعديلات

#### ملفات جديدة (٤)

**`lib/features/live/domain/entities/live_capture_profile.dart`**
كيان يمثّل سلّم التقاط **16:9 فقط**: `fullHd` (1920×1080 @30 / 4.5 Mbps)، `hd` (1280×720 @30 / 2.5 Mbps)، `sd` (854×480 @30 / 1.2 Mbps). يوفّر `ladder` و`preferred` و`fallbacks`. هذا هو مقابل `ResolutionSelectionService` من العينة، مكتوباً بنمط مشروعنا.

**`lib/core/services/live_video_quality_preference.dart`**
`ChangeNotifier` مفرد يحفظ **السقف** الذي اختاره المضيف. يقرأه مسار المعاينة ومسار النشر معاً. مكتوب بنفس نمط `LiveFeedRefreshBus` و`FeedPlaybackGate` الموجودين في `core/services`.

**`lib/features/live/presentation/widgets/room/live_video_quality_sheet.dart`**
ورقة اختيار جودة الفيديو بنمط TikTok. تستخدم ألوان وبطاقات المشروع نفسها (`AppColors.optionsSheetBackground`, `LiveRoomOptionsCard`) بترتيب RTL. لم أضف قيمة جديدة إلى `LiveRoomOptionTrailing` — بنيت `_QualityTile` خاصاً بالورقة حتى لا أمسّ عنصراً مشتركاً تستخدمه شاشات أخرى.

**`test/live_capture_profile_test.dart`**
سبعة اختبارات: ترتيب السلّم، أن كل طبقة 16:9 حقيقية، أن لا شيء ينزل تحت 854×480، صحة `fallbacks`، تصاعد الـbitrate، القيمة الافتراضية، وأن `select` يُشعر المستمعين مرة واحدة فقط.

#### ملفات معدّلة (١٤)

**`lib/features/live/data/repositories/camera_repository_impl.dart`**
- `_initializeUnlocked` صار يبدأ من سقف المضيف بدل `ResolutionPreset.medium` الثابت.
- `_openController` صار يمشي على السلّم نزولاً (1080p → 720p → 480p)، وفصلت محاولة الفتح الواحدة في `_tryOpen`.
- **أبقيت محاولة `ResolutionPreset.low` كملاذ أخير** بعد استنفاد السلّم، حتى لا أُسقط جهازاً ضعيفاً كان يعمل سابقاً. توقيع `initialize()` العام لم يتغيّر إطلاقاً، فالـBloc الذي يستدعيه في مكانين لم يتأثر.

**`lib/features/live/data/datasources/lives_media_datasource.dart`**
- أضفت ثلاث دوال مساعدة: `_captureOptionsFor` و`_simulcastLayersFor` و`_publishOptionsFor` — تبني خيارات LiveKit من الملف الشخصي بدل الأرقام المكرّرة يدوياً في خمسة مواضع.
- حلقة `createCameraTrack` صارت تنزل درجة كل محاولتين بدل تكرار نفس الدقة ست مرات. **أبقيت ميزانية المحاولات الست وتأخيرها التصاعدي كما ضبطها الفريق** لأجهزة Xiaomi.
- أضفت `_activeProfile` يحفظ ما **قبلته العتاد فعلاً**، والنشر يبني سلّمه منه — فلا نعلن طبقة رفضها المستشعر.
- `flipCamera` صار يقلب على الملف الشخصي النشط بدل 720p ثابتة (كان يخفّض بثاً 1080p بصمت عند تبديل العدسة).
- **لم أمسّ** `dynacast: false` ولا `backupVideoCodec` ولا `adaptiveStream` — التعليقات تشرح أنها تمنع انهيار التفاوض على Xiaomi، واحتفظت بها وبتفسيرها.

**`features/live_source/` — إحياء شاشة بدء البث (٦ ملفات)**
- `live_event.dart` / `live_state.dart` / `live_bloc.dart`: أضفت دورة حياة الكاميرا بنفس بنية `features/live` المجرَّبة، معتمداً على `InitializeCamera` و`DisposeCamera` الموجودتين — لم أكتب مستودع كاميرا جديداً.
- `camera_preview_layer.dart`: صار يعرض `AspectPreservingCameraPreview` الحقيقية بدل `Container(color: Colors.black)`.
- `live_start_page.dart`: أضفت `WidgetsBindingObserver` وطلب صلاحيات الكاميرا والميكروفون مسبقاً و`LiveScreenWakelock`.
- `live_container.dart`: أضفت **تسليم الكاميرا** إلى `LiveRoomPage` عبر `initialCamera`. هذه ليست تحسيناً تجميلياً: بما أن الشاشة تُستبدل بـ`pushReplacement`، لولا التسليم لبقي الـcontroller بلا مالك بينما تفتح الغرفة جلسة ثانية.

**`settings_panel.dart` (في `live` و`live_source`)**
صف "جودة الفيديو" كان `chevron` ميتاً بلا `onTap`. صار يفتح الورقة الجديدة.

**`lib/app/home/presentation/pages/add_post_camera_screen.dart`**
هذا التعديل نتيجة مباشرة لإحياء الكاميرا في شاشة بدء البث، ولولاه لكنت أدخلت خطأً جديداً على iOS:

الشاشة تفتح صفحة البث بـ`Navigator.push`، أي أن كاميرتها تبقى **مركّبة وتعمل** تحت الصفحة المدفوعة. على Android المسار محمي أصلاً — `_handleGoLiveTap` تستدعي `ArCameraBridge.stopCamera()` قبل الدفع وتعيد التشغيل في `finally`. على iOS لا يوجد ما يوقف `CameraAwesomeBuilder`، لأنه لم يكن هناك ما ينافسه: صفحة البث كانت شاشة سوداء بلا كاميرا.

بعد تعديلي صارت صفحة البث تفتح جلسة التقاط حقيقية، و iOS لا يسلّم الجهاز نفسه لجلستين. لذلك أضفت `_liveHandoffActive`: يفكّ تركيب معاينة CamerAwesome طوال وجود صفحة البث ثم يعيدها عند الرجوع — بنفس شكل المسار الأندرويدي الموجود، لا بنمط جديد.

**`live_state.dart` (في `live_source` و`live`) — إصلاح خطأ حقيقي**

`copyWith` كانت تكتب `controller: controller ?? this.controller`. مع هذا السطر **لا يمكن إطلاقاً تصفير الـcontroller**: كل نداء `copyWith(controller: null)` — وهي ثلاثة نداءات في الـBloc (`_onSwitchCamera`، `_onAppPaused`، `_onCameraHandedOff`) — كان يُبقي الـcontroller القديم **بعد التخلص منه**، فيبقى كائن مُتلَف داخل الحالة. تعليق `_onCameraHandedOff` يقول حرفياً "انسَ الكاميرا هنا بلا تخلّص" وهو ما لم يكن يحدث.

لم أخترع نمطاً جديداً: المشروع **يحلّ هذه المشكلة نفسها سلفاً** في `live_room_state.dart` عبر حارس `const Object _unset = Object();` ثم `identical(x, _unset) ? this.x : x as T?`. نقلت النمط نفسه حرفياً إلى الملفين. كل مواضع الاستدعاء تقصد الإسناد لا الاحتفاظ، والنداءات التي لا تمرّر `controller` تبقى سلوكها كما هو عبر القيمة الافتراضية للحارس.

عدّلت النسخة الميتة في `features/live` أيضاً لأن الملفين مرآة لبعضهما في هذا المشروع، وتركها يعني أن أول من يربط تلك الشاشة بمسار يرث الخطأ نفسه.

**`ios/Podfile` + `ios/Runner.xcodeproj/project.pbxproj`**
`IPHONEOS_DEPLOYMENT_TARGET` كان `13.0`، وهو أقل من الحد الأدنى الذي تعلنه الحزم. تحققت من المصدر بدل التخمين — قرأت `ios.deployment_target` من كل podspec محلي:

| الحد الأدنى | الحزمة |
|---|---|
| **15.5** | `google_mlkit_face_detection` · `google_mlkit_commons` |
| 15.0 | `cloud_firestore` · `firebase_core` · `firebase_auth` · `firebase_messaging` · `cloud_functions` |
| 14.0 | `google_maps_flutter_ios` |

**القيد الحاكم هو MLKit عند 15.5**، لا Firebase — ولهذا الرقم `15.5` تحديداً وليس `15.0`. رفعت الهدف في الـPodfile وفي الأهداف الثلاثة داخل `project.pbxproj`.

**تحققت من الأساس تجريبياً** (لا استنتاجاً): أنشأت worktree منفصلاً على `origin/live-merge` نظيفاً وشغّلت `pod install`، والنتيجة:

```text
[!] CocoaPods could not find compatible versions for pod "cloud_firestore":
    Specs satisfying the dependency were found, but they
    required a higher minimum deployment target.
```

أي أن **`live-merge` لا يبني على iOS إطلاقاً — يفشل عند `pod install` قبل أي ترجمة**. هذه حقيقة مؤكَّدة الآن بالتشغيل، لا ترجيحاً.

> **تصحيح مزدوج لمسودة سابقة:** المسودة نسبت الرفع إلى `cloud_firestore` وذكرت `15.0`.
> - نسبتها إلى `cloud_firestore` **صحيحة** كسبب لرسالة الفشل عند `13.0` — وهو أول pod يصطدم به الحل.
> - لكن الرقم `15.0` **غير كافٍ**: رفعُه إلى 15.0 يتجاوز Firebase ثم يصطدم بـMLKit عند 15.5.
>
> فالخلاصة الدقيقة: `cloud_firestore` هو ما **يكسر** البناء عند 13.0، و`google_mlkit_*` هو ما **يحدد السقف** عند 15.5. (وقد صحّحتُ هنا تصحيحاً سابقاً لي نفسه كان يلغي دور `cloud_firestore` بالكامل — وهذا تبسيط خاطئ.)

#### حالة بناء iOS — تشخيص مؤكَّد

فشل البناء مرتين، والسبب **ليس في الكود**. التسلسل كما جرى فعلاً:

1. `flutter run` فشل بـ`Command CompileC failed with a nonzero exit code` **بلا أي سطر `error:` في السجل كله**. الفشل الحقيقي في ملف C يطبع دائماً الملف والسطر والتشخيص؛ غيابها كان الدليل الأول على أن السبب بيئي لا برمجي.
2. أعدت البناء عبر `flutter build ios --release` فظهرت الرسالة صريحة:

```text
error: accessing build database ".../DerivedData/Runner-hfeqksaeceatfveedniplhesgjde/
Build/Intermediates.noindex/XCBuildData/build.db": disk I/O error
```

3. التحقق من الاحتمالات:

| الاحتمال | الفحص | النتيجة |
|---|---|---|
| القرص ممتلئ | `df -h` | **مستبعد** — 30 GB متاحة |
| قاعدة بناء تالفة | `ls .../XCBuildData/` | **مؤكَّد** — المجلد **فارغ**، القاعدة مفقودة |
| تزاحم مع Xcode | `pgrep -x Xcode` | **مؤكَّد** — Xcode يعمل على المشروع نفسه أثناء بناء سطر الأوامر |

وقد أظهرت لقطة شاشة من المستخدم خطأ Xcode نفسه في اللحظة ذاتها: `unable to attach DB: error: accessing build database` — أي أن البرنامجين كانا يتنازعان قاعدة البناء نفسها داخل DerivedData.

**الخلاصة:** لا علاقة للفشل بتعديلات هذا الفرع. `CompileC` مرحلة ترجمة C/Objective-C، ولا يمكن لتغيير Dart أن يسببها، والتغيير الوحيد الذي يمسّ iOS هنا هو هدف النشر الذي يرفع التوافر ولا يخفضه.

**الإجراء:** إغلاق Xcode ثم مسح مجلدات `Runner-*` في DerivedData (ذاكرة بناء مؤقتة تُعاد توليدها تلقائياً، ولا تمسّ الشيفرة) ثم إعادة البناء.

**لن أعلن نجاح التشغيل على الجهاز قبل أن يعمل فعلاً.**

### ما لم ألمسه عمداً

- **محرّكات Android الأصلية** (`ar_camera/`, `camera_engine/`): مضبوطة سلفاً على 1080p بتعليقات تشرح سقوف أجهزة بعينها. تعديلها كان سيكسر كاميرا المنشور بلا مقابل.
- **`features/live_viewer`**: جانب المشاهد يستخدم `adaptiveStream: true` بلا سقف، فهو **يستفيد تلقائياً** من الطبقة الجديدة 1080p دون أي تعديل.
- **أي دالة أو Widget مشترك**: كلما احتجت سلوكاً جديداً أنشأت عنصراً جديداً بدل تعديل القائم.
- **`pubspec.lock`**: أرجعته لحالته الأصلية — التغيّر كان انجرافاً من إصدار Flutter المحلي لا علاقة له بالعمل.

### عن بند "استنساخ واجهة TikTok": ما وجدته فعلياً

طُلب مني استنساخ واجهة TikTok. قبل أن أكتب سطر واجهة واحداً فحصت ما هو موجود، والنتيجة أن **الفريق سبقني إلى ذلك وبدقة عالية**:

- `features/live_viewer/presentation/widgets/tiktok_live_tokens.dart` — نظام تصميم كامل موصوف حرفياً بأنه *"Pixel-measured TikTok LIVE viewer tokens (~390pt iPhone reference). Source of truth: real TikTok LIVE chrome — do not use Material defaults."* ألوان العلامة (`liveRed 0xFFFE2C55`, `liveCyan 0xFF25F4EE`)، وارتفاعات وأنصاف أقطار وفجوات مقاسة بالبكسل.
- `tiktok_live_chrome.dart` (860 سطراً) — الشريط العلوي والسفلي والشارات بنفس المقاسات.
- `features/live/presentation/widgets/room/` — 24 widget للمضيف (الرأس، الشريط السفلي، الدردشة، الهدايا، الضيوف، الترتيب، المشاركة، المؤثرات).

**لذلك لم أعِد بناء الواجهة.** إعادة كتابة نظام تصميم مقاس بالبكسل ومربوط بـ24 شاشة كانت ستكسر شاشات تعمل اليوم، وهذا بالضبط ما طلبتَ تجنّبه. الفجوة الحقيقية في الواجهة لم تكن التصميم بل **شاشتين**:

1. شاشة بدء البث تعرض مستطيلاً أسود بدل الكاميرا — **أصلحتها**.
2. صف "جودة الفيديو" زر ميت — **أصلحته**.

وكلاهما داخل الأسلوب البصري القائم: ورقة الجودة تستخدم `AppColors.optionsSheetBackground` و`LiveRoomOptionsCard` و`AppTextStyles.optionsMenu*` الموجودة، لا ألواناً ولا مقاسات جديدة.

إن كان لدى قائد الفريق فروق بصرية محددة مقابل TikTok يريد إغلاقها، فهي تُفتح كمهام مستقلة بلقطات شاشة مرجعية — لا كإعادة بناء شاملة.

### إصلاحان إضافيان بعد أول تشغيل على الجهاز

بعد أن نجح البناء والتثبيت على الآيفون، ظهرت مشكلتان حقيقيتان — كلتاهما **سابقة لعملي** ولا علاقة لهما بسلّم الدقة:

#### 1. تعطّل التطبيق عند الإقلاع: `GoogleService-Info.plist` غير مضمَّن

```text
*** Terminating app due to uncaught exception 'com.firebase.core',
reason: '`FirebaseApp.configure()` could not find a valid
GoogleService-Info.plist in your project.'
```

الملف **موجود على القرص** في `ios/Runner/GoogleService-Info.plist`، لكنه **لم يكن مضافاً إلى مشروع Xcode إطلاقاً** (`grep -c` على `project.pbxproj` = صفر)، فلا يُنسخ إلى حزمة التطبيق. و`AppDelegate.swift:13` يستدعي `FirebaseApp.configure()` أصلياً، وهو يقرأ الملف من الحزمة لا من القرص.

أضفته كمورد إلى هدف `Runner` عبر مكتبة `xcodeproj` (المتوفرة أصلاً مع CocoaPods) بدل التحرير اليدوي لـ`project.pbxproj`، والنتيجة **٤ أسطر فقط** بلا إعادة تنسيق للملف.

**تعارض معرّفات مكتشف ولم أغيّره:**

| الموضع | المعرّف |
|---|---|
| `applicationId` في أندرويد | `com.dubai.bimobondapp` |
| `GoogleService-Info.plist` | `com.dubai.bimobondapp` |
| هدف iOS في Xcode | `com.example.bimobondapp` ← قيمة افتراضية |
| `iosBundleId` في `firebase_options.dart` | `com.example.bimobondapp` |

تركته كما هو عمداً: تغيير معرّف الحزمة يمسّ التوقيع والـprovisioning وتسجيل Firebase console، وهو قرار قائد الفريق لا قرار منفرد. لكنه **يجب أن يُحسم قبل أي رفع إلى TestFlight**.

#### 2. زر قلب الكاميرا معطّل في شاشة بدء البث

`live_source/.../tools_row.dart:96` كان يرسل `LiveToolsToggleRequested`، أي أنه **يكرّر سهم الطي الموجود فوقه مباشرة**، ولا توجد أي طريقة لتبديل العدسة قبل البث. النسخة القديمة `live/.../tools_row.dart:96` تحمل الربط الصحيح `LiveCameraSwitchRequested` — أي أن `live_source` فقدته حين كانت الشاشة "واجهة فقط بلا كاميرا".

النتيجة الجانبية: `_onSwitchCamera` كان **كوداً ميتاً** بلا أي مُرسِل رغم أنه منفَّذ بالكامل. وقد صار الآن صحيحاً فعلاً بفضل إصلاح `_unset` (فبدونه كان `copyWith(controller: null)` يُبقي controller متلَفاً أثناء التبديل).

#### ملاحظة عن مرجع الواجهة

راجعت `go_live_page.dart` في مشروع العينة كمرجع لواجهة TikTok كما طُلب مني، ووجدته **صفحة نموذج بسيطة (AppBar + حقل نص + زر)** — أي **أبعد عن TikTok** مما هو موجود عندنا. تخطيط `bimobondapp` الحالي (كاميرا ملء الشاشة + صف أدوات + بطاقة LIVE) هو الأقرب فعلاً. لذلك **لم أنسخ منها شيئاً** — النسخ كان سيكون تراجعاً لا تحسيناً.

**عنصر ميت لم ألمسه:** زر اختيار صورة الغلاف في `live_container.dart` مجرد `Icon` بلا `onTap`. تفعيله يحتاج اختيار صورة + رفعاً، وهو نطاق مستقل لم أُدخله في هذه المرحلة.

### نتائج التشغيل الفعلي

#### أندرويد (محاكي `sdk gphone64 arm64`) — أقلع بنجاح

التطبيق بُني وثُبّت وأقلع. **لا تعطّل Firebase** لأن أندرويد يقرأ `google-services.json` وهو موجود ومسجَّل على `com.dubai.bimobondapp` الصحيح. هذا يؤكد أن خلل `GoogleService-Info.plist` كان **خاصاً بـiOS وحده**.

لكن السجل أظهر حلقة فشل متكررة في CameraX:

```text
Camera2DeviceCache: Expected minimum camera count = 2
Failed to query camera ID list: Invalid list returned: [CameraId-1]
Camera LENS_FACING_FRONT verification failed
CameraIdListIncorrectException: Expected camera missing from device
```

**التشخيص:** المحاكي يعلن كاميرا واحدة فقط (خلفية، `id=1`) بلا أمامية، وCameraX يتوقع اثنتين فيرفض التهيئة ويعيد المحاولة بلا توقف. **ليس خطأً في الكود.**

تحققت من أن كود الفريق يتعامل مع الحالة أصلاً — `CameraRepositoryImpl._initializeUnlocked` يستخدم `orElse: () => cameras.first`، فلا يرمي استثناءً عند غياب الأمامية. لكن CameraX يفشل على مستوى أدنى قبل أن يصل التنفيذ إلى تلك السطور.

**نقطة تقنية مهمة:** تأكدت من `pubspec.lock` أن تنفيذ أندرويد للملحق `camera` هو `camera_android_camerax`، أي أن معاينة شاشة بدء البث **تمر فعلاً عبر CameraX** لا عبر camera2 مباشرة.

#### iOS (آيفون حقيقي) — البناء نجح، والربط فشل لاسلكياً

البناء اكتمل ووُقّع وبدأ التثبيت، ثم فشل عند اكتشاف `Dart VM Service`:

```text
Your debugging device seems wirelessly connected.
The mDNS query for an attached iOS device failed.
Error launching application on Bashar's iPhone (wireless).
```

عقبة اتصال شبكي لا خطأ برمجي. الحل: كابل USB.

#### لماذا المحاكي لا يصلح للتحقق من هذه المهمة

المهمة كلها عن **دقة الكاميرا** (١٠٨٠p بنسبة ١٦:٩). المحاكي يقدّم كاميرا وهمية بدقة ثابتة، فلا يثبت ولا ينفي شيئاً عن سلّم الدقة. أي نتيجة منه **مضلِّلة**. التحقق الحقيقي يحتاج عتاداً فعلياً.

لإصلاح المحاكي إن أُريد اختبار بقية الواجهة عليه: Device Manager ← تعديل AVD ← Advanced Settings ← Camera ← ضبط **Front** و**Back** على `Emulated`، ثم Cold Boot.

### التسليم: الفرع والـcommits والـPR

العمل كله على `bashar` فقط، مسحوب من `live-merge` ومطابق له قبل البدء (`0 ahead / 0 behind`). لم ألمس أي فرع آخر.

قسّمت العمل إلى أربعة commits منطقية بدل commit واحد ضخم، بنفس أسلوب الفريق المختصر:

| # | الرسالة | النطاق |
|---|---|---|
| 1 | `Raise iOS deployment target to 15.5` | إصلاح البناء المتوقف — منفصل عمداً حتى يمكن انتقاؤه (cherry-pick) وحده |
| 2 | `Open the host preview on a real 16:9 profile` | الكيان + التفضيل + مستودع الكاميرا + ورقة الجودة + الاختبارات |
| 3 | `Publish the ladder the camera actually opened at` | مسار LiveKit |
| 4 | `Bring the camera back to the go-live screen` | إحياء `live_source` + إصلاح `copyWith` + تسليم iOS |

**PR:** <https://github.com/ahesain8-bot/bimobondapp/pull/25> — الأساس `live-merge`، بانتظار مراجعة قائد الفريق.

ملاحظة: أثناء التجهيز التقط `git add -A` ملف build ناتجاً عن Gradle (`packages/face_detection_tflite/android/build/reports/problems/problems-report.html`) وهو **متتبَّع سلفاً في المستودع** من commits سابقة للفريق. أعدته إلى حالته وعدّلت الـcommit حتى لا يدخل ضجيج غير متعلق بالعمل.

### التحقّق

| الفحص | النتيجة |
|---|---|
| `flutter analyze` (المشروع كاملاً) | **٠ أخطاء** (396 ملاحظة، كلها من كود قائم سابقاً) |
| `flutter analyze` على المناطق التي لمستها | **٠ أخطاء ولا تحذير جديد** |
| التحذير الوحيد في ملف عدّلته | `unnecessary_cast` في `lives_media_datasource.dart:275` — **موجود سلفاً في `HEAD`** (تحققت عبر `git show HEAD:` فوجدته في السطر 266 بالنص نفسه)، وتركته لأنه ليس من عملي |
| `flutter test` | **14 ناجحاً**، وفشل واحد في `widget_test.dart` |
| `widget_test.dart` | اختبار العدّاد الافتراضي من `flutter create` الذي لم يُحدَّث قط: يفحص عدّاداً و`Icons.add` لا وجود لهما في `MyApp` الحقيقي. لا علاقة له بالكاميرا ولا بالبث، ويفشل على `live-merge` أيضاً. **لم أحذفه ولم أعدّله** — إصلاحه خارج نطاق هذه المهمة، وحذفه إخفاء لا إصلاح |
| اختبارات سلّم الدقة الجديدة | **7/7 ناجحة** |

### الأثر المتوقّع

| | قبل | بعد |
|---|---|---|
| معاينة المضيف | 480p (وتسقط إلى 240p عند الفشل) | 1080p، وتنزل 720p ثم 480p بحسب العتاد |
| التقاط LiveKit | 720p ثابتة | 1080p بسقف قابل للاختيار |
| سلّم Simulcast | 720p / 480p | 1080p / 720p / 480p |
| سقف المشاهد | 720p | 1080p (عبر `adaptiveStream` القائم) |
| شاشة بدء البث | شاشة سوداء | معاينة كاميرا حيّة تُسلَّم للغرفة بلا وميض |
| صف "جودة الفيديو" | زر ميت | ورقة اختيار حقيقية تتحكم بالمسارين |

---

## ملحق: تغطية واجهات الخادم مقابل `endpoints.md`

راجعت `lib/core/network/api_endpoints.dart` و`lives_remote_datasource.dart` مقابل الـ76 مساراً الموثّقة في `endpoints.md`. **لم أضف مسارات جديدة** لأن نطاق هذه المرحلة — بحسب طلبك — هو الكاميرا والواجهة. لكن هذا هو الوضع الحالي ليراه قائد الفريق:

### مُنفَّذ ومربوط ✅

دورة حياة البث (`POST /lives`, `start`, `end`, `PATCH /lives/:id`)، الاكتشاف (`feed`, `mine`, `:id`)، الحضور (`join`, `leave`)، الإعجاب، التعليقات (إرسال/سرد/حذف/تثبيت/إلغاء تثبيت)، إشراف المشاهدين (كتم/إلغاء كتم/حظر/رفع حظر)، إدارة الضيوف من طرف المضيف (دعوة/قبول/رفض/طرد/كتم/كاميرا/ترقية/تخفيض)، الإعدادات، المعرض وتثبيت المزادات، لوحات الترتيب، وملخص ما بعد البث.

### موثّق وغير مربوط بعد ⬜

| العائلة | المسارات | المهمة في `tasks.md` |
|---|---|---|
| طلب المقعد من المشاهد | `POST …/guests/request` · `POST …/guests/accept-invite` · `POST …/guests/token` | M4 |
| معارك PK | `POST …/battle` · `…/battle/match` · `…/battle/multiplier` · `GET …/battle` · `…/battle/opponents` · `POST …/battle/:id/end` | M5 |
| أهداف الهدايا | `POST …/gift-goal` | M6 |
| الاستطلاعات | `POST …/polls` · `…/polls/:pollId/vote` · `GET …/polls/active` | M7 |
| صندوق الأسئلة | `POST …/qa` · `…/qa/:qaId/answer` · `GET …/qa` | M8 |
| صناديق الكنز | `POST …/treasure-boxes` · `…/:boxId/claim` · `GET …/treasure-boxes` | M9 |
| قواعد الدردشة | `PATCH …/chat-rules` | M3 |
| مشرفو الغرفة | `GET/POST/DELETE …/moderators` | M4 |
| المزادات النشطة والدوريات | `GET …/auctions/active` · `GET /lives/leagues` | M10 · M11 |

هذه تُقدَّر بمهام مستقلة (M4 الجزء المتبقي، وM5 حتى M9) وتحتاج قراراً بالأولويات قبل البدء.

---

## ملاحظة واقعية

كما هو مكتوب في تقرير العينة: الجودة النهائية تتأثر بالإضاءة والعدسة وحرارة الجهاز وعرض الشبكة. الهدف الصحيح ليس عرض أكبر رقم على الشاشة، بل **طلب أعلى مسار فيديو 16:9 يعالجه الجهاز بثبات، ثم النزول بصدق عند العجز**. هذا ما يفعله الكود الآن على المسارين معاً.

يبقى بند واحد خارج نطاق التطبيق: مشاكل الأداء الاثنتا عشرة في `PERFORMANCE.md` كلها في الخادم (NestJS/Prisma) وتحتاج قرار فريق الباك-إند.
