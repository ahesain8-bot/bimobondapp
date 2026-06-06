// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تطبيق بيموبوند';

  @override
  String get helloWorld => 'مرحبا بالعالم!';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get signInSubtitle => 'تسجيل الدخول للمتابعة';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟ ';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get orDivider => 'أو';

  @override
  String get continueAsGuest => 'الدخول كضيف';

  @override
  String get continueWith => 'المتابعة باستخدام';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpSubtitle => 'أدخل بياناتك لإنشاء حساب جديد';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get countryLabel => 'الدولة';

  @override
  String get nationalityLabel => 'الجنسية';

  @override
  String get ageLabel => 'العمر';

  @override
  String get addressLabel => 'العنوان';

  @override
  String get phoneLabel => 'رقم الجوال';

  @override
  String get mobileNumberLabel => 'رقم الجوال';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get createAccountBtn => 'إنشاء الحساب';

  @override
  String get alreadyHaveAccount => 'لديك حساب؟ ';

  @override
  String get phoneLoginTitle => 'الدخول برقم الجوال';

  @override
  String get phoneLoginSubtitle => 'أدخل رقم جوالك لتلقي رمز التحقق';

  @override
  String get phoneHint => '+20 123 456 7890';

  @override
  String get termsAndConditionsPart1 => 'بالاستمرار، أنت توافق على ';

  @override
  String get termsAndConditionsPart2 => 'الشروط والأحكام';

  @override
  String get verifyPhoneTitle => 'التحقق من الجوال';

  @override
  String get emailVerificationTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String emailVerificationSent(Object email) {
    return 'أرسلنا رابط التحقق إلى $email.';
  }

  @override
  String get emailVerificationContinue => 'افتح بريدك الإلكتروني وتحقق من حسابك قبل المتابعة.';

  @override
  String get emailVerificationButton => 'لقد قمت بالتحقق من بريدي الإلكتروني';

  @override
  String get emailVerificationResendError => 'يتعذر إعادة إرسال بريد التحقق. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get emailVerificationResendSuccess => 'تمت إعادة إرسال بريد التحقق. تحقق من صندوق الوارد ومجلد البريد العشوائي.';

  @override
  String get emailVerificationResendFailed => 'فشل إعادة إرسال بريد التحقق. يرجى المحاولة مرة أخرى.';

  @override
  String get emailVerificationStatusError => 'يتعذر التحقق من حالة البريد الإلكتروني. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get emailVerificationNotVerified => 'لم يتم التحقق من البريد الإلكتروني بعد. يرجى فتح بريدك الإلكتروني والتحقق من حسابك.';

  @override
  String get emailVerificationCheckFailed => 'تعذّر التحقق من حالة البريد الإلكتروني. يرجى المحاولة مرة أخرى.';

  @override
  String get emailVerificationResendButton => 'إعادة إرسال بريد التحقق';

  @override
  String get emailVerificationResending => 'جارٍ إعادة الإرسال...';

  @override
  String get enterCodeSentTo => 'أدخل الرمز المكون من 6 أرقام المرسل إلى';

  @override
  String get verificationCodeLabel => 'رمز التحقق';

  @override
  String get verifyAndLoginBtn => 'التحقق والدخول';

  @override
  String get didNotReceiveCode => 'لم يصلك الرمز؟ ';

  @override
  String get resendCode => 'إعادة إرسال';

  @override
  String get back => 'رجوع';

  @override
  String get continueAction => 'متابعة';

  @override
  String get emailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get invalidEmail => 'أدخل بريد إلكتروني صحيح';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String get passwordTooShort => 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';

  @override
  String get loginFailed => 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';

  @override
  String get verificationFailed => 'فشل التحقق';

  @override
  String get invalidOtpCode => 'رمز OTP غير صحيح';

  @override
  String get facebookLoginFailed => 'فشل تسجيل الدخول عبر فيسبوك';

  @override
  String get googleLoginFailed => 'فشل تسجيل الدخول عبر جوجل';

  @override
  String get updateProfileFailed => 'فشل تحديث الملف الشخصي';

  @override
  String get signupFailed => 'فشل إنشاء الحساب. يرجى المحاولة مرة أخرى.';

  @override
  String get profileUpdatedSuccessfully => 'تم تحديث الملف الشخصي بنجاح!';

  @override
  String get enterSixDigitCode => 'يرجى إدخال رمز مكون من 6 أرقام';

  @override
  String get postAdded => 'تم إضافة المنشور!';

  @override
  String get addPost => 'إضافة منشور';

  @override
  String get postButton => 'نشر';

  @override
  String get loginSuccess => 'تم تسجيل الدخول بنجاح!';

  @override
  String get signupSuccess => 'تم التسجيل بنجاح! يرجى التحقق من بريدك الإلكتروني لتفعيل حسابك.';

  @override
  String get signUpWithEmailPassword => 'إنشاء حساب بالبريد الإلكتروني وكلمة المرور';

  @override
  String get following => 'متابعة';

  @override
  String get followers => 'متابعون';

  @override
  String get connectionsTitle => 'العلاقات';

  @override
  String get connectionsEmptyFollowers => 'لا يوجد متابعون بعد';

  @override
  String get connectionsEmptyFollowing => 'لا تتابع أحداً بعد';

  @override
  String get connectionsEmptyFriends => 'لا يوجد أصدقاء بعد';

  @override
  String get connectionsFollowBack => 'رد المتابعة';

  @override
  String get profileMessageButton => 'رسالة';

  @override
  String get likes => 'إعجابات';

  @override
  String get profilePostsTab => 'المنشورات';

  @override
  String get profilePostAuction => 'مزاد';

  @override
  String get profileLikesTab => 'الإعجابات';

  @override
  String get noPostsYet => 'لا توجد منشورات بعد';

  @override
  String get noLikedPosts => 'لا توجد منشورات معجب بها';

  @override
  String get noSavedPosts => 'لا توجد منشورات محفوظة';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get noBio => 'لا يوجد نبذة شخصية بعد.';

  @override
  String get profileAvatarViewPhoto => 'صورة الملف الشخصي';

  @override
  String get profileAvatarViewStory => 'عرض القصة';

  @override
  String get profileAvatarNoPhoto => 'لا توجد صورة للملف الشخصي';

  @override
  String get story => 'قصة';

  @override
  String get addStoryTitle => 'إضافة قصة';

  @override
  String get shareStoryButton => 'نشر القصة';

  @override
  String get storyCaptionHint => 'أضف تعليقاً (اختياري)';

  @override
  String storyPickMediaError(String error) {
    return 'تعذر اختيار الوسائط: $error';
  }

  @override
  String get storyExpired => 'انتهت القصة';

  @override
  String storyTimeMinutesAgo(int count) {
    return 'منذ $count د';
  }

  @override
  String storyTimeHoursAgo(int count) {
    return 'منذ $count س';
  }

  @override
  String get storyAddCommentHint => 'أضف تعليقاً...';

  @override
  String get storySendMessageHint => 'اكتب رسالة...';

  @override
  String get storySendMessageTitle => 'الرد برسالة';

  @override
  String get storyViewersTitle => 'المشاهدون';

  @override
  String get storyViewerUnknown => 'مشاهد';

  @override
  String get storyMessagesTitle => 'رسائل على هذه القصة';

  @override
  String get storyMessagesEmpty => 'لا رسائل على هذه القصة بعد';

  @override
  String get storyMessageSendFailed => 'تعذر إرسال الرسالة. حاول مرة أخرى.';

  @override
  String storyMessageSent(String name) {
    return 'تم إرسال الرسالة إلى $name';
  }

  @override
  String get storyPreviewLabel => 'قصة';

  @override
  String get postPreviewLabel => 'منشور';

  @override
  String get storyMessageOnStory => 'رد على قصتك';

  @override
  String get storyMessageOnPost => 'رد على منشورك';

  @override
  String get personalInfo => 'المعلومات الشخصية';

  @override
  String get genderLabel => 'الجنس';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get selectCountry => 'اختر الدولة';

  @override
  String get changeProfilePhoto => 'تغيير صورة الملف الشخصي';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get selectFromGallery => 'اختيار من المعرض';

  @override
  String get removeCurrentPhoto => 'إزالة الصورة الحالية';

  @override
  String get changePhoto => 'تغيير الصورة';

  @override
  String get enterYourName => 'أدخل اسمك';

  @override
  String get enterUsername => 'أدخل اسم المستخدم';

  @override
  String get addBioToProfile => 'أضف نبذة شخصية لملفك';

  @override
  String get selectGender => 'اختر الجنس';

  @override
  String get instagramProfileUrl => 'رابط حساب إنستجرام';

  @override
  String get youtubeChannelUrl => 'رابط قناة يوتيوب';

  @override
  String get egypt => 'مصر';

  @override
  String get saudiArabia => 'السعودية';

  @override
  String get uae => 'الإمارات';

  @override
  String get usa => 'أمريكا';

  @override
  String get uk => 'بريطانيا';

  @override
  String get kuwait => 'الكويت';

  @override
  String get qatar => 'قطر';

  @override
  String get bioLabel => 'نبذة شخصية';

  @override
  String get instagramLabel => 'إنستجرام';

  @override
  String get youtubeLabel => 'يوتيوب';

  @override
  String fieldIsRequired(String field) {
    return '$field مطلوب';
  }

  @override
  String get edit => 'تعديل';

  @override
  String get feedFollowingTab => 'المتابَعون';

  @override
  String get feedForYou => 'لك';

  @override
  String get feedLive => 'مباشر';

  @override
  String get noPostsFound => 'لا توجد منشورات';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navFriends => 'الأصدقاء';

  @override
  String get navAuctions => 'مزادات';

  @override
  String get auctionsSearchHint => 'ابحث في المزادات...';

  @override
  String get postsSearchTitle => 'بحث المنشورات';

  @override
  String get postsSearchHint => 'ابحث في المنشورات...';

  @override
  String get auctionsFiltersTitle => 'تصفية';

  @override
  String get auctionsFiltersApply => 'تطبيق التصفية';

  @override
  String get auctionsFiltersReset => 'إعادة تعيين';

  @override
  String get auctionsFiltersCategories => 'الفئات';

  @override
  String get auctionsFiltersPriceRange => 'نطاق السعر (دولار)';

  @override
  String get auctionsFiltersMinPrice => 'أقل سعر';

  @override
  String get auctionsFiltersMaxPrice => 'أعلى سعر';

  @override
  String get auctionsFiltersTimeRemaining => 'الوقت المتبقي';

  @override
  String get auctionsFiltersInvalidPriceRange => 'لا يمكن أن يكون أقل سعر أكبر من أعلى سعر';

  @override
  String get auctionsTimeRemainingAny => 'أي وقت';

  @override
  String get auctionsTimeRemaining1Hour => 'ينتهي خلال ساعة';

  @override
  String get auctionsTimeRemaining6Hours => 'ينتهي خلال 6 ساعات';

  @override
  String get auctionsTimeRemaining24Hours => 'ينتهي خلال 24 ساعة';

  @override
  String get auctionsTimeRemaining7Days => 'ينتهي خلال 7 أيام';

  @override
  String get auctionsTimeRemaining30Days => 'ينتهي خلال 30 يوماً';

  @override
  String get popularCategories => 'الفئات الرائجة';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get auctionCategoryWatches => 'ساعات فاخرة';

  @override
  String get auctionCategoryCars => 'سيارات رياضية';

  @override
  String get auctionCategoryArt => 'فنون نادرة';

  @override
  String get auctionCategoryJewelry => 'مجوهرات';

  @override
  String get auctionCategoryAll => 'الكل';

  @override
  String get activeAuctionsNow => 'مزادات نشطة الآن';

  @override
  String get liveBadge => 'مباشر';

  @override
  String get auctionActiveBadge => 'نشط';

  @override
  String get auctionFinishedBadge => 'انتهى';

  @override
  String get auctionTimeLeft => 'الوقت المتبقي';

  @override
  String get auctionStartsIn => 'يبدأ خلال';

  @override
  String auctionAddedBy(String username) {
    return 'أضافه $username';
  }

  @override
  String auctionCountdownDayCount(int days) {
    return '$days يوم';
  }

  @override
  String get auctionTimerHour => 'س';

  @override
  String get auctionTimerMinute => 'د';

  @override
  String get auctionTimerSecond => 'ث';

  @override
  String auctionCountdownWithDays(int days, String time) {
    return '$days يوم $time';
  }

  @override
  String get auctionTargetReachedMessage => 'تم الوصول للسعر المستهدف. انتهى المزاد.';

  @override
  String get auctionBiddingClosed => 'المزايدة مغلقة';

  @override
  String auctionTargetPrice(String amount, String currency) {
    return 'الهدف $amount $currency';
  }

  @override
  String get liveStreamsTitle => 'بث مباشر';

  @override
  String get searchLiveStreamsHint => 'ابحث عن بث...';

  @override
  String get liveFilterAll => 'الكل';

  @override
  String get liveFilterRealEstate => 'عقارات';

  @override
  String get liveFilterAuctions => 'مزادات';

  @override
  String get liveFilterTrending => 'رائج';

  @override
  String get liveFilterInvestments => 'استثمارات';

  @override
  String get liveStreamTitle1 => 'استثمار عقاري مباشر';

  @override
  String get liveStreamTitle2 => 'عرض مزادات فاخرة';

  @override
  String get liveStreamTitle3 => 'نصائح استثمارية مباشرة';

  @override
  String liveHostName(int number) {
    return 'مضيف $number';
  }

  @override
  String liveViewersCount(int count) {
    return '$count';
  }

  @override
  String get joinLiveStream => 'انضم للبث';

  @override
  String get liveDetailsTitle => 'بث مباشر';

  @override
  String get liveFollow => 'متابعة';

  @override
  String get liveFollowing => 'متابع';

  @override
  String liveViewersShort(String count) {
    return '$count مشاهد';
  }

  @override
  String get liveTopBid => 'أعلى سعر';

  @override
  String get currencyUsd => 'دولار';

  @override
  String get currencySar => 'ر.س';

  @override
  String liveHighestBidAmount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get liveAddCommentOrBid => 'أضف تعليق أو سعر...';

  @override
  String liveBidAmount(int amount) {
    return 'زايد بـ $amount ر.س';
  }

  @override
  String get liveCommentSample => 'هذا العقار ممتاز جداً!';

  @override
  String get liveChatYou => 'أنت';

  @override
  String get liveSendGift => 'إرسال هدية';

  @override
  String get liveSelectGift => 'اختر هدية';

  @override
  String get liveSendToHost => 'إرسال للمضيف';

  @override
  String liveGiftSent(String name, String icon) {
    return 'أرسل $name $icon';
  }

  @override
  String get liveGiftCommentGeneric => 'أرسل هدية';

  @override
  String get liveGiftRose => 'وردة';

  @override
  String get liveGiftCoffee => 'قهوة';

  @override
  String get liveGiftDonut => 'دونات';

  @override
  String get liveGiftHeart => 'قلب';

  @override
  String get liveGiftParty => 'احتفال';

  @override
  String get liveGiftCrown => 'تاج';

  @override
  String get liveGiftRocket => 'صاروخ';

  @override
  String get liveGiftDiamond => 'ماسة';

  @override
  String get liveVipBadge => 'VIP';

  @override
  String liveCoinsBalance(int count) {
    return '$count';
  }

  @override
  String get liveGiftPriceLabel => 'السعر';

  @override
  String liveGiftPriceAmount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String liveGiftBuy(String price) {
    return 'شراء — $price';
  }

  @override
  String get liveGiftBuyMore => 'شراء المزيد';

  @override
  String get liveGiftBuying => 'جاري الشراء…';

  @override
  String get liveGiftSending => 'جاري الإرسال…';

  @override
  String liveGiftPurchaseSuccess(String name) {
    return 'تم شراء $name';
  }

  @override
  String get liveGiftLoginRequired => 'سجّل الدخول لشراء أو إرسال الهدايا';

  @override
  String get liveGiftNoRecipient => 'افتح بثاً أو مزاداً لإرسال هدية';

  @override
  String get liveGiftCannotSendToSelf => 'لا يمكنك إرسال هدية إلى مزادك الخاص';

  @override
  String get liveGiftCatalogEmpty => 'لا توجد هدايا متاحة';

  @override
  String get liveGiftRetry => 'إعادة المحاولة';

  @override
  String liveGiftOwned(int count) {
    return '×$count';
  }

  @override
  String get auctionGiftsTitle => 'هدايا المزاد';

  @override
  String get auctionGiftsEmpty => 'لم تُرسل هدايا على هذا المزاد بعد';

  @override
  String auctionGiftsSummary(String current, String target, String currency) {
    return '$current / $target $currency';
  }

  @override
  String auctionGiftsContribution(String amount, String currency) {
    return '+$amount $currency';
  }

  @override
  String liveQuickBid(int amount) {
    return '+$amount';
  }

  @override
  String get highestCurrentBid => 'أعلى مزايدة حالية';

  @override
  String get bidsLabel => 'المزايدات';

  @override
  String get auctionGiftsLabel => 'الهدايا';

  @override
  String get bidNow => 'زايد الآن';

  @override
  String get navAdd => 'إضافة';

  @override
  String get navChat => 'الدردشة';

  @override
  String get navProfile => 'حسابي';

  @override
  String get describePostHint => 'صف منشورك… استخدم @اسم_المستخدم و #وسم في النص';

  @override
  String get hashtagsLabel => 'هاشتاجات';

  @override
  String get mentionsLabel => 'منشن';

  @override
  String get whoCanWatchLabel => 'من يمكنه مشاهدة هذا المنشور';

  @override
  String get allowCommentsLabel => 'السماح بالتعليقات';

  @override
  String get allowDuetLabel => 'السماح بـ Duet';

  @override
  String get allowStitchLabel => 'السماح بـ Stitch';

  @override
  String get addLocationLabel => 'إضافة موقع';

  @override
  String get everyoneLabel => 'الجميع';

  @override
  String get friendsLabel => 'الأصدقاء';

  @override
  String get onlyMeLabel => 'أنا فقط';

  @override
  String get videoLabel => 'فيديو';

  @override
  String get recordVideo => 'تسجيل فيديو';

  @override
  String get imagesLabel => 'صور';

  @override
  String get imageFromLibrary => 'صور من المعرض';

  @override
  String get videoFromLibrary => 'فيديوهات من المعرض';

  @override
  String get tapToSelectMedia => 'اضغط لاختيار الوسائط';

  @override
  String get pleaseSelectMediaFirst => 'يرجى اختيار الوسائط أولاً';

  @override
  String get loginRequired => 'تسجيل الدخول مطلوب';

  @override
  String get loginRequiredMessage => 'يرجى تسجيل الدخول للإعجاب أو التعليق أو حفظ المنشورات';

  @override
  String get cancel => 'إلغاء';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get commentsTitle => 'التعليقات';

  @override
  String commentsCount(int count) {
    return '$count تعليقات';
  }

  @override
  String get postLikesEmpty => 'لا إعجابات بعد';

  @override
  String get postViewsEmpty => 'لا مشاهدات بعد';

  @override
  String postViewWatchedDuration(int seconds) {
    return 'شاهد $seconds ث';
  }

  @override
  String get viewsLabel => 'المشاهدات';

  @override
  String get commentsSortNewest => 'الأحدث';

  @override
  String get commentsSortOldest => 'الأقدم';

  @override
  String get commentsSortTop => 'الأكثر إعجاباً';

  @override
  String get noCommentsYet => 'لا توجد تعليقات بعد. كن أول من يعلق!';

  @override
  String get addCommentHint => 'أضف تعليقًا… @اسم_المستخدم للإشارة';

  @override
  String get justNow => 'الآن';

  @override
  String inboxTimeMinutes(int count) {
    return '$count د';
  }

  @override
  String inboxTimeHours(int count) {
    return '$count س';
  }

  @override
  String inboxTimeDays(int count) {
    return '$count ي';
  }

  @override
  String get replyAction => 'رد';

  @override
  String replyingTo(String username) {
    return 'الرد على $username';
  }

  @override
  String viewReplies(int count) {
    return 'عرض $count ردود';
  }

  @override
  String get hideReplies => 'إخفاء الردود';

  @override
  String get loadMoreReplies => 'تحميل المزيد من الردود';

  @override
  String get deleteCommentTitle => 'حذف التعليق؟';

  @override
  String get deleteCommentMessage => 'سيتم حذف هذا التعليق نهائيًا.';

  @override
  String get deleteAction => 'حذف';

  @override
  String get editPost => 'تعديل المنشور';

  @override
  String get deletePost => 'حذف المنشور';

  @override
  String get deletePostTitle => 'حذف المنشور؟';

  @override
  String get deletePostMessage => 'سيتم حذف هذا المنشور نهائيًا. يمكنك حذف منشوراتك فقط.';

  @override
  String get postUpdatedSuccessfully => 'تم تحديث المنشور بنجاح';

  @override
  String get postDeletedSuccessfully => 'تم حذف المنشور بنجاح';

  @override
  String get saveButton => 'حفظ';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get selectCategoryHint => 'اختر فئة';

  @override
  String get hashtagsHint => 'اكتب #وسم في الوصف (مثال: #سفر #طعام)';

  @override
  String get mentionsHint => 'اكتب @اسم_المستخدم في الوصف (مثال: @jane_doe)';

  @override
  String get mediaLabel => 'الوسائط';

  @override
  String get settingsAndPrivacy => 'الإعدادات والخصوصية';

  @override
  String get settingsSectionAccount => 'الحساب';

  @override
  String get settingsSecurity => 'الأمان';

  @override
  String get settingsPrivacy => 'الخصوصية';

  @override
  String get settingsSectionContent => 'المحتوى والعرض';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsDarkMode => 'الوضع المظلم';

  @override
  String get settingsSectionSupport => 'الدعم';

  @override
  String get settingsHelpCenter => 'مركز المساعدة';

  @override
  String get settingsAbout => 'حول التطبيق';

  @override
  String get settingsLogout => 'تسجيل الخروج';

  @override
  String get settingsSelectLanguage => 'اختر اللغة';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsLightMode => 'وضع النهار';

  @override
  String get settingsDarkModeOption => 'الوضع المظلم';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsOn => 'مفعل';

  @override
  String get settingsOff => 'معطل';

  @override
  String get settingsLogoutTitle => 'تسجيل الخروج؟';

  @override
  String get settingsLogoutMessage => 'ستحتاج إلى تسجيل الدخول مرة أخرى لاستخدام حسابك.';

  @override
  String get settingsComingSoon => 'قريباً';

  @override
  String get settingsChatWallpaper => 'خلفية المحادثة';

  @override
  String get settingsSectionAdmin => 'المسؤول';

  @override
  String get settingsAdminActivity => 'نشاط المستخدم';

  @override
  String get adminActivityTitle => 'النشاط';

  @override
  String get adminActivityEmpty => 'لا يوجد نشاط بعد';

  @override
  String get adminActivityJustNow => 'الآن';

  @override
  String get adminActivityNoDetails => 'لا توجد تفاصيل';

  @override
  String adminActivityOnPost(String post) {
    return 'على المنشور: $post';
  }

  @override
  String get adminActivityTypeCreatePost => 'أنشأ منشوراً';

  @override
  String get adminActivityTypeComment => 'علّق';

  @override
  String get adminActivityTypeLikePost => 'أعجب بمنشور';

  @override
  String get adminActivityTypeSendGift => 'أرسل هدية';

  @override
  String get chatWallpaperTitle => 'خلفية المحادثة';

  @override
  String get chatWallpaperSubtitle => 'اختر نمط الخلفية للمحادثات. الألوان تتبع سمة التطبيق.';

  @override
  String get chatWallpaperPlus => 'علامات زائد';

  @override
  String get chatWallpaperSquares => 'مربعات';

  @override
  String get chatWallpaperMaze => 'متاهة';

  @override
  String get messagesTitle => 'الرسائل';

  @override
  String get messagesInboxTitle => 'البريد الوارد';

  @override
  String get messagesSwitchAccount => 'تغيير الحساب';

  @override
  String get messagesNewConversation => 'بدء محادثة جديدة';

  @override
  String get messagesSearchHint => 'بحث عن محادثات أو أشخاص';

  @override
  String get messagesYourStory => 'قصتك';

  @override
  String get messagesPeopleYouMayKnow => 'أشخاص قد تعرفهم';

  @override
  String get messagesSeeAll => 'عرض الكل';

  @override
  String get messagesFollow => 'متابعة';

  @override
  String get messagesFollowing => 'متابَع';

  @override
  String get messagesRecentMentions => 'الإشارات الأخيرة';

  @override
  String get messagesActivityFollowers => 'متابعون';

  @override
  String get messagesActivityActivities => 'أنشطة';

  @override
  String get messagesActivityComments => 'تعليقات';

  @override
  String get messagesActivityMentions => 'إشارات';

  @override
  String get messagesRecentMessages => 'الرسائل الأخيرة';

  @override
  String get messagesAllChats => 'جميع المحادثات';

  @override
  String get messagesAll => 'الكل';

  @override
  String get messagesNoResults => 'لا توجد نتائج';

  @override
  String get messagesInboxNoMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get messagesInboxYouPrefix => 'أنت';

  @override
  String get messagesInboxLastPhoto => 'صورة';

  @override
  String get messagesInboxLastVideo => 'فيديو';

  @override
  String get messagesInboxLastVoice => 'رسالة صوتية';

  @override
  String get messagesInboxLastGift => 'هدية';

  @override
  String get messagesInboxLastShare => 'شارك منشوراً';

  @override
  String get messagesInboxMessageDeleted => 'تم حذف الرسالة';

  @override
  String get messagesInboxGroupFallback => 'مجموعة';

  @override
  String get messagesInboxUserFallback => 'مستخدم';

  @override
  String get messagesPreviewProperty => 'أهلاً، هل العقار لا يزال متاحاً؟';

  @override
  String get messagesPreviewOffer => 'تم إرسال العرض الجديد';

  @override
  String get messagesPreviewThanks => 'شكراً لاهتمامك بخدماتنا';

  @override
  String get messagesPreviewCar => 'متى يمكنني معاينة السيارة؟';

  @override
  String get messagesMentionVilla => 'منشور رائع يصف الفيلا! @myself';

  @override
  String get messagesMentionCheck => 'ألقِ نظرة على هذا @myself';

  @override
  String get messagesSuggestionBioDesigner => 'مصمم داخلي | معماري';

  @override
  String get messagesSuggestionBioJeddah => 'أفضل العروض في جدة';

  @override
  String get messagesSuggestionBioLuxury => 'عقارات فاخرة عالمية';

  @override
  String get messagesSuggestionFriendsOfFriends => 'مقترح لك';

  @override
  String get messagesSuggestionPopular => 'منشئ محتوى شائع';

  @override
  String messagesSuggestionMutualFriends(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أصدقاء مشتركين',
      one: 'صديق مشترك واحد',
    );
    return '$_temp0';
  }

  @override
  String get messagesSuggestionsEmpty => 'لا توجد اقتراحات حالياً';

  @override
  String get userCommentsTitle => 'تعليقاتي';

  @override
  String get userCommentsEmpty => 'لم تعلق على أي منشور بعد';

  @override
  String get userCommentReplyLabel => 'رد';

  @override
  String get userCommentAction => 'علّق';

  @override
  String userCommentOnPost(String author) {
    return 'على منشور $author';
  }

  @override
  String get userLikesTitle => 'الإعجابات';

  @override
  String get userLikesEmpty => 'لم يعجب أحد بمنشوراتك بعد';

  @override
  String get userLikeReceivedAction => 'أعجب بمنشورك';

  @override
  String get userMentionsTitle => 'إشاراتي';

  @override
  String get userMentionsEmpty => 'لم يذكرك أحد بعد';

  @override
  String get userMentionAction => 'ذكرك';

  @override
  String get userMentionInComment => 'في تعليق';

  @override
  String get userFollowersTitle => 'المتابعون';

  @override
  String get userFollowerAction => 'بدأ بمتابعتك';

  @override
  String get chatMessageDeleted => 'تم حذف هذه الرسالة';

  @override
  String get chatActionReply => 'رد';

  @override
  String get chatActionReact => 'تفاعل';

  @override
  String get chatActionDelete => 'حذف';

  @override
  String get chatDeleteMessageTitle => 'حذف الرسالة؟';

  @override
  String get chatDeleteMessageMessage => 'سيتم إخفاء هذه الرسالة عن الجميع في المحادثة.';

  @override
  String get chatActiveNow => 'نشط الآن';

  @override
  String get chatAddComment => 'إضافة تعليق...';

  @override
  String get chatRecording => 'جاري التسجيل...';

  @override
  String get chatSlideUpToCancel => 'اسحب للأعلى للإلغاء';

  @override
  String get chatRecordingPermissionDenied => 'اسمح بالوصول إلى الميكروفون لتسجيل الرسائل الصوتية.';

  @override
  String get chatRecordingPermissionTitle => 'الوصول إلى الميكروفون';

  @override
  String get chatRecordingPermissionSettingsMessage => 'الرسائل الصوتية تحتاج الميكروفون. افتح الإعدادات، ثم الأذونات، واسمح بالميكروفون لتطبيق Bimo Bond.';

  @override
  String get chatRecordingOpenSettings => 'فتح الإعدادات';

  @override
  String get chatRecordingAllowMicrophone => 'سماح';

  @override
  String get chatRecordingPluginUnavailable => 'التسجيل الصوتي غير جاهز. أغلق التطبيق بالكامل ثم شغّله من جديد (وليس إعادة التحميل السريع).';

  @override
  String get chatVoiceTooShort => 'اضغط مطولاً لتسجيل رسالة صوتية.';

  @override
  String get chatVoicePlaybackFailed => 'تعذّر تشغيل الرسالة الصوتية.';

  @override
  String get chatAttachmentSendFailed => 'تعذّر إرسال المرفق. حاول مرة أخرى.';

  @override
  String get chatLocationPermissionDenied => 'يلزم إذن الموقع لمشاركة موقعك.';

  @override
  String get chatContactsPermissionDenied => 'يلزم إذن جهات الاتصال لمشاركة جهة اتصال.';

  @override
  String get chatFeatureComingSoon => 'قريباً.';

  @override
  String get chatMessageLocation => 'الموقع';

  @override
  String get messagesInboxLastLocation => 'موقع';

  @override
  String get messagesInboxLastFile => 'ملف';

  @override
  String get messagesInboxLastContact => 'جهة اتصال';

  @override
  String get chatSeedGreeting => 'مرحباً! كيف يمكنني مساعدتك؟';

  @override
  String get chatSeedInterested => 'أنا مهتم بالعقار المعروض';

  @override
  String get chatSeedFinalPrice => 'هل يمكنني معرفة السعر النهائي؟';

  @override
  String get chatSeedAutoReply => 'شكراً لتواصلك معنا، سنرد عليك في أقرب وقت بمزيد من التفاصيل.';

  @override
  String get chatUserBio => 'مهتم بالعقارات والتصميم.';

  @override
  String get chatMoreGallery => 'المعرض';

  @override
  String get chatMoreCamera => 'الكاميرا';

  @override
  String get chatMoreVideo => 'فيديو';

  @override
  String get chatMoreLocation => 'الموقع';

  @override
  String get chatMoreContact => 'جهة اتصال';

  @override
  String get chatMoreFile => 'ملف';

  @override
  String get chatMoreGift => 'هدية';

  @override
  String get chatMorePoll => 'تصويت';

  @override
  String get chatLastMessage1 => 'هل يمكنني معرفة السعر النهائي؟';

  @override
  String get chatLastMessage2 => 'شكراً على التحديث!';

  @override
  String get chatLastMessage3 => 'هل العقار ما زال متاحاً؟';

  @override
  String get chatLastMessage4 => 'أرسل صورة';

  @override
  String get chatLastMessage5 => 'أراك غداً 👋';

  @override
  String get addPostAsAuction => 'عرض كمزاد';

  @override
  String get auctionItemName => 'اسم المنتج';

  @override
  String get auctionItemNameHint => 'مثال: ساعة جيب عتيقة';

  @override
  String get auctionStartingPrice => 'السعر الابتدائي (دولار)';

  @override
  String get auctionTargetPriceLabel => 'السعر المستهدف (دولار)';

  @override
  String get auctionStartDate => 'بداية المزاد';

  @override
  String get auctionEndDate => 'نهاية المزاد';

  @override
  String get auctionEndBeforeStart => 'يجب أن يكون تاريخ النهاية بعد تاريخ البداية';

  @override
  String get auctionTargetBelowStart => 'يجب أن يكون السعر المستهدف أعلى من السعر الابتدائي';

  @override
  String get auctionInvalidPrice => 'أدخل سعراً صالحاً';
}
