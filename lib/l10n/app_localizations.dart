import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bimobond App'**
  String get appTitle;

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @continueWith.
  ///
  /// In en, this message translates to:
  /// **'Continue with'**
  String get continueWith;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your details to create a new account'**
  String get signUpSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @nationalityLabel.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get nationalityLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @mobileNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumberLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @createAccountBtn.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountBtn;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @phoneLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Login'**
  String get phoneLoginTitle;

  /// No description provided for @phoneLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to receive a verification code'**
  String get phoneLoginSubtitle;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+20 123 456 7890'**
  String get phoneHint;

  /// No description provided for @termsAndConditionsPart1.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get termsAndConditionsPart1;

  /// No description provided for @termsAndConditionsPart2.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditionsPart2;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhoneTitle;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get emailVerificationTitle;

  /// Displayed after sending verification email
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}.'**
  String emailVerificationSent(Object email);

  /// No description provided for @emailVerificationContinue.
  ///
  /// In en, this message translates to:
  /// **'Open your email and verify your account before continuing.'**
  String get emailVerificationContinue;

  /// No description provided for @emailVerificationButton.
  ///
  /// In en, this message translates to:
  /// **'I have verified my email'**
  String get emailVerificationButton;

  /// No description provided for @emailVerificationResendError.
  ///
  /// In en, this message translates to:
  /// **'Unable to resend verification email. Please sign in again.'**
  String get emailVerificationResendError;

  /// No description provided for @emailVerificationResendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent. Check your inbox and spam folder.'**
  String get emailVerificationResendSuccess;

  /// No description provided for @emailVerificationResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend verification email. Please try again.'**
  String get emailVerificationResendFailed;

  /// No description provided for @emailVerificationStatusError.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify email status. Please sign in again.'**
  String get emailVerificationStatusError;

  /// No description provided for @emailVerificationNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified yet. Please open your email and verify your account.'**
  String get emailVerificationNotVerified;

  /// No description provided for @emailVerificationCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check verification status. Please try again.'**
  String get emailVerificationCheckFailed;

  /// No description provided for @emailVerificationResendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get emailVerificationResendButton;

  /// No description provided for @emailVerificationResending.
  ///
  /// In en, this message translates to:
  /// **'Resending...'**
  String get emailVerificationResending;

  /// No description provided for @enterCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to'**
  String get enterCodeSentTo;

  /// No description provided for @verificationCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCodeLabel;

  /// No description provided for @verifyAndLoginBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify & Login'**
  String get verifyAndLoginBtn;

  /// No description provided for @didNotReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive a code? '**
  String get didNotReceiveCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resendCode;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// No description provided for @invalidOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP code'**
  String get invalidOtpCode;

  /// No description provided for @facebookLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Facebook login failed'**
  String get facebookLoginFailed;

  /// No description provided for @googleLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Google login failed'**
  String get googleLoginFailed;

  /// No description provided for @updateProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get updateProfileFailed;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed. Please try again.'**
  String get signupFailed;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a 6-digit code'**
  String get enterSixDigitCode;

  /// No description provided for @postAdded.
  ///
  /// In en, this message translates to:
  /// **'Post added!'**
  String get postAdded;

  /// No description provided for @addPost.
  ///
  /// In en, this message translates to:
  /// **'Add Post'**
  String get addPost;

  /// No description provided for @postButton.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postButton;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccess;

  /// No description provided for @signupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signup successful! Please check your email to verify your account.'**
  String get signupSuccess;

  /// No description provided for @signUpWithEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Email and Password'**
  String get signUpWithEmailPassword;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @connectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connectionsTitle;

  /// No description provided for @connectionsEmptyFollowers.
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get connectionsEmptyFollowers;

  /// No description provided for @connectionsEmptyFollowing.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get connectionsEmptyFollowing;

  /// No description provided for @connectionsEmptyFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get connectionsEmptyFriends;

  /// No description provided for @connectionsFollowBack.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get connectionsFollowBack;

  /// No description provided for @profileMessageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessageButton;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @profilePostsTab.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profilePostsTab;

  /// No description provided for @profilePostAuction.
  ///
  /// In en, this message translates to:
  /// **'Auction'**
  String get profilePostAuction;

  /// No description provided for @profileLikesTab.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get profileLikesTab;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @noLikedPosts.
  ///
  /// In en, this message translates to:
  /// **'No liked posts'**
  String get noLikedPosts;

  /// No description provided for @noSavedPosts.
  ///
  /// In en, this message translates to:
  /// **'No saved posts'**
  String get noSavedPosts;

  /// No description provided for @noRepostedPosts.
  ///
  /// In en, this message translates to:
  /// **'No reposts yet'**
  String get noRepostedPosts;

  /// No description provided for @noOnlyMePosts.
  ///
  /// In en, this message translates to:
  /// **'No only me posts yet'**
  String get noOnlyMePosts;

  /// No description provided for @repostTitle.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get repostTitle;

  /// No description provided for @repostSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share this post to your profile'**
  String get repostSubtitle;

  /// No description provided for @repostAction.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get repostAction;

  /// No description provided for @repostUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo repost'**
  String get repostUndo;

  /// No description provided for @savePost.
  ///
  /// In en, this message translates to:
  /// **'Save post'**
  String get savePost;

  /// No description provided for @unsavePost.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get unsavePost;

  /// No description provided for @repostQuoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get repostQuoteHint;

  /// No description provided for @repostSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reposted'**
  String get repostSuccess;

  /// No description provided for @repostRemoved.
  ///
  /// In en, this message translates to:
  /// **'Repost removed'**
  String get repostRemoved;

  /// No description provided for @cannotRepostOwnPost.
  ///
  /// In en, this message translates to:
  /// **'You can\'t repost your own post'**
  String get cannotRepostOwnPost;

  /// No description provided for @repostCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} reposts'**
  String repostCountLabel(int count);

  /// No description provided for @repostedByUser.
  ///
  /// In en, this message translates to:
  /// **'{name} reposted'**
  String repostedByUser(Object name);

  /// No description provided for @postRepostersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reposts · {count}'**
  String postRepostersTitle(int count);

  /// No description provided for @postRepostersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reposts yet'**
  String get postRepostersEmpty;

  /// No description provided for @profileRepostsTab.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get profileRepostsTab;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @noBio.
  ///
  /// In en, this message translates to:
  /// **'No bio yet.'**
  String get noBio;

  /// No description provided for @profileAvatarViewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Open profile photo'**
  String get profileAvatarViewPhoto;

  /// No description provided for @profileAvatarViewStory.
  ///
  /// In en, this message translates to:
  /// **'View story'**
  String get profileAvatarViewStory;

  /// No description provided for @profileAvatarNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No profile photo'**
  String get profileAvatarNoPhoto;

  /// No description provided for @story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// No description provided for @addStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add story'**
  String get addStoryTitle;

  /// No description provided for @shareStoryButton.
  ///
  /// In en, this message translates to:
  /// **'Share story'**
  String get shareStoryButton;

  /// No description provided for @storyCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption (optional)'**
  String get storyCaptionHint;

  /// No description provided for @storyPickMediaError.
  ///
  /// In en, this message translates to:
  /// **'Could not pick media: {error}'**
  String storyPickMediaError(String error);

  /// No description provided for @storyExpired.
  ///
  /// In en, this message translates to:
  /// **'Story expired'**
  String get storyExpired;

  /// No description provided for @storyTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String storyTimeMinutesAgo(int count);

  /// No description provided for @storyTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String storyTimeHoursAgo(int count);

  /// No description provided for @storyTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String storyTimeDaysAgo(int count);

  /// No description provided for @storyAddCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add comment...'**
  String get storyAddCommentHint;

  /// No description provided for @storySendMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get storySendMessageHint;

  /// No description provided for @storySendMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Reply with a message'**
  String get storySendMessageTitle;

  /// No description provided for @storyViewersTitle.
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get storyViewersTitle;

  /// No description provided for @storyViewerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get storyViewerUnknown;

  /// No description provided for @storyMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages on this story'**
  String get storyMessagesTitle;

  /// No description provided for @storyMessagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages on this story yet'**
  String get storyMessagesEmpty;

  /// No description provided for @storyMessageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send message. Try again.'**
  String get storyMessageSendFailed;

  /// No description provided for @storyMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent to {name}'**
  String storyMessageSent(String name);

  /// No description provided for @storyPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get storyPreviewLabel;

  /// No description provided for @postPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postPreviewLabel;

  /// No description provided for @storyMessageOnStory.
  ///
  /// In en, this message translates to:
  /// **'Replied to your story'**
  String get storyMessageOnStory;

  /// No description provided for @storyMessageOnPost.
  ///
  /// In en, this message translates to:
  /// **'Replied to your post'**
  String get storyMessageOnPost;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get personalInfo;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// No description provided for @changeProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get changeProfilePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @selectFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Select from gallery'**
  String get selectFromGallery;

  /// No description provided for @removeCurrentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove current photo'**
  String get removeCurrentPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get enterUsername;

  /// No description provided for @addBioToProfile.
  ///
  /// In en, this message translates to:
  /// **'Add a bio to your profile'**
  String get addBioToProfile;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get selectGender;

  /// No description provided for @instagramProfileUrl.
  ///
  /// In en, this message translates to:
  /// **'Instagram profile URL'**
  String get instagramProfileUrl;

  /// No description provided for @youtubeChannelUrl.
  ///
  /// In en, this message translates to:
  /// **'YouTube channel URL'**
  String get youtubeChannelUrl;

  /// No description provided for @egypt.
  ///
  /// In en, this message translates to:
  /// **'Egypt'**
  String get egypt;

  /// No description provided for @saudiArabia.
  ///
  /// In en, this message translates to:
  /// **'Saudi Arabia'**
  String get saudiArabia;

  /// No description provided for @uae.
  ///
  /// In en, this message translates to:
  /// **'UAE'**
  String get uae;

  /// No description provided for @usa.
  ///
  /// In en, this message translates to:
  /// **'USA'**
  String get usa;

  /// No description provided for @uk.
  ///
  /// In en, this message translates to:
  /// **'UK'**
  String get uk;

  /// No description provided for @kuwait.
  ///
  /// In en, this message translates to:
  /// **'Kuwait'**
  String get kuwait;

  /// No description provided for @qatar.
  ///
  /// In en, this message translates to:
  /// **'Qatar'**
  String get qatar;

  /// No description provided for @bioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioLabel;

  /// No description provided for @instagramLabel.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagramLabel;

  /// No description provided for @youtubeLabel.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youtubeLabel;

  /// No description provided for @fieldIsRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String fieldIsRequired(String field);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @feedFollowingTab.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get feedFollowingTab;

  /// No description provided for @feedForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get feedForYou;

  /// No description provided for @feedLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get feedLive;

  /// No description provided for @noPostsFound.
  ///
  /// In en, this message translates to:
  /// **'No posts found'**
  String get noPostsFound;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get navFriends;

  /// No description provided for @navAuctions.
  ///
  /// In en, this message translates to:
  /// **'Auctions'**
  String get navAuctions;

  /// No description provided for @auctionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search auctions...'**
  String get auctionsSearchHint;

  /// No description provided for @postsSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search posts'**
  String get postsSearchTitle;

  /// No description provided for @postsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search posts...'**
  String get postsSearchHint;

  /// No description provided for @auctionsFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get auctionsFiltersTitle;

  /// No description provided for @auctionsFiltersApply.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get auctionsFiltersApply;

  /// No description provided for @auctionsFiltersReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get auctionsFiltersReset;

  /// No description provided for @auctionsFiltersCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get auctionsFiltersCategories;

  /// No description provided for @auctionsFiltersPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range (USD)'**
  String get auctionsFiltersPriceRange;

  /// No description provided for @auctionsFiltersMinPrice.
  ///
  /// In en, this message translates to:
  /// **'Min price'**
  String get auctionsFiltersMinPrice;

  /// No description provided for @auctionsFiltersMaxPrice.
  ///
  /// In en, this message translates to:
  /// **'Max price'**
  String get auctionsFiltersMaxPrice;

  /// No description provided for @auctionsFiltersLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Auction status'**
  String get auctionsFiltersLiveStatus;

  /// No description provided for @auctionsFilterLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get auctionsFilterLive;

  /// No description provided for @auctionsFilterEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get auctionsFilterEnded;

  /// No description provided for @endedAuctionsNow.
  ///
  /// In en, this message translates to:
  /// **'Ended auctions'**
  String get endedAuctionsNow;

  /// No description provided for @auctionsFiltersTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get auctionsFiltersTimeRemaining;

  /// No description provided for @auctionsFiltersInvalidPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Min price cannot be greater than max price'**
  String get auctionsFiltersInvalidPriceRange;

  /// No description provided for @auctionsTimeRemainingAny.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get auctionsTimeRemainingAny;

  /// No description provided for @auctionsTimeRemaining1Hour.
  ///
  /// In en, this message translates to:
  /// **'Ending within 1 hour'**
  String get auctionsTimeRemaining1Hour;

  /// No description provided for @auctionsTimeRemaining6Hours.
  ///
  /// In en, this message translates to:
  /// **'Ending within 6 hours'**
  String get auctionsTimeRemaining6Hours;

  /// No description provided for @auctionsTimeRemaining24Hours.
  ///
  /// In en, this message translates to:
  /// **'Ending within 24 hours'**
  String get auctionsTimeRemaining24Hours;

  /// No description provided for @auctionsTimeRemaining7Days.
  ///
  /// In en, this message translates to:
  /// **'Ending within 7 days'**
  String get auctionsTimeRemaining7Days;

  /// No description provided for @auctionsTimeRemaining30Days.
  ///
  /// In en, this message translates to:
  /// **'Ending within 30 days'**
  String get auctionsTimeRemaining30Days;

  /// No description provided for @popularCategories.
  ///
  /// In en, this message translates to:
  /// **'Popular categories'**
  String get popularCategories;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @auctionCategoryWatches.
  ///
  /// In en, this message translates to:
  /// **'Luxury watches'**
  String get auctionCategoryWatches;

  /// No description provided for @auctionCategoryCars.
  ///
  /// In en, this message translates to:
  /// **'Sports cars'**
  String get auctionCategoryCars;

  /// No description provided for @auctionCategoryArt.
  ///
  /// In en, this message translates to:
  /// **'Rare art'**
  String get auctionCategoryArt;

  /// No description provided for @auctionCategoryJewelry.
  ///
  /// In en, this message translates to:
  /// **'Jewelry'**
  String get auctionCategoryJewelry;

  /// No description provided for @auctionCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get auctionCategoryAll;

  /// No description provided for @activeAuctionsNow.
  ///
  /// In en, this message translates to:
  /// **'Active auctions now'**
  String get activeAuctionsNow;

  /// No description provided for @liveBadge.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveBadge;

  /// No description provided for @auctionActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get auctionActiveBadge;

  /// No description provided for @auctionFinishedBadge.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get auctionFinishedBadge;

  /// No description provided for @auctionTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left'**
  String get auctionTimeLeft;

  /// No description provided for @auctionStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in'**
  String get auctionStartsIn;

  /// No description provided for @auctionAddedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by {username}'**
  String auctionAddedBy(String username);

  /// No description provided for @auctionCountdownDayCount.
  ///
  /// In en, this message translates to:
  /// **'{days} day'**
  String auctionCountdownDayCount(int days);

  /// No description provided for @auctionTimerHour.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get auctionTimerHour;

  /// No description provided for @auctionTimerMinute.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get auctionTimerMinute;

  /// No description provided for @auctionTimerSecond.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get auctionTimerSecond;

  /// No description provided for @auctionCountdownWithDays.
  ///
  /// In en, this message translates to:
  /// **'{days} day {time}'**
  String auctionCountdownWithDays(int days, String time);

  /// No description provided for @auctionTargetReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'Target price reached. Auction ended.'**
  String get auctionTargetReachedMessage;

  /// No description provided for @auctionBiddingClosed.
  ///
  /// In en, this message translates to:
  /// **'Bidding closed'**
  String get auctionBiddingClosed;

  /// No description provided for @auctionTargetPrice.
  ///
  /// In en, this message translates to:
  /// **'Target {amount} {currency}'**
  String auctionTargetPrice(String amount, String currency);

  /// No description provided for @liveStreamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Streams'**
  String get liveStreamsTitle;

  /// No description provided for @searchLiveStreamsHint.
  ///
  /// In en, this message translates to:
  /// **'Search live streams...'**
  String get searchLiveStreamsHint;

  /// No description provided for @liveFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get liveFilterAll;

  /// No description provided for @liveFilterRealEstate.
  ///
  /// In en, this message translates to:
  /// **'Real Estate'**
  String get liveFilterRealEstate;

  /// No description provided for @liveFilterAuctions.
  ///
  /// In en, this message translates to:
  /// **'Auctions'**
  String get liveFilterAuctions;

  /// No description provided for @liveFilterTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get liveFilterTrending;

  /// No description provided for @liveFilterInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get liveFilterInvestments;

  /// No description provided for @liveStreamTitle1.
  ///
  /// In en, this message translates to:
  /// **'Live Real Estate Q&A'**
  String get liveStreamTitle1;

  /// No description provided for @liveStreamTitle2.
  ///
  /// In en, this message translates to:
  /// **'Luxury Auction Showcase'**
  String get liveStreamTitle2;

  /// No description provided for @liveStreamTitle3.
  ///
  /// In en, this message translates to:
  /// **'Investment Tips Live'**
  String get liveStreamTitle3;

  /// No description provided for @liveHostName.
  ///
  /// In en, this message translates to:
  /// **'Host {number}'**
  String liveHostName(int number);

  /// No description provided for @liveViewersCount.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String liveViewersCount(int count);

  /// No description provided for @joinLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Join live'**
  String get joinLiveStream;

  /// No description provided for @liveDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live stream'**
  String get liveDetailsTitle;

  /// No description provided for @liveFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get liveFollow;

  /// No description provided for @liveFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get liveFollowing;

  /// No description provided for @liveViewersShort.
  ///
  /// In en, this message translates to:
  /// **'{count} viewers'**
  String liveViewersShort(String count);

  /// No description provided for @liveTopBid.
  ///
  /// In en, this message translates to:
  /// **'Highest price'**
  String get liveTopBid;

  /// No description provided for @currencyUsd.
  ///
  /// In en, this message translates to:
  /// **'USD'**
  String get currencyUsd;

  /// No description provided for @currencySar.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get currencySar;

  /// No description provided for @liveHighestBidAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String liveHighestBidAmount(String amount, String currency);

  /// No description provided for @liveAddCommentOrBid.
  ///
  /// In en, this message translates to:
  /// **'Add comment or bid...'**
  String get liveAddCommentOrBid;

  /// No description provided for @liveBidAmount.
  ///
  /// In en, this message translates to:
  /// **'Bid {amount} SAR'**
  String liveBidAmount(int amount);

  /// No description provided for @liveCommentSample.
  ///
  /// In en, this message translates to:
  /// **'This property looks amazing!'**
  String get liveCommentSample;

  /// No description provided for @liveChatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get liveChatYou;

  /// No description provided for @liveSendGift.
  ///
  /// In en, this message translates to:
  /// **'Send Gift'**
  String get liveSendGift;

  /// No description provided for @liveSelectGift.
  ///
  /// In en, this message translates to:
  /// **'Select a Gift'**
  String get liveSelectGift;

  /// No description provided for @liveSendToHost.
  ///
  /// In en, this message translates to:
  /// **'Send to Host'**
  String get liveSendToHost;

  /// No description provided for @liveGiftSent.
  ///
  /// In en, this message translates to:
  /// **'Sent {name} {icon}'**
  String liveGiftSent(String name, String icon);

  /// No description provided for @liveGiftCommentGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sent a gift'**
  String get liveGiftCommentGeneric;

  /// No description provided for @liveGiftRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get liveGiftRose;

  /// No description provided for @liveGiftCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get liveGiftCoffee;

  /// No description provided for @liveGiftDonut.
  ///
  /// In en, this message translates to:
  /// **'Donut'**
  String get liveGiftDonut;

  /// No description provided for @liveGiftHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get liveGiftHeart;

  /// No description provided for @liveGiftParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get liveGiftParty;

  /// No description provided for @liveGiftCrown.
  ///
  /// In en, this message translates to:
  /// **'Crown'**
  String get liveGiftCrown;

  /// No description provided for @liveGiftRocket.
  ///
  /// In en, this message translates to:
  /// **'Rocket'**
  String get liveGiftRocket;

  /// No description provided for @liveGiftDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get liveGiftDiamond;

  /// No description provided for @liveVipBadge.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get liveVipBadge;

  /// No description provided for @liveCoinsBalance.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String liveCoinsBalance(int count);

  /// No description provided for @liveGiftPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get liveGiftPriceLabel;

  /// No description provided for @liveGiftPriceAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String liveGiftPriceAmount(String amount, String currency);

  /// No description provided for @liveGiftBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy — {price}'**
  String liveGiftBuy(String price);

  /// No description provided for @liveGiftBuyMore.
  ///
  /// In en, this message translates to:
  /// **'Buy more'**
  String get liveGiftBuyMore;

  /// No description provided for @liveGiftBuying.
  ///
  /// In en, this message translates to:
  /// **'Buying…'**
  String get liveGiftBuying;

  /// No description provided for @liveGiftSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get liveGiftSending;

  /// No description provided for @liveGiftPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchased {name}'**
  String liveGiftPurchaseSuccess(String name);

  /// No description provided for @liveGiftLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to buy or send gifts'**
  String get liveGiftLoginRequired;

  /// No description provided for @liveGiftNoRecipient.
  ///
  /// In en, this message translates to:
  /// **'Open a live or auction post to send a gift'**
  String get liveGiftNoRecipient;

  /// No description provided for @liveGiftCannotSendToSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot send a gift to your own auction'**
  String get liveGiftCannotSendToSelf;

  /// No description provided for @liveGiftCatalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No gifts available'**
  String get liveGiftCatalogEmpty;

  /// No description provided for @liveGiftRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get liveGiftRetry;

  /// No description provided for @liveGiftOwned.
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String liveGiftOwned(int count);

  /// No description provided for @auctionGiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Auction gifts'**
  String get auctionGiftsTitle;

  /// No description provided for @auctionGiftsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No gifts sent on this auction yet'**
  String get auctionGiftsEmpty;

  /// No description provided for @auctionGiftsSummary.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} {currency}'**
  String auctionGiftsSummary(String current, String target, String currency);

  /// No description provided for @auctionGiftsContribution.
  ///
  /// In en, this message translates to:
  /// **'+{amount} {currency}'**
  String auctionGiftsContribution(String amount, String currency);

  /// No description provided for @liveQuickBid.
  ///
  /// In en, this message translates to:
  /// **'+{amount}'**
  String liveQuickBid(int amount);

  /// No description provided for @highestCurrentBid.
  ///
  /// In en, this message translates to:
  /// **'Highest current bid'**
  String get highestCurrentBid;

  /// No description provided for @bidsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bids'**
  String get bidsLabel;

  /// No description provided for @auctionGiftsLabel.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get auctionGiftsLabel;

  /// No description provided for @bidNow.
  ///
  /// In en, this message translates to:
  /// **'Bid now'**
  String get bidNow;

  /// No description provided for @navAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @describePostHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your post… use @username and #tag in the text'**
  String get describePostHint;

  /// No description provided for @hashtagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Hashtags'**
  String get hashtagsLabel;

  /// No description provided for @mentionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get mentionsLabel;

  /// No description provided for @whoCanWatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can watch this post'**
  String get whoCanWatchLabel;

  /// No description provided for @allowCommentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow comments'**
  String get allowCommentsLabel;

  /// No description provided for @allowDuetLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow Duet'**
  String get allowDuetLabel;

  /// No description provided for @allowStitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow Stitch'**
  String get allowStitchLabel;

  /// No description provided for @addLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocationLabel;

  /// No description provided for @everyoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyoneLabel;

  /// No description provided for @friendsLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsLabel;

  /// No description provided for @onlyMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Only me'**
  String get onlyMeLabel;

  /// No description provided for @videoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoLabel;

  /// No description provided for @recordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get recordVideo;

  /// No description provided for @imagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imagesLabel;

  /// No description provided for @imageFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Images from library'**
  String get imageFromLibrary;

  /// No description provided for @videoFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Videos from library'**
  String get videoFromLibrary;

  /// No description provided for @tapToSelectMedia.
  ///
  /// In en, this message translates to:
  /// **'Tap to select media'**
  String get tapToSelectMedia;

  /// No description provided for @pleaseSelectMediaFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select media first'**
  String get pleaseSelectMediaFirst;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please login to like, comment or save posts'**
  String get loginRequiredMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String commentsCount(int count);

  /// No description provided for @postLikesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get postLikesEmpty;

  /// No description provided for @postViewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No views yet'**
  String get postViewsEmpty;

  /// No description provided for @postViewWatchedDuration.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s watched'**
  String postViewWatchedDuration(int seconds);

  /// No description provided for @viewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get viewsLabel;

  /// No description provided for @commentsSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get commentsSortNewest;

  /// No description provided for @commentsSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get commentsSortOldest;

  /// No description provided for @commentsSortTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get commentsSortTop;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first!'**
  String get noCommentsYet;

  /// No description provided for @addCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add comment… @username to mention'**
  String get addCommentHint;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @inboxTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String inboxTimeMinutes(int count);

  /// No description provided for @inboxTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String inboxTimeHours(int count);

  /// No description provided for @inboxTimeDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String inboxTimeDays(int count);

  /// No description provided for @replyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyAction;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {username}'**
  String replyingTo(String username);

  /// No description provided for @viewReplies.
  ///
  /// In en, this message translates to:
  /// **'View {count} replies'**
  String viewReplies(int count);

  /// No description provided for @hideReplies.
  ///
  /// In en, this message translates to:
  /// **'Hide replies'**
  String get hideReplies;

  /// No description provided for @loadMoreReplies.
  ///
  /// In en, this message translates to:
  /// **'Load more replies'**
  String get loadMoreReplies;

  /// No description provided for @deleteCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get deleteCommentTitle;

  /// No description provided for @deleteCommentMessage.
  ///
  /// In en, this message translates to:
  /// **'This comment will be permanently removed.'**
  String get deleteCommentMessage;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get editPost;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePost;

  /// No description provided for @deletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get deletePostTitle;

  /// No description provided for @deletePostMessage.
  ///
  /// In en, this message translates to:
  /// **'This post will be permanently removed. Only you can delete your own posts.'**
  String get deletePostMessage;

  /// No description provided for @postUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Post updated successfully'**
  String get postUpdatedSuccessfully;

  /// No description provided for @postDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Post deleted successfully'**
  String get postDeletedSuccessfully;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @selectCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get selectCategoryHint;

  /// No description provided for @hashtagsHint.
  ///
  /// In en, this message translates to:
  /// **'Type #tag in your caption (e.g. #travel #food)'**
  String get hashtagsHint;

  /// No description provided for @mentionsHint.
  ///
  /// In en, this message translates to:
  /// **'Type @username in your caption (e.g. @jane_doe)'**
  String get mentionsHint;

  /// No description provided for @mediaLabel.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get mediaLabel;

  /// No description provided for @settingsAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Settings and privacy'**
  String get settingsAndPrivacy;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsSectionContent.
  ///
  /// In en, this message translates to:
  /// **'Content & display'**
  String get settingsSectionContent;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// No description provided for @settingsHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get settingsHelpCenter;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @settingsSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get settingsSelectLanguage;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get settingsLightMode;

  /// No description provided for @settingsDarkModeOption.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkModeOption;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsOn;

  /// No description provided for @settingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// No description provided for @settingsLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogoutTitle;

  /// No description provided for @settingsLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use your account.'**
  String get settingsLogoutMessage;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @settingsChatWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get settingsChatWallpaper;

  /// No description provided for @settingsSectionAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get settingsSectionAdmin;

  /// No description provided for @settingsAdminActivity.
  ///
  /// In en, this message translates to:
  /// **'User activity'**
  String get settingsAdminActivity;

  /// No description provided for @adminActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get adminActivityTitle;

  /// No description provided for @adminActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get adminActivityEmpty;

  /// No description provided for @adminActivityJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get adminActivityJustNow;

  /// No description provided for @adminActivityNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details'**
  String get adminActivityNoDetails;

  /// No description provided for @adminActivityOnPost.
  ///
  /// In en, this message translates to:
  /// **'On post: {post}'**
  String adminActivityOnPost(String post);

  /// No description provided for @adminActivityTypeCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Created a post'**
  String get adminActivityTypeCreatePost;

  /// No description provided for @adminActivityTypeComment.
  ///
  /// In en, this message translates to:
  /// **'Commented'**
  String get adminActivityTypeComment;

  /// No description provided for @adminActivityTypeLikePost.
  ///
  /// In en, this message translates to:
  /// **'Liked a post'**
  String get adminActivityTypeLikePost;

  /// No description provided for @adminActivityTypeSendGift.
  ///
  /// In en, this message translates to:
  /// **'Sent a gift'**
  String get adminActivityTypeSendGift;

  /// No description provided for @chatWallpaperTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get chatWallpaperTitle;

  /// No description provided for @chatWallpaperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a background pattern for your chats. Colors follow your app theme.'**
  String get chatWallpaperSubtitle;

  /// No description provided for @chatWallpaperPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get chatWallpaperPlus;

  /// No description provided for @chatWallpaperSquares.
  ///
  /// In en, this message translates to:
  /// **'Squares'**
  String get chatWallpaperSquares;

  /// No description provided for @chatWallpaperMaze.
  ///
  /// In en, this message translates to:
  /// **'Maze'**
  String get chatWallpaperMaze;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @messagesInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get messagesInboxTitle;

  /// No description provided for @messagesSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get messagesSwitchAccount;

  /// No description provided for @messagesNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get messagesNewConversation;

  /// No description provided for @messagesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages or people'**
  String get messagesSearchHint;

  /// No description provided for @messagesYourStory.
  ///
  /// In en, this message translates to:
  /// **'Your Story'**
  String get messagesYourStory;

  /// No description provided for @messagesPeopleYouMayKnow.
  ///
  /// In en, this message translates to:
  /// **'People you may know'**
  String get messagesPeopleYouMayKnow;

  /// No description provided for @messagesSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get messagesSeeAll;

  /// No description provided for @messagesFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get messagesFollow;

  /// No description provided for @messagesFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get messagesFollowing;

  /// No description provided for @messagesRecentMentions.
  ///
  /// In en, this message translates to:
  /// **'Recent Mentions'**
  String get messagesRecentMentions;

  /// No description provided for @messagesActivityFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get messagesActivityFollowers;

  /// No description provided for @messagesActivityActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get messagesActivityActivities;

  /// No description provided for @messagesActivityComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get messagesActivityComments;

  /// No description provided for @messagesActivityMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get messagesActivityMentions;

  /// No description provided for @messagesActivityNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get messagesActivityNotifications;

  /// No description provided for @messagesRecentMessages.
  ///
  /// In en, this message translates to:
  /// **'Recent Messages'**
  String get messagesRecentMessages;

  /// No description provided for @messagesAllChats.
  ///
  /// In en, this message translates to:
  /// **'All Chats'**
  String get messagesAllChats;

  /// No description provided for @messagesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get messagesAll;

  /// No description provided for @messagesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get messagesNoResults;

  /// No description provided for @messagesInboxNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get messagesInboxNoMessagesYet;

  /// No description provided for @messagesInboxYouPrefix.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get messagesInboxYouPrefix;

  /// No description provided for @messagesInboxLastPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get messagesInboxLastPhoto;

  /// No description provided for @messagesInboxLastVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get messagesInboxLastVideo;

  /// No description provided for @messagesInboxLastVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get messagesInboxLastVoice;

  /// No description provided for @messagesInboxLastGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get messagesInboxLastGift;

  /// No description provided for @messagesInboxLastShare.
  ///
  /// In en, this message translates to:
  /// **'Shared a post'**
  String get messagesInboxLastShare;

  /// No description provided for @messagesInboxMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get messagesInboxMessageDeleted;

  /// No description provided for @messagesInboxGroupFallback.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get messagesInboxGroupFallback;

  /// No description provided for @messagesInboxUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get messagesInboxUserFallback;

  /// No description provided for @messagesPreviewProperty.
  ///
  /// In en, this message translates to:
  /// **'Hi, is the property still available?'**
  String get messagesPreviewProperty;

  /// No description provided for @messagesPreviewOffer.
  ///
  /// In en, this message translates to:
  /// **'New offer has been sent'**
  String get messagesPreviewOffer;

  /// No description provided for @messagesPreviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your interest'**
  String get messagesPreviewThanks;

  /// No description provided for @messagesPreviewCar.
  ///
  /// In en, this message translates to:
  /// **'When can I check the car?'**
  String get messagesPreviewCar;

  /// No description provided for @messagesMentionVilla.
  ///
  /// In en, this message translates to:
  /// **'Great post describing the villa! @myself'**
  String get messagesMentionVilla;

  /// No description provided for @messagesMentionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check this out @myself'**
  String get messagesMentionCheck;

  /// No description provided for @messagesSuggestionBioDesigner.
  ///
  /// In en, this message translates to:
  /// **'Interior Designer | Arch'**
  String get messagesSuggestionBioDesigner;

  /// No description provided for @messagesSuggestionBioJeddah.
  ///
  /// In en, this message translates to:
  /// **'Top listings in Jeddah'**
  String get messagesSuggestionBioJeddah;

  /// No description provided for @messagesSuggestionBioLuxury.
  ///
  /// In en, this message translates to:
  /// **'Worldwide luxury estates'**
  String get messagesSuggestionBioLuxury;

  /// No description provided for @messagesSuggestionFriendsOfFriends.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get messagesSuggestionFriendsOfFriends;

  /// No description provided for @messagesSuggestionPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular creator'**
  String get messagesSuggestionPopular;

  /// No description provided for @messagesSuggestionMutualFriends.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mutual friend} other{{count} mutual friends}}'**
  String messagesSuggestionMutualFriends(num count);

  /// No description provided for @messagesSuggestionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No suggestions right now'**
  String get messagesSuggestionsEmpty;

  /// No description provided for @userCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Comments'**
  String get userCommentsTitle;

  /// No description provided for @userCommentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t commented on any posts yet'**
  String get userCommentsEmpty;

  /// No description provided for @userCommentReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get userCommentReplyLabel;

  /// No description provided for @userCommentAction.
  ///
  /// In en, this message translates to:
  /// **'commented'**
  String get userCommentAction;

  /// No description provided for @userCommentOnPost.
  ///
  /// In en, this message translates to:
  /// **'On post by {author}'**
  String userCommentOnPost(String author);

  /// No description provided for @userLikesTitle.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get userLikesTitle;

  /// No description provided for @userLikesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one has liked your posts yet'**
  String get userLikesEmpty;

  /// No description provided for @userLikeReceivedAction.
  ///
  /// In en, this message translates to:
  /// **'liked your post'**
  String get userLikeReceivedAction;

  /// No description provided for @userMentionsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Mentions'**
  String get userMentionsTitle;

  /// No description provided for @userMentionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one has mentioned you yet'**
  String get userMentionsEmpty;

  /// No description provided for @userMentionAction.
  ///
  /// In en, this message translates to:
  /// **'mentioned you'**
  String get userMentionAction;

  /// No description provided for @userMentionInComment.
  ///
  /// In en, this message translates to:
  /// **'in a comment'**
  String get userMentionInComment;

  /// No description provided for @userFollowersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get userFollowersTitle;

  /// No description provided for @userFollowerAction.
  ///
  /// In en, this message translates to:
  /// **'started following you'**
  String get userFollowerAction;

  /// No description provided for @chatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get chatMessageDeleted;

  /// No description provided for @chatActionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatActionReply;

  /// No description provided for @chatActionReact.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get chatActionReact;

  /// No description provided for @chatActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatActionDelete;

  /// No description provided for @chatDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get chatDeleteMessageTitle;

  /// No description provided for @chatDeleteMessageMessage.
  ///
  /// In en, this message translates to:
  /// **'This message will be hidden for everyone in the chat.'**
  String get chatDeleteMessageMessage;

  /// No description provided for @chatActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get chatActiveNow;

  /// No description provided for @chatAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add comment...'**
  String get chatAddComment;

  /// No description provided for @chatRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get chatRecording;

  /// No description provided for @chatSlideUpToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide up to cancel'**
  String get chatSlideUpToCancel;

  /// No description provided for @chatRecordingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to record voice messages.'**
  String get chatRecordingPermissionDenied;

  /// No description provided for @chatRecordingPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone access'**
  String get chatRecordingPermissionTitle;

  /// No description provided for @chatRecordingPermissionSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice messages need the microphone. Open Settings, tap Permissions, and allow Microphone for Bimo Bond.'**
  String get chatRecordingPermissionSettingsMessage;

  /// No description provided for @chatRecordingOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get chatRecordingOpenSettings;

  /// No description provided for @chatRecordingAllowMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get chatRecordingAllowMicrophone;

  /// No description provided for @chatRecordingPluginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice recording is not ready. Stop the app completely, then run it again (not hot reload).'**
  String get chatRecordingPluginUnavailable;

  /// No description provided for @chatVoiceTooShort.
  ///
  /// In en, this message translates to:
  /// **'Hold longer to record a voice message.'**
  String get chatVoiceTooShort;

  /// No description provided for @chatVoicePlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this voice message.'**
  String get chatVoicePlaybackFailed;

  /// No description provided for @chatAttachmentSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send attachment. Please try again.'**
  String get chatAttachmentSendFailed;

  /// No description provided for @chatLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to share your position.'**
  String get chatLocationPermissionDenied;

  /// No description provided for @chatContactsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Contacts permission is required to share a contact.'**
  String get chatContactsPermissionDenied;

  /// No description provided for @chatFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon.'**
  String get chatFeatureComingSoon;

  /// No description provided for @chatMessageLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatMessageLocation;

  /// No description provided for @messagesInboxLastLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get messagesInboxLastLocation;

  /// No description provided for @messagesInboxLastFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get messagesInboxLastFile;

  /// No description provided for @messagesInboxLastContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get messagesInboxLastContact;

  /// No description provided for @chatSeedGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi! How can I help you?'**
  String get chatSeedGreeting;

  /// No description provided for @chatSeedInterested.
  ///
  /// In en, this message translates to:
  /// **'I am interested in the property shown'**
  String get chatSeedInterested;

  /// No description provided for @chatSeedFinalPrice.
  ///
  /// In en, this message translates to:
  /// **'Can I know the final price?'**
  String get chatSeedFinalPrice;

  /// No description provided for @chatSeedAutoReply.
  ///
  /// In en, this message translates to:
  /// **'Thanks for reaching out! We will get back to you soon with more details.'**
  String get chatSeedAutoReply;

  /// No description provided for @chatUserBio.
  ///
  /// In en, this message translates to:
  /// **'Interested in real estate and design.'**
  String get chatUserBio;

  /// No description provided for @chatMoreGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatMoreGallery;

  /// No description provided for @chatMoreCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatMoreCamera;

  /// No description provided for @chatMoreVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatMoreVideo;

  /// No description provided for @chatMoreLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatMoreLocation;

  /// No description provided for @chatMoreContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get chatMoreContact;

  /// No description provided for @chatMoreFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatMoreFile;

  /// No description provided for @chatMoreGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get chatMoreGift;

  /// No description provided for @chatMorePoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get chatMorePoll;

  /// No description provided for @chatLastMessage1.
  ///
  /// In en, this message translates to:
  /// **'Can I know the final price?'**
  String get chatLastMessage1;

  /// No description provided for @chatLastMessage2.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the update!'**
  String get chatLastMessage2;

  /// No description provided for @chatLastMessage3.
  ///
  /// In en, this message translates to:
  /// **'Is the property still available?'**
  String get chatLastMessage3;

  /// No description provided for @chatLastMessage4.
  ///
  /// In en, this message translates to:
  /// **'Sent a photo'**
  String get chatLastMessage4;

  /// No description provided for @chatLastMessage5.
  ///
  /// In en, this message translates to:
  /// **'See you tomorrow 👋'**
  String get chatLastMessage5;

  /// No description provided for @addPostAsAuction.
  ///
  /// In en, this message translates to:
  /// **'List as auction'**
  String get addPostAsAuction;

  /// No description provided for @auctionItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get auctionItemName;

  /// No description provided for @auctionItemNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Antique Pocket Watch'**
  String get auctionItemNameHint;

  /// No description provided for @auctionStartingPrice.
  ///
  /// In en, this message translates to:
  /// **'Starting price (USD)'**
  String get auctionStartingPrice;

  /// No description provided for @auctionTargetPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Target price (USD)'**
  String get auctionTargetPriceLabel;

  /// No description provided for @auctionStartDate.
  ///
  /// In en, this message translates to:
  /// **'Auction starts'**
  String get auctionStartDate;

  /// No description provided for @auctionEndDate.
  ///
  /// In en, this message translates to:
  /// **'Auction ends'**
  String get auctionEndDate;

  /// No description provided for @auctionEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End date must be after start date'**
  String get auctionEndBeforeStart;

  /// No description provided for @auctionTargetBelowStart.
  ///
  /// In en, this message translates to:
  /// **'Target price must be greater than starting price'**
  String get auctionTargetBelowStart;

  /// No description provided for @auctionInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get auctionInvalidPrice;

  /// No description provided for @hashtagFeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Posts with this hashtag'**
  String get hashtagFeedSubtitle;

  /// No description provided for @noHashtagPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts for this hashtag yet'**
  String get noHashtagPosts;

  /// No description provided for @trendingHashtags.
  ///
  /// In en, this message translates to:
  /// **'Trending hashtags'**
  String get trendingHashtags;

  /// No description provided for @searchHashtagsHint.
  ///
  /// In en, this message translates to:
  /// **'Search hashtags'**
  String get searchHashtagsHint;

  /// No description provided for @noHashtagsFound.
  ///
  /// In en, this message translates to:
  /// **'No hashtags found'**
  String get noHashtagsFound;

  /// No description provided for @hashtagPostCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No posts} =1{1 post} other{{count} posts}}'**
  String hashtagPostCount(int count);

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone interacts with you, you\'ll see it here.'**
  String get notificationsEmptySubtitle;

  /// No description provided for @notificationsEmptyUnread.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up — no unread notifications.'**
  String get notificationsEmptyUnread;

  /// No description provided for @notificationsEmptyRead.
  ///
  /// In en, this message translates to:
  /// **'No read notifications yet.'**
  String get notificationsEmptyRead;

  /// No description provided for @notificationsFilterUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread notification} other{{count} unread notifications}}'**
  String notificationsFilterUnreadCount(int count);

  /// No description provided for @notificationsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsRetry;

  /// No description provided for @notificationsOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get notificationsOk;

  /// No description provided for @notificationsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications'**
  String get notificationsLoadError;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsClearRead.
  ///
  /// In en, this message translates to:
  /// **'Clear read'**
  String get notificationsClearRead;

  /// No description provided for @notificationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// No description provided for @notificationsFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsFilterUnread;

  /// No description provided for @notificationsFilterRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notificationsFilterRead;

  /// No description provided for @notificationSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notificationSomeone;

  /// No description provided for @notificationTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationTitleDefault;

  /// No description provided for @notificationTitleNewFollower.
  ///
  /// In en, this message translates to:
  /// **'New follower'**
  String get notificationTitleNewFollower;

  /// No description provided for @notificationTitleFollowRequest.
  ///
  /// In en, this message translates to:
  /// **'Follow request'**
  String get notificationTitleFollowRequest;

  /// No description provided for @notificationTitleFollowAccepted.
  ///
  /// In en, this message translates to:
  /// **'Follow request accepted'**
  String get notificationTitleFollowAccepted;

  /// No description provided for @notificationTitlePostLike.
  ///
  /// In en, this message translates to:
  /// **'New like'**
  String get notificationTitlePostLike;

  /// No description provided for @notificationTitlePostComment.
  ///
  /// In en, this message translates to:
  /// **'New comment'**
  String get notificationTitlePostComment;

  /// No description provided for @notificationTitleCommentReply.
  ///
  /// In en, this message translates to:
  /// **'New reply'**
  String get notificationTitleCommentReply;

  /// No description provided for @notificationTitleCommentLike.
  ///
  /// In en, this message translates to:
  /// **'Comment liked'**
  String get notificationTitleCommentLike;

  /// No description provided for @notificationTitleMention.
  ///
  /// In en, this message translates to:
  /// **'Mention'**
  String get notificationTitleMention;

  /// No description provided for @notificationTitleRepost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get notificationTitleRepost;

  /// No description provided for @notificationTitleGift.
  ///
  /// In en, this message translates to:
  /// **'Gift received'**
  String get notificationTitleGift;

  /// No description provided for @notificationTitleAuctionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auction update'**
  String get notificationTitleAuctionUpdate;

  /// No description provided for @notificationTitleAuctionWon.
  ///
  /// In en, this message translates to:
  /// **'Auction won'**
  String get notificationTitleAuctionWon;

  /// No description provided for @notificationBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'You have a new notification'**
  String get notificationBodyDefault;

  /// No description provided for @notificationBodyNewFollower.
  ///
  /// In en, this message translates to:
  /// **'{name} started following you'**
  String notificationBodyNewFollower(String name);

  /// No description provided for @notificationBodyFollowRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} requested to follow you'**
  String notificationBodyFollowRequest(String name);

  /// No description provided for @notificationBodyFollowAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your follow request'**
  String notificationBodyFollowAccepted(String name);

  /// No description provided for @notificationBodyPostLike.
  ///
  /// In en, this message translates to:
  /// **'{name} liked your post'**
  String notificationBodyPostLike(String name);

  /// No description provided for @notificationBodyPostComment.
  ///
  /// In en, this message translates to:
  /// **'{name} commented on your post'**
  String notificationBodyPostComment(String name);

  /// No description provided for @notificationBodyCommentReply.
  ///
  /// In en, this message translates to:
  /// **'{name} replied to your comment'**
  String notificationBodyCommentReply(String name);

  /// No description provided for @notificationBodyCommentLike.
  ///
  /// In en, this message translates to:
  /// **'{name} liked your comment'**
  String notificationBodyCommentLike(String name);

  /// No description provided for @notificationBodyMention.
  ///
  /// In en, this message translates to:
  /// **'{name} mentioned you'**
  String notificationBodyMention(String name);

  /// No description provided for @notificationBodyRepost.
  ///
  /// In en, this message translates to:
  /// **'{name} reposted your post'**
  String notificationBodyRepost(String name);

  /// No description provided for @notificationBodyGift.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a gift'**
  String notificationBodyGift(String name);

  /// No description provided for @notificationBodyAuctionUpdate.
  ///
  /// In en, this message translates to:
  /// **'An auction you follow was updated'**
  String get notificationBodyAuctionUpdate;

  /// No description provided for @notificationBodyAuctionWon.
  ///
  /// In en, this message translates to:
  /// **'You won an auction'**
  String get notificationBodyAuctionWon;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
