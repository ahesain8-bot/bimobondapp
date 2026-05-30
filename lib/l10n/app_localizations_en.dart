// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bimobond App';

  @override
  String get helloWorld => 'Hello World!';

  @override
  String get loginTitle => 'Login';

  @override
  String get signInSubtitle => 'Sign in to continue';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get orDivider => 'OR';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get continueWith => 'Continue with';

  @override
  String get signUpTitle => 'Create Account';

  @override
  String get signUpSubtitle => 'Enter your details to create a new account';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get usernameLabel => 'Username';

  @override
  String get countryLabel => 'Country';

  @override
  String get nationalityLabel => 'Nationality';

  @override
  String get ageLabel => 'Age';

  @override
  String get addressLabel => 'Address';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get mobileNumberLabel => 'Mobile Number';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get createAccountBtn => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get phoneLoginTitle => 'Phone Login';

  @override
  String get phoneLoginSubtitle => 'Enter your phone number to receive a verification code';

  @override
  String get phoneHint => '+20 123 456 7890';

  @override
  String get termsAndConditionsPart1 => 'By continuing, you agree to our ';

  @override
  String get termsAndConditionsPart2 => 'Terms & Conditions';

  @override
  String get verifyPhoneTitle => 'Verify Phone';

  @override
  String get emailVerificationTitle => 'Verify Your Email';

  @override
  String emailVerificationSent(Object email) {
    return 'We sent a verification link to $email.';
  }

  @override
  String get emailVerificationContinue => 'Open your email and verify your account before continuing.';

  @override
  String get emailVerificationButton => 'I have verified my email';

  @override
  String get emailVerificationResendError => 'Unable to resend verification email. Please sign in again.';

  @override
  String get emailVerificationResendSuccess => 'Verification email resent. Check your inbox and spam folder.';

  @override
  String get emailVerificationResendFailed => 'Failed to resend verification email. Please try again.';

  @override
  String get emailVerificationStatusError => 'Unable to verify email status. Please sign in again.';

  @override
  String get emailVerificationNotVerified => 'Email not verified yet. Please open your email and verify your account.';

  @override
  String get emailVerificationCheckFailed => 'Could not check verification status. Please try again.';

  @override
  String get emailVerificationResendButton => 'Resend verification email';

  @override
  String get emailVerificationResending => 'Resending...';

  @override
  String get enterCodeSentTo => 'Enter the 6-digit code sent to';

  @override
  String get verificationCodeLabel => 'Verification Code';

  @override
  String get verifyAndLoginBtn => 'Verify & Login';

  @override
  String get didNotReceiveCode => 'Didn\'t receive a code? ';

  @override
  String get resendCode => 'Resend';

  @override
  String get back => 'Back';

  @override
  String get continueAction => 'Continue';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get loginFailed => 'Login failed. Please try again.';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get invalidOtpCode => 'Invalid OTP code';

  @override
  String get facebookLoginFailed => 'Facebook login failed';

  @override
  String get googleLoginFailed => 'Google login failed';

  @override
  String get updateProfileFailed => 'Failed to update profile';

  @override
  String get signupFailed => 'Signup failed. Please try again.';

  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully!';

  @override
  String get enterSixDigitCode => 'Please enter a 6-digit code';

  @override
  String get postAdded => 'Post added!';

  @override
  String get addPost => 'Add Post';

  @override
  String get postButton => 'Post';

  @override
  String get loginSuccess => 'Login successful!';

  @override
  String get signupSuccess => 'Signup successful! Please check your email to verify your account.';

  @override
  String get signUpWithEmailPassword => 'Sign up with Email and Password';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String get connectionsTitle => 'Connections';

  @override
  String get connectionsEmptyFollowers => 'No followers yet';

  @override
  String get connectionsEmptyFollowing => 'Not following anyone yet';

  @override
  String get connectionsEmptyFriends => 'No friends yet';

  @override
  String get connectionsFollowBack => 'Follow back';

  @override
  String get profileMessageButton => 'Message';

  @override
  String get likes => 'Likes';

  @override
  String get profilePostsTab => 'Posts';

  @override
  String get profilePostAuction => 'Auction';

  @override
  String get profileLikesTab => 'Likes';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get noLikedPosts => 'No liked posts';

  @override
  String get noSavedPosts => 'No saved posts';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get noBio => 'No bio yet.';

  @override
  String get story => 'Story';

  @override
  String get personalInfo => 'Personal Info';

  @override
  String get genderLabel => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get selectCountry => 'Select Country';

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get selectFromGallery => 'Select from gallery';

  @override
  String get removeCurrentPhoto => 'Remove current photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get enterUsername => 'Enter username';

  @override
  String get addBioToProfile => 'Add a bio to your profile';

  @override
  String get selectGender => 'Select gender';

  @override
  String get instagramProfileUrl => 'Instagram profile URL';

  @override
  String get youtubeChannelUrl => 'YouTube channel URL';

  @override
  String get egypt => 'Egypt';

  @override
  String get saudiArabia => 'Saudi Arabia';

  @override
  String get uae => 'UAE';

  @override
  String get usa => 'USA';

  @override
  String get uk => 'UK';

  @override
  String get kuwait => 'Kuwait';

  @override
  String get qatar => 'Qatar';

  @override
  String get bioLabel => 'Bio';

  @override
  String get instagramLabel => 'Instagram';

  @override
  String get youtubeLabel => 'YouTube';

  @override
  String fieldIsRequired(String field) {
    return '$field is required';
  }

  @override
  String get edit => 'Edit';

  @override
  String get feedFollowingTab => 'Following';

  @override
  String get feedForYou => 'For You';

  @override
  String get feedLive => 'Live';

  @override
  String get noPostsFound => 'No posts found';

  @override
  String get navHome => 'Home';

  @override
  String get navFriends => 'Friends';

  @override
  String get navAuctions => 'Auctions';

  @override
  String get auctionsSearchHint => 'Search by category or description...';

  @override
  String get popularCategories => 'Popular categories';

  @override
  String get viewAll => 'View all';

  @override
  String get auctionCategoryWatches => 'Luxury watches';

  @override
  String get auctionCategoryCars => 'Sports cars';

  @override
  String get auctionCategoryArt => 'Rare art';

  @override
  String get auctionCategoryJewelry => 'Jewelry';

  @override
  String get auctionCategoryAll => 'All';

  @override
  String get activeAuctionsNow => 'Active auctions now';

  @override
  String get liveBadge => 'Live';

  @override
  String get auctionActiveBadge => 'Active';

  @override
  String get auctionFinishedBadge => 'Finished';

  @override
  String get auctionTimeLeft => 'Time left';

  @override
  String get auctionStartsIn => 'Starts in';

  @override
  String auctionAddedBy(String username) {
    return 'Added by $username';
  }

  @override
  String auctionCountdownDayCount(int days) {
    return '$days day';
  }

  @override
  String get auctionTimerHour => 'h';

  @override
  String get auctionTimerMinute => 'm';

  @override
  String get auctionTimerSecond => 's';

  @override
  String auctionCountdownWithDays(int days, String time) {
    return '$days day $time';
  }

  @override
  String get auctionTargetReachedMessage => 'Target price reached. Auction ended.';

  @override
  String get auctionBiddingClosed => 'Bidding closed';

  @override
  String auctionTargetPrice(String amount, String currency) {
    return 'Target $amount $currency';
  }

  @override
  String get liveStreamsTitle => 'Live Streams';

  @override
  String get searchLiveStreamsHint => 'Search live streams...';

  @override
  String get liveFilterAll => 'All';

  @override
  String get liveFilterRealEstate => 'Real Estate';

  @override
  String get liveFilterAuctions => 'Auctions';

  @override
  String get liveFilterTrending => 'Trending';

  @override
  String get liveFilterInvestments => 'Investments';

  @override
  String get liveStreamTitle1 => 'Live Real Estate Q&A';

  @override
  String get liveStreamTitle2 => 'Luxury Auction Showcase';

  @override
  String get liveStreamTitle3 => 'Investment Tips Live';

  @override
  String liveHostName(int number) {
    return 'Host $number';
  }

  @override
  String liveViewersCount(int count) {
    return '$count';
  }

  @override
  String get joinLiveStream => 'Join live';

  @override
  String get liveDetailsTitle => 'Live stream';

  @override
  String get liveFollow => 'Follow';

  @override
  String get liveFollowing => 'Following';

  @override
  String liveViewersShort(String count) {
    return '$count viewers';
  }

  @override
  String get liveTopBid => 'Highest price';

  @override
  String get currencyUsd => 'USD';

  @override
  String get currencySar => 'SAR';

  @override
  String liveHighestBidAmount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get liveAddCommentOrBid => 'Add comment or bid...';

  @override
  String liveBidAmount(int amount) {
    return 'Bid $amount SAR';
  }

  @override
  String get liveCommentSample => 'This property looks amazing!';

  @override
  String get liveChatYou => 'You';

  @override
  String get liveSendGift => 'Send Gift';

  @override
  String get liveSelectGift => 'Select a Gift';

  @override
  String get liveSendToHost => 'Send to Host';

  @override
  String liveGiftSent(String name, String icon) {
    return 'Sent $name $icon';
  }

  @override
  String get liveGiftCommentGeneric => 'Sent a gift';

  @override
  String get liveGiftRose => 'Rose';

  @override
  String get liveGiftCoffee => 'Coffee';

  @override
  String get liveGiftDonut => 'Donut';

  @override
  String get liveGiftHeart => 'Heart';

  @override
  String get liveGiftParty => 'Party';

  @override
  String get liveGiftCrown => 'Crown';

  @override
  String get liveGiftRocket => 'Rocket';

  @override
  String get liveGiftDiamond => 'Diamond';

  @override
  String get liveVipBadge => 'VIP';

  @override
  String liveCoinsBalance(int count) {
    return '$count';
  }

  @override
  String get liveGiftPriceLabel => 'PRICE';

  @override
  String liveGiftPriceAmount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String liveGiftBuy(String price) {
    return 'Buy — $price';
  }

  @override
  String get liveGiftBuyMore => 'Buy more';

  @override
  String get liveGiftBuying => 'Buying…';

  @override
  String get liveGiftSending => 'Sending…';

  @override
  String liveGiftPurchaseSuccess(String name) {
    return 'Purchased $name';
  }

  @override
  String get liveGiftLoginRequired => 'Sign in to buy or send gifts';

  @override
  String get liveGiftNoRecipient => 'Open a live or auction post to send a gift';

  @override
  String get liveGiftCannotSendToSelf => 'You cannot send a gift to your own auction';

  @override
  String get liveGiftCatalogEmpty => 'No gifts available';

  @override
  String get liveGiftRetry => 'Retry';

  @override
  String liveGiftOwned(int count) {
    return '×$count';
  }

  @override
  String get auctionGiftsTitle => 'Auction gifts';

  @override
  String get auctionGiftsEmpty => 'No gifts sent on this auction yet';

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
  String get highestCurrentBid => 'Highest current bid';

  @override
  String get bidsLabel => 'Bids';

  @override
  String get auctionGiftsLabel => 'Gifts';

  @override
  String get bidNow => 'Bid now';

  @override
  String get navAdd => 'Add';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get describePostHint => 'Describe your post...';

  @override
  String get hashtagsLabel => 'Hashtags';

  @override
  String get mentionsLabel => 'Mentions';

  @override
  String get whoCanWatchLabel => 'Who can watch this post';

  @override
  String get allowCommentsLabel => 'Allow comments';

  @override
  String get allowDuetLabel => 'Allow Duet';

  @override
  String get allowStitchLabel => 'Allow Stitch';

  @override
  String get addLocationLabel => 'Add location';

  @override
  String get everyoneLabel => 'Everyone';

  @override
  String get friendsLabel => 'Friends';

  @override
  String get onlyMeLabel => 'Only me';

  @override
  String get videoLabel => 'Video';

  @override
  String get recordVideo => 'Record video';

  @override
  String get imagesLabel => 'Images';

  @override
  String get imageFromLibrary => 'Images from library';

  @override
  String get videoFromLibrary => 'Videos from library';

  @override
  String get tapToSelectMedia => 'Tap to select media';

  @override
  String get pleaseSelectMediaFirst => 'Please select media first';

  @override
  String get loginRequired => 'Login Required';

  @override
  String get loginRequiredMessage => 'Please login to like, comment or save posts';

  @override
  String get cancel => 'Cancel';

  @override
  String get login => 'Login';

  @override
  String get commentsTitle => 'Comments';

  @override
  String commentsCount(int count) {
    return '$count comments';
  }

  @override
  String get noCommentsYet => 'No comments yet. Be the first!';

  @override
  String get addCommentHint => 'Add comment...';

  @override
  String get justNow => 'Just now';

  @override
  String get replyAction => 'Reply';

  @override
  String replyingTo(String username) {
    return 'Replying to $username';
  }

  @override
  String viewReplies(int count) {
    return 'View $count replies';
  }

  @override
  String get hideReplies => 'Hide replies';

  @override
  String get loadMoreReplies => 'Load more replies';

  @override
  String get deleteCommentTitle => 'Delete comment?';

  @override
  String get deleteCommentMessage => 'This comment will be permanently removed.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get editPost => 'Edit post';

  @override
  String get deletePost => 'Delete post';

  @override
  String get deletePostTitle => 'Delete post?';

  @override
  String get deletePostMessage => 'This post will be permanently removed. Only you can delete your own posts.';

  @override
  String get postUpdatedSuccessfully => 'Post updated successfully';

  @override
  String get postDeletedSuccessfully => 'Post deleted successfully';

  @override
  String get saveButton => 'Save';

  @override
  String get categoryLabel => 'Category';

  @override
  String get selectCategoryHint => 'Choose a category';

  @override
  String get hashtagsHint => 'Separate with commas (e.g. travel, food)';

  @override
  String get mentionsHint => 'Separate with commas (e.g. john, jane)';

  @override
  String get mediaLabel => 'Media';

  @override
  String get settingsAndPrivacy => 'Settings and privacy';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsSectionContent => 'Content & display';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsHelpCenter => 'Help center';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsSelectLanguage => 'Select language';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLightMode => 'Light mode';

  @override
  String get settingsDarkModeOption => 'Dark mode';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'Arabic';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsLogoutTitle => 'Log out?';

  @override
  String get settingsLogoutMessage => 'You will need to sign in again to use your account.';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesInboxTitle => 'Inbox';

  @override
  String get messagesSwitchAccount => 'Switch Account';

  @override
  String get messagesNewConversation => 'New conversation';

  @override
  String get messagesSearchHint => 'Search messages or people';

  @override
  String get messagesYourStory => 'Your Story';

  @override
  String get messagesPeopleYouMayKnow => 'People you may know';

  @override
  String get messagesSeeAll => 'See all';

  @override
  String get messagesFollow => 'Follow';

  @override
  String get messagesFollowing => 'Following';

  @override
  String get messagesRecentMentions => 'Recent Mentions';

  @override
  String get messagesActivityFollowers => 'Followers';

  @override
  String get messagesActivityActivities => 'Activities';

  @override
  String get messagesActivityComments => 'Comments';

  @override
  String get messagesActivityMentions => 'Mentions';

  @override
  String get messagesRecentMessages => 'Recent Messages';

  @override
  String get messagesAll => 'All';

  @override
  String get messagesNoResults => 'No results found';

  @override
  String get messagesInboxNoMessagesYet => 'No messages yet';

  @override
  String get messagesInboxYouPrefix => 'You';

  @override
  String get messagesInboxLastPhoto => 'Photo';

  @override
  String get messagesInboxLastVideo => 'Video';

  @override
  String get messagesInboxLastGift => 'Gift';

  @override
  String get messagesInboxLastShare => 'Shared a post';

  @override
  String get messagesInboxMessageDeleted => 'Message deleted';

  @override
  String get messagesInboxGroupFallback => 'Group';

  @override
  String get messagesInboxUserFallback => 'User';

  @override
  String get messagesPreviewProperty => 'Hi, is the property still available?';

  @override
  String get messagesPreviewOffer => 'New offer has been sent';

  @override
  String get messagesPreviewThanks => 'Thank you for your interest';

  @override
  String get messagesPreviewCar => 'When can I check the car?';

  @override
  String get messagesMentionVilla => 'Great post describing the villa! @myself';

  @override
  String get messagesMentionCheck => 'Check this out @myself';

  @override
  String get messagesSuggestionBioDesigner => 'Interior Designer | Arch';

  @override
  String get messagesSuggestionBioJeddah => 'Top listings in Jeddah';

  @override
  String get messagesSuggestionBioLuxury => 'Worldwide luxury estates';

  @override
  String get chatActiveNow => 'Active now';

  @override
  String get chatAddComment => 'Add comment...';

  @override
  String get chatRecording => 'Recording...';

  @override
  String get chatSlideUpToCancel => 'Slide up to cancel';

  @override
  String get chatSeedGreeting => 'Hi! How can I help you?';

  @override
  String get chatSeedInterested => 'I am interested in the property shown';

  @override
  String get chatSeedFinalPrice => 'Can I know the final price?';

  @override
  String get chatSeedAutoReply => 'Thanks for reaching out! We will get back to you soon with more details.';

  @override
  String get chatUserBio => 'Interested in real estate and design.';

  @override
  String get chatMoreGallery => 'Gallery';

  @override
  String get chatMoreCamera => 'Camera';

  @override
  String get chatMoreVideo => 'Video';

  @override
  String get chatMoreLocation => 'Location';

  @override
  String get chatMoreContact => 'Contact';

  @override
  String get chatMoreFile => 'File';

  @override
  String get chatMoreGift => 'Gift';

  @override
  String get chatMorePoll => 'Poll';

  @override
  String get chatLastMessage1 => 'Can I know the final price?';

  @override
  String get chatLastMessage2 => 'Thanks for the update!';

  @override
  String get chatLastMessage3 => 'Is the property still available?';

  @override
  String get chatLastMessage4 => 'Sent a photo';

  @override
  String get chatLastMessage5 => 'See you tomorrow 👋';

  @override
  String get addPostAsAuction => 'List as auction';

  @override
  String get auctionItemName => 'Item name';

  @override
  String get auctionItemNameHint => 'e.g. Antique Pocket Watch';

  @override
  String get auctionStartingPrice => 'Starting price (USD)';

  @override
  String get auctionTargetPriceLabel => 'Target price (USD)';

  @override
  String get auctionStartDate => 'Auction starts';

  @override
  String get auctionEndDate => 'Auction ends';

  @override
  String get auctionEndBeforeStart => 'End date must be after start date';

  @override
  String get auctionTargetBelowStart => 'Target price must be greater than starting price';

  @override
  String get auctionInvalidPrice => 'Enter a valid price';
}
