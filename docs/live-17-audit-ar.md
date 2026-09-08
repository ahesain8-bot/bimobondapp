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

## استئناف الميزة 20 — 2026-09-08 — مرحلة التحقق

- المرجع المحلي: فرع `bashar`، HEAD `ce411b85624b5eb82d63cdc158c513b72699e86c`. عند البدء لا ملفات جديدة والتعديل الوحيد السابق `ios/Podfile.lock` (GoogleUtilities 8.1.2 → 8.1.3)، تُرك كما هو. لم تنفذ عمليات استعادة Git أو تبديل فرع أو commit/push.
- Flutter 3.44.8 / Dart 3.12.2؛ نقطة الدخول `lib/main.dart`. `/create-live` يبني Host LiveRoomPage وفيه DI محلي للمستودع وSocket وLiveRoomBloc؛ `/lives` يستخدم LiveViewerEntry وlive_viewer_injector.
- قُرئت وثيقة الاستعادة وهذا السجل، وأقسام PK والهدايا والتوكنات كاملة من `lives/mobile-api.md` و`logic.md` و`endpoints.md`. لم توجد AGENTS.md/CLAUDE.md في الشجرة أو المسارات العليا المفحوصة. وجدت `/Users/macbookair/Desktop/app_like_tiktok.zip` وفُحصت محتوياته دون استبدال الشجرة: نموذح LiveBattle ووثيقة الاستعادة مطابقان محليًا؛ features-ar/endpoints2/P1/P2 غير موجودة داخله أيضًا. ادعاءات التوثيق السابق لا تثبت العقد المفقود.
- baseline: `flutter test --no-pub test/live_team_battle_test.dart test/live_battle_test.dart test/live_battle_media_serialization_test.dart test/live_battle_layout_rebuild_test.dart test/live_competition_request_test.dart test/live_socket_payload_test.dart` = **95 Passed** (`/tmp/pk-baseline.log`).
- baseline إضافي: `flutter test --no-pub test/live_room_stage_test.dart test/live_pk_rtl_layout_test.dart test/live_viewer_ui_test.dart test/live_ticket_service_test.dart` = **18 Passed** (`/tmp/pk-baseline-room.log`).
- خريطة الربط: زر خيارات PK → LiveRoomBattleOpponentsSheet → repository.startBattle (الإعداد الفردي فقط) → POST /lives/:id/battle → LiveRoomBattleChanged؛ liveBattle/liveBattlePhase → datasource/SocketMapper → Bloc → battle state → LiveRoomStage أو viewer LiveRoomPage → بث أساسي + opponent room وشريط النقاط. TEAM/join/invite/leave/power-up موجودة بالمستودع بلا مستهلك UI؛ LiveCohostTiles بلا تركيب؛ cohostRooms متاح بالتطبيق فقط، ولا ربط TEAM للمضيف/المشاهد.
- مصدر opponent token الحالي: POST join للمضيف وJoinLiveUseCase للمشاهد؛ الوثيقة تقول إن join لغير المضيف يفتح viewer session ويزيد viewers. لذلك لا يصلح تعميمه ثلاث مرات دون عقد مستقل؛ لا توجد توكنات TEAM موثقة في الملفات المتاحة.
- الأجهزة: adb فارغ، لا simctl booted؛ Flutter يرى iPhone واحدًا لاسلكيًا. Android package الحالي `com.dubai.bimobondapp` وiOS `com.example.bimobondapp`. توجد عملية build/run من IDE بدأت قبل عمل هذه الجولة؛ لا تُنسب لهذه الجولة ولا تُوقف تلقائيًا. قبول الأربعة أطراف **Not run**.
- طُلبت دفعة واحدة الوثائق الأحدث وعقد توكنات المشاهدة وهوية المضيف والتجديد والإلغاء وأثر العداد، والتنسيق مع مايا لتغييرات LiveRoomBloc/Socket/LiveKit، وموارد وتفويض الاختبار. لم يصل الرد بعد؛ تستمر إصلاحات PK المستقلة.
- ثمانية اختبارات انحدار جديدة `live_battle_patch_test.dart` فشلت جميعها قبل إصلاح النموذج: انتماء الزميل، patch roster، null/zero، النهاية الجزئية، ACTIVE المتأخر، جولة أقدم، round_finished، وأولوية null للمقعد. الإصلاح قيد التحقق؛ لا يُعد PK مكتملًا.

### مرحلة واجهة PK ودمج التحديثات — 2026-09-08

- نجحت اختبارات النموذج بعد الإصلاح: **39 Passed** (`/tmp/pk-patch-green.log`). يحافظ الدمج على الحقول الغائبة ويطبق null/zero صراحةً، ويعالج انتماء الزميل، ويمنع ACTIVE المتأخر لجولة منتهية والجولة الأقدم عند وجود roundNumber. لا يُعامل `round_finished` وحده كنهاية سلسلة. حماية المعرف المختلف تعمل عند تمرير updateType؛ مسار المضيف الحالي يفقده، وهذا **متبقٍ** مع تنسيق Bloc/Socket.
- تم توصيل الورقة الفعلية بـ`LiveBattleControls`: SOLO/TEAM، مدة 30–1800، طريقة النقاط واختيار هدية من GetGiftsUseCase القائم، BO3، إنشاء بقبطانين، open-teams والانضمام إلى رقم الفريق الصريح، دعوة liveId لزميل، مغادرة الزميل فقط، إنهاء PK للقبطان، STUN/TIME/GLOVE والمضاعف القائم. هذا ربط بمسارات موجودة، **وليس تحققًا من عقد TEAM المنشور**؛ مصادر P1/P2 ما زالت مفقودة.
- `LiveTeamBattleGrid` مركّب داخل Host LiveRoomStage وViewer LiveRoomPage. الفريق الحالي يسارًا بما يطابق شريط نقاطه، وزميله تحته؛ التخطيط ثابت في RTL ومفاتيح الفيديو حسب liveId. يعرض الأساسي فقط حاليًا وحالة «فيديو المشارك غير متاح» للأطراف الأخرى، أو «مقعد زميل فارغ». لا تستخدم الشبكة الجديدة أول remote track كهوية مضيف. **أربعة فيديوهات غير مكتملة**، ومدير الغرف الثانوية لم يُوصل إلى TEAM.
- أضيف عرض roundNumber/wins1/wins2 وحالة القدرات من snapshot داخل طبقة HUD؛ لا ينفذ منطق جولات أو نقاط محليًا. نهاية السلسلة والتعادل ما زالا يحتاجان العقد وقبول الأجهزة، خصوصًا الحالات التي تنتهي أثناء إعادة الاتصال.
- تحقق واجهة/RTL/انحدارات: `flutter test --no-pub test/live_battle_controls_test.dart test/live_team_battle_grid_test.dart test/live_battle_patch_test.dart test/live_battle_layout_rebuild_test.dart test/live_pk_rtl_layout_test.dart test/live_viewer_ui_test.dart` = **29 Passed** (`/tmp/pk-ui-regression.log`). اختبار المداخل يفتح LiveRoomBattleOpponentsSheet الحقيقي ويثبت TEAM → repository → LiveRoomBattleChanged؛ مع اختبارات patch الإضافية **12 Passed** (`/tmp/pk-entry-test.log`). هذه widget/unit tests ببدائل اختبار، وليست أجهزة LiveKit.
- التحليل المحدد للملفات المعدلة آنذاك: **No issues found** (`/tmp/pk-analysis-modified.log`). التحليل العام كشف invalid_override سابقًا في `_LiveRepo.joinLive` داخل `test/live_guest_auto_join_test.dart`، إذ غاب الوسيط `trafficSource` الموجود فعلًا في LiveRepository.joinLive. أضيف الوسيط للاختبار فقط دون تغيير expected أو منطق الضيوف؛ فحصه النهائي جارٍ. بقيت ملاحظات وتحذيرات عامة أخرى.
- تغيّر HEAD خارج أوامر هذه الجلسة إلى `81b69590729c1aa3e80d9762cc6e49483a48feae`، متضمنًا أجزاء من عمل المرحلة الأولى وPodfile.lock. لم أنفذ commit/push ولم أرجع ذلك التغيير. جميع الملفات الجديدة والتعديلات الباقية تحتاج أخذها مع هذا HEAD، وليس HEAD وحده.
- `xcrun devicectl device info apps` نجح عبر الشبكة وأكد المثبت `com.example.bimobondapp` = `1.0.0 (1)`. هذا إثبات هوية النسخة فقط، **لا قبول PK**. لا USB Android، ولا أربعة ناشرين حقيقيين.
- الخطوة التالية: إنهاء فحص المجموعة العامة والبناء المميز، ثم تسليم قائمة تنسيق دقيقة لـLiveRoomBloc/LiveViewerBloc/Socket/LiveKit وعقد التوكنات؛ لا انتقال إلى ميزة أخرى.

### مرحلة سباقات المدير القائم — بعد طلب «أكمل»

- اكتمل `flutter test --no-pub` بعد تحديث fake الضيوف: **419 Passed** (`/tmp/pk-full-final-test.log`). التشغيل الأول قبل تحديثه كان **412 Passed / 1 failed-to-load**؛ وبعد إضافة trafficSource اتضح أن fake لا ينفذ getLiveById الذي تستخدمه بوابة الدخول الحالية. أُضيف إرجاع fixture نفسه في fake، فنجحت اختباراته السبعة دون تغيير أي expected أو كود دخول الإنتاج.
- أضيفت منافذ حقن Room factory وعمليتي audio acquire/release إلى `LiveSecondaryRooms` لاختبار المدير الحقيقي دون نشر أو شبكة. الاختبارات الأولية كانت **1 Passed / 5 Failed** (`/tmp/pk-secondary-red.log`): sync متداخل، disconnect/reconnect، listener بعد فشل connect، acquire مزدوج، وعدم dispose بعد فشل disconnect.
- أصلحت العيوب في المدير القائم: generation على sync؛ إزالة ملكية map قبل await حتى لا يحذف disconnect قديم slot جديدًا؛ تنظيف listener والـRoom في جميع نهايات connect؛ dispose مستقل حتى إن فشل disconnect؛ تسلسل ملكية الصوت وعدّ الغرف الفعلية؛ طابور تنظيف يحرر آخر lease قبل آخر SDK disconnect. لم يُعدّل LiveAudioSession نفسه أو اتصال الكاميرا/الميك الأساسي.
- الاختبارات الموسعة أثبتت أيضًا خطأ ترتيب release بعد آخر disconnect، ثم حالة dispose أثناء connect. أُصلحتا دون تعديل expected. `videoTrackFor` أصبح يتطلب هوية LiveKit صريحة للاختيار ويعيد null عند غيابها، ولا يفترض hostId/liveId/أول ضيف. إشعارات participant/track/reconnect مركّبة؛ تبديل token فقط لا يهدم الغرفة، وتبديل roomName يعيدها.
- `flutter test --no-pub test/live_secondary_rooms_race_test.dart test/live_battle_media_serialization_test.dart test/live_team_battle_test.dart` = **33 Passed** (`/tmp/pk-secondary-final.log`)، منها **11** اختبار مدير غرف. هذه بدائل Room ومجرى أحداث SDK داخل الاختبار، وليست أربعة ناشرين أو اختبار صوت native.
- البناء الأول نجح: `flutter build apk --debug --no-pub --target lib/main.dart --build-name=1.0.0-pk.20260908.81b6959 --build-number=2026090801`؛ aapt2 أكد `com.dubai.bimobondapp`/2026090801، وapksigner أكد v2. هذا البناء سبق آخر إصلاحات مدير الغرف، ولذلك يُعاد الآن بناء النسخة النهائية ولا يُقدّم الأول كأنه يحتوي آخر التعديلات.
- مصدر Dart قبل البناء النهائي: SHA-256 مجمّع لملفات `lib/**/*.dart` = `32aff995cc49717f6803efd146960253536dd993c99714f11203a6029d8c01fb`، والـHEAD `81b6959` مع تعديلات غير ملتزمة. الاسم النهائي المطلوب `1.0.0-pk.20260908.32aff995` ورقم `2026090802`؛ الأوامر النهائية واختبارات المجموعة الكاملة والتحليل العام قيد التشغيل.
- ما زالت حالة PK **Partial**: لا عقد TEAM/P1/P2 مستلم، لا مصدر توكنات مشاهدة الأطراف الأخرى، ولا تنسيق محدد مع مايا لتعديل Bloc/Socket/ربط LiveKit، ولا أربعة أطراف أو تفويض بث/رصيد. قائمة التفصيل وخطوات قبول المدير في `docs/live-pk-20-acceptance-2026-09-08.md`.

### نقطة التسليم النهائية لهذه الجولة — PK 20 — 2026-09-08

**الحالة: Partial؛ تنفيذ Flutter جزئي، عقد TEAM/توكناته غير متحقق، قبول الأجهزة Not run.**

- `flutter test --no-pub` النهائي = **430 Passed / 0 Failed**، 138 ثانية (`/tmp/pk-all-final.log`). تتضمن المجموعة اختبارات الأزرار والمدخل الفعلي والـmodel والـRTL والـmedia races والانحدارات الموجودة. لا تمثل بثًا حيًا أو قبولًا متعدد الأجهزة.
- `flutter analyze --no-pub` النهائي = **0 errors / 103 warnings / 347 infos**، exit 1 بسبب التحذيرات/الملاحظات، دون أعلام تخفيها (`/tmp/pk-analysis-all-final.log`). فحص جميع المسارات المعدلة/الجديدة ضمن الخرج = **لا ملاحظات**. فحص الملفات المعدلة السابق المباشر كان `No issues found` أيضًا.
- format على الملفات المعدلة والجديدة فقط؛ `git diff --check` ناجح. لا تغيير l10n/ARB يستلزم gen-l10n. بعض الفروق الكبيرة في ملف Viewer LiveRoomPage نتيجة formatter؛ تغييرات السلوك محصورة بتخطيط/عرض PK.
- البناء النهائي: `flutter build apk --debug --no-pub --target lib/main.dart --build-name=1.0.0-pk.20260908.32aff995 --build-number=2026090802` = **نجح خلال 122.1 ثانية** (`/tmp/pk-build-final.log`).
- artifact: `../artifacts/pk-20260908-32aff995/bimobond-pk-20260908-32aff995-debug.apk`، الحجم **259469022 بايت**؛ SHA-256: `3f3a72c61abaa666bddf79fdef6c205685f1288db20ec8231ec1f3785731c77a`.
- aapt2 أكد `com.dubai.bimobondapp` / `1.0.0-pk.20260908.32aff995` / `2026090802`، وapksigner verify ناجح بتوقيع v2. ملف build-manifest.json وبصمات كل ملفات Dart محفوظة بجانب APK. تحقق البصمات قبل/بعد البناء أثبت عدم تغير مصدر Dart أثناءه. HEAD الحالي `81b6959` **مع** التعديلات الجديدة؛ HEAD وحده لا يعيد إنتاج البناء.
- **لم يُثبت APK على جهاز**: adb فارغ؛ الهاتف الظاهر iOS فقط. لم يُحذف تطبيق أو بيانات، ولم يُبدأ بث عام أو تُصرف عملات أو تُنشأ توكنات. المثبت على iPhone الذي تحققت منه كان `com.example.bimobondapp` / `1.0.0 (1)`، وليس هذا البناء.
- نواقص الإغلاق: مصدر توكنات مشاهدة/هوية الغرف الثلاث الأخرى ودورة تجديدها/إلغائها وأثر العداد؛ عقد TEAM/BO3/القدرات الحالي؛ تنسيق تغييرات Bloc/Socket لحفظ updateType وحراسة الردود والـroster المتأخر وربط المدير بالمضيف والمشاهد ومنع ازدواج الصوت؛ ثم أربعة ناشرين وحساب مشاهدة بتفويض البيئة والظهور ورصيد الاختبار. **لا تختزل المتبقي إلى عدد أجهزة فقط**.
- يبدأ الاستئناف بقراءة `docs/live-pk-20-acceptance-2026-09-08.md` وهذا المقطع، والتحقق من Git الحالي دون استرجاع/commit/push. خريطة الملفات وأسبابها والمتوقع وعدد طلبات سيناريوهات القبول محفوظة هناك. لا تنفيذ مستقل لأي ميزة تالية حتى إغلاق 20 أو تسليم عائقها المحدد.

### استكمال PK وiOS — 2026-09-08

- نقل `updateType` من `LiveHudBattleEvent` إلى `LiveRoomBattleChanged` ثم إلى `LiveBattle.withTimingFrom`. لذلك patch من socket مثل `score` يحتفظ بتشكيلة 2v2/الجولات والقدرات الغائبة، بدل معاملته snapshot كاملًا. لا تغيّر مسار HTTP؛ غياب النوع فيه يعامله snapshot كاملًا كما كان.
- `LiveCohostRoom` يحمل الآن `hostIdentity` فقط عندما يرسله الـbackend صراحةً باسم `hostIdentity` أو `liveKitHostIdentity`. لا يستخدم `hostId` كبديل. `LiveCohostTiles` يطلب كاميرا تلك الهوية فقط؛ يبقى البلاط بحالة غير متاحة عند غيابها، وهو السلوك الآمن إلى أن يوفّر العقد الهوية. ما زالت توكنات وغرف أطراف TEAM الأخرى عائقًا للقبول متعدد الأجهزة.
- تحقق موجّه: `flutter test --no-pub test/live_team_battle_test.dart test/live_secondary_rooms_race_test.dart test/live_battle_test.dart test/live_battle_patch_test.dart test/live_battle_controls_test.dart` = **63 Passed / 0 Failed**.
- لتقليل كلفة Debug في iOS، أضيف `COMPILER_INDEX_STORE_ENABLE=NO` لمشاريع Pods في Debug فقط عبر `ios/Podfile`. هذا يستهدف إعادة بناء WebRTC/LiveKit/ML Kit المحلية ولا يمس Release أو archive. نُفّذ `pod install` بنجاح: 38 dependency مباشرة و84 Pod. تحذيرات CocoaPods الخاصة بتعارض `EXCLUDED_ARCHS` لـML Kit سابقة لإعداد التحسين وغير قاتلة؛ لم تُحذف architectures أو Pods.
- تحقق بناء iOS: `flutter build ios --debug --no-codesign --no-pub` نجح وأنتج `build/ios/iphoneos/Runner.app`. أول بناء كامل بعد تغيير Podfile استغرق **9:08** (CocoaPods 57.1s، Xcode 176.8s). لا signing ولا تثبيت على الهاتف. دليل التشغيل وتفادي إعادة بناء Pods في `docs/ios-debug-build-speed-ar.md`.
- إعادة البناء بلا تغيير مصدر وبلا `clean`/`pod install` نجحت في **1:38**، منها Xcode **53.8s**. لا يصح اعتبارها قياسًا لـHot Reload؛ بعد `flutter run` يبقى Hot Reload أسرع مسار للتعديل اليومي.
- التحقق الكامل بعد الاستكمال: `flutter test --no-pub` = **431 Passed / 0 Failed** في 1:28. `git diff --check` ناجح، والتحليل المحدد للملفات الجديدة في PK/الكوهوست = **No issues found**.


## جولة 2026-09-08 (الثانية) — إغلاق الميزة 30 وفتح حارسين مغلقين

نقطة البداية: فرع `bashar`، المجموعة الكاملة **443 Passed** بعد إضافة اختبارات عقد الترويج، ثم **450 Passed** بعد بقية هذه الجولة. `flutter analyze` على كل ملف معدَّل/جديد: **No issues found**.

النمط الذي حكم هذه الجولة: ثلاثة مواضع كان الكود فيها يفشل مغلقًا بانتظار عقد، بينما العقد موجود فعلًا في الوثائق أو في استجابة الخادم المنشور. الفشل المغلق كان صحيحًا يوم كُتب؛ لم يعد صحيحًا بعد وصول الدليل.

### 30 — الترويج: من Blocked إلى منفَّذ

الدليل الذي وصل: لوقات HTTP حقيقية من الخادم المنشور تُظهر `GET /promotions/lives/options` و`/promotions/packages` و`/promotions/lives/mine` ترجع **200** بأظرف كاملة، بينما الشاشة تعرض «ترويج البث غير متاح مؤقتًا».

- السبب: `UnverifiedLivePromotionContract` كان ما زال العقد الافتراضي في `LivePromotionsRepository`، فيرمي `LivePromotionContractException` في كل قراءة، ويمنع كل تعديل قبل إرساله عبر `_mutate`.
- أُضيف `LiveApiPromotionContract` مكتوبًا على الأظرف الملتقطة: `categories:[{id,name}]`، `customBudget.durationPresetsDays`، `coinsPer1000Impressions`، الباقات بـ`priceCoins`/`durationHours` (تُحوَّل إلى أيام)، و`{data, meta:{totalPages}}`. صار هو الافتراضي؛ و`UnverifiedLivePromotionContract` باقٍ ويفشل مغلقًا لمن يحتاجه.
- ظرف الخيارات لا يحمل دولًا إطلاقًا، فكانت شريحة «الدول» تظهر بعنوان بلا خيارات. تُقرأ الآن من `GET /promotions/options` المشترك، مرة واحدة لكل جلسة، وفشلها لا يُعطّل بقية النموذج.
- بوابة `visibility == 'PUBLIC'`: الحقل غير موجود في مرجع كائن Live (`lives/mobile-api.md` §5) ولا يوجد مفهوم visibility لكل بث في أي وثيقة، فكان الإنشاء محجوبًا للأبد. الغياب لم يعد يمنع (خصوصية الحساب مفحوصة أصلًا)، وأي قيمة صريحة غير `PUBLIC` ما زالت تُرفض.
- **الحماية المالية لم تُمسّ**: `hasPaymentSummary` ما زال يشترط كل حقل اقتصادي قبل تفعيل الدفع، و`create` يرفض حملة لا يطابق `id`/`liveId`/`PENDING_PAYMENT` فيها الطلب، والحالة غير المعروفة تبقى للقراءة فقط، والرصيد من الخادم دائمًا.
- الملفات: `live_promotion_api_contract.dart` (جديد)، `live_promotions_repository.dart`، `live_promotion_models.dart`، `live_promotions_injector.dart`.
- الاختبارات: `live_promotion_api_contract_test.dart` — **12 Passed**، تثبّت الأظرف الملتقطة كـfixtures. مجموعة الترويج كاملة **47 Passed**.
- **المتبقي**: أظرف الحملة و`stats` و`preview` لم تُلتقط بعد؛ حُلِّلت على شكل خدمة ترويج المنشورات. إن اختلفت الأسماء يظهر زر الدفع معطَّلًا (لا خصم خاطئ). المطلوب: لوق `POST /promotions/lives` بعد أول إنشاء. القبول على الجهاز **Not run**.

### 14 — الكوهوست: التايلات كانت سوداء دائمًا

`LiveSecondaryRooms.videoTrackFor` كان يشترط `hostIdentity` بمطابقة حرفية، ويعيد null بدونها. ظرف `cohosts[]` الموثق (`live-p2-parity.md` §2) يرسل `host: { id }` — معرّف المستخدم في الخلفية — ولا يرسل هوية LiveKit إطلاقًا. أي أن كل تايل شريك كان يبقى «غير متاح» بالتصميم.

الإصلاح: عند غياب `hostIdentity` يُستخدم `hostId` عبر `liveKitParticipantMatches` — وهو المطابِق نفسه الذي تستخدمه الغرفة الأساسية (`live_room_stage.dart:1018`) وواجهة المشاهد (`viewer_stage.dart:248`) لكاميرات الضيوف في الإنتاج، ويتحمّل الهوية المباشرة والمسبوقة وسمات/بيانات المشارك. الهوية الصريحة ما زالت تفوز عند إرسالها، والقيمتان الفارغتان ليستا wildcard.

الاختبارات: اختباران جديدان في `live_secondary_rooms_race_test.dart` (هوية مباشرة، هوية مسبوقة، سمة `userId`، ومعرّف لا ينشر أحد تحته) — المجموعة **13 Passed**.

### 20 — PK: قبطان الخصم صار يظهر في 2v2

في وضع TEAM كان `videoFor` يعيد null لكل طرف غير الذات، رغم أن `battle.opponentLiveId()` يعيد قبطان الفريق الخصم في TEAM كما في SOLO، وأن اتصال غرفة الخصم (`connectBattleOpponentMedia`) قائم وموصول أصلًا للوضعين. أي أن التايل الوحيد الذي نملك اعتماداته فعلًا كان يُرمى.

الآن يعرض المضيف والمشاهد قبطان الخصم في شبكة 2v2 بالاتصال نفسه المستخدم في 1v1 — تايلان من أربعة بدل تايل واحد.

مقعدا الزميل (`live3` / `live4`) يبقيان «فيديو المشارك غير متاح»: قائمة تحقق التطبيق في `live-p1-parity.md` §7 تعرّف اللوبي والتشكيلة والنقاط وHUD فقط، ولا تعرّف وسائط للفريق. الحصول عليها يستلزم `POST /lives/:id/join` على غرفتين إضافيتين، وهو ما يفتح جلسة مشاهدة ويزيد عدّاد مضيفَين آخرين — **قرار منتج لا يُتخذ من العميل بلا عقد**. الحالة تبقى Partial لهذا السبب المحدد.

### 26 — التقرير: مصدر NOTIFICATION صار قابلًا للإرسال

`LIVE_STARTED` إشعار موثّق يصل متابعي المضيف عند بدء البث (`lives/mobile-api.md` §6)، لكن `notification_navigation.dart` لم يكن فيه `case` له — يسقط إلى `default` ولا يفتح شيئًا. أي أن النقر على «فلان بدأ بثًا» لم يكن يفعل شيئًا، ودلو NOTIFICATION لم يكن يُرسَل أبدًا.

الآن: الإشعار يحلّ المضيف من `actorId`، يقرأ `GET /users/:id` (يحمل `isLive` و`currentLive` — `live-p3-parity.md` §7)، ويفتح البث عبر المساعد المشترك نفسه، فتمر بوابتا العمر والتذكرة قبل `join`، ويُرسل `trafficSource: NOTIFICATION`. البث المنتهي أو الملف غير المقروء لا يفتح شيئًا ولا يُخمَّن معرّف بث من الإشعار.

الاختبارات: `live_notification_entry_test.dart` — **5 Passed**.

**ما زال مغلقًا في 26 ودليله:**

| الدلو | العائق المحدد |
|---|---|
| `SEARCH` | لا حقل `isLive`/`currentLive` في نتائج البحث ولا في `SocialUserEntity`؛ الوثائق تعرّفهما على `GET /users/:id` و`GET /auth/me` فقط. لا مدخل بث من البحث. |
| `SHARES` | `POST /lives/:id/share` يعيد `deepLink` (`dcc://lives/:id`)، لكن المشروع لا يسجّل URL scheme على iOS ولا Android ولا يعتمد حزمة روابط عميقة. لا يوجد مسار دخول من رابط. |
| `CHAT` | مشاركة البث تخرج إلى تطبيقات خارجية أو تنسخ الرابط؛ لا رسالة داخل الدردشة تحمل بثًا. |

### حالة الأجهزة في هذه الجولة

- `flutter devices`: macOS + **Bashar’s iPhone** (iOS 26.6.1، لاسلكي) فقط. `adb devices` فارغ.
- محاكيا أندرويد `LiveHost` و`LiveViewer` موجودان لكن **لا يقلعان**: `FATAL | Your device does not have enough disk space to run avd`. القرص على 99% (**2.1 GB متاحة**). المستهلكات الكبيرة: `build/` 6.3 GB، `~/Library/Developer/Xcode/DerivedData` 13 GB، `~/Library/Caches` 6.2 GB. لم يُحذف أي منها — قرار المستخدم.
- بلا جهازين لا يمكن تنفيذ سيناريو PK (يتطلب حسابين يبثّان في آن واحد) ولا الكوهوست بأربع غرف.

### المصفوفة بعد هذه الجولة

| # | قبل | بعد | السبب |
|---|---|---|---|
| 30 | Blocked | منفَّذ (قبول الجهاز Not run) | عقد استجابة حقيقي + رفع بوابة visibility الوهمية |
| 14 | Partial | منفَّذ (قبول الجهاز Not run) | التايل يُحلّ من `host.id` الموثق |
| 20 | Partial | Partial | قبطان الخصم يظهر؛ مقعدا الزميل بلا عقد وسائط |
| 26 | Partial | Partial | NOTIFICATION موصول؛ SEARCH/SHARES/CHAT بلا مدخل |
| 15 | Partial | بلا تغيير | لا يُمس — لِمايا |
| 17 | Partial | بلا تغيير | يحتاج رصيد اختبار وتفويض |
| الباقي (16، 29، 28، 10، 21، 22، 18، 19، 3، 24، 25) | Complete | بلا تغيير | لم تُعد كتابتها |

**قبول الأجهزة ما زال Not run في الصفوف السبعة عشر جميعها.** نجاح 450 اختبارًا لا يمثل بثًا حيًا ولا صرف رصيد ولا أربعة ناشرين.


### دليل الجهاز — بث حقيقي على iPhone — 2026-09-08

بثّ حقيقي كامل من `Bashar’s iPhone` (iOS 26.6.1) على الخادم المنشور `159.65.227.87`: إنشاء ← نشر ← إنهاء ← تقرير ← فتح شاشة الترويج. هذا **أول دليل جهاز** في هذا الملف؛ ما يلي مقروء من كونسول التشغيل نفسه لا من اختبار.

| # | ما أثبته اللوق |
|---|---|
| 1 | `POST /lives` → 201؛ `connectAndPublish` نجح: صوت + فيديو 720p (`vp8`، simulcast، `1280x720@30fps/2500kbps`)؛ `LivePerf: room_ready=4985ms`؛ `POST /lives/:id/end` → 201 |
| 29 | `GET /leaderboard/hourly` → `{"rank":2,"score":0.5,"isPopular":true,"popularReason":"…"}` — الترتيب وشارة Popular يصلان فعلًا |
| 26 | `GET /summary` → `durationSeconds`، `peakViewers`، `totalViewerSessions`، `uniqueViewers`، `topGifters`، `host.hostLeagueTier` |
| 21 | `treasure-boxes` → `[]`، `qa` → `[]`، `polls/active` → **body فارغ (null) بلا content-type**؛ `getActivePoll` يتعامل معه بسلام ويعيد null |
| 17 · 19 · 13 · 20 | `auctions/active` → `{"data":[]}`، `gallery` → `{"pinnedCount":0,"data":[]}`، `guests` → `{"data":[]}`، `battle` → `{"battle":null}` |
| 6 · 24 | `studio` → `streamKey` + `ingressId` + `recording:{status,egressId:null,autoRecord:true}` — التسجيل التلقائي مسلّح |
| 30 | `GET /promotions/lives/options` → **200** ومتابعة الشاشة. قبل هذه الجولة كانت الاستجابة نفسها 200 ثم يسقط التحليل. اللوق انقطع قبل نتيجة العرض، فالقبول النهائي للميزة 30 **ما زال بانتظار بقية الأسطر**. |

**عيبان كشفهما الجهاز ولم يكشفهما أي اختبار:**

1. **تقرير نهاية البث يُفتح مرتين — أُصلح.** المستمع في `live_room_page.dart` (المضيف) كان `listenWhen: (previous, current) => current is LiveRoomEnded` بلا فحص انتقال. `_onEnd` (إنهاء المضيف) و`_onRemoteEnded` (حدث `liveEnded`) معالِجان منفصلان، وكلاهما يجتاز حارس `_readyOrNull` قبل أن يُصدر أيٌّ منهما الحالة، فيُصدران `LiveRoomEnded` مرتين. النتيجة في اللوق: `#31` و`#32` طلبا `GET /summary` معًا، وعلى الشاشة تقريران مكدّسان يغلقهما المضيف مرتين. صار الشرط `previous is! LiveRoomEnded && current is LiveRoomEnded`، مطابقًا للمستمع الشقيق تحته مباشرة. لا اختبار وحدة له: المسار يحتاج `LiveRoomPage` كاملة بحقن ثقيل؛ دليله كونسول الجهاز أعلاه.

2. **التعليقات تُجلب مرتين — تُركت عمدًا.** `#21` من إعادة مزامنة السوكِت عند أول اتصال، و`#22` ضمن دفعة `_enrichSession`. حذف الأولى يوفّر طلبًا واحدًا لكل فتح غرفة، لكن `_enrichSession` يستخدم `Future.wait` **بلا try**: فشل أي عضو في الدفعة يترك خلاصة التعليقات فارغة، وإعادة المزامنة هي شبكة الأمان الوحيدة عندها. الرصيد سلبي، فلم تُحذف.

المجموعة الكاملة بعد إصلاح التقرير: **450 Passed / 0 Failed**. التحليل على الملفات المعدّلة: **No issues found**.
