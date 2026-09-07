# تدقيق مهام LIVE — بشار — 2026-09-07

> تحديث الاستعادة: هذا تقرير الجولة السابقة. راجع [استعادة مايا وتصحيح الدمج](live-recovery-2026-09-07.md) للأخطاء التي كُشفت بعده، ومنها توثيق طلبات ألعاب المشاهد وإعادة البث ونادي المعجبين وحالة الألعاب. أوصاف Complete أدناه لا تعني قبولًا على الأجهزة أو تحققًا من صيغ استجابة غير موثقة.

هذا سجل عمل يتحدث أثناء التنفيذ. الحالات النهائية في المصفوفة أدناه؛ وجود عقد مكتوب أو نجاح unit test لا يمثل اختبار بيئة ولا اكتمال منتج.

## البداية والبيئة (الجولة الحالية)

- الجذر: `bimobondapp`؛ البرانش **`maya-bimo`** بعد دمج `bashar` فيه (انظر «الدمج» أدناه). لا reset ولا clean ولا استبدال بأرشيف.
- Flutter 3.44.8؛ Dart 3.12.2؛ entrypoint الإنتاج `lib/main.dart`.
- **baseline هذه الجولة (بعد الدمج، قبل الميزات الجديدة):** `flutter analyze --no-pub` = 0 errors؛ `flutter test --no-pub` = **325 Passed**.
- **النتيجة الحالية:** `flutter analyze --no-pub` = **0 errors** (445–448 info/warning سابقة في المشروع)؛ `flutter test --no-pub` = **377 Passed / 0 Failed**؛ `git diff --check` نظيف.
- الأجهزة المتاحة الآن (`flutter devices`): محاكيا Android 15 (`emulator-5554`، `emulator-5556`)، محاكيا iOS 26.5 (iPhone 17 Pro، iPhone Air)، وهاتف حقيقي `Bashar’s iPhone` iOS 26.6.1 عبر اتصال لاسلكي، وmacOS.
- **أرقام الجولة الماضية (297 اختبارًا) لم تُعد استخدامها كنتيجة حالية.** كل رقم أعلاه من تشغيل هذه الجولة.

## الدمج مع عمل مايا (maya-bimo)

- `git merge-base bashar origin/maya-bimo` = `05a0f3b`؛ بشار 7 commits، مايا commit واحد (`932cfcd`). لا فقدان لأي طرف.
- نسخ احتياطية قبل الدمج: البرانش `backup/bashar-pre-maya-merge-2026-09-07` والوسم `backup/maya-bimo-pre-merge-2026-09-07`.
- 15 ملفًا تعارض (30 hunk)، حُلّت يدويًا بالإبقاء على الجانبين. أهم القرارات:
  - `LiveViewerBloc`: مسار دخول واحد — قراءة الحساب ← `GET /lives/:id` جديد ← بوابة تاريخ الميلاد (+18) ← بوابة التذكرة ← `join`. علم `ageRestricted` صار يُقرأ من استجابة الغرفة لا من بطاقة الخلاصة.
  - الاكتشاف: بقيت مسارات بشار الثلاثة (`feed` / `nearby` / `audio`)، وتبويب Voice عند مايا صار يمر بسطح audio بدل علم على `/lives/feed`، وتبويب الصوت ولوحة الفلاتر يتشاركان قيمة `surface` واحدة.
  - `live_room_page` للمشاهد: مستمع المشاركة/الإبلاغ عند مايا يغلّف مستهلك هدف الهدايا عند بشار.
- **عيبان أحدثهما الدمج نفسه، وأُصلحا:**
  1. عادت `latitude`/`longitude` إلى `/lives/feed`؛ الخادم المنشور يرفضها (HTTP 400) ويُفرِّغ شاشة الاكتشاف. حُذفت من مسار الخلاصة، وNearby يبقى على endpoint الخاص به.
  2. مدخل «البث من البروفايل» عند مايا كان يعتمد على تفعيل ذاتي داخل `LiveRoomPage` أُزيل عند نقل التفعيل إلى نقطة الدخول؛ صار المدخل يرسل `LiveViewerActivated` نفسه (فتمر بوابتا العمر والتذكرة) ويحمل مصدر الزيارة `PROFILE`.
- مهام مايا (pause، الغرف الصوتية، البيت، المشرفين، الاستوديو، قواعد الدردشة، المشهد/الكاميرا المزدوجة، إدارة الضيوف) بقيت كما هي ولم تُعد كتابتها؛ اختبارها الآلي (`test/live_socket_payload_test.dart`) يعمل ضمن المجموعة الكاملة.

## المصفوفة النهائية — 17 صفًا

| # | الميزة | التنفيذ | القبول على الجهاز | المتبقي بالتحديد ودليله | الملفات | الاختبارات ونتائجها |
|---|---|---|---|---|---|---|
| 30 | الترويج | **Blocked** | **Not run** | `UnverifiedLivePromotionContract` ما زال مستخدمًا عمدًا. لا توجد أظرف استجابة لأي من `/promotions/lives/*` في أي وثيقة محلية (فُحصت `live-promotions.md` و`endpoints2.md` و`mobile-api.md` و`logic.md` و`tasks.md`)، ولا حقل `visibility` في مرجع كائن Live. الطلب مجمّع في `docs/live-promotions-integration.md`. | `lib/app/live_promotions/**` | `live_promotions_domain_test.dart`، `live_promotion_bloc_test.dart`، `live_promotion_attribution_test.dart`، `live_promotions_ui_test.dart` — كلها Passed |
| 20 | PK (فرق/BO3/قدرات) | **Partial** | **Not run** | العقد والنموذج والطلبات مكتملة (TEAM، المقاعد، `openSlots`، `scoringMode`، BO3، الجولات، STUN/TIME/GLOVE). الناقص: **وسائط 2v2** — لا توكن LiveKit موثق لغرفتي `live3`/`live4` في أي وثيقة، فلا يمكن عرض تايلات الفريق إلا عبر ما يرسله السيرفر في `cohosts[]`. لم يُخترع ظرف. | `lib/core/models/live_battle.dart`، `lives_remote_datasource.dart`، `live_session_repository_impl.dart` | `live_team_battle_test.dart` (17) + `live_battle_test.dart` + `live_battle_media_serialization_test.dart` — Passed |
| 14 | الكوهوست المتعدد | **Partial** | **Not run** | الدعوة/القبول/الإنهاء/القائمة والتايلات منفذة، وحتى ثلاث غرف ثانوية subscribe-only كلٌّ بسجل مستقل. الناقص: تحقق ميداني بأربع غرف حقيقية، وهو غير ممكن دون أربعة حسابات بث. | `live_cohost.dart`، `live_cohost_mapper.dart`، `live_secondary_rooms.dart`، `live_cohost_tiles.dart` | ضمن `live_team_battle_test.dart` — Passed |
| 15 | الهدايا | **Partial** | **Not run** | المسار الحقيقي `lib/app/gifts` سليم ولم يُمس. الناقص: إرسال هدية فعلي بحساب اختبار ورصيد — لم يُنفَّذ (لا صرف رصيد دون تفويض). | `lib/app/gifts/**` | `live_gift_route_policy_test.dart`، `gift_large_top_blend_test.dart` — Passed |
| 16 | هدف الهدايا | **Complete** | **Not run** | تهيئة الهدف للمشاهد محفوظة عبر الدمج (`LiveInteractiveGiftGoalSnapshotReceived`). | `live_interactive_bloc.dart`، `gift_goal_card.dart` | `live_gift_goal_test.dart` — Passed |
| 29 | الترتيب والدوري | **Complete** | **Not run** | القراءة والربط قائمان (`loadHostLeague` موصول بورقة الترتيب). | `live_room_ranking_sheet.dart`، `live_host_extras_mapper.dart` | `live_ranking_league_test.dart` — Passed |
| 28 | نادي المعجبين | **Complete** | **Not run** | الشرائح وأسعارها من السيرفر، `tierSlug`، العضوية والولاء، الإيموجي بحسب `minTier`، وإدارة المضيف. الحجب المالي بقي **فقط** حين لا يرسل السيرفر سعرًا للشريحة. | `fan_club_*` (datasource/repo/usecases/bloc/UI)، `live_operation_guard.dart` | `live_fan_club_test.dart` (10) — Passed |
| 10 | التذاكر | **Complete** | **Not run** | مسار دخول واحد لكل المداخل (خلاصة، صفحة غرفة، دخول من البروفايل، إعادة محاولة). منع التذكرة مفصول عن 403 العمر/الحظر/الخصوصية. الناقص: شراء تذكرة حقيقي — يحتاج رصيد اختبار. | `live_viewer_bloc.dart`، `live_ticket_service.dart`، `open_profile_live.dart` | `live_ticket_service_test.dart`، `live_promotion_attribution_test.dart` — Passed |
| 21 | التفاعل (تصويت/أسئلة/كنز) | **Complete** | **Not run** | حماية الصفر والدمج الجزئي ونتائج البث السابق قائمة ولم تُعد كتابتها. | `live_interactive_bloc.dart` | `live_poll_treasure_test.dart`، `live_operation_guard_test.dart` — Passed |
| 22 | الألعاب الرسمية | **Complete** | **Not run** | كتالوج + QUIZ/WHEEL/LUCKY_DRAW، لعبة نشطة واحدة، لعبة واحدة لكل مشاهد، إخفاء الإجابة حتى الإنهاء، والنتيجة من السيرفر فقط. | `live_game.dart`، `live_games_remote_datasource.dart`، `live_game_mapper.dart`، `live_games_bloc.dart`، `live_games_sheet.dart` | `live_games_test.dart` (10) — Passed |
| 17 | المزادات | **Partial** | **Not run** | الربط بـ`auctionId` والمستلم ووحدات السعر قائم. الناقص: مزايدة/دفع حقيقي — يحتاج رصيد اختبار وتفويض. | `lib/app/auctions/**`، `live_interactive_*` | ضمن `live_poll_treasure_test.dart` — Passed |
| 18 | الحقيبة والمتجر | **Complete** | **Not run** | تمرير `liveId` والكوبون وعرض bag قائم، وأُضيفت **إدارة عروض الفلاش والكوبونات للمضيف** عبر `PATCH …/deal`. لا يُحسب أي خصم محليًا. الناقص: طلب شراء حقيقي. | `shop_remote_data_source.dart`، `shop_repository_impl.dart`، `shop_usecases.dart`، `live_product_sheet.dart`، `checkout_screen.dart` | `live_shop_deal_test.dart` (7) — Passed |
| 19 | المعرض | **Complete** | **Not run** | إعادة الترتيب موصولة بالشاشة (`reorderGalleryItems`). | `live_room_gallery_sheet.dart` | ضمن `live_discovery_surfaces_test.dart` — Passed |
| 3 | الاكتشاف | **Complete** | **Not run** | For You/Following/التصنيف/Nearby/audio/topic تعمل عبر ثلاثة endpoints منفصلة بمفاتيح cache معزولة بالحساب والسطح. **بدون** إحداثيات على `/lives/feed`. | `live_feed_screen.dart`، `http_live_remote_datasource.dart`، `fake_live_repository.dart`، `get_live_feed_usecase.dart` | `live_discovery_surfaces_test.dart`، `live_promotion_attribution_test.dart` — Passed |
| 24 | الإعادة | **Complete** | **Not run** | شاشة وصول + مشغّل + إدارة المضيف (نشر رابط/حذف). `GET replay` يُستدعى مرة عند الفتح ومرة عند Refresh الصريح فقط. | `live_replay_bloc.dart`، `live_replay_page.dart`، `live_state_overlay.dart`، `live_summary_page.dart` | `live_replay_ui_test.dart` (8) + `live_replay_clips_test.dart` — Passed |
| 25 | القصاصات | **Complete** | **Not run** | اختيار الحدود على مدة المشغّل الحقيقية، معاينة تتوقف عند نهاية الاختيار، إنشاء ثم نشر بتأكيد، والتنقل للمنشور **فقط** إن أعاد السيرفر `postId`. | نفس ملفات 24 | `live_replay_ui_test.dart` — Passed |
| 26 | التقرير | **Partial** | **Not run** | كل الحقول من السيرفر، والمجهول يظهر «غير متاح» لا صفرًا. مصادر الزيارة: FOR_YOU وFOLLOWING وPROFILE وOTHER موصولة. **SEARCH/SHARES/NOTIFICATION/CHAT غير موصولة لعدم وجود مدخل بث في تلك الشاشات** (لا حقل `isLive` في `SocialUserEntity`، لا نوع إشعار LIVE، ولا معالجة روابط عميقة في المشروع). | `live_summary_page.dart`، `live_traffic_source.dart`، `open_profile_live.dart` | `live_discovery_surfaces_test.dart` — Passed |

**العدّ (17 صفًا):**

- **Complete = 11:** 16، 29، 28، 10، 21، 22، 18، 19، 3، 24، 25.
- **Partial = 5:** 20 (وسائط 2v2)، 14 (تحقق بأربع غرف)، 15 (إرسال هدية حقيقي)، 17 (مزايدة/دفع حقيقي)، 26 (أربعة مصادر زيارة بلا مدخل بث).
- **Blocked = 1:** 30.

هذا عدّ **تنفيذ** فقط. **حالة القبول على الجهاز: Not run في الصفوف السبعة عشر جميعها** — لا يوجد صف واحد Passed في هذه الجولة. وجود models أو نجاح unit tests لا يُحتسب إكمالًا للمنتج.

## اختبار الأجهزة — هذه الجولة

- **لم تُنفَّذ سيناريوهات القبول الـ17 على الأجهزة في هذه الجولة، وحالتها Not run.** لم أستبدل أي سيناريو جهاز بـmock وأسميه Passed.
- **ما نُفِّذ فعلًا:** `flutter build apk --debug` اكتمل بنجاح (exit 0، `build/app/outputs/flutter-apk/app-debug.apk`) — أي أن كل الكود الجديد يُصرَّف لهدف Android حقيقي. هذا **بناء وليس سيناريو قبول**، ولا يُحتسب Passed لأي ميزة.
- **العوائق الفعلية:** السيناريوهات المطلوبة (تذكرة، هدية، كنز، مزاد، اشتراك نادي، شراء متجر، نشر قصاصة، بدء/إنهاء بث، 2v2 بأربعة بثوث) تصرف رصيدًا أو تغيّر حالة خادم أو تنشر محتوى عامًا. لا يوجد تفويض محدد ولا حسابات اختبار ولا بيئة قبول ولا أرصدة اختبار. طلب واحد بها في القسم التالي.
- ما لا يعتمد على ذلك نُفِّذ: التحليل الساكن، المجموعة الكاملة للاختبارات، وبناء التطبيق.

## طلب واحد لإكمال اختبار القبول

1. بيئة قبول (Backend + LiveKit) منفصلة عن الإنتاج، مع عنوانها.
2. أربعة حسابات بث تجريبية قادرة على البث فعليًا (لاختبار 2v2 والكوهوست بأربع غرف)، وحسابا مشاهدة.
3. أرصدة عملات تجريبية على تلك الحسابات، وسقف ميزانية مسموح صرفه.
4. تفويض مكتوب ببدء/إنهاء بث في تلك البيئة، وبنشر قصاصة/منشور داخلها.
5. دور مضيف على بث ذي تذكرة مفعّلة، ونادي معجبين بأسعار شرائح مضبوطة.
6. أذونات التحكم بالأجهزة (أكثر من جهاز متزامن) أو جلسات إضافية لتشغيل الأطراف الأربعة.

## طلب واحد إلى فريق Backend (نواقص العقد)

| العملية | شكل البيانات المطلوب | أثر الغياب اليوم |
|---|---|---|
| كل `/promotions/lives/*` (options, packages, custom/preview, create, mine, by-live, stats, pay, patch/pause/resume/cancel) | ظرف نجاح وفشل لكل endpoint: حقول الحملة وحالتها الدقيقة، الميزانية والمدة والهدف ونمط الجمهور وحقول الاستهداف، ترقيم `mine`، وحدات الانطباعات/الإنفاق/المتبقي، ودلالة استجابة الدفع | الميزة 30 محجوبة بالكامل: كل قراءة تفشل مغلقة وكل تعديل يُمنع قبل الإرسال. التفاصيل الكاملة في `docs/live-promotions-integration.md` |
| `GET /lives/:id` | حقل `visibility` بقيمة `PUBLIC` موثقة | أهلية إنشاء حملة تفشل مغلقة لأن غياب الحقل ليس دليلًا على أن البث عام |
| `GET /lives/feed` مقابل `live-promotions.md` | حسم: هل يقبل `latitude`/`longitude` أم تُحذف من الوثيقة؟ الخادم المنشور يرد 400 `property latitude should not exist` | لا استهداف جغرافي؛ العميل لا يرسل إحداثيات على الخلاصة إطلاقًا |
| PK فرق 2v2 | توكنات LiveKit (أو مصدرها) لغرفتي `live3Id`/`live4Id`، وهل تصل ضمن `cohosts[]` أم في ظرف خاص | الفرق والنتيجة تعمل، لكن تايلات فيديو الفريق لا تُعرض إلا لما يرسله السيرفر في `cohosts[]` |
| `GET /lives/games/catalog` و`/games/active` و`/play` و`/end` | ظرف الاستجابة: أسماء حقول اللعبة والمشاركات، ومتى يظهر `correctIndex`، وشكل نتيجة WHEEL/LUCKY_DRAW والفائز | العميل يحلّل دفاعيًا: أي حقل غير مرسل يبقى «غير معروف» ولا نتيجة محلية |
| `GET /creators/:id/fan-club` | شكل `tiers[]` (اسم الحقل للسعر والمدة) و`membership` و`emotes[]` بشكل صريح، وظرف استجابة `subscribe` (بما فيه `alreadyMember`) | شريحة بلا سعر من السيرفر تبقى غير قابلة للشراء؛ لا سعر يُشتق محليًا |
| `POST /lives/:id/clips/:clipId/post` | هل يعود `postId` دائمًا عند `alreadyPosted: true`؟ | عند غياب `postId` لا يُعرض زر «فتح المنشور» بدل تخمين معرّف |
| مصادر الزيارة | حقل `isLive`/`currentLive` في نتائج البحث، ونوع إشعار لبدء بث، ورابط عميق لبث | مصادر SEARCH وSHARES وNOTIFICATION وCHAT غير قابلة للإرسال لعدم وجود مدخل بث في تلك الشاشات |
| مصالحة العمليات المالية | endpoint أو حقل يخص المستخدم لتأكيد نتيجة عملية غير محسومة (تذكرة/اشتراك/مطالبة) | العميل لا يعيد الإرسال أبدًا؛ يعرض «بانتظار التأكيد» ويحسمها فقط بدليل شخصي من السيرفر (عضوية/تذكرة) |

## سجل أسباب التغيير (الجولة الحالية)

- **28:** الاشتراك كان يرمي `FAN_CLUB_PRICE_UNVERIFIED` دائمًا — حجب آمن لا ميزة. الآن السعر يأتي من السيرفر، و`User.fanClubPriceCoins` يملأ سعر BASIC فقط إن لم ترسل القائمة سعرًا. «PLUS = 3×» افتراض خادم لا حساب عميل. الشراء يمر بـ`LiveOperationGuard` مع `retainSuccess: false` لأن العضوية تتجدد كل 30 يومًا بعكس تذكرة الدخول.
- **`LiveOperationGuard.settle`:** حسم يعتمد دليلًا شخصيًا خاصًا بالعملية (عضوية المستخدم نفسه كما يعيدها السيرفر). لا يُرفع القفل بمرور الوقت ولا بضغط Refresh ولا بتغير رصيد المحفظة ولا بقائمة عامة.
- **24/25:** `GET /lives/:id/replay` يزيد `viewCount`، فاستُدعي مرة عند الفتح ومرة عند Refresh الصريح فقط؛ قائمة القصاصات لها حدث مستقل لا يكلّف مشاهدة. لا Egress ولا ffmpeg ولا قص محلي: القصاصة هي بداية/نهاية على رابط الإعادة كما في العقد.
- **22:** لعبة نشطة واحدة، ولعبة واحدة لكل مشاهد، وإجابة مخفية حتى الإنهاء — مفروضة في العميل أيضًا لا في السيرفر وحده. لا animation ولا mock يُعتبر نتيجة.
- **20:** `hasRosterPayload` يميّز حمولة تحمل تشكيلة الفريق من tick يحمل النقاط فقط، فلا ينهار 2v2 إلى 1v1 بين تحديثين، بينما حدث roster حقيقي ما زال يفرّغ المقعد.
- **14:** كل غرفة شريك لها slot و generation و queue خاصة بها، وتُغلق الغرفة التي يملكها الـslot فقط؛ فشل متأخر من اتصال مُستبدل لا يقطع التايل الحالي. الغرفة الأساسية والكاميرا والميكروفون لم تُمس، وغرفة خصم 1v1 بقيت في مكانها.
- **18:** كل نصف من العرض (سعر فلاش + وقت انتهاء) و(رمز كوبون + قيمة) يُرسل كاملًا أو يُرفض قبل الطلب؛ والإلغاء يرسل null صريحًا لذلك النصف.

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

### ملفات مرجعية مطلوبة وغير موجودة محليًا

لم أدّعِ قراءتها: **لا يوجد** `features-ar` في `~/Downloads` ولا داخل شجرة المشروع، ولا مجلد `../promotions/` الذي تشير إليه `live-promotions.md`، ولا نسخة من `Archive(4).zip` محليًا. الملفات الموجودة فعليًا هي المذكورة أعلاه في `tiktok/lives/`.
