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
  String get loginScreenTitle => 'تسجيل الدخول إلى بيموبوند';

  @override
  String get loginWithPhone => 'استخدام رقم الجوال';

  @override
  String get loginWithEmailUsername => 'استخدام البريد الإلكتروني أو اسم المستخدم';

  @override
  String get loginEmailUsernameHint => 'البريد الإلكتروني أو اسم المستخدم';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get continueWithApple => 'المتابعة باستخدام Apple';

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
  String get notificationErrorTitle => 'خطأ';

  @override
  String get notificationSuccessTitle => 'نجاح';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpScreenTitle => 'إنشاء حساب في بيموبوند';

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
  String get phoneLoginUsageNote => 'قد يُستخدم رقم جوالك للتواصل مع أشخاص قد تعرفهم وتحسين الإعلانات والمزيد حسب إعداداتك.';

  @override
  String get emailLoginUsageNote => 'قد يُستخدم بريدك الإلكتروني للتواصل مع أشخاص قد تعرفهم وتحسين الإعلانات والمزيد حسب إعداداتك.';

  @override
  String get phoneHint => '+20 123 456 7890';

  @override
  String get termsAndConditionsPart1 => 'بالاستمرار، أنت توافق على ';

  @override
  String get termsAndConditionsPart2 => 'الشروط والأحكام';

  @override
  String get loginLegalNotePart1 => 'بالمتابعة، أنت توافق على ';

  @override
  String get loginTermsOfService => 'شروط الخدمة';

  @override
  String get loginLegalNotePart2 => ' وتؤكد أنك قرأت ';

  @override
  String get loginPrivacyPolicy => 'سياسة الخصوصية';

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
  String get passwordSignUpTooShort => 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';

  @override
  String get passwordTooLong => 'يجب ألا تتجاوز كلمة المرور 20 حرفاً';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get forgotPasswordSubtitle => 'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get forgotPasswordButton => 'إرسال رابط إعادة التعيين';

  @override
  String get forgotPasswordSuccess => 'تم إرسال بريد إعادة تعيين كلمة المرور. تحقق من صندوق الوارد ومجلد البريد العشوائي.';

  @override
  String get forgotPasswordFailed => 'فشل إرسال بريد إعادة التعيين. يرجى المحاولة مرة أخرى.';

  @override
  String get forgotPasswordUserNotFound => 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';

  @override
  String get loginFailed => 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';

  @override
  String get verificationFailed => 'فشل التحقق';

  @override
  String get invalidOtpCode => 'رمز OTP غير صحيح';

  @override
  String get googleLoginFailed => 'فشل تسجيل الدخول عبر جوجل';

  @override
  String get googleLoginSheetTitle => 'تسجيل الدخول عبر جوجل';

  @override
  String get googleLoginSheetSubtitle => 'استخدم حساب جوجل لتسجيل الدخول بسرعة وأمان.';

  @override
  String get googleLoginContinue => 'المتابعة عبر جوجل';

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
  String get signUpEmailStepTitle => 'ما هو بريدك الإلكتروني؟';

  @override
  String get signUpNameStepTitle => 'ما هو اسمك؟';

  @override
  String get signUpPasswordStepTitle => 'أنشئ كلمة مرور';

  @override
  String get nextAction => 'التالي';

  @override
  String get passwordStrengthLabel => 'قوة كلمة المرور';

  @override
  String get passwordStrengthWeak => 'ضعيفة';

  @override
  String get passwordStrengthFair => 'متوسطة';

  @override
  String get passwordStrengthGood => 'جيدة';

  @override
  String get passwordStrengthStrong => 'قوية';

  @override
  String get passwordStrengthHint => 'يجب أن تتكون كلمة المرور من 8 إلى 20 حرفاً وتتضمن مزيجاً من الأحرف والأرقام والرموز.';

  @override
  String get passwordReqLength => 'من 8 إلى 20 حرفاً';

  @override
  String get passwordReqLetter => 'حرف واحد';

  @override
  String get passwordReqNumber => 'رقم واحد';

  @override
  String get passwordReqSpecialChar => 'رمز خاص واحد (مثل ! @ # \$ % & *)';

  @override
  String get passwordRequirementsNotMet => 'يجب أن تستوفي كلمة المرور جميع المتطلبات';

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
  String get noRepostedPosts => 'لا توجد إعادات نشر بعد';

  @override
  String get noOnlyMePosts => 'لا توجد منشورات خاصة بك فقط';

  @override
  String get repostTitle => 'إعادة النشر';

  @override
  String get repostSubtitle => 'شارك هذا المنشور على ملفك الشخصي';

  @override
  String get repostAction => 'إعادة النشر';

  @override
  String get repostUndo => 'تراجع عن إعادة النشر';

  @override
  String get savePost => 'حفظ المنشور';

  @override
  String get unsavePost => 'إزالة من المحفوظات';

  @override
  String get repostQuoteHint => 'أضف تعليقاً (اختياري)';

  @override
  String get repostSuccess => 'تمت إعادة النشر';

  @override
  String get repostRemoved => 'تم إلغاء إعادة النشر';

  @override
  String get cannotRepostOwnPost => 'لا يمكنك إعادة نشر منشورك';

  @override
  String repostCountLabel(int count) {
    return '$count إعادة نشر';
  }

  @override
  String repostedByUser(Object name) {
    return 'أعاد $name النشر';
  }

  @override
  String postRepostersTitle(int count) {
    return 'إعادات النشر · $count';
  }

  @override
  String get postRepostersEmpty => 'لا توجد إعادات نشر بعد';

  @override
  String get profileRepostsTab => 'إعادات النشر';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get noBio => 'لا يوجد نبذة شخصية بعد.';

  @override
  String get profileAvatarViewPhoto => 'فتح صورة الملف الشخصي';

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
  String get storyAddText => 'نص';

  @override
  String get storyTextDone => 'تم';

  @override
  String get storyCaptionHint => 'أضف تعليقاً (اختياري)';

  @override
  String get storyLoadMore => 'عرض المزيد';

  @override
  String get storyShowLess => 'عرض أقل';

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
  String storyTimeDaysAgo(int count) {
    return 'منذ $count ي';
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
  String get importFromLibrary => 'استيراد';

  @override
  String get uploadFromLibrary => 'رفع من المكتبة';

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
  String get searchAction => 'بحث';

  @override
  String get searchHistorySeeMore => 'عرض المزيد';

  @override
  String get searchHistorySeeLess => 'عرض أقل';

  @override
  String get searchHistoryClear => 'مسح';

  @override
  String get searchHistoryEmpty => 'لا توجد عمليات بحث حديثة';

  @override
  String get searchSeeAll => 'عرض الكل';

  @override
  String get searchSeeLess => 'عرض أقل';

  @override
  String get searchYouMayLike => 'قد يعجبك';

  @override
  String get searchNoResults => 'لا توجد منشورات';

  @override
  String get searchTabTop => 'الأعلى';

  @override
  String get searchTabUsers => 'المستخدمون';

  @override
  String get searchTabVideos => 'الفيديوهات';

  @override
  String get searchTabLive => 'مباشر';

  @override
  String get searchTabSounds => 'الأصوات';

  @override
  String get searchTabPlaces => 'الأماكن';

  @override
  String get searchComingSoon => 'قريبًا';

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
  String get auctionsFiltersLiveStatus => 'حالة المزاد';

  @override
  String get auctionsFilterLive => 'مباشر';

  @override
  String get auctionsFilterEnded => 'منتهي';

  @override
  String get endedAuctionsNow => 'مزادات منتهية';

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
  String get auctionTapToEnter => 'اضغط للدخول';

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
  String get addDescriptionHint => 'أضف وصفًا...';

  @override
  String get hashtagsLabel => 'هاشتاجات';

  @override
  String get mentionsLabel => 'منشن';

  @override
  String get whoCanWatchLabel => 'من يمكنه مشاهدة هذا المنشور';

  @override
  String get allowCommentsLabel => 'السماح بالتعليقات';

  @override
  String get allowReuseLabel => 'السماح بإعادة استخدام المحتوى';

  @override
  String get allowReuseSubtitle => 'Duet و Stitch والملصقات والإضافة إلى القصة';

  @override
  String get videoPrivacySection => 'خصوصية الفيديو';

  @override
  String get advancedSettings => 'إعدادات متقدمة';

  @override
  String get addPostSettingsTitle => 'الإعدادات';

  @override
  String get everyoneCanViewPost => 'يمكن للجميع مشاهدة هذا المنشور';

  @override
  String get friendsCanViewPost => 'يمكن للأصدقاء مشاهدة هذا المنشور';

  @override
  String get onlyYouCanViewPost => 'يمكنك أنت فقط مشاهدة هذا المنشور';

  @override
  String get friendsPrivacySubtitle => 'المتابعون الذين تتابعهم';

  @override
  String get draftsLabel => 'المسودات';

  @override
  String get moreOptionsLabel => 'المزيد من الخيارات';

  @override
  String get previewLabel => 'معاينة';

  @override
  String get editCoverLabel => 'تعديل الغلاف';

  @override
  String get locationLabelShort => 'الموقع';

  @override
  String get addPostDraftsComingSoon => 'المسودات قريبًا';

  @override
  String get allowDuetLabel => 'السماح بـ Duet';

  @override
  String get allowStitchLabel => 'السماح بـ Stitch';

  @override
  String get addLocationLabel => 'إضافة موقع';

  @override
  String get selectCity => 'اختر المدينة';

  @override
  String get selectCityHint => 'ابحث عن المدن';

  @override
  String get selectCountryHint => 'ابحث عن الدول';

  @override
  String get locationSearchHint => 'ابحث عن الدول أو المدن';

  @override
  String get clearLocation => 'مسح الموقع';

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
  String get imageFromLibrary => 'رفع صور من المكتبة';

  @override
  String get videoFromLibrary => 'استيراد فيديوهات من المكتبة';

  @override
  String get tapToSelectMedia => 'اضغط للرفع من المكتبة';

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
  String get postOptionShare => 'مشاركة';

  @override
  String get postOptionReport => 'إبلاغ';

  @override
  String get postOptionNotInterested => 'غير مهتم';

  @override
  String get postOptionDownload => 'تنزيل';

  @override
  String get postOptionAddToStory => 'إضافة للقصة';

  @override
  String get postOptionShareAsGif => 'مشاركة كصورة متحركة';

  @override
  String get postOptionCreateGroup => 'إنشاء مجموعة';

  @override
  String get postLinkCopied => 'تم نسخ الرابط';

  @override
  String get postReportTitle => 'الإبلاغ عن المنشور؟';

  @override
  String get postReportMessage => 'أخبرنا إذا كان هذا المنشور يخالف إرشادات المجتمع.';

  @override
  String get postReportSubmitted => 'شكرًا على الإبلاغ. سنراجع هذا المنشور.';

  @override
  String get postNotInterestedApplied => 'سنعرض منشورات أقل من هذا النوع';

  @override
  String get postDownloadStarted => 'جاري التنزيل…';

  @override
  String get postDownloadSaved => 'تم الحفظ في مجلد التنزيلات';

  @override
  String get postDownloadFailed => 'تعذر تنزيل الوسائط';

  @override
  String get postShareAsGifUnavailable => 'مشاركة GIF متاحة للفيديو فقط';

  @override
  String get postShareSheetTitle => 'مشاركة المنشور';

  @override
  String get postShareSearchUsers => 'ابحث عن الأصدقاء والمستخدمين';

  @override
  String get postShareNoUsers => 'لم يتم العثور على مستخدمين';

  @override
  String get postShareToApps => 'مشاركة عبر التطبيقات';

  @override
  String get postShareMessenger => 'ماسنجر';

  @override
  String get postShareFacebook => 'فيسبوك';

  @override
  String get postShareWhatsApp => 'واتساب';

  @override
  String get postShareTelegram => 'تيليجرام';

  @override
  String get postShareTwitter => 'إكس';

  @override
  String get postShareSms => 'رسائل';

  @override
  String get postShareEmail => 'بريد';

  @override
  String get postShareCopyLink => 'نسخ الرابط';

  @override
  String get postShareMore => 'المزيد';

  @override
  String get postShareSendFailed => 'تعذر إرسال المنشور';

  @override
  String postShareSentTo(String name) {
    return 'تم الإرسال إلى $name';
  }

  @override
  String get postAddToStoryHint => 'أنشئ قصتك — المنشور جاهز للمشاركة';

  @override
  String get postCreateGroupHint => 'اختر جهات اتصال لبدء مجموعة';

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
  String get settingsSectionDeveloper => 'المطور';

  @override
  String get settingsArCameraTest => 'اختبار كاميرا الواقع المعزز';

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
  String get messagesNewChatTitle => 'محادثة جديدة';

  @override
  String get messagesNewChatSearchHint => 'بحث';

  @override
  String get closeAction => 'إغلاق';

  @override
  String get chatSendMessageHint => 'أرسل رسالة...';

  @override
  String get chatActiveYesterday => 'نشط أمس';

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
  String get messagesActivityTitle => 'النشاط';

  @override
  String get messagesNewFollowers => 'متابعون جدد';

  @override
  String get messagesActivityComments => 'تعليقات';

  @override
  String get messagesActivityMentions => 'إشارات';

  @override
  String get messagesActivityNotifications => 'إشعارات';

  @override
  String get activityTabLikes => 'إعجابات';

  @override
  String get activityAllCaughtUp => 'أنت على اطلاع بكل شيء';

  @override
  String get activityClearNotificationsMessage => 'هل تريد إزالة جميع الإشعارات المقروءة من نشاطك؟';

  @override
  String get activityOpenCommentsSubtitle => 'عرض التعليقات على منشوراتك';

  @override
  String get activityInboxSubtitle => 'إعجابات وتعليقات والمزيد';

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
  String get userFollowerAction => 'تابعك';

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
  String get chatAddComment => 'اكتب رسالة...';

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
  String get chatMoreGallery => 'استيراد';

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
  String get chatGiftSheetTitle => 'أرسل هدية';

  @override
  String get chatGiftSheetSubtitle => 'اختر هدية من مخزونك';

  @override
  String get chatGiftInventoryEmpty => 'لا تملك أي هدايا بعد. اشترِ هدايا من المحفظة أولاً.';

  @override
  String get chatGiftSentLabel => 'تم إرسال الهدية';

  @override
  String get chatMessageContact => 'جهة اتصال';

  @override
  String get chatPollSheetTitle => 'إنشاء تصويت';

  @override
  String get chatPollQuestionHint => 'اطرح سؤالاً';

  @override
  String get chatPollOptionsLabel => 'الخيارات';

  @override
  String chatPollOptionHint(int index) {
    return 'خيار $index';
  }

  @override
  String get chatPollAddOption => 'إضافة خيار';

  @override
  String get chatPollAllowMultiple => 'السماح باختيارات متعددة';

  @override
  String get chatPollSend => 'إرسال التصويت';

  @override
  String get chatPollQuestionRequired => 'أدخل سؤالاً للتصويت.';

  @override
  String get chatPollOptionsRequired => 'أضف خيارين على الأقل.';

  @override
  String get chatPollEnded => 'انتهى التصويت';

  @override
  String chatPollVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أصوات',
      one: 'صوت واحد',
      zero: 'لا أصوات بعد',
    );
    return '$_temp0';
  }

  @override
  String get messagesInboxLastPoll => 'تصويت';

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

  @override
  String get hashtagFeedSubtitle => 'منشورات بهذا الوسم';

  @override
  String get noHashtagPosts => 'لا توجد منشورات لهذا الوسم بعد';

  @override
  String get trendingHashtags => 'الوسوم الرائجة';

  @override
  String get searchHashtagsHint => 'ابحث عن وسوم';

  @override
  String get noHashtagsFound => 'لم يتم العثور على وسوم';

  @override
  String hashtagPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منشورات',
      one: 'منشور واحد',
      zero: 'لا منشورات',
    );
    return '$_temp0';
  }

  @override
  String get notificationsEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notificationsEmptySubtitle => 'عندما يتفاعل شخص معك، ستظهر الإشعارات هنا.';

  @override
  String get notificationsEmptyUnread => 'لا توجد إشعارات غير مقروءة.';

  @override
  String get notificationsEmptyRead => 'لا توجد إشعارات مقروءة بعد.';

  @override
  String notificationsFilterUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعارات غير مقروءة',
      one: 'إشعار واحد غير مقروء',
    );
    return '$_temp0';
  }

  @override
  String get notificationsRetry => 'حاول مجدداً';

  @override
  String get notificationsOk => 'حسناً';

  @override
  String get notificationsLoadError => 'تعذّر تحميل الإشعارات';

  @override
  String get notificationsMarkAllRead => 'تحديد الكل كمقروء';

  @override
  String get notificationsClearRead => 'مسح المقروء';

  @override
  String get notificationsFilterAll => 'الكل';

  @override
  String get notificationsFilterUnread => 'غير مقروء';

  @override
  String get notificationsFilterRead => 'مقروء';

  @override
  String get notificationsFilterViewAll => 'عرض الكل';

  @override
  String get notificationsFilterActivity => 'النشاط';

  @override
  String get notificationsFilterAuctions => 'المزادات';

  @override
  String get notificationsFilterInvites => 'الدعوات';

  @override
  String get notificationsAccept => 'قبول';

  @override
  String get notificationsDecline => 'رفض';

  @override
  String get notificationsEmptyActivity => 'لا توجد إشعارات نشاط بعد.';

  @override
  String get notificationsEmptyAuctions => 'لا توجد إشعارات مزادات بعد.';

  @override
  String get notificationsEmptyInvites => 'لا توجد إشعارات دعوات بعد.';

  @override
  String get notificationContextPost => 'منشور';

  @override
  String get notificationMediaVideo => 'فيديو';

  @override
  String get notificationMediaImage => 'صورة';

  @override
  String get notificationActionFollowedYou => 'تابعك';

  @override
  String get notificationActionFollowRequest => 'طلب متابعتك';

  @override
  String get notificationActionFollowAccepted => 'قبل طلب متابعتك';

  @override
  String get notificationActionPostLike => 'أعجب بمنشورك';

  @override
  String get notificationActionPostComment => 'علّق على منشورك';

  @override
  String get notificationActionCommentReply => 'رد على تعليقك';

  @override
  String get notificationActionCommentLike => 'أعجب بتعليقك';

  @override
  String get notificationActionMention => 'أشار إليك';

  @override
  String get notificationActionRepost => 'أعاد نشر منشورك';

  @override
  String get notificationActionGift => 'أرسل لك هدية';

  @override
  String get notificationActionAuctionUpdate => 'حدّث مزاد تتابعه';

  @override
  String get notificationActionAuctionWon => 'فزت بمزاد';

  @override
  String get notificationSomeone => 'شخص ما';

  @override
  String get notificationTitleDefault => 'إشعار';

  @override
  String get notificationTitleNewFollower => 'متابع جديد';

  @override
  String get notificationTitleFollowRequest => 'طلب متابعة';

  @override
  String get notificationTitleFollowAccepted => 'تم قبول طلب المتابعة';

  @override
  String get notificationTitlePostLike => 'إعجاب جديد';

  @override
  String get notificationTitlePostComment => 'تعليق جديد';

  @override
  String get notificationTitleCommentReply => 'رد جديد';

  @override
  String get notificationTitleCommentLike => 'إعجاب على تعليق';

  @override
  String get notificationTitleMention => 'إشارة';

  @override
  String get notificationTitleRepost => 'إعادة نشر';

  @override
  String get notificationTitleGift => 'هدية مستلمة';

  @override
  String get notificationTitleAuctionUpdate => 'تحديث مزاد';

  @override
  String get notificationTitleAuctionWon => 'فوز في مزاد';

  @override
  String get notificationBodyDefault => 'لديك إشعار جديد';

  @override
  String notificationBodyNewFollower(String name) {
    return 'بدأ $name بمتابعتك';
  }

  @override
  String notificationBodyFollowRequest(String name) {
    return 'طلب $name متابعتك';
  }

  @override
  String notificationBodyFollowAccepted(String name) {
    return 'قبل $name طلب متابعتك';
  }

  @override
  String notificationBodyPostLike(String name) {
    return 'أعجب $name بمنشورك';
  }

  @override
  String notificationBodyPostComment(String name) {
    return 'علّق $name على منشورك';
  }

  @override
  String notificationBodyCommentReply(String name) {
    return 'رد $name على تعليقك';
  }

  @override
  String notificationBodyCommentLike(String name) {
    return 'أعجب $name بتعليقك';
  }

  @override
  String notificationBodyMention(String name) {
    return 'أشار إليك $name';
  }

  @override
  String notificationBodyRepost(String name) {
    return 'أعاد $name نشر منشورك';
  }

  @override
  String notificationBodyGift(String name) {
    return '$name sent you a gift';
  }

  @override
  String get notificationBodyAuctionUpdate => 'تم تحديث مزاد تتابعه';

  @override
  String get notificationBodyAuctionWon => 'لقد فزت بمزاد';

  @override
  String get walletTitle => 'المحفظة';

  @override
  String get walletBalanceLabel => 'رصيد العملات';

  @override
  String get walletChoosePackage => 'اختر باقة';

  @override
  String get walletCustomAmountTitle => 'مبلغ مخصص';

  @override
  String get walletCustomCoinsLabel => 'كم عملة تريد؟';

  @override
  String get walletCustomCoinsHint => 'مثال: 500';

  @override
  String get walletCustomCoinsReceive => 'ستحصل على';

  @override
  String walletCustomCoinsValue(String coins) {
    return '$coins عملة';
  }

  @override
  String get walletCustomYouPay => 'ستدفع';

  @override
  String get walletPackageQuotes => 'عروض الباقات';

  @override
  String get walletPackageQuotePrice => 'سعر الباقة';

  @override
  String get walletPricingPreviewCost => 'التكلفة الإجمالية';

  @override
  String get walletPricingPreviewLoading => 'جاري الحساب...';

  @override
  String get walletCustomAmountInvalid => 'أدخل عدد عملات صالح.';

  @override
  String walletPurchaseSuccess(int amount) {
    return 'تم شراء $amount عملة بنجاح!';
  }

  @override
  String get walletTopUpButton => 'شحن الرصيد';

  @override
  String get walletProcessing => 'جاري معالجة الدفع...';

  @override
  String get walletCardNumber => 'رقم البطاقة';

  @override
  String get walletExpiry => 'تاريخ الانتهاء (MM/YY)';

  @override
  String get walletCvv => 'رمز التحقق (CVV)';

  @override
  String get walletCardHolder => 'اسم حامل البطاقة';

  @override
  String walletPayButton(String price) {
    return 'دفع $price';
  }

  @override
  String get coinsHubTitle => 'العملات';

  @override
  String get coinsAvailableBalance => 'الرصيد المتاح';

  @override
  String coinsWalletAccountName(String name) {
    return 'حساب $name';
  }

  @override
  String get coinsBalanceRefresh => 'تحديث الرصيد';

  @override
  String get coinsBalanceFooterHint => 'يُحدَّث عند الفتح';

  @override
  String coinsBalanceFooter(String date, String hint) {
    return '$date | $hint';
  }

  @override
  String get coinsTabBuy => 'شراء';

  @override
  String get coinsTabMarket => 'السوق';

  @override
  String get coinsTabVault => 'المخزن';

  @override
  String get coinsUnit => 'عملة';

  @override
  String get coinsHistoryTitle => 'النشاط الأخير';

  @override
  String get coinsMarketSuccess => 'تمت إضافة الهدية إلى مخزنك!';

  @override
  String get coinsVaultEmpty => 'لا توجد هدايا في مخزنك بعد. زُر السوق لشراء هدايا بالعملات.';

  @override
  String get coinsVaultOwned => 'في المخزن';

  @override
  String get coinsInsufficientBalance => 'رصيد العملات غير كافٍ. اشترِ المزيد من تبويب الشراء.';

  @override
  String get walletAccountingPurchase => 'شراء عملات';

  @override
  String get walletAccountingGiftPurchase => 'شراء هدية';

  @override
  String get walletAccountingGiftReceived => 'هدية مستلمة';

  @override
  String get walletAccountingPromotion => 'ترويج منشور';

  @override
  String get walletAccountingAdmin => 'تعديل الرصيد';

  @override
  String get balanceTitle => 'الرصيد';

  @override
  String get balanceDefaultUserName => 'المستخدم';

  @override
  String balanceUserTitle(String name) {
    return 'رصيد $name';
  }

  @override
  String get balanceEstimatedBalance => 'الرصيد التقديري';

  @override
  String get balanceView => 'عرض';

  @override
  String get balanceGet => 'احصل';

  @override
  String get balanceScheduledPayouts => 'المدفوعات المجدولة';

  @override
  String get balanceViewFullSchedule => 'عرض الجدول الكامل >';

  @override
  String get balanceSetupPaymentsBanner => 'لاستلام المدفوعات من برنامج مكافآت المبدعين، قم بإعداد المدفوعات.';

  @override
  String get balanceSetup => 'إعداد';

  @override
  String get balanceSetupRequired => 'الإعداد مطلوب';

  @override
  String get balancePastPayouts => 'المدفوعات السابقة >';

  @override
  String get balanceTransactions => 'المعاملات';

  @override
  String balanceTransactionPreview(String title, String amount) {
    return '$title: $amount >';
  }

  @override
  String get balanceFirstCoinOfferTitle => 'عرض أول شراء للعملات';

  @override
  String get balanceFirstCoinOfferSubtitle => 'احصل على عملات إضافية وهدية متحركة بخصم 99% من أول عملية شراء';

  @override
  String get balanceGetNow => 'احصل الآن ←';

  @override
  String get balanceMonetization => 'تحقيق الدخل';

  @override
  String get balanceViewMore => 'عرض المزيد >';

  @override
  String get balanceMonetizationLive => 'LIVE';

  @override
  String get balanceMonetizationActivities => 'الأنشطة';

  @override
  String get balanceServices => 'الخدمات';

  @override
  String get balancePaymentMethods => 'طرق الدفع';

  @override
  String get balanceRequired => 'مطلوب';

  @override
  String get balanceTaxInformation => 'المعلومات الضريبية';

  @override
  String get balanceIdentityVerification => 'التحقق من الهوية';

  @override
  String get balanceMonetizationCenter => 'مركز تحقيق الدخل';

  @override
  String get balanceExplore => 'استكشف >';

  @override
  String get balanceProgramCreatorRewards => 'برنامج مكافآت المبدعين';

  @override
  String get balanceProgramTiktokGo => 'مكافآت TikTok GO';

  @override
  String get balanceProgramSeries => 'Series';

  @override
  String get balanceSetupPaymentsTitle => 'إعداد المدفوعات';

  @override
  String get balanceSetupPaymentsMessage => 'تأكد من دقة معلوماتك لاستلام المدفوعات في الوقت المحدد. يمكنك تغييرها في أي وقت.';

  @override
  String get balancePayoutMethodTitle => 'طريقة الدفع';

  @override
  String get balancePayoutMethodSubtitle => 'اختر مكان استلام المدفوعات.';

  @override
  String get balanceTaxInfoTitle => 'المعلومات الضريبية';

  @override
  String get balanceTaxInfoSubtitle => 'مطلوبة لأغراض الامتثال.';

  @override
  String get balanceIdentityTitle => 'التحقق من الهوية';

  @override
  String get balanceIdentitySubtitle => 'جهّز هويتك.';

  @override
  String get balanceAddPayoutMethod => 'إضافة طريقة دفع';

  @override
  String get balanceCountryRegion => 'البلد / المنطقة';

  @override
  String get balanceCountryRegionNote => 'يمكنك التسجيل في بلد أو منطقة واحدة فقط. تأكد من اختيارك.';

  @override
  String get balanceChoosePayoutMethod => 'اختر طريقة الدفع';

  @override
  String get balancePayoutZaloPay => 'ZaloPay (VND)';

  @override
  String get balancePayoutZaloPayDetails => 'رسوم الخدمة 1.5% | الحد الأدنى للسحب 2 USD | يصل خلال يوم عمل واحد';

  @override
  String get balancePayoutBank => 'تحويل بنكي (VND)';

  @override
  String get balancePayoutBankDetails => 'رسوم الخدمة 2.9 USD | الحد الأدنى للسحب 8 USD | يصل خلال 3-5 أيام عمل';

  @override
  String get balancePayoutPayPal => 'PayPal (USD)';

  @override
  String get balancePayoutPayPalDetails => 'رسوم الخدمة 1.5% + 0.1 USD | الحد الأدنى للسحب 1 USD | يصل خلال يوم عمل واحد';

  @override
  String get balanceTransactionHistory => 'سجل المعاملات';

  @override
  String get balanceTransactionDetails => 'تفاصيل المعاملة';

  @override
  String get balanceTransactionNotFound => 'المعاملة غير موجودة';

  @override
  String get balanceNoTransactions => 'لا توجد معاملات بعد';

  @override
  String get balanceTabAll => 'الكل';

  @override
  String get balanceTabRevenue => 'الإيرادات';

  @override
  String get balanceTabExpense => 'المصروفات';

  @override
  String get balanceTabPayout => 'المدفوعات';

  @override
  String get balanceTabRefund => 'الاسترداد';

  @override
  String get balanceDetailStatus => 'الحالة';

  @override
  String get balanceStatusCompleted => 'مكتمل';

  @override
  String get balanceDetailType => 'النوع';

  @override
  String get balanceDetailActivityType => 'نوع النشاط';

  @override
  String get balanceDetailPaymentMethod => 'طريقة الدفع';

  @override
  String get balanceDetailCreated => 'تاريخ الإنشاء';

  @override
  String get balanceDetailUpdated => 'تاريخ التحديث';

  @override
  String get balanceDetailTransactionId => 'معرف المعاملة';

  @override
  String get balanceCopied => 'تم النسخ';

  @override
  String get balanceNeedHelp => 'هل تحتاج مساعدة؟ >';

  @override
  String get deleteChatTitle => 'حذف المحادثة';

  @override
  String get deleteChatMessage => 'هل أنت متأكد من رغبتك في حذف هذه المحادثة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteChatConfirm => 'حذف';

  @override
  String get deleteForEveryone => 'حذف للجميع';

  @override
  String get cameraFlip => 'قلب';

  @override
  String get cameraFlash => 'فلاش';

  @override
  String get cameraSpeed => 'السرعة';

  @override
  String get cameraBeauty => 'تجميل';

  @override
  String get cameraFilters => 'فلاتر';

  @override
  String get cameraTimer => 'مؤقت';

  @override
  String get cameraMusic => 'موسيقى';

  @override
  String get cameraEffects => 'تأثيرات';

  @override
  String get cameraUpload => 'رفع من المكتبة';

  @override
  String get cameraOriginalSound => 'الصوت الأصلي';

  @override
  String get cameraSeconds => 'ثانية';

  @override
  String get cameraRecording => 'جاري التسجيل';

  @override
  String get cameraMusicComingSoon => 'اختيار الموسيقى قريباً.';

  @override
  String get cameraPermissionDenied => 'يلزم السماح بالكاميرا والميكروفون للتسجيل.';

  @override
  String get cameraStarting => 'جاري تشغيل الكاميرا...';

  @override
  String get cameraOpenSettings => 'فتح الإعدادات';

  @override
  String get cameraUnavailable => 'لم يتم العثور على كاميرا على هذا الجهاز.';

  @override
  String cameraInitError(String error) {
    return 'تعذر تشغيل الكاميرا: $error';
  }

  @override
  String cameraCaptureError(String error) {
    return 'فشل الالتقاط: $error';
  }

  @override
  String get cameraCategoryTrending => 'رائج';

  @override
  String get cameraCategoryNew => 'جديد';

  @override
  String get cameraCategoryPortrait => 'بورتريه';

  @override
  String get cameraCategoryVibe => 'أجواء';

  @override
  String get cameraCategoryLandscape => 'مناظر';

  @override
  String get cameraFilterOriginal => 'أصلي';

  @override
  String get cameraFilterWarm => 'دافئ';

  @override
  String get cameraFilterCool => 'بارد';

  @override
  String get cameraFilterSunny => 'مشمس';

  @override
  String get cameraFilterPink => 'وردي';

  @override
  String get cameraFilterMoody => 'داكن';

  @override
  String get cameraFilterBw => 'أبيض وأسود';

  @override
  String get cameraFilterRetro => 'ريترو';

  @override
  String get cameraFilterFlashVintage => 'فلاش';

  @override
  String get cameraFilterBeautyGlow => 'توهج';

  @override
  String get cameraFilterNaturalBright => 'طبيعي';

  @override
  String get cameraFilterGoldenHour => 'ذهبي';

  @override
  String get openCameraStudio => 'فتح الكاميرا';

  @override
  String get cameraModePhoto => 'صورة';

  @override
  String get cameraModeVideo => 'فيديو';

  @override
  String get cameraModeLive => 'مباشر';

  @override
  String get cameraModeText => 'نص';

  @override
  String get cameraAddSound => 'إضافة صوت';

  @override
  String get cameraLayout => 'التخطيط';

  @override
  String get cameraAspectRatio => 'النسبة';

  @override
  String get cameraTabPost => 'منشور';

  @override
  String get cameraTabCreative => 'الإبداع';

  @override
  String get cameraDuration10m => '10 د';

  @override
  String get cameraZoom => 'تكبير';

  @override
  String get cameraGoLive => 'بدء البث';

  @override
  String get cameraLiveTitleHint => 'أضف عنواناً';

  @override
  String get cameraLiveComingSoon => 'البث المباشر قريباً.';

  @override
  String get cameraEffectCrown => 'تاج';

  @override
  String get cameraEffectBunny => 'أرنب';

  @override
  String get cameraEffectSunglasses => 'نظارات';

  @override
  String get cameraEffectDog => 'كلب';

  @override
  String get cameraEffectHearts => 'قلوب';

  @override
  String get cameraEffectSparkle => 'بريق';

  @override
  String get cameraEffectNeon => 'نيون';

  @override
  String get cameraEffectGlitch => 'تشويش';

  @override
  String get promotePostTitle => 'ترويج المنشور';

  @override
  String get promotionScreenTitle => 'الترويج';

  @override
  String get promotePostAction => 'ترويج';

  @override
  String get promoteGoalTitle => 'اختر هدفك';

  @override
  String get promoteAudienceTitle => 'حدد جمهورك';

  @override
  String get promoteAgeRange => 'الفئة العمرية';

  @override
  String get promoteGeoTarget => 'استهداف الأشخاص القريبين';

  @override
  String get promoteGeoTargetHint => 'استخدم موقعك الحالي للوصول المحلي';

  @override
  String get promoteGeoMapHint => 'اضغط على الخريطة لاختيار منطقة الاستهداف. الافتراضي هو موقعك.';

  @override
  String get promoteGeoUseMyLocation => 'استخدم موقعي';

  @override
  String get promoteGeoPlaceLoading => 'جاري تحديد المكان…';

  @override
  String get promoteGeoCity => 'المدينة';

  @override
  String get promoteGeoRegion => 'المنطقة';

  @override
  String get promoteGeoTown => 'المدينة';

  @override
  String get promoteGeoCountry => 'الدولة';

  @override
  String get promoteGeoContinent => 'القارة';

  @override
  String get promoteBudgetTitle => 'اختر الميزانية';

  @override
  String get promoteProcessing => 'جاري المعالجة...';

  @override
  String promotePostCta(String price) {
    return 'ترويج مقابل $price';
  }

  @override
  String promotePostSuccess(String balance) {
    return 'بدأ الترويج! رصيد المحفظة: $balance';
  }

  @override
  String get promotedBadge => 'مروّج';

  @override
  String get promoteLanguages => 'اللغات';

  @override
  String get promoteInterests => 'الاهتمامات';

  @override
  String promoteRadiusKm(int km) {
    return 'نطاق: $km كم';
  }

  @override
  String get promotePayFailedTitle => 'فشل الدفع';

  @override
  String get promoteRetryPay => 'إعادة محاولة الدفع';

  @override
  String get promoteAudienceCustomize => 'تخصيص الجمهور';

  @override
  String get promoteAudienceAllGenders => 'جميع الأجناس';

  @override
  String get promoteAudienceNearby => 'قريب';

  @override
  String get promoteAudienceGender => 'الجنس';

  @override
  String get promotePostNoCaption => 'بدون وصف';

  @override
  String get promotePopularBadge => 'شائع';

  @override
  String promoteImpressions(int count) {
    return '$count مشاهدة';
  }

  @override
  String get promoteStepGoalHeading => 'ما هو هدفك؟';

  @override
  String get promoteStepGoalSubtitle => 'اختر هدفاً لترويج هذا الفيديو.';

  @override
  String get promoteStepAudienceSubtitle => 'حدد كيف تريد الوصول إلى جمهورك.';

  @override
  String get promoteAudienceDefault => 'جمهور افتراضي';

  @override
  String get promoteAudienceDefaultHint => 'سنختار أفضل جمهور لك';

  @override
  String get promoteAudienceCreateOwn => 'إنشاء جمهورك الخاص';

  @override
  String get promoteStepLocationHeading => 'اختر منطقة الاستهداف';

  @override
  String get promoteStepLocationSubtitle => 'حدّد موقعك واضبط نطاق الوصول للأشخاص القريبين.';

  @override
  String get promoteStepBudgetSubtitle => 'اختر باقة الترويج لحملتك.';

  @override
  String promoteBudgetTotal(String price) {
    return '$price الإجمالي';
  }

  @override
  String promoteEstimatedViews(String min, String max) {
    return '$min – $max';
  }

  @override
  String get promoteEstimatedViewsLabel => 'مشاهدات الفيديو المتوقعة';

  @override
  String get promoteOverviewTitle => 'نظرة عامة';

  @override
  String get promoteOverviewGoal => 'الهدف';

  @override
  String get promoteOverviewAudience => 'الجمهور';

  @override
  String get promoteOverviewLocation => 'الموقع';

  @override
  String get promoteOverviewBudget => 'الميزانية';

  @override
  String get promoteLocationOff => 'استهداف الموقع متوقف';

  @override
  String get promoteLocationPending => 'لم يُحدَّد الموقع';

  @override
  String promoteAudienceNearbyWithRadius(int km) {
    return 'قريب · $km كم';
  }

  @override
  String get promoteLocationModeRegional => 'إقليمياً';

  @override
  String get promoteLocationModeRegionalHint => 'اختر الدولة والمنطقة والمدينة';

  @override
  String get promoteLocationModeMap => 'على الخريطة';

  @override
  String get promoteLocationModeMapHint => 'حدّد موقعك GPS واختر النطاق على الخريطة';

  @override
  String get promoteSelectCountry => 'الدولة';

  @override
  String get promoteSelectCountryHint => 'اختر الدولة';

  @override
  String get promoteSelectRegion => 'المنطقة';

  @override
  String get promoteSelectRegionHint => 'اختر المنطقة';

  @override
  String get promoteSelectTown => 'المدينة';

  @override
  String get promoteSelectTownHint => 'اختر المدينة';

  @override
  String promoteLocationRegionalSummary(String town, String region, String country) {
    return '$town · $region · $country';
  }

  @override
  String get promoteLocationCountryRequired => 'يرجى اختيار الدولة.';

  @override
  String get promoteLocationRegionRequired => 'يرجى اختيار المنطقة.';

  @override
  String get promoteLocationTownRequired => 'يرجى اختيار المدينة.';

  @override
  String get promoteLocationTownCoordinatesRequired => 'لا توجد إحداثيات لهذه المدينة. يرجى اختيار مدينة أخرى.';

  @override
  String get promoteLocationMapRequired => 'يرجى السماح بالموقع أو اختيار نقطة على الخريطة.';

  @override
  String get promoteOverviewSubtotal => 'المجموع الفرعي';

  @override
  String get promoteOverviewTotal => 'الإجمالي';

  @override
  String get promoteNext => 'التالي';

  @override
  String get promotePayStart => 'ادفع وابدأ الترويج';

  @override
  String get promoteQuickPack => 'باقة ترويج جاهزة';

  @override
  String promoteStepOf(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get promoteInsightsDashboardTitle => 'المنشورات المروّجة';

  @override
  String get promoteInsightsTitle => 'إحصائيات الترويج';

  @override
  String get promoteInsightsEmptyTitle => 'لا توجد منشورات مروّجة بعد';

  @override
  String get promoteInsightsEmptyHint => 'روّج فيديو من خلاصتك لمشاهدة الأداء هنا.';

  @override
  String get promoteInsightsPerformanceTitle => 'الأداء';

  @override
  String get promoteInsightsPromotedImpressions => 'مرات الظهور المروّجة';

  @override
  String get promoteInsightsFollowersGained => 'متابعون جدد';

  @override
  String get promoteInsightsSpend => 'إنفاق الترويج';

  @override
  String get promoteInsightsEngagementRate => 'معدل التفاعل';

  @override
  String get promoteInsightsShares => 'مشاركات';

  @override
  String get promoteInsightsCostPerImpression => 'التكلفة / ظهور';

  @override
  String get promoteInsightsCostPerView => 'التكلفة / مشاهدة';

  @override
  String get promoteInsightsUniqueViewers => 'مشاهدون فريدون';

  @override
  String get promoteInsightsChartTitle => 'مرات الظهور (آخر 7 أيام)';

  @override
  String get promoteInsightsNoChartData => 'لا توجد بيانات ظهور بعد';

  @override
  String get promoteInsightsCampaignProgress => 'تقدم الحملة';

  @override
  String get promoteInsightsImpressions => 'مرات الظهور';

  @override
  String get promoteInsightsBudget => 'الميزانية';

  @override
  String get promoteInsightsPauseCampaign => 'إيقاف الحملة';

  @override
  String get promoteInsightsResumeCampaign => 'استئناف الحملة';

  @override
  String get promoteInsightsCampaignHistory => 'سجل الحملات';

  @override
  String get promoteInsightsCampaignHistoryHint => 'اضغط على حملة لتصفية الإحصائيات';

  @override
  String get promoteInsightsAllCampaigns => 'جميع الحملات';

  @override
  String get promoteInsightsMultipleCampaigns => 'حملات متعددة';

  @override
  String get promoteInsightsViewInsights => 'عرض الإحصائيات';

  @override
  String get promoteInsightsObjectiveViews => 'مشاهدات الفيديو';

  @override
  String get promoteInsightsObjectiveFollowers => 'متابعون';

  @override
  String get promoteInsightsObjectiveEngagement => 'تفاعل';

  @override
  String get promoteInsightsObjectiveChallenges => 'تحديات';

  @override
  String get promoteInsightsObjectiveProfileVisits => 'زيارات الملف';

  @override
  String get promoteInsightsObjectiveSales => 'مبيعات';

  @override
  String get promoteInsightsStatusActive => 'نشطة';

  @override
  String get promoteInsightsStatusPaused => 'متوقفة';

  @override
  String get promoteInsightsStatusPendingPayment => 'بانتظار الدفع';

  @override
  String get promoteInsightsStatusCompleted => 'مكتملة';

  @override
  String get promoteInsightsStatusCancelled => 'ملغاة';

  @override
  String promoteInsightsCampaignProgressSummary(String percent, String spent) {
    return '$percent · $spent مُنفَق';
  }

  @override
  String get settingsPromotedPosts => 'المنشورات المروّجة';

  @override
  String get soundLabel => 'الصوت';

  @override
  String get soundNoneSelected => 'بدون';

  @override
  String get soundPickerTitle => 'إضافة صوت';

  @override
  String get soundSearchHint => 'ابحث عن أصوات';

  @override
  String get soundTabTrending => 'الرائج';

  @override
  String get soundTabBrowse => 'تصفح';

  @override
  String get soundTabMine => 'أصواتي';

  @override
  String get soundPickerEmpty => 'لا توجد أصوات';

  @override
  String get soundPickFromFiles => 'اختر من الملفات';

  @override
  String get soundUseThis => 'استخدام';

  @override
  String get soundUseThisSound => 'استخدم هذا الصوت';

  @override
  String get soundConfirmSelection => 'استخدام الصوت المحدد';

  @override
  String get soundClearSelection => 'مسح';

  @override
  String get soundDetailTitle => 'الصوت';

  @override
  String get soundVideosUsing => 'فيديوهات تستخدم هذا الصوت';

  @override
  String get soundNoVideosYet => 'لا توجد فيديوهات بعد';

  @override
  String soundOriginalLink(String name) {
    return 'الأصل: $name';
  }

  @override
  String soundUseCount(int count) {
    return '$count فيديو';
  }

  @override
  String soundUseCountThousands(String count) {
    return '$count ألف فيديو';
  }

  @override
  String soundUseCountMillions(String count) {
    return '$count مليون فيديو';
  }

  @override
  String get interestSelectionTitle => 'اختر اهتماماتك';

  @override
  String get interestSelectionSubtitle => 'اختر بعض الفئات حتى نُخصّص تجربتك.';

  @override
  String get interestSelectionSkip => 'تخطي';

  @override
  String get interestSelectionContinue => 'متابعة';

  @override
  String interestSelectionMinHint(int count) {
    return 'اختر $count اهتمامات على الأقل';
  }

  @override
  String interestSelectionCountHint(int selected, int min) {
    return '$selected/$min مهتم';
  }

  @override
  String get interestSelectionNotInterestedHint => 'اضغط مرة أخرى لتحديد غير مهتم (اختياري).';

  @override
  String get interestSelectionNotInterestedLegend => 'غير مهتم';

  @override
  String get interestSelectionInterestedLegend => 'مهتم';

  @override
  String get interestSelectionSave => 'حفظ';

  @override
  String get settingsInterests => 'الاهتمامات';

  @override
  String get retry => 'حاول مرة أخرى';
}
