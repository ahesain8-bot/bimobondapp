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
  String get loginScreenTitle => 'Log in to BimoBond';

  @override
  String get loginWithPhone => 'Use phone number';

  @override
  String get loginWithEmailUsername => 'Use email or username';

  @override
  String get loginEmailUsernameHint => 'Email or username';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

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
  String get notificationErrorTitle => 'Error';

  @override
  String get notificationSuccessTitle => 'Success';

  @override
  String get signUpTitle => 'Create Account';

  @override
  String get signUpScreenTitle => 'Sign up to BimoBond';

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
  String get phoneLoginUsageNote => 'Your phone number may be used to connect you to people you may know, improve ads, and more depending on your settings.';

  @override
  String get emailLoginUsageNote => 'Your email may be used to connect you to people you may know, improve ads, and more depending on your settings.';

  @override
  String get phoneHint => '+20 123 456 7890';

  @override
  String get termsAndConditionsPart1 => 'By continuing, you agree to our ';

  @override
  String get termsAndConditionsPart2 => 'Terms & Conditions';

  @override
  String get loginLegalNotePart1 => 'By continuing, you agree to our ';

  @override
  String get loginTermsOfService => 'Terms of Service';

  @override
  String get loginLegalNotePart2 => ' and confirm that you have read our ';

  @override
  String get loginPrivacyPolicy => 'Privacy Policy';

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
  String get passwordSignUpTooShort => 'Password must be at least 8 characters';

  @override
  String get passwordTooLong => 'Password must be at most 20 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordSubtitle => 'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordButton => 'Send Reset Link';

  @override
  String get forgotPasswordSuccess => 'Password reset email sent. Check your inbox and spam folder.';

  @override
  String get forgotPasswordFailed => 'Failed to send reset email. Please try again.';

  @override
  String get forgotPasswordUserNotFound => 'No account found with this email address.';

  @override
  String get loginFailed => 'Login failed. Please try again.';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get invalidOtpCode => 'Invalid OTP code';

  @override
  String get googleLoginFailed => 'Google login failed';

  @override
  String get googleLoginSheetTitle => 'Sign in with Google';

  @override
  String get googleLoginSheetSubtitle => 'Use your Google account to sign in quickly and securely.';

  @override
  String get googleLoginContinue => 'Continue with Google';

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
  String get signUpEmailStepTitle => 'What\'s your email?';

  @override
  String get signUpNameStepTitle => 'What\'s your name?';

  @override
  String get signUpPasswordStepTitle => 'Create a password';

  @override
  String get nextAction => 'Next';

  @override
  String get passwordStrengthLabel => 'Password strength';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthGood => 'Good';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get passwordStrengthHint => 'Your password must have 8 to 20 characters and include a mix of letters, numbers, and symbols.';

  @override
  String get passwordReqLength => '8 to 20 characters';

  @override
  String get passwordReqLetter => '1 letter';

  @override
  String get passwordReqNumber => '1 number';

  @override
  String get passwordReqSpecialChar => '1 special character (e.g. ! @ # \$ % & *)';

  @override
  String get passwordRequirementsNotMet => 'Password must meet all requirements';

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
  String get noRepostedPosts => 'No reposts yet';

  @override
  String get noOnlyMePosts => 'No only me posts yet';

  @override
  String get repostTitle => 'Repost';

  @override
  String get repostSubtitle => 'Share this post to your profile';

  @override
  String get repostAction => 'Repost';

  @override
  String get repostUndo => 'Undo repost';

  @override
  String get savePost => 'Save post';

  @override
  String get unsavePost => 'Remove from saved';

  @override
  String get repostQuoteHint => 'Add a comment (optional)';

  @override
  String get repostSuccess => 'Reposted';

  @override
  String get repostRemoved => 'Repost removed';

  @override
  String get cannotRepostOwnPost => 'You can\'t repost your own post';

  @override
  String repostCountLabel(int count) {
    return '$count reposts';
  }

  @override
  String repostedByUser(Object name) {
    return '$name reposted';
  }

  @override
  String postRepostersTitle(int count) {
    return 'Reposts · $count';
  }

  @override
  String get postRepostersEmpty => 'No reposts yet';

  @override
  String get profileRepostsTab => 'Reposts';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get noBio => 'No bio yet.';

  @override
  String get profileAvatarViewPhoto => 'Open profile photo';

  @override
  String get profileAvatarViewStory => 'View story';

  @override
  String get profileAvatarNoPhoto => 'No profile photo';

  @override
  String get story => 'Story';

  @override
  String get addStoryTitle => 'Add story';

  @override
  String get shareStoryButton => 'Share story';

  @override
  String get storyAddText => 'Text';

  @override
  String get storyTextDone => 'Done';

  @override
  String get storyCaptionHint => 'Add a caption (optional)';

  @override
  String get storyLoadMore => 'Load more';

  @override
  String get storyShowLess => 'Show less';

  @override
  String storyPickMediaError(String error) {
    return 'Could not pick media: $error';
  }

  @override
  String get storyExpired => 'Story expired';

  @override
  String storyTimeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String storyTimeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String storyTimeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get storyAddCommentHint => 'Add comment...';

  @override
  String get storySendMessageHint => 'Write a message...';

  @override
  String get storySendMessageTitle => 'Reply with a message';

  @override
  String get storyViewersTitle => 'Viewers';

  @override
  String get storyViewerUnknown => 'Viewer';

  @override
  String get storyMessagesTitle => 'Messages on this story';

  @override
  String get storyMessagesEmpty => 'No messages on this story yet';

  @override
  String get storyMessageSendFailed => 'Could not send message. Try again.';

  @override
  String storyMessageSent(String name) {
    return 'Message sent to $name';
  }

  @override
  String get storyPreviewLabel => 'Story';

  @override
  String get postPreviewLabel => 'Post';

  @override
  String get storyMessageOnStory => 'Replied to your story';

  @override
  String get storyMessageOnPost => 'Replied to your post';

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
  String get importFromLibrary => 'Import';

  @override
  String get uploadFromLibrary => 'Upload from library';

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
  String get auctionsSearchHint => 'Search auctions...';

  @override
  String get postsSearchTitle => 'Search posts';

  @override
  String get postsSearchHint => 'Search posts...';

  @override
  String get auctionsFiltersTitle => 'Filters';

  @override
  String get auctionsFiltersApply => 'Apply filters';

  @override
  String get auctionsFiltersReset => 'Reset';

  @override
  String get auctionsFiltersCategories => 'Categories';

  @override
  String get auctionsFiltersPriceRange => 'Price range (USD)';

  @override
  String get auctionsFiltersMinPrice => 'Min price';

  @override
  String get auctionsFiltersMaxPrice => 'Max price';

  @override
  String get auctionsFiltersLiveStatus => 'Auction status';

  @override
  String get auctionsFilterLive => 'Live';

  @override
  String get auctionsFilterEnded => 'Ended';

  @override
  String get endedAuctionsNow => 'Ended auctions';

  @override
  String get auctionsFiltersTimeRemaining => 'Time remaining';

  @override
  String get auctionsFiltersInvalidPriceRange => 'Min price cannot be greater than max price';

  @override
  String get auctionsTimeRemainingAny => 'Any time';

  @override
  String get auctionsTimeRemaining1Hour => 'Ending within 1 hour';

  @override
  String get auctionsTimeRemaining6Hours => 'Ending within 6 hours';

  @override
  String get auctionsTimeRemaining24Hours => 'Ending within 24 hours';

  @override
  String get auctionsTimeRemaining7Days => 'Ending within 7 days';

  @override
  String get auctionsTimeRemaining30Days => 'Ending within 30 days';

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
  String get auctionTapToEnter => 'Tap to enter';

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
  String get describePostHint => 'Describe your post… use @username and #tag in the text';

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
  String get imageFromLibrary => 'Upload images from library';

  @override
  String get videoFromLibrary => 'Import videos from library';

  @override
  String get tapToSelectMedia => 'Tap to upload from library';

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
  String get postLikesEmpty => 'No likes yet';

  @override
  String get postViewsEmpty => 'No views yet';

  @override
  String postViewWatchedDuration(int seconds) {
    return '${seconds}s watched';
  }

  @override
  String get viewsLabel => 'Views';

  @override
  String get commentsSortNewest => 'Newest';

  @override
  String get commentsSortOldest => 'Oldest';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get noCommentsYet => 'No comments yet. Be the first!';

  @override
  String get addCommentHint => 'Add comment… @username to mention';

  @override
  String get justNow => 'Just now';

  @override
  String inboxTimeMinutes(int count) {
    return '${count}m';
  }

  @override
  String inboxTimeHours(int count) {
    return '${count}h';
  }

  @override
  String inboxTimeDays(int count) {
    return '${count}d';
  }

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
  String get postOptionShare => 'Share';

  @override
  String get postOptionReport => 'Report';

  @override
  String get postOptionNotInterested => 'Not interested';

  @override
  String get postOptionDownload => 'Download';

  @override
  String get postOptionAddToStory => 'Add to story';

  @override
  String get postOptionShareAsGif => 'Share as GIF';

  @override
  String get postOptionCreateGroup => 'Create group';

  @override
  String get postLinkCopied => 'Link copied to clipboard';

  @override
  String get postReportTitle => 'Report post?';

  @override
  String get postReportMessage => 'Tell us if this post breaks our community guidelines.';

  @override
  String get postReportSubmitted => 'Thanks for reporting. We\'ll review this post.';

  @override
  String get postNotInterestedApplied => 'We\'ll show fewer posts like this';

  @override
  String get postDownloadStarted => 'Downloading…';

  @override
  String get postDownloadSaved => 'Saved to app downloads';

  @override
  String get postDownloadFailed => 'Could not download media';

  @override
  String get postShareAsGifUnavailable => 'GIF share is only available for videos';

  @override
  String get postShareSheetTitle => 'Share post';

  @override
  String get postShareSearchUsers => 'Search friends and users';

  @override
  String get postShareNoUsers => 'No users found';

  @override
  String get postShareToApps => 'Share to apps';

  @override
  String get postShareMessenger => 'Messenger';

  @override
  String get postShareFacebook => 'Facebook';

  @override
  String get postShareWhatsApp => 'WhatsApp';

  @override
  String get postShareTelegram => 'Telegram';

  @override
  String get postShareTwitter => 'X';

  @override
  String get postShareSms => 'SMS';

  @override
  String get postShareEmail => 'Email';

  @override
  String get postShareCopyLink => 'Copy link';

  @override
  String get postShareMore => 'More';

  @override
  String get postShareSendFailed => 'Could not send post';

  @override
  String postShareSentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String get postAddToStoryHint => 'Create your story — the post is ready to share';

  @override
  String get postCreateGroupHint => 'Pick contacts to start a group chat';

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
  String get hashtagsHint => 'Type #tag in your caption (e.g. #travel #food)';

  @override
  String get mentionsHint => 'Type @username in your caption (e.g. @jane_doe)';

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
  String get settingsChatWallpaper => 'Chat wallpaper';

  @override
  String get settingsSectionAdmin => 'Admin';

  @override
  String get settingsAdminActivity => 'User activity';

  @override
  String get adminActivityTitle => 'Activity';

  @override
  String get adminActivityEmpty => 'No activity yet';

  @override
  String get adminActivityJustNow => 'Just now';

  @override
  String get adminActivityNoDetails => 'No details';

  @override
  String adminActivityOnPost(String post) {
    return 'On post: $post';
  }

  @override
  String get adminActivityTypeCreatePost => 'Created a post';

  @override
  String get adminActivityTypeComment => 'Commented';

  @override
  String get adminActivityTypeLikePost => 'Liked a post';

  @override
  String get adminActivityTypeSendGift => 'Sent a gift';

  @override
  String get chatWallpaperTitle => 'Chat wallpaper';

  @override
  String get chatWallpaperSubtitle => 'Choose a background pattern for your chats. Colors follow your app theme.';

  @override
  String get chatWallpaperPlus => 'Plus';

  @override
  String get chatWallpaperSquares => 'Squares';

  @override
  String get chatWallpaperMaze => 'Maze';

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
  String get messagesActivityNotifications => 'Notifications';

  @override
  String get messagesRecentMessages => 'Recent Messages';

  @override
  String get messagesAllChats => 'All Chats';

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
  String get messagesInboxLastVoice => 'Voice message';

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
  String get messagesSuggestionFriendsOfFriends => 'Suggested for you';

  @override
  String get messagesSuggestionPopular => 'Popular creator';

  @override
  String messagesSuggestionMutualFriends(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mutual friends',
      one: '1 mutual friend',
    );
    return '$_temp0';
  }

  @override
  String get messagesSuggestionsEmpty => 'No suggestions right now';

  @override
  String get userCommentsTitle => 'My Comments';

  @override
  String get userCommentsEmpty => 'You haven\'t commented on any posts yet';

  @override
  String get userCommentReplyLabel => 'Reply';

  @override
  String get userCommentAction => 'commented';

  @override
  String userCommentOnPost(String author) {
    return 'On post by $author';
  }

  @override
  String get userLikesTitle => 'Likes';

  @override
  String get userLikesEmpty => 'No one has liked your posts yet';

  @override
  String get userLikeReceivedAction => 'liked your post';

  @override
  String get userMentionsTitle => 'My Mentions';

  @override
  String get userMentionsEmpty => 'No one has mentioned you yet';

  @override
  String get userMentionAction => 'mentioned you';

  @override
  String get userMentionInComment => 'in a comment';

  @override
  String get userFollowersTitle => 'Followers';

  @override
  String get userFollowerAction => 'followed you';

  @override
  String get chatMessageDeleted => 'This message was deleted';

  @override
  String get chatActionReply => 'Reply';

  @override
  String get chatActionReact => 'React';

  @override
  String get chatActionDelete => 'Delete';

  @override
  String get chatDeleteMessageTitle => 'Delete message?';

  @override
  String get chatDeleteMessageMessage => 'This message will be hidden for everyone in the chat.';

  @override
  String get chatActiveNow => 'Active now';

  @override
  String get chatAddComment => 'Write message';

  @override
  String get chatRecording => 'Recording...';

  @override
  String get chatSlideUpToCancel => 'Slide up to cancel';

  @override
  String get chatRecordingPermissionDenied => 'Allow microphone access to record voice messages.';

  @override
  String get chatRecordingPermissionTitle => 'Microphone access';

  @override
  String get chatRecordingPermissionSettingsMessage => 'Voice messages need the microphone. Open Settings, tap Permissions, and allow Microphone for Bimo Bond.';

  @override
  String get chatRecordingOpenSettings => 'Open Settings';

  @override
  String get chatRecordingAllowMicrophone => 'Allow';

  @override
  String get chatRecordingPluginUnavailable => 'Voice recording is not ready. Stop the app completely, then run it again (not hot reload).';

  @override
  String get chatVoiceTooShort => 'Hold longer to record a voice message.';

  @override
  String get chatVoicePlaybackFailed => 'Could not play this voice message.';

  @override
  String get chatAttachmentSendFailed => 'Could not send attachment. Please try again.';

  @override
  String get chatLocationPermissionDenied => 'Location permission is required to share your position.';

  @override
  String get chatContactsPermissionDenied => 'Contacts permission is required to share a contact.';

  @override
  String get chatFeatureComingSoon => 'Coming soon.';

  @override
  String get chatMessageLocation => 'Location';

  @override
  String get messagesInboxLastLocation => 'Location';

  @override
  String get messagesInboxLastFile => 'File';

  @override
  String get messagesInboxLastContact => 'Contact';

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
  String get chatMoreGallery => 'Import';

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

  @override
  String get hashtagFeedSubtitle => 'Posts with this hashtag';

  @override
  String get noHashtagPosts => 'No posts for this hashtag yet';

  @override
  String get trendingHashtags => 'Trending hashtags';

  @override
  String get searchHashtagsHint => 'Search hashtags';

  @override
  String get noHashtagsFound => 'No hashtags found';

  @override
  String hashtagPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
      zero: 'No posts',
    );
    return '$_temp0';
  }

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsEmptySubtitle => 'When someone interacts with you, you\'ll see it here.';

  @override
  String get notificationsEmptyUnread => 'You\'re all caught up — no unread notifications.';

  @override
  String get notificationsEmptyRead => 'No read notifications yet.';

  @override
  String notificationsFilterUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String get notificationsRetry => 'Try again';

  @override
  String get notificationsOk => 'OK';

  @override
  String get notificationsLoadError => 'Couldn\'t load notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsClearRead => 'Clear read';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterUnread => 'Unread';

  @override
  String get notificationsFilterRead => 'Read';

  @override
  String get notificationsFilterViewAll => 'View all';

  @override
  String get notificationsFilterActivity => 'Activity';

  @override
  String get notificationsFilterAuctions => 'Auctions';

  @override
  String get notificationsFilterInvites => 'Invites';

  @override
  String get notificationsAccept => 'Accept';

  @override
  String get notificationsDecline => 'Decline';

  @override
  String get notificationsEmptyActivity => 'No activity notifications yet.';

  @override
  String get notificationsEmptyAuctions => 'No auction notifications yet.';

  @override
  String get notificationsEmptyInvites => 'No invite notifications yet.';

  @override
  String get notificationContextPost => 'Post';

  @override
  String get notificationMediaVideo => 'Video';

  @override
  String get notificationMediaImage => 'Image';

  @override
  String get notificationActionFollowedYou => 'followed you';

  @override
  String get notificationActionFollowRequest => 'requested to follow you';

  @override
  String get notificationActionFollowAccepted => 'accepted your follow request';

  @override
  String get notificationActionPostLike => 'liked your post';

  @override
  String get notificationActionPostComment => 'commented on your post';

  @override
  String get notificationActionCommentReply => 'replied to your comment';

  @override
  String get notificationActionCommentLike => 'liked your comment';

  @override
  String get notificationActionMention => 'mentioned you';

  @override
  String get notificationActionRepost => 'reposted your post';

  @override
  String get notificationActionGift => 'sent you a gift';

  @override
  String get notificationActionAuctionUpdate => 'updated an auction you follow';

  @override
  String get notificationActionAuctionWon => 'you won an auction';

  @override
  String get notificationSomeone => 'Someone';

  @override
  String get notificationTitleDefault => 'Notification';

  @override
  String get notificationTitleNewFollower => 'New follower';

  @override
  String get notificationTitleFollowRequest => 'Follow request';

  @override
  String get notificationTitleFollowAccepted => 'Follow request accepted';

  @override
  String get notificationTitlePostLike => 'New like';

  @override
  String get notificationTitlePostComment => 'New comment';

  @override
  String get notificationTitleCommentReply => 'New reply';

  @override
  String get notificationTitleCommentLike => 'Comment liked';

  @override
  String get notificationTitleMention => 'Mention';

  @override
  String get notificationTitleRepost => 'Repost';

  @override
  String get notificationTitleGift => 'Gift received';

  @override
  String get notificationTitleAuctionUpdate => 'Auction update';

  @override
  String get notificationTitleAuctionWon => 'Auction won';

  @override
  String get notificationBodyDefault => 'You have a new notification';

  @override
  String notificationBodyNewFollower(String name) {
    return '$name started following you';
  }

  @override
  String notificationBodyFollowRequest(String name) {
    return '$name requested to follow you';
  }

  @override
  String notificationBodyFollowAccepted(String name) {
    return '$name accepted your follow request';
  }

  @override
  String notificationBodyPostLike(String name) {
    return '$name liked your post';
  }

  @override
  String notificationBodyPostComment(String name) {
    return '$name commented on your post';
  }

  @override
  String notificationBodyCommentReply(String name) {
    return '$name replied to your comment';
  }

  @override
  String notificationBodyCommentLike(String name) {
    return '$name liked your comment';
  }

  @override
  String notificationBodyMention(String name) {
    return '$name mentioned you';
  }

  @override
  String notificationBodyRepost(String name) {
    return '$name reposted your post';
  }

  @override
  String notificationBodyGift(String name) {
    return '$name sent you a gift';
  }

  @override
  String get notificationBodyAuctionUpdate => 'An auction you follow was updated';

  @override
  String get notificationBodyAuctionWon => 'You won an auction';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletBalanceLabel => 'Coins Balance';

  @override
  String get walletChoosePackage => 'Choose a Package';

  @override
  String get walletCustomAmountTitle => 'Custom amount';

  @override
  String get walletCustomCoinsLabel => 'How many coins?';

  @override
  String get walletCustomCoinsHint => 'e.g. 500';

  @override
  String get walletCustomCoinsReceive => 'You receive';

  @override
  String walletCustomCoinsValue(String coins) {
    return '$coins coins';
  }

  @override
  String get walletCustomYouPay => 'You pay';

  @override
  String get walletPackageQuotes => 'Package quotes';

  @override
  String get walletPackageQuotePrice => 'Package price';

  @override
  String get walletPricingPreviewCost => 'Total cost';

  @override
  String get walletPricingPreviewLoading => 'Calculating...';

  @override
  String get walletCustomAmountInvalid => 'Enter a valid coin amount.';

  @override
  String walletPurchaseSuccess(int amount) {
    return 'Successfully purchased $amount coins!';
  }

  @override
  String get walletTopUpButton => 'Top Up';

  @override
  String get walletProcessing => 'Processing payment...';

  @override
  String get walletCardNumber => 'Card Number';

  @override
  String get walletExpiry => 'Expiry Date (MM/YY)';

  @override
  String get walletCvv => 'CVV';

  @override
  String get walletCardHolder => 'Cardholder Name';

  @override
  String walletPayButton(String price) {
    return 'Pay $price';
  }

  @override
  String get coinsHubTitle => 'Coins';

  @override
  String get coinsAvailableBalance => 'Available balance';

  @override
  String coinsWalletAccountName(String name) {
    return '$name\'s Account';
  }

  @override
  String get coinsBalanceRefresh => 'Refresh balance';

  @override
  String get coinsBalanceFooterHint => 'UPDATED ON OPEN';

  @override
  String coinsBalanceFooter(String date, String hint) {
    return '$date | $hint';
  }

  @override
  String get coinsTabBuy => 'Buy';

  @override
  String get coinsTabMarket => 'Market';

  @override
  String get coinsTabVault => 'Vault';

  @override
  String get coinsUnit => 'coins';

  @override
  String get coinsHistoryTitle => 'Recent activity';

  @override
  String get coinsMarketSuccess => 'Gift added to your vault!';

  @override
  String get coinsVaultEmpty => 'No gifts in your vault yet. Visit the market to buy gifts with coins.';

  @override
  String get coinsVaultOwned => 'In vault';

  @override
  String get coinsInsufficientBalance => 'Not enough coins. Buy more in the Buy tab.';

  @override
  String get walletAccountingPurchase => 'Bought coins';

  @override
  String get walletAccountingGiftPurchase => 'Bought gift';

  @override
  String get walletAccountingGiftReceived => 'Received gift';

  @override
  String get walletAccountingPromotion => 'Post promotion';

  @override
  String get walletAccountingAdmin => 'Balance adjustment';

  @override
  String get balanceTitle => 'Balance';

  @override
  String get balanceDefaultUserName => 'User';

  @override
  String balanceUserTitle(String name) {
    return '$name\'s balance';
  }

  @override
  String get balanceEstimatedBalance => 'Estimated balance';

  @override
  String get balanceView => 'View';

  @override
  String get balanceGet => 'Get';

  @override
  String get balanceScheduledPayouts => 'Scheduled payouts';

  @override
  String get balanceViewFullSchedule => 'View full schedule >';

  @override
  String get balanceSetupPaymentsBanner => 'To receive payouts from Creator Rewards Program, set up payments.';

  @override
  String get balanceSetup => 'Set up';

  @override
  String get balanceSetupRequired => 'Setup required';

  @override
  String get balancePastPayouts => 'Past payouts >';

  @override
  String get balanceTransactions => 'Transactions';

  @override
  String balanceTransactionPreview(String title, String amount) {
    return '$title: $amount >';
  }

  @override
  String get balanceFirstCoinOfferTitle => 'First Coin purchase offer';

  @override
  String get balanceFirstCoinOfferSubtitle => 'Get bonus Coins and a 99% off animated Gift from your first purchase';

  @override
  String get balanceGetNow => 'Get now →';

  @override
  String get balanceMonetization => 'Monetization';

  @override
  String get balanceViewMore => 'View more >';

  @override
  String get balanceMonetizationLive => 'LIVE';

  @override
  String get balanceMonetizationActivities => 'Activities';

  @override
  String get balanceServices => 'Services';

  @override
  String get balancePaymentMethods => 'Payment methods';

  @override
  String get balanceRequired => 'Required';

  @override
  String get balanceTaxInformation => 'Tax information';

  @override
  String get balanceIdentityVerification => 'Identity verification';

  @override
  String get balanceMonetizationCenter => 'Monetization Center';

  @override
  String get balanceExplore => 'Explore >';

  @override
  String get balanceProgramCreatorRewards => 'Creator Rewards Program';

  @override
  String get balanceProgramTiktokGo => 'TikTok GO rewards';

  @override
  String get balanceProgramSeries => 'Series';

  @override
  String get balanceSetupPaymentsTitle => 'Set up payments';

  @override
  String get balanceSetupPaymentsMessage => 'Ensure your information is accurate to receive payouts on time. You can change this at any time.';

  @override
  String get balancePayoutMethodTitle => 'Payout method';

  @override
  String get balancePayoutMethodSubtitle => 'Select where to receive payouts.';

  @override
  String get balanceTaxInfoTitle => 'Tax information';

  @override
  String get balanceTaxInfoSubtitle => 'Required for compliance purposes.';

  @override
  String get balanceIdentityTitle => 'Identity verification';

  @override
  String get balanceIdentitySubtitle => 'Get your ID ready.';

  @override
  String get balanceAddPayoutMethod => 'Add payout method';

  @override
  String get balanceCountryRegion => 'Country / region';

  @override
  String get balanceCountryRegionNote => 'You can only register for one country or region. Make sure your selection is correct.';

  @override
  String get balanceChoosePayoutMethod => 'Choose payout method';

  @override
  String get balancePayoutZaloPay => 'ZaloPay (VND)';

  @override
  String get balancePayoutZaloPayDetails => 'Service fee 1.5% | Min. withdrawal 2 USD | Arrives in 1 business day';

  @override
  String get balancePayoutBank => 'Bank transfer (VND)';

  @override
  String get balancePayoutBankDetails => 'Service fee 2.9 USD | Min. withdrawal 8 USD | Arrives in 3-5 business days';

  @override
  String get balancePayoutPayPal => 'PayPal (USD)';

  @override
  String get balancePayoutPayPalDetails => 'Service fee 1.5% + 0.1 USD | Min. withdrawal 1 USD | Arrives in 1 business day';

  @override
  String get balanceTransactionHistory => 'Transaction history';

  @override
  String get balanceTransactionDetails => 'Transaction details';

  @override
  String get balanceTransactionNotFound => 'Transaction not found';

  @override
  String get balanceNoTransactions => 'No transactions yet';

  @override
  String get balanceTabAll => 'All';

  @override
  String get balanceTabRevenue => 'Revenue';

  @override
  String get balanceTabExpense => 'Expense';

  @override
  String get balanceTabPayout => 'Payout';

  @override
  String get balanceTabRefund => 'Refund';

  @override
  String get balanceDetailStatus => 'Status';

  @override
  String get balanceStatusCompleted => 'Completed';

  @override
  String get balanceDetailType => 'Type';

  @override
  String get balanceDetailActivityType => 'Activity type';

  @override
  String get balanceDetailPaymentMethod => 'Payment method';

  @override
  String get balanceDetailCreated => 'Created';

  @override
  String get balanceDetailUpdated => 'Updated';

  @override
  String get balanceDetailTransactionId => 'Transaction ID';

  @override
  String get balanceCopied => 'Copied to clipboard';

  @override
  String get balanceNeedHelp => 'Need help? >';

  @override
  String get deleteChatTitle => 'Delete chat';

  @override
  String get deleteChatMessage => 'Are you sure you want to delete this conversation? This action cannot be undone.';

  @override
  String get deleteChatConfirm => 'Delete';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get cameraFlip => 'Flip';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraSpeed => 'Speed';

  @override
  String get cameraBeauty => 'Beauty';

  @override
  String get cameraFilters => 'Filters';

  @override
  String get cameraTimer => 'Timer';

  @override
  String get cameraMusic => 'Music';

  @override
  String get cameraEffects => 'Effects';

  @override
  String get cameraUpload => 'Upload from library';

  @override
  String get cameraOriginalSound => 'Original Sound';

  @override
  String get cameraSeconds => 'seconds';

  @override
  String get cameraRecording => 'Recording';

  @override
  String get cameraMusicComingSoon => 'Music selection is coming soon.';

  @override
  String get cameraPermissionDenied => 'Camera and microphone permissions are required to record.';

  @override
  String get cameraStarting => 'Starting camera...';

  @override
  String get cameraOpenSettings => 'Open settings';

  @override
  String get cameraUnavailable => 'No camera was found on this device.';

  @override
  String cameraInitError(String error) {
    return 'Could not start the camera: $error';
  }

  @override
  String cameraCaptureError(String error) {
    return 'Capture failed: $error';
  }

  @override
  String get cameraCategoryTrending => 'Trending';

  @override
  String get cameraCategoryNew => 'New';

  @override
  String get cameraCategoryPortrait => 'Portrait';

  @override
  String get cameraCategoryVibe => 'Vibe';

  @override
  String get cameraCategoryLandscape => 'Landscape';

  @override
  String get cameraFilterOriginal => 'Original';

  @override
  String get cameraFilterWarm => 'Warm';

  @override
  String get cameraFilterCool => 'Cool';

  @override
  String get cameraFilterSunny => 'Sunny';

  @override
  String get cameraFilterPink => 'Pink';

  @override
  String get cameraFilterMoody => 'Moody';

  @override
  String get cameraFilterBw => 'B&W';

  @override
  String get cameraFilterRetro => 'Retro';

  @override
  String get cameraFilterFlashVintage => 'Flash';

  @override
  String get cameraFilterBeautyGlow => 'Glow';

  @override
  String get cameraFilterNaturalBright => 'Natural';

  @override
  String get cameraFilterGoldenHour => 'Golden';

  @override
  String get openCameraStudio => 'Open camera';

  @override
  String get cameraModePhoto => 'Photo';

  @override
  String get cameraModeVideo => 'Video';

  @override
  String get cameraModeLive => 'LIVE';

  @override
  String get cameraModeText => 'Text';

  @override
  String get cameraAddSound => 'Add sound';

  @override
  String get cameraLayout => 'Layout';

  @override
  String get cameraAspectRatio => 'Ratio';

  @override
  String get cameraTabPost => 'Post';

  @override
  String get cameraTabCreative => 'Creative';

  @override
  String get cameraDuration10m => '10m';

  @override
  String get cameraZoom => 'Zoom';

  @override
  String get cameraGoLive => 'Go LIVE';

  @override
  String get cameraLiveTitleHint => 'Add a title';

  @override
  String get cameraLiveComingSoon => 'Live streaming is coming soon.';

  @override
  String get cameraEffectCrown => 'Crown';

  @override
  String get cameraEffectBunny => 'Bunny';

  @override
  String get cameraEffectSunglasses => 'Shades';

  @override
  String get cameraEffectDog => 'Dog';

  @override
  String get cameraEffectHearts => 'Hearts';

  @override
  String get cameraEffectSparkle => 'Sparkle';

  @override
  String get cameraEffectNeon => 'Neon';

  @override
  String get cameraEffectGlitch => 'Glitch';

  @override
  String get promotePostTitle => 'Promote post';

  @override
  String get promotionScreenTitle => 'Promotion';

  @override
  String get promotePostAction => 'Promote';

  @override
  String get promoteGoalTitle => 'Choose your goal';

  @override
  String get promoteAudienceTitle => 'Define your audience';

  @override
  String get promoteAgeRange => 'Age range';

  @override
  String get promoteGeoTarget => 'Target people nearby';

  @override
  String get promoteGeoTargetHint => 'Use your current location for local reach';

  @override
  String get promoteGeoMapHint => 'Tap the map to choose your target area. Default is your location.';

  @override
  String get promoteGeoUseMyLocation => 'Use my location';

  @override
  String get promoteGeoPlaceLoading => 'Looking up place…';

  @override
  String get promoteGeoCity => 'City';

  @override
  String get promoteGeoRegion => 'Region';

  @override
  String get promoteGeoTown => 'Town';

  @override
  String get promoteGeoCountry => 'Country';

  @override
  String get promoteGeoContinent => 'Continent';

  @override
  String get promoteBudgetTitle => 'Select budget';

  @override
  String get promoteProcessing => 'Processing...';

  @override
  String promotePostCta(String price) {
    return 'Promote for $price';
  }

  @override
  String promotePostSuccess(String balance) {
    return 'Promotion started! Wallet balance: $balance';
  }

  @override
  String get promotedBadge => 'Promoted';

  @override
  String get promoteLanguages => 'Languages';

  @override
  String get promoteInterests => 'Interests';

  @override
  String promoteRadiusKm(int km) {
    return 'Radius: $km km';
  }

  @override
  String get promotePayFailedTitle => 'Payment failed';

  @override
  String get promoteRetryPay => 'Retry payment';

  @override
  String get promoteAudienceCustomize => 'Customize audience';

  @override
  String get promoteAudienceAllGenders => 'All genders';

  @override
  String get promoteAudienceNearby => 'Nearby';

  @override
  String get promoteAudienceGender => 'Gender';

  @override
  String get promotePostNoCaption => 'No caption';

  @override
  String get promotePopularBadge => 'POPULAR';

  @override
  String promoteImpressions(int count) {
    return '$count impressions';
  }

  @override
  String get promoteStepGoalHeading => 'What is your goal?';

  @override
  String get promoteStepGoalSubtitle => 'Choose a goal for promoting this video.';

  @override
  String get promoteStepAudienceSubtitle => 'Select how you want to reach your audience for your promotion.';

  @override
  String get promoteAudienceDefault => 'Default audience';

  @override
  String get promoteAudienceDefaultHint => 'We\'ll choose the best audience for you';

  @override
  String get promoteAudienceCreateOwn => 'Create your own';

  @override
  String get promoteStepLocationHeading => 'Choose your target area';

  @override
  String get promoteStepLocationSubtitle => 'Detect your location and set a radius to reach people nearby.';

  @override
  String get promoteStepBudgetSubtitle => 'Choose a promotion package for your campaign.';

  @override
  String promoteBudgetTotal(String price) {
    return '$price total';
  }

  @override
  String promoteEstimatedViews(String min, String max) {
    return '$min – $max';
  }

  @override
  String get promoteEstimatedViewsLabel => 'Estimated video views';

  @override
  String get promoteOverviewTitle => 'Overview';

  @override
  String get promoteOverviewGoal => 'Goal';

  @override
  String get promoteOverviewAudience => 'Audience';

  @override
  String get promoteOverviewLocation => 'Location';

  @override
  String get promoteOverviewBudget => 'Budget';

  @override
  String get promoteLocationOff => 'Location targeting off';

  @override
  String get promoteLocationPending => 'Location not set';

  @override
  String promoteAudienceNearbyWithRadius(int km) {
    return 'Nearby · $km km';
  }

  @override
  String get promoteLocationModeRegional => 'Regionally';

  @override
  String get promoteLocationModeRegionalHint => 'Choose country, region, and town';

  @override
  String get promoteLocationModeMap => 'On map';

  @override
  String get promoteLocationModeMapHint => 'Detect GPS and pick a radius on the map';

  @override
  String get promoteSelectCountry => 'Country';

  @override
  String get promoteSelectCountryHint => 'Select country';

  @override
  String get promoteSelectRegion => 'Region';

  @override
  String get promoteSelectRegionHint => 'Select region';

  @override
  String get promoteSelectTown => 'Town';

  @override
  String get promoteSelectTownHint => 'Select town';

  @override
  String promoteLocationRegionalSummary(String town, String region, String country) {
    return '$town · $region · $country';
  }

  @override
  String get promoteLocationCountryRequired => 'Please select a country.';

  @override
  String get promoteLocationRegionRequired => 'Please select a region.';

  @override
  String get promoteLocationTownRequired => 'Please select a town.';

  @override
  String get promoteLocationTownCoordinatesRequired => 'This town has no coordinates. Please choose another town.';

  @override
  String get promoteLocationMapRequired => 'Please allow location or pick a point on the map.';

  @override
  String get promoteOverviewSubtotal => 'Subtotal';

  @override
  String get promoteOverviewTotal => 'Total';

  @override
  String get promoteNext => 'Next';

  @override
  String get promotePayStart => 'Pay and start promotion';

  @override
  String get promoteQuickPack => 'Ready-to-use promotion pack';

  @override
  String promoteStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get promoteInsightsDashboardTitle => 'Promoted posts';

  @override
  String get promoteInsightsTitle => 'Promotion insights';

  @override
  String get promoteInsightsEmptyTitle => 'No promoted posts yet';

  @override
  String get promoteInsightsEmptyHint => 'Promote a video from your feed to see performance here.';

  @override
  String get promoteInsightsPerformanceTitle => 'Performance';

  @override
  String get promoteInsightsPromotedImpressions => 'Promoted impressions';

  @override
  String get promoteInsightsFollowersGained => 'Followers gained';

  @override
  String get promoteInsightsSpend => 'Promotion spend';

  @override
  String get promoteInsightsEngagementRate => 'Engagement rate';

  @override
  String get promoteInsightsShares => 'Shares';

  @override
  String get promoteInsightsCostPerImpression => 'Cost / impression';

  @override
  String get promoteInsightsCostPerView => 'Cost / view';

  @override
  String get promoteInsightsUniqueViewers => 'Unique viewers';

  @override
  String get promoteInsightsChartTitle => 'Impressions (last 7 days)';

  @override
  String get promoteInsightsNoChartData => 'No impression data yet';

  @override
  String get promoteInsightsCampaignProgress => 'Campaign progress';

  @override
  String get promoteInsightsImpressions => 'Impressions';

  @override
  String get promoteInsightsBudget => 'Budget';

  @override
  String get promoteInsightsPauseCampaign => 'Pause campaign';

  @override
  String get promoteInsightsResumeCampaign => 'Resume campaign';

  @override
  String get promoteInsightsCampaignHistory => 'Campaign history';

  @override
  String get promoteInsightsCampaignHistoryHint => 'Tap a campaign to filter stats';

  @override
  String get promoteInsightsAllCampaigns => 'All campaigns';

  @override
  String get promoteInsightsMultipleCampaigns => 'Multiple campaigns';

  @override
  String get promoteInsightsViewInsights => 'View insights';

  @override
  String get promoteInsightsObjectiveViews => 'Video views';

  @override
  String get promoteInsightsObjectiveFollowers => 'Followers';

  @override
  String get promoteInsightsObjectiveEngagement => 'Engagement';

  @override
  String get promoteInsightsObjectiveChallenges => 'Challenges';

  @override
  String get promoteInsightsObjectiveProfileVisits => 'Profile visits';

  @override
  String get promoteInsightsObjectiveSales => 'Sales';

  @override
  String get promoteInsightsStatusActive => 'Active';

  @override
  String get promoteInsightsStatusPaused => 'Paused';

  @override
  String get promoteInsightsStatusPendingPayment => 'Pending payment';

  @override
  String get promoteInsightsStatusCompleted => 'Completed';

  @override
  String get promoteInsightsStatusCancelled => 'Cancelled';

  @override
  String promoteInsightsCampaignProgressSummary(String percent, String spent) {
    return '$percent · $spent spent';
  }

  @override
  String get settingsPromotedPosts => 'Promoted posts';

  @override
  String get soundLabel => 'Sound';

  @override
  String get soundNoneSelected => 'None';

  @override
  String get soundPickerTitle => 'Add sound';

  @override
  String get soundSearchHint => 'Search sounds';

  @override
  String get soundTabTrending => 'Trending';

  @override
  String get soundTabBrowse => 'Browse';

  @override
  String get soundTabMine => 'My sounds';

  @override
  String get soundPickerEmpty => 'No sounds found';

  @override
  String get soundPickFromFiles => 'Pick from files';

  @override
  String get soundUseThis => 'Use';

  @override
  String get soundUseThisSound => 'Use this sound';

  @override
  String get soundConfirmSelection => 'Use selected sound';

  @override
  String get soundClearSelection => 'Clear';

  @override
  String get soundDetailTitle => 'Sound';

  @override
  String get soundVideosUsing => 'Videos using this sound';

  @override
  String get soundNoVideosYet => 'No videos yet';

  @override
  String soundOriginalLink(String name) {
    return 'Original: $name';
  }

  @override
  String soundUseCount(int count) {
    return '$count videos';
  }

  @override
  String soundUseCountThousands(String count) {
    return '${count}K videos';
  }

  @override
  String soundUseCountMillions(String count) {
    return '${count}M videos';
  }

  @override
  String get interestSelectionTitle => 'Choose your interests';

  @override
  String get interestSelectionSubtitle => 'Pick a few categories so we can personalize your experience.';

  @override
  String get interestSelectionSkip => 'Skip';

  @override
  String get interestSelectionContinue => 'Continue';

  @override
  String interestSelectionMinHint(int count) {
    return 'Select at least $count interests';
  }

  @override
  String get retry => 'Try again';
}
