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

  /// No description provided for @loginScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to BimoBond'**
  String get loginScreenTitle;

  /// No description provided for @loginWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Use phone number'**
  String get loginWithPhone;

  /// No description provided for @loginWithEmailUsername.
  ///
  /// In en, this message translates to:
  /// **'Use email or username'**
  String get loginWithEmailUsername;

  /// No description provided for @loginEmailUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get loginEmailUsernameHint;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

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

  /// No description provided for @notificationErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get notificationErrorTitle;

  /// No description provided for @notificationSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get notificationSuccessTitle;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUpTitle;

  /// No description provided for @signUpScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up to BimoBond'**
  String get signUpScreenTitle;

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

  /// No description provided for @phoneLoginUsageNote.
  ///
  /// In en, this message translates to:
  /// **'Your phone number may be used to connect you to people you may know, improve ads, and more depending on your settings.'**
  String get phoneLoginUsageNote;

  /// No description provided for @emailLoginUsageNote.
  ///
  /// In en, this message translates to:
  /// **'Your email may be used to connect you to people you may know, improve ads, and more depending on your settings.'**
  String get emailLoginUsageNote;

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

  /// No description provided for @loginLegalNotePart1.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get loginLegalNotePart1;

  /// No description provided for @loginTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get loginTermsOfService;

  /// No description provided for @loginLegalNotePart2.
  ///
  /// In en, this message translates to:
  /// **' and confirm that you have read our '**
  String get loginLegalNotePart2;

  /// No description provided for @loginPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get loginPrivacyPolicy;

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

  /// No description provided for @passwordSignUpTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordSignUpTooShort;

  /// No description provided for @passwordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Password must be at most 20 characters'**
  String get passwordTooLong;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgotPasswordButton;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox and spam folder.'**
  String get forgotPasswordSuccess;

  /// No description provided for @forgotPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please try again.'**
  String get forgotPasswordFailed;

  /// No description provided for @forgotPasswordUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address.'**
  String get forgotPasswordUserNotFound;

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

  /// No description provided for @googleLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Google login failed'**
  String get googleLoginFailed;

  /// No description provided for @googleLoginSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleLoginSheetTitle;

  /// No description provided for @googleLoginSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your Google account to sign in quickly and securely.'**
  String get googleLoginSheetSubtitle;

  /// No description provided for @googleLoginContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleLoginContinue;

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

  /// No description provided for @signUpEmailStepTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your email?'**
  String get signUpEmailStepTitle;

  /// No description provided for @signUpNameStepTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get signUpNameStepTitle;

  /// No description provided for @signUpPasswordStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get signUpPasswordStepTitle;

  /// No description provided for @nextAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextAction;

  /// No description provided for @passwordStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get passwordStrengthLabel;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordStrengthGood;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordStrengthHint.
  ///
  /// In en, this message translates to:
  /// **'Your password must have 8 to 20 characters and include a mix of letters, numbers, and symbols.'**
  String get passwordStrengthHint;

  /// No description provided for @passwordReqLength.
  ///
  /// In en, this message translates to:
  /// **'8 to 20 characters'**
  String get passwordReqLength;

  /// No description provided for @passwordReqLetter.
  ///
  /// In en, this message translates to:
  /// **'1 letter'**
  String get passwordReqLetter;

  /// No description provided for @passwordReqNumber.
  ///
  /// In en, this message translates to:
  /// **'1 number'**
  String get passwordReqNumber;

  /// No description provided for @passwordReqSpecialChar.
  ///
  /// In en, this message translates to:
  /// **'1 special character (e.g. ! @ # \$ % & *)'**
  String get passwordReqSpecialChar;

  /// No description provided for @passwordRequirementsNotMet.
  ///
  /// In en, this message translates to:
  /// **'Password must meet all requirements'**
  String get passwordRequirementsNotMet;

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

  /// No description provided for @storyAddText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get storyAddText;

  /// No description provided for @storyTextDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get storyTextDone;

  /// No description provided for @storyCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption (optional)'**
  String get storyCaptionHint;

  /// No description provided for @storyLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get storyLoadMore;

  /// No description provided for @storyShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get storyShowLess;

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

  /// No description provided for @importFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importFromLibrary;

  /// No description provided for @uploadFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Upload from library'**
  String get uploadFromLibrary;

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

  /// No description provided for @auctionTapToEnter.
  ///
  /// In en, this message translates to:
  /// **'Tap to enter'**
  String get auctionTapToEnter;

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
  /// **'Upload images from library'**
  String get imageFromLibrary;

  /// No description provided for @videoFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import videos from library'**
  String get videoFromLibrary;

  /// No description provided for @tapToSelectMedia.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload from library'**
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

  /// No description provided for @postOptionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postOptionShare;

  /// No description provided for @postOptionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get postOptionReport;

  /// No description provided for @postOptionNotInterested.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get postOptionNotInterested;

  /// No description provided for @postOptionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get postOptionDownload;

  /// No description provided for @postOptionAddToStory.
  ///
  /// In en, this message translates to:
  /// **'Add to story'**
  String get postOptionAddToStory;

  /// No description provided for @postOptionShareAsGif.
  ///
  /// In en, this message translates to:
  /// **'Share as GIF'**
  String get postOptionShareAsGif;

  /// No description provided for @postOptionCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get postOptionCreateGroup;

  /// No description provided for @postLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get postLinkCopied;

  /// No description provided for @postReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report post?'**
  String get postReportTitle;

  /// No description provided for @postReportMessage.
  ///
  /// In en, this message translates to:
  /// **'Tell us if this post breaks our community guidelines.'**
  String get postReportMessage;

  /// No description provided for @postReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks for reporting. We\'ll review this post.'**
  String get postReportSubmitted;

  /// No description provided for @postNotInterestedApplied.
  ///
  /// In en, this message translates to:
  /// **'We\'ll show fewer posts like this'**
  String get postNotInterestedApplied;

  /// No description provided for @postDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get postDownloadStarted;

  /// No description provided for @postDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to app downloads'**
  String get postDownloadSaved;

  /// No description provided for @postDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download media'**
  String get postDownloadFailed;

  /// No description provided for @postShareAsGifUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GIF share is only available for videos'**
  String get postShareAsGifUnavailable;

  /// No description provided for @postShareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share post'**
  String get postShareSheetTitle;

  /// No description provided for @postShareSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search friends and users'**
  String get postShareSearchUsers;

  /// No description provided for @postShareNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get postShareNoUsers;

  /// No description provided for @postShareToApps.
  ///
  /// In en, this message translates to:
  /// **'Share to apps'**
  String get postShareToApps;

  /// No description provided for @postShareMessenger.
  ///
  /// In en, this message translates to:
  /// **'Messenger'**
  String get postShareMessenger;

  /// No description provided for @postShareFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get postShareFacebook;

  /// No description provided for @postShareWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get postShareWhatsApp;

  /// No description provided for @postShareTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get postShareTelegram;

  /// No description provided for @postShareTwitter.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get postShareTwitter;

  /// No description provided for @postShareSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get postShareSms;

  /// No description provided for @postShareEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get postShareEmail;

  /// No description provided for @postShareCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get postShareCopyLink;

  /// No description provided for @postShareMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get postShareMore;

  /// No description provided for @postShareSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send post'**
  String get postShareSendFailed;

  /// No description provided for @postShareSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String postShareSentTo(String name);

  /// No description provided for @postAddToStoryHint.
  ///
  /// In en, this message translates to:
  /// **'Create your story — the post is ready to share'**
  String get postAddToStoryHint;

  /// No description provided for @postCreateGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Pick contacts to start a group chat'**
  String get postCreateGroupHint;

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
  /// **'followed you'**
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
  /// **'Write message'**
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
  /// **'Import'**
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

  /// No description provided for @notificationsFilterViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get notificationsFilterViewAll;

  /// No description provided for @notificationsFilterActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get notificationsFilterActivity;

  /// No description provided for @notificationsFilterAuctions.
  ///
  /// In en, this message translates to:
  /// **'Auctions'**
  String get notificationsFilterAuctions;

  /// No description provided for @notificationsFilterInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get notificationsFilterInvites;

  /// No description provided for @notificationsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get notificationsAccept;

  /// No description provided for @notificationsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get notificationsDecline;

  /// No description provided for @notificationsEmptyActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity notifications yet.'**
  String get notificationsEmptyActivity;

  /// No description provided for @notificationsEmptyAuctions.
  ///
  /// In en, this message translates to:
  /// **'No auction notifications yet.'**
  String get notificationsEmptyAuctions;

  /// No description provided for @notificationsEmptyInvites.
  ///
  /// In en, this message translates to:
  /// **'No invite notifications yet.'**
  String get notificationsEmptyInvites;

  /// No description provided for @notificationContextPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get notificationContextPost;

  /// No description provided for @notificationMediaVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get notificationMediaVideo;

  /// No description provided for @notificationMediaImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get notificationMediaImage;

  /// No description provided for @notificationActionFollowedYou.
  ///
  /// In en, this message translates to:
  /// **'followed you'**
  String get notificationActionFollowedYou;

  /// No description provided for @notificationActionFollowRequest.
  ///
  /// In en, this message translates to:
  /// **'requested to follow you'**
  String get notificationActionFollowRequest;

  /// No description provided for @notificationActionFollowAccepted.
  ///
  /// In en, this message translates to:
  /// **'accepted your follow request'**
  String get notificationActionFollowAccepted;

  /// No description provided for @notificationActionPostLike.
  ///
  /// In en, this message translates to:
  /// **'liked your post'**
  String get notificationActionPostLike;

  /// No description provided for @notificationActionPostComment.
  ///
  /// In en, this message translates to:
  /// **'commented on your post'**
  String get notificationActionPostComment;

  /// No description provided for @notificationActionCommentReply.
  ///
  /// In en, this message translates to:
  /// **'replied to your comment'**
  String get notificationActionCommentReply;

  /// No description provided for @notificationActionCommentLike.
  ///
  /// In en, this message translates to:
  /// **'liked your comment'**
  String get notificationActionCommentLike;

  /// No description provided for @notificationActionMention.
  ///
  /// In en, this message translates to:
  /// **'mentioned you'**
  String get notificationActionMention;

  /// No description provided for @notificationActionRepost.
  ///
  /// In en, this message translates to:
  /// **'reposted your post'**
  String get notificationActionRepost;

  /// No description provided for @notificationActionGift.
  ///
  /// In en, this message translates to:
  /// **'sent you a gift'**
  String get notificationActionGift;

  /// No description provided for @notificationActionAuctionUpdate.
  ///
  /// In en, this message translates to:
  /// **'updated an auction you follow'**
  String get notificationActionAuctionUpdate;

  /// No description provided for @notificationActionAuctionWon.
  ///
  /// In en, this message translates to:
  /// **'you won an auction'**
  String get notificationActionAuctionWon;

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

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Coins Balance'**
  String get walletBalanceLabel;

  /// No description provided for @walletChoosePackage.
  ///
  /// In en, this message translates to:
  /// **'Choose a Package'**
  String get walletChoosePackage;

  /// No description provided for @walletCustomAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom amount'**
  String get walletCustomAmountTitle;

  /// No description provided for @walletCustomCoinsLabel.
  ///
  /// In en, this message translates to:
  /// **'How many coins?'**
  String get walletCustomCoinsLabel;

  /// No description provided for @walletCustomCoinsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500'**
  String get walletCustomCoinsHint;

  /// No description provided for @walletCustomCoinsReceive.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get walletCustomCoinsReceive;

  /// No description provided for @walletCustomCoinsValue.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String walletCustomCoinsValue(String coins);

  /// No description provided for @walletCustomYouPay.
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get walletCustomYouPay;

  /// No description provided for @walletPackageQuotes.
  ///
  /// In en, this message translates to:
  /// **'Package quotes'**
  String get walletPackageQuotes;

  /// No description provided for @walletPackageQuotePrice.
  ///
  /// In en, this message translates to:
  /// **'Package price'**
  String get walletPackageQuotePrice;

  /// No description provided for @walletPricingPreviewCost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get walletPricingPreviewCost;

  /// No description provided for @walletPricingPreviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get walletPricingPreviewLoading;

  /// No description provided for @walletCustomAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid coin amount.'**
  String get walletCustomAmountInvalid;

  /// No description provided for @walletPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully purchased {amount} coins!'**
  String walletPurchaseSuccess(int amount);

  /// No description provided for @walletTopUpButton.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get walletTopUpButton;

  /// No description provided for @walletProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get walletProcessing;

  /// No description provided for @walletCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get walletCardNumber;

  /// No description provided for @walletExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date (MM/YY)'**
  String get walletExpiry;

  /// No description provided for @walletCvv.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get walletCvv;

  /// No description provided for @walletCardHolder.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get walletCardHolder;

  /// No description provided for @walletPayButton.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String walletPayButton(String price);

  /// No description provided for @coinsHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coinsHubTitle;

  /// No description provided for @coinsAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get coinsAvailableBalance;

  /// No description provided for @coinsWalletAccountName.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Account'**
  String coinsWalletAccountName(String name);

  /// No description provided for @coinsBalanceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh balance'**
  String get coinsBalanceRefresh;

  /// No description provided for @coinsBalanceFooterHint.
  ///
  /// In en, this message translates to:
  /// **'UPDATED ON OPEN'**
  String get coinsBalanceFooterHint;

  /// No description provided for @coinsBalanceFooter.
  ///
  /// In en, this message translates to:
  /// **'{date} | {hint}'**
  String coinsBalanceFooter(String date, String hint);

  /// No description provided for @coinsTabBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get coinsTabBuy;

  /// No description provided for @coinsTabMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get coinsTabMarket;

  /// No description provided for @coinsTabVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get coinsTabVault;

  /// No description provided for @coinsUnit.
  ///
  /// In en, this message translates to:
  /// **'coins'**
  String get coinsUnit;

  /// No description provided for @coinsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get coinsHistoryTitle;

  /// No description provided for @coinsMarketSuccess.
  ///
  /// In en, this message translates to:
  /// **'Gift added to your vault!'**
  String get coinsMarketSuccess;

  /// No description provided for @coinsVaultEmpty.
  ///
  /// In en, this message translates to:
  /// **'No gifts in your vault yet. Visit the market to buy gifts with coins.'**
  String get coinsVaultEmpty;

  /// No description provided for @coinsVaultOwned.
  ///
  /// In en, this message translates to:
  /// **'In vault'**
  String get coinsVaultOwned;

  /// No description provided for @coinsInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins. Buy more in the Buy tab.'**
  String get coinsInsufficientBalance;

  /// No description provided for @walletAccountingPurchase.
  ///
  /// In en, this message translates to:
  /// **'Bought coins'**
  String get walletAccountingPurchase;

  /// No description provided for @walletAccountingGiftPurchase.
  ///
  /// In en, this message translates to:
  /// **'Bought gift'**
  String get walletAccountingGiftPurchase;

  /// No description provided for @walletAccountingGiftReceived.
  ///
  /// In en, this message translates to:
  /// **'Received gift'**
  String get walletAccountingGiftReceived;

  /// No description provided for @walletAccountingPromotion.
  ///
  /// In en, this message translates to:
  /// **'Post promotion'**
  String get walletAccountingPromotion;

  /// No description provided for @walletAccountingAdmin.
  ///
  /// In en, this message translates to:
  /// **'Balance adjustment'**
  String get walletAccountingAdmin;

  /// No description provided for @balanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balanceTitle;

  /// No description provided for @balanceDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get balanceDefaultUserName;

  /// No description provided for @balanceUserTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s balance'**
  String balanceUserTitle(String name);

  /// No description provided for @balanceEstimatedBalance.
  ///
  /// In en, this message translates to:
  /// **'Estimated balance'**
  String get balanceEstimatedBalance;

  /// No description provided for @balanceView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get balanceView;

  /// No description provided for @balanceGet.
  ///
  /// In en, this message translates to:
  /// **'Get'**
  String get balanceGet;

  /// No description provided for @balanceScheduledPayouts.
  ///
  /// In en, this message translates to:
  /// **'Scheduled payouts'**
  String get balanceScheduledPayouts;

  /// No description provided for @balanceViewFullSchedule.
  ///
  /// In en, this message translates to:
  /// **'View full schedule >'**
  String get balanceViewFullSchedule;

  /// No description provided for @balanceSetupPaymentsBanner.
  ///
  /// In en, this message translates to:
  /// **'To receive payouts from Creator Rewards Program, set up payments.'**
  String get balanceSetupPaymentsBanner;

  /// No description provided for @balanceSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get balanceSetup;

  /// No description provided for @balanceSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Setup required'**
  String get balanceSetupRequired;

  /// No description provided for @balancePastPayouts.
  ///
  /// In en, this message translates to:
  /// **'Past payouts >'**
  String get balancePastPayouts;

  /// No description provided for @balanceTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get balanceTransactions;

  /// No description provided for @balanceTransactionPreview.
  ///
  /// In en, this message translates to:
  /// **'{title}: {amount} >'**
  String balanceTransactionPreview(String title, String amount);

  /// No description provided for @balanceFirstCoinOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'First Coin purchase offer'**
  String get balanceFirstCoinOfferTitle;

  /// No description provided for @balanceFirstCoinOfferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get bonus Coins and a 99% off animated Gift from your first purchase'**
  String get balanceFirstCoinOfferSubtitle;

  /// No description provided for @balanceGetNow.
  ///
  /// In en, this message translates to:
  /// **'Get now →'**
  String get balanceGetNow;

  /// No description provided for @balanceMonetization.
  ///
  /// In en, this message translates to:
  /// **'Monetization'**
  String get balanceMonetization;

  /// No description provided for @balanceViewMore.
  ///
  /// In en, this message translates to:
  /// **'View more >'**
  String get balanceViewMore;

  /// No description provided for @balanceMonetizationLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get balanceMonetizationLive;

  /// No description provided for @balanceMonetizationActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get balanceMonetizationActivities;

  /// No description provided for @balanceServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get balanceServices;

  /// No description provided for @balancePaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get balancePaymentMethods;

  /// No description provided for @balanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get balanceRequired;

  /// No description provided for @balanceTaxInformation.
  ///
  /// In en, this message translates to:
  /// **'Tax information'**
  String get balanceTaxInformation;

  /// No description provided for @balanceIdentityVerification.
  ///
  /// In en, this message translates to:
  /// **'Identity verification'**
  String get balanceIdentityVerification;

  /// No description provided for @balanceMonetizationCenter.
  ///
  /// In en, this message translates to:
  /// **'Monetization Center'**
  String get balanceMonetizationCenter;

  /// No description provided for @balanceExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore >'**
  String get balanceExplore;

  /// No description provided for @balanceProgramCreatorRewards.
  ///
  /// In en, this message translates to:
  /// **'Creator Rewards Program'**
  String get balanceProgramCreatorRewards;

  /// No description provided for @balanceProgramTiktokGo.
  ///
  /// In en, this message translates to:
  /// **'TikTok GO rewards'**
  String get balanceProgramTiktokGo;

  /// No description provided for @balanceProgramSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get balanceProgramSeries;

  /// No description provided for @balanceSetupPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up payments'**
  String get balanceSetupPaymentsTitle;

  /// No description provided for @balanceSetupPaymentsMessage.
  ///
  /// In en, this message translates to:
  /// **'Ensure your information is accurate to receive payouts on time. You can change this at any time.'**
  String get balanceSetupPaymentsMessage;

  /// No description provided for @balancePayoutMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout method'**
  String get balancePayoutMethodTitle;

  /// No description provided for @balancePayoutMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select where to receive payouts.'**
  String get balancePayoutMethodSubtitle;

  /// No description provided for @balanceTaxInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Tax information'**
  String get balanceTaxInfoTitle;

  /// No description provided for @balanceTaxInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required for compliance purposes.'**
  String get balanceTaxInfoSubtitle;

  /// No description provided for @balanceIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity verification'**
  String get balanceIdentityTitle;

  /// No description provided for @balanceIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get your ID ready.'**
  String get balanceIdentitySubtitle;

  /// No description provided for @balanceAddPayoutMethod.
  ///
  /// In en, this message translates to:
  /// **'Add payout method'**
  String get balanceAddPayoutMethod;

  /// No description provided for @balanceCountryRegion.
  ///
  /// In en, this message translates to:
  /// **'Country / region'**
  String get balanceCountryRegion;

  /// No description provided for @balanceCountryRegionNote.
  ///
  /// In en, this message translates to:
  /// **'You can only register for one country or region. Make sure your selection is correct.'**
  String get balanceCountryRegionNote;

  /// No description provided for @balanceChoosePayoutMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose payout method'**
  String get balanceChoosePayoutMethod;

  /// No description provided for @balancePayoutZaloPay.
  ///
  /// In en, this message translates to:
  /// **'ZaloPay (VND)'**
  String get balancePayoutZaloPay;

  /// No description provided for @balancePayoutZaloPayDetails.
  ///
  /// In en, this message translates to:
  /// **'Service fee 1.5% | Min. withdrawal 2 USD | Arrives in 1 business day'**
  String get balancePayoutZaloPayDetails;

  /// No description provided for @balancePayoutBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer (VND)'**
  String get balancePayoutBank;

  /// No description provided for @balancePayoutBankDetails.
  ///
  /// In en, this message translates to:
  /// **'Service fee 2.9 USD | Min. withdrawal 8 USD | Arrives in 3-5 business days'**
  String get balancePayoutBankDetails;

  /// No description provided for @balancePayoutPayPal.
  ///
  /// In en, this message translates to:
  /// **'PayPal (USD)'**
  String get balancePayoutPayPal;

  /// No description provided for @balancePayoutPayPalDetails.
  ///
  /// In en, this message translates to:
  /// **'Service fee 1.5% + 0.1 USD | Min. withdrawal 1 USD | Arrives in 1 business day'**
  String get balancePayoutPayPalDetails;

  /// No description provided for @balanceTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get balanceTransactionHistory;

  /// No description provided for @balanceTransactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get balanceTransactionDetails;

  /// No description provided for @balanceTransactionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found'**
  String get balanceTransactionNotFound;

  /// No description provided for @balanceNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get balanceNoTransactions;

  /// No description provided for @balanceTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get balanceTabAll;

  /// No description provided for @balanceTabRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get balanceTabRevenue;

  /// No description provided for @balanceTabExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get balanceTabExpense;

  /// No description provided for @balanceTabPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get balanceTabPayout;

  /// No description provided for @balanceTabRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get balanceTabRefund;

  /// No description provided for @balanceDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get balanceDetailStatus;

  /// No description provided for @balanceStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get balanceStatusCompleted;

  /// No description provided for @balanceDetailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get balanceDetailType;

  /// No description provided for @balanceDetailActivityType.
  ///
  /// In en, this message translates to:
  /// **'Activity type'**
  String get balanceDetailActivityType;

  /// No description provided for @balanceDetailPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get balanceDetailPaymentMethod;

  /// No description provided for @balanceDetailCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get balanceDetailCreated;

  /// No description provided for @balanceDetailUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get balanceDetailUpdated;

  /// No description provided for @balanceDetailTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get balanceDetailTransactionId;

  /// No description provided for @balanceCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get balanceCopied;

  /// No description provided for @balanceNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? >'**
  String get balanceNeedHelp;

  /// No description provided for @deleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChatTitle;

  /// No description provided for @deleteChatMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this conversation? This action cannot be undone.'**
  String get deleteChatMessage;

  /// No description provided for @deleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteChatConfirm;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @cameraFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get cameraFlip;

  /// No description provided for @cameraFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get cameraFlash;

  /// No description provided for @cameraSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get cameraSpeed;

  /// No description provided for @cameraBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get cameraBeauty;

  /// No description provided for @cameraFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get cameraFilters;

  /// No description provided for @cameraTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get cameraTimer;

  /// No description provided for @cameraMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get cameraMusic;

  /// No description provided for @cameraEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get cameraEffects;

  /// No description provided for @cameraUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload from library'**
  String get cameraUpload;

  /// No description provided for @cameraOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original Sound'**
  String get cameraOriginalSound;

  /// No description provided for @cameraSeconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get cameraSeconds;

  /// No description provided for @cameraRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get cameraRecording;

  /// No description provided for @cameraMusicComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Music selection is coming soon.'**
  String get cameraMusicComingSoon;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone permissions are required to record.'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting camera...'**
  String get cameraStarting;

  /// No description provided for @cameraOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get cameraOpenSettings;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No camera was found on this device.'**
  String get cameraUnavailable;

  /// No description provided for @cameraInitError.
  ///
  /// In en, this message translates to:
  /// **'Could not start the camera: {error}'**
  String cameraInitError(String error);

  /// No description provided for @cameraCaptureError.
  ///
  /// In en, this message translates to:
  /// **'Capture failed: {error}'**
  String cameraCaptureError(String error);

  /// No description provided for @cameraCategoryTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get cameraCategoryTrending;

  /// No description provided for @cameraCategoryNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get cameraCategoryNew;

  /// No description provided for @cameraCategoryPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get cameraCategoryPortrait;

  /// No description provided for @cameraCategoryVibe.
  ///
  /// In en, this message translates to:
  /// **'Vibe'**
  String get cameraCategoryVibe;

  /// No description provided for @cameraCategoryLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get cameraCategoryLandscape;

  /// No description provided for @cameraFilterOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get cameraFilterOriginal;

  /// No description provided for @cameraFilterWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get cameraFilterWarm;

  /// No description provided for @cameraFilterCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get cameraFilterCool;

  /// No description provided for @cameraFilterSunny.
  ///
  /// In en, this message translates to:
  /// **'Sunny'**
  String get cameraFilterSunny;

  /// No description provided for @cameraFilterPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get cameraFilterPink;

  /// No description provided for @cameraFilterMoody.
  ///
  /// In en, this message translates to:
  /// **'Moody'**
  String get cameraFilterMoody;

  /// No description provided for @cameraFilterBw.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get cameraFilterBw;

  /// No description provided for @cameraFilterRetro.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get cameraFilterRetro;

  /// No description provided for @cameraFilterFlashVintage.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get cameraFilterFlashVintage;

  /// No description provided for @cameraFilterBeautyGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get cameraFilterBeautyGlow;

  /// No description provided for @cameraFilterNaturalBright.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get cameraFilterNaturalBright;

  /// No description provided for @cameraFilterGoldenHour.
  ///
  /// In en, this message translates to:
  /// **'Golden'**
  String get cameraFilterGoldenHour;

  /// No description provided for @openCameraStudio.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get openCameraStudio;

  /// No description provided for @cameraModePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get cameraModePhoto;

  /// No description provided for @cameraModeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get cameraModeVideo;

  /// No description provided for @cameraModeLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get cameraModeLive;

  /// No description provided for @cameraModeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get cameraModeText;

  /// No description provided for @cameraAddSound.
  ///
  /// In en, this message translates to:
  /// **'Add sound'**
  String get cameraAddSound;

  /// No description provided for @cameraLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get cameraLayout;

  /// No description provided for @cameraAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Ratio'**
  String get cameraAspectRatio;

  /// No description provided for @cameraTabPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get cameraTabPost;

  /// No description provided for @cameraTabCreative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get cameraTabCreative;

  /// No description provided for @cameraDuration10m.
  ///
  /// In en, this message translates to:
  /// **'10m'**
  String get cameraDuration10m;

  /// No description provided for @cameraZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get cameraZoom;

  /// No description provided for @cameraGoLive.
  ///
  /// In en, this message translates to:
  /// **'Go LIVE'**
  String get cameraGoLive;

  /// No description provided for @cameraLiveTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Add a title'**
  String get cameraLiveTitleHint;

  /// No description provided for @cameraLiveComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Live streaming is coming soon.'**
  String get cameraLiveComingSoon;

  /// No description provided for @cameraEffectCrown.
  ///
  /// In en, this message translates to:
  /// **'Crown'**
  String get cameraEffectCrown;

  /// No description provided for @cameraEffectBunny.
  ///
  /// In en, this message translates to:
  /// **'Bunny'**
  String get cameraEffectBunny;

  /// No description provided for @cameraEffectSunglasses.
  ///
  /// In en, this message translates to:
  /// **'Shades'**
  String get cameraEffectSunglasses;

  /// No description provided for @cameraEffectDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get cameraEffectDog;

  /// No description provided for @cameraEffectHearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get cameraEffectHearts;

  /// No description provided for @cameraEffectSparkle.
  ///
  /// In en, this message translates to:
  /// **'Sparkle'**
  String get cameraEffectSparkle;

  /// No description provided for @cameraEffectNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get cameraEffectNeon;

  /// No description provided for @cameraEffectGlitch.
  ///
  /// In en, this message translates to:
  /// **'Glitch'**
  String get cameraEffectGlitch;

  /// No description provided for @promotePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Promote post'**
  String get promotePostTitle;

  /// No description provided for @promotionScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get promotionScreenTitle;

  /// No description provided for @promotePostAction.
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get promotePostAction;

  /// No description provided for @promoteGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your goal'**
  String get promoteGoalTitle;

  /// No description provided for @promoteAudienceTitle.
  ///
  /// In en, this message translates to:
  /// **'Define your audience'**
  String get promoteAudienceTitle;

  /// No description provided for @promoteAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age range'**
  String get promoteAgeRange;

  /// No description provided for @promoteGeoTarget.
  ///
  /// In en, this message translates to:
  /// **'Target people nearby'**
  String get promoteGeoTarget;

  /// No description provided for @promoteGeoTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Use your current location for local reach'**
  String get promoteGeoTargetHint;

  /// No description provided for @promoteGeoMapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to choose your target area. Default is your location.'**
  String get promoteGeoMapHint;

  /// No description provided for @promoteGeoUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get promoteGeoUseMyLocation;

  /// No description provided for @promoteGeoPlaceLoading.
  ///
  /// In en, this message translates to:
  /// **'Looking up place…'**
  String get promoteGeoPlaceLoading;

  /// No description provided for @promoteGeoCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get promoteGeoCity;

  /// No description provided for @promoteGeoRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get promoteGeoRegion;

  /// No description provided for @promoteGeoTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get promoteGeoTown;

  /// No description provided for @promoteGeoCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get promoteGeoCountry;

  /// No description provided for @promoteGeoContinent.
  ///
  /// In en, this message translates to:
  /// **'Continent'**
  String get promoteGeoContinent;

  /// No description provided for @promoteBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select budget'**
  String get promoteBudgetTitle;

  /// No description provided for @promoteProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get promoteProcessing;

  /// No description provided for @promotePostCta.
  ///
  /// In en, this message translates to:
  /// **'Promote for {price}'**
  String promotePostCta(String price);

  /// No description provided for @promotePostSuccess.
  ///
  /// In en, this message translates to:
  /// **'Promotion started! Wallet balance: {balance}'**
  String promotePostSuccess(String balance);

  /// No description provided for @promotedBadge.
  ///
  /// In en, this message translates to:
  /// **'Promoted'**
  String get promotedBadge;

  /// No description provided for @promoteLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get promoteLanguages;

  /// No description provided for @promoteInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get promoteInterests;

  /// No description provided for @promoteRadiusKm.
  ///
  /// In en, this message translates to:
  /// **'Radius: {km} km'**
  String promoteRadiusKm(int km);

  /// No description provided for @promotePayFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get promotePayFailedTitle;

  /// No description provided for @promoteRetryPay.
  ///
  /// In en, this message translates to:
  /// **'Retry payment'**
  String get promoteRetryPay;

  /// No description provided for @promoteAudienceCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize audience'**
  String get promoteAudienceCustomize;

  /// No description provided for @promoteAudienceAllGenders.
  ///
  /// In en, this message translates to:
  /// **'All genders'**
  String get promoteAudienceAllGenders;

  /// No description provided for @promoteAudienceNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get promoteAudienceNearby;

  /// No description provided for @promoteAudienceGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get promoteAudienceGender;

  /// No description provided for @promotePostNoCaption.
  ///
  /// In en, this message translates to:
  /// **'No caption'**
  String get promotePostNoCaption;

  /// No description provided for @promotePopularBadge.
  ///
  /// In en, this message translates to:
  /// **'POPULAR'**
  String get promotePopularBadge;

  /// No description provided for @promoteImpressions.
  ///
  /// In en, this message translates to:
  /// **'{count} impressions'**
  String promoteImpressions(int count);

  /// No description provided for @promoteStepGoalHeading.
  ///
  /// In en, this message translates to:
  /// **'What is your goal?'**
  String get promoteStepGoalHeading;

  /// No description provided for @promoteStepGoalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a goal for promoting this video.'**
  String get promoteStepGoalSubtitle;

  /// No description provided for @promoteStepAudienceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select how you want to reach your audience for your promotion.'**
  String get promoteStepAudienceSubtitle;

  /// No description provided for @promoteAudienceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default audience'**
  String get promoteAudienceDefault;

  /// No description provided for @promoteAudienceDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll choose the best audience for you'**
  String get promoteAudienceDefaultHint;

  /// No description provided for @promoteAudienceCreateOwn.
  ///
  /// In en, this message translates to:
  /// **'Create your own'**
  String get promoteAudienceCreateOwn;

  /// No description provided for @promoteStepLocationHeading.
  ///
  /// In en, this message translates to:
  /// **'Choose your target area'**
  String get promoteStepLocationHeading;

  /// No description provided for @promoteStepLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect your location and set a radius to reach people nearby.'**
  String get promoteStepLocationSubtitle;

  /// No description provided for @promoteStepBudgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a promotion package for your campaign.'**
  String get promoteStepBudgetSubtitle;

  /// No description provided for @promoteBudgetTotal.
  ///
  /// In en, this message translates to:
  /// **'{price} total'**
  String promoteBudgetTotal(String price);

  /// No description provided for @promoteEstimatedViews.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String promoteEstimatedViews(String min, String max);

  /// No description provided for @promoteEstimatedViewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated video views'**
  String get promoteEstimatedViewsLabel;

  /// No description provided for @promoteOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get promoteOverviewTitle;

  /// No description provided for @promoteOverviewGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get promoteOverviewGoal;

  /// No description provided for @promoteOverviewAudience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get promoteOverviewAudience;

  /// No description provided for @promoteOverviewLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get promoteOverviewLocation;

  /// No description provided for @promoteOverviewBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get promoteOverviewBudget;

  /// No description provided for @promoteLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location targeting off'**
  String get promoteLocationOff;

  /// No description provided for @promoteLocationPending.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get promoteLocationPending;

  /// No description provided for @promoteAudienceNearbyWithRadius.
  ///
  /// In en, this message translates to:
  /// **'Nearby · {km} km'**
  String promoteAudienceNearbyWithRadius(int km);

  /// No description provided for @promoteLocationModeRegional.
  ///
  /// In en, this message translates to:
  /// **'Regionally'**
  String get promoteLocationModeRegional;

  /// No description provided for @promoteLocationModeRegionalHint.
  ///
  /// In en, this message translates to:
  /// **'Choose country, region, and town'**
  String get promoteLocationModeRegionalHint;

  /// No description provided for @promoteLocationModeMap.
  ///
  /// In en, this message translates to:
  /// **'On map'**
  String get promoteLocationModeMap;

  /// No description provided for @promoteLocationModeMapHint.
  ///
  /// In en, this message translates to:
  /// **'Detect GPS and pick a radius on the map'**
  String get promoteLocationModeMapHint;

  /// No description provided for @promoteSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get promoteSelectCountry;

  /// No description provided for @promoteSelectCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get promoteSelectCountryHint;

  /// No description provided for @promoteSelectRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get promoteSelectRegion;

  /// No description provided for @promoteSelectRegionHint.
  ///
  /// In en, this message translates to:
  /// **'Select region'**
  String get promoteSelectRegionHint;

  /// No description provided for @promoteSelectTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get promoteSelectTown;

  /// No description provided for @promoteSelectTownHint.
  ///
  /// In en, this message translates to:
  /// **'Select town'**
  String get promoteSelectTownHint;

  /// No description provided for @promoteLocationRegionalSummary.
  ///
  /// In en, this message translates to:
  /// **'{town} · {region} · {country}'**
  String promoteLocationRegionalSummary(String town, String region, String country);

  /// No description provided for @promoteLocationCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a country.'**
  String get promoteLocationCountryRequired;

  /// No description provided for @promoteLocationRegionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a region.'**
  String get promoteLocationRegionRequired;

  /// No description provided for @promoteLocationTownRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a town.'**
  String get promoteLocationTownRequired;

  /// No description provided for @promoteLocationTownCoordinatesRequired.
  ///
  /// In en, this message translates to:
  /// **'This town has no coordinates. Please choose another town.'**
  String get promoteLocationTownCoordinatesRequired;

  /// No description provided for @promoteLocationMapRequired.
  ///
  /// In en, this message translates to:
  /// **'Please allow location or pick a point on the map.'**
  String get promoteLocationMapRequired;

  /// No description provided for @promoteOverviewSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get promoteOverviewSubtotal;

  /// No description provided for @promoteOverviewTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get promoteOverviewTotal;

  /// No description provided for @promoteNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get promoteNext;

  /// No description provided for @promotePayStart.
  ///
  /// In en, this message translates to:
  /// **'Pay and start promotion'**
  String get promotePayStart;

  /// No description provided for @promoteQuickPack.
  ///
  /// In en, this message translates to:
  /// **'Ready-to-use promotion pack'**
  String get promoteQuickPack;

  /// No description provided for @promoteStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String promoteStepOf(int current, int total);

  /// No description provided for @promoteInsightsDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Promoted posts'**
  String get promoteInsightsDashboardTitle;

  /// No description provided for @promoteInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Promotion insights'**
  String get promoteInsightsTitle;

  /// No description provided for @promoteInsightsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No promoted posts yet'**
  String get promoteInsightsEmptyTitle;

  /// No description provided for @promoteInsightsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Promote a video from your feed to see performance here.'**
  String get promoteInsightsEmptyHint;

  /// No description provided for @promoteInsightsPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get promoteInsightsPerformanceTitle;

  /// No description provided for @promoteInsightsPromotedImpressions.
  ///
  /// In en, this message translates to:
  /// **'Promoted impressions'**
  String get promoteInsightsPromotedImpressions;

  /// No description provided for @promoteInsightsFollowersGained.
  ///
  /// In en, this message translates to:
  /// **'Followers gained'**
  String get promoteInsightsFollowersGained;

  /// No description provided for @promoteInsightsSpend.
  ///
  /// In en, this message translates to:
  /// **'Promotion spend'**
  String get promoteInsightsSpend;

  /// No description provided for @promoteInsightsEngagementRate.
  ///
  /// In en, this message translates to:
  /// **'Engagement rate'**
  String get promoteInsightsEngagementRate;

  /// No description provided for @promoteInsightsShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get promoteInsightsShares;

  /// No description provided for @promoteInsightsCostPerImpression.
  ///
  /// In en, this message translates to:
  /// **'Cost / impression'**
  String get promoteInsightsCostPerImpression;

  /// No description provided for @promoteInsightsCostPerView.
  ///
  /// In en, this message translates to:
  /// **'Cost / view'**
  String get promoteInsightsCostPerView;

  /// No description provided for @promoteInsightsUniqueViewers.
  ///
  /// In en, this message translates to:
  /// **'Unique viewers'**
  String get promoteInsightsUniqueViewers;

  /// No description provided for @promoteInsightsChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Impressions (last 7 days)'**
  String get promoteInsightsChartTitle;

  /// No description provided for @promoteInsightsNoChartData.
  ///
  /// In en, this message translates to:
  /// **'No impression data yet'**
  String get promoteInsightsNoChartData;

  /// No description provided for @promoteInsightsCampaignProgress.
  ///
  /// In en, this message translates to:
  /// **'Campaign progress'**
  String get promoteInsightsCampaignProgress;

  /// No description provided for @promoteInsightsImpressions.
  ///
  /// In en, this message translates to:
  /// **'Impressions'**
  String get promoteInsightsImpressions;

  /// No description provided for @promoteInsightsBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get promoteInsightsBudget;

  /// No description provided for @promoteInsightsPauseCampaign.
  ///
  /// In en, this message translates to:
  /// **'Pause campaign'**
  String get promoteInsightsPauseCampaign;

  /// No description provided for @promoteInsightsResumeCampaign.
  ///
  /// In en, this message translates to:
  /// **'Resume campaign'**
  String get promoteInsightsResumeCampaign;

  /// No description provided for @promoteInsightsCampaignHistory.
  ///
  /// In en, this message translates to:
  /// **'Campaign history'**
  String get promoteInsightsCampaignHistory;

  /// No description provided for @promoteInsightsCampaignHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a campaign to filter stats'**
  String get promoteInsightsCampaignHistoryHint;

  /// No description provided for @promoteInsightsAllCampaigns.
  ///
  /// In en, this message translates to:
  /// **'All campaigns'**
  String get promoteInsightsAllCampaigns;

  /// No description provided for @promoteInsightsMultipleCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Multiple campaigns'**
  String get promoteInsightsMultipleCampaigns;

  /// No description provided for @promoteInsightsViewInsights.
  ///
  /// In en, this message translates to:
  /// **'View insights'**
  String get promoteInsightsViewInsights;

  /// No description provided for @promoteInsightsObjectiveViews.
  ///
  /// In en, this message translates to:
  /// **'Video views'**
  String get promoteInsightsObjectiveViews;

  /// No description provided for @promoteInsightsObjectiveFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get promoteInsightsObjectiveFollowers;

  /// No description provided for @promoteInsightsObjectiveEngagement.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get promoteInsightsObjectiveEngagement;

  /// No description provided for @promoteInsightsObjectiveChallenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get promoteInsightsObjectiveChallenges;

  /// No description provided for @promoteInsightsObjectiveProfileVisits.
  ///
  /// In en, this message translates to:
  /// **'Profile visits'**
  String get promoteInsightsObjectiveProfileVisits;

  /// No description provided for @promoteInsightsObjectiveSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get promoteInsightsObjectiveSales;

  /// No description provided for @promoteInsightsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get promoteInsightsStatusActive;

  /// No description provided for @promoteInsightsStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get promoteInsightsStatusPaused;

  /// No description provided for @promoteInsightsStatusPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Pending payment'**
  String get promoteInsightsStatusPendingPayment;

  /// No description provided for @promoteInsightsStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get promoteInsightsStatusCompleted;

  /// No description provided for @promoteInsightsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get promoteInsightsStatusCancelled;

  /// No description provided for @promoteInsightsCampaignProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'{percent} · {spent} spent'**
  String promoteInsightsCampaignProgressSummary(String percent, String spent);

  /// No description provided for @settingsPromotedPosts.
  ///
  /// In en, this message translates to:
  /// **'Promoted posts'**
  String get settingsPromotedPosts;

  /// No description provided for @soundLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundLabel;

  /// No description provided for @soundNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get soundNoneSelected;

  /// No description provided for @soundPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add sound'**
  String get soundPickerTitle;

  /// No description provided for @soundSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search sounds'**
  String get soundSearchHint;

  /// No description provided for @soundTabTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get soundTabTrending;

  /// No description provided for @soundTabBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get soundTabBrowse;

  /// No description provided for @soundTabMine.
  ///
  /// In en, this message translates to:
  /// **'My sounds'**
  String get soundTabMine;

  /// No description provided for @soundPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sounds found'**
  String get soundPickerEmpty;

  /// No description provided for @soundPickFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Pick from files'**
  String get soundPickFromFiles;

  /// No description provided for @soundUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get soundUseThis;

  /// No description provided for @soundUseThisSound.
  ///
  /// In en, this message translates to:
  /// **'Use this sound'**
  String get soundUseThisSound;

  /// No description provided for @soundConfirmSelection.
  ///
  /// In en, this message translates to:
  /// **'Use selected sound'**
  String get soundConfirmSelection;

  /// No description provided for @soundClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get soundClearSelection;

  /// No description provided for @soundDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundDetailTitle;

  /// No description provided for @soundVideosUsing.
  ///
  /// In en, this message translates to:
  /// **'Videos using this sound'**
  String get soundVideosUsing;

  /// No description provided for @soundNoVideosYet.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get soundNoVideosYet;

  /// No description provided for @soundOriginalLink.
  ///
  /// In en, this message translates to:
  /// **'Original: {name}'**
  String soundOriginalLink(String name);

  /// No description provided for @soundUseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String soundUseCount(int count);

  /// No description provided for @soundUseCountThousands.
  ///
  /// In en, this message translates to:
  /// **'{count}K videos'**
  String soundUseCountThousands(String count);

  /// No description provided for @soundUseCountMillions.
  ///
  /// In en, this message translates to:
  /// **'{count}M videos'**
  String soundUseCountMillions(String count);

  /// No description provided for @interestSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your interests'**
  String get interestSelectionTitle;

  /// No description provided for @interestSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a few categories so we can personalize your experience.'**
  String get interestSelectionSubtitle;

  /// No description provided for @interestSelectionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get interestSelectionSkip;

  /// No description provided for @interestSelectionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get interestSelectionContinue;

  /// No description provided for @interestSelectionMinHint.
  ///
  /// In en, this message translates to:
  /// **'Select at least {count} interests'**
  String interestSelectionMinHint(int count);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;
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
