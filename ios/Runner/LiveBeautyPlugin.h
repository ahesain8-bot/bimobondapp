#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

/// Beauty shader for the live camera on iOS.
///
/// Mirrors the Android `LiveBeautyPlugin`: the effect runs on the frames
/// LiveKit publishes, not on a widget above the preview, so viewers see it too.
@interface LiveBeautyPlugin : NSObject

+ (void)registerWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

NS_ASSUME_NONNULL_END
