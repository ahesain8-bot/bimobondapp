#import "LiveBeautyPlugin.h"

#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <os/lock.h>
#import <WebRTC/WebRTC.h>

#import <flutter_webrtc/FlutterWebRTCPlugin.h>
#import <flutter_webrtc/LocalTrack.h>
#import <flutter_webrtc/LocalVideoTrack.h>
#import <flutter_webrtc/VideoProcessingAdapter.h>

static NSString *const kLiveBeautyChannel = @"com.dubai.bimobondapp/live_beauty";

#pragma mark - Frame processor

/// Runs the beauty chain on every published frame.
///
/// Core Image rather than a hand-written Metal kernel: `CINoiseReduction` is
/// edge-preserving, so it softens skin without melting the eyes and jawline
/// the way a plain blur does, and Apple's filters are already tuned and tested
/// on every device we would otherwise have to validate a custom shader on.
///
/// The Android build gates smoothing by a YCbCr skin probability so the effect
/// only lands on skin. That needs a custom kernel here, so this first version
/// applies the chain to the whole frame — see `eyes`, which has no counterpart
/// without landmarks and is deliberately ignored.
@interface LiveBeautyFrameProcessor : NSObject <ExternalVideoProcessingDelegate>

@property(atomic, assign) BOOL active;
@property(atomic, assign) float smooth;
@property(atomic, assign) float brighten;
@property(atomic, assign) float tone;
@property(atomic, assign) float sharpen;

@end

@implementation LiveBeautyFrameProcessor {
  CIContext *_context;
  CVPixelBufferPoolRef _pool;
  size_t _poolWidth;
  size_t _poolHeight;
  OSType _poolFormat;
  os_unfair_lock _lock;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _lock = OS_UNFAIR_LOCK_INIT;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    // A null working colour space keeps Core Image out of colour management,
    // which on video frames is both faster and closer to what the encoder
    // expects than a round trip through sRGB.
    NSDictionary *options = @{kCIContextWorkingColorSpace : [NSNull null]};
    _context = device ? [CIContext contextWithMTLDevice:device options:options]
                      : [CIContext contextWithOptions:options];
  }
  return self;
}

- (void)dealloc {
  if (_pool) {
    CVPixelBufferPoolRelease(_pool);
    _pool = NULL;
  }
}

- (RTCVideoFrame *)onFrame:(RTCVideoFrame *)frame {
  if (!self.active) {
    return frame;
  }
  if (![frame.buffer isKindOfClass:[RTCCVPixelBuffer class]]) {
    // Anything that is not a pixel buffer (rare on the camera path) is
    // published untouched rather than dropped.
    return frame;
  }

  RTCCVPixelBuffer *source = (RTCCVPixelBuffer *)frame.buffer;
  CVPixelBufferRef input = source.pixelBuffer;
  if (input == NULL) {
    return frame;
  }

  CVPixelBufferRef output = [self outputBufferLike:input];
  if (output == NULL) {
    return frame;
  }

  @try {
    CIImage *image = [CIImage imageWithCVPixelBuffer:input];
    CGRect extent = image.extent;
    image = [self applyBeautyTo:image];
    // Blur-style filters grow the extent; the encoder needs the original size.
    image = [image imageByCroppingToRect:extent];

    [_context render:image toCVPixelBuffer:output];

    RTCCVPixelBuffer *buffer =
        [[RTCCVPixelBuffer alloc] initWithPixelBuffer:output];
    RTCVideoFrame *processed =
        [[RTCVideoFrame alloc] initWithBuffer:buffer
                                     rotation:frame.rotation
                                  timeStampNs:frame.timeStampNs];
    CVPixelBufferRelease(output);
    return processed;
  } @catch (NSException *exception) {
    // A filter failure must never take the broadcast down: the host stays
    // live with an unfiltered frame.
    NSLog(@"[LiveBeauty] frame pass failed: %@", exception.reason);
    CVPixelBufferRelease(output);
    return frame;
  }
}

- (CIImage *)applyBeautyTo:(CIImage *)image {
  CIImage *result = image;

  const float smoothLevel = self.smooth;
  if (smoothLevel > 0.01f) {
    CIFilter *noise = [CIFilter filterWithName:@"CINoiseReduction"];
    [noise setValue:result forKey:kCIInputImageKey];
    // Apple's default noise level is 0.02; past ~0.09 skin turns to wax.
    [noise setValue:@(0.012f + smoothLevel * 0.075f) forKey:@"inputNoiseLevel"];
    [noise setValue:@(0.40f) forKey:@"inputSharpness"];
    CIImage *output = noise.outputImage;
    if (output) {
      result = output;
    }
  }

  const float brightenLevel = self.brighten;
  if (brightenLevel > 0.01f) {
    CIFilter *exposure = [CIFilter filterWithName:@"CIExposureAdjust"];
    [exposure setValue:result forKey:kCIInputImageKey];
    // Two thirds of a stop at full strength — enough to open a face lit by a
    // phone screen without blowing out the room behind it.
    [exposure setValue:@(brightenLevel * 0.65f) forKey:kCIInputEVKey];
    CIImage *output = exposure.outputImage;
    if (output) {
      result = output;
    }
  }

  const float toneLevel = self.tone;
  if (toneLevel > 0.01f) {
    CIFilter *temperature = [CIFilter filterWithName:@"CITemperatureAndTint"];
    [temperature setValue:result forKey:kCIInputImageKey];
    [temperature setValue:[CIVector vectorWithX:6500 Y:0]
                   forKey:@"inputNeutral"];
    [temperature setValue:[CIVector vectorWithX:6500 + toneLevel * 900 Y:0]
                   forKey:@"inputTargetNeutral"];
    CIImage *output = temperature.outputImage;
    if (output) {
      result = output;
    }
  }

  const float sharpenLevel = self.sharpen;
  if (sharpenLevel > 0.01f) {
    CIFilter *sharpen = [CIFilter filterWithName:@"CISharpenLuminance"];
    [sharpen setValue:result forKey:kCIInputImageKey];
    // Puts back some of the detail the smoothing pass takes out.
    [sharpen setValue:@(sharpenLevel * 0.60f) forKey:kCIInputSharpnessKey];
    CIImage *output = sharpen.outputImage;
    if (output) {
      result = output;
    }
  }

  return result;
}

/// A pooled output buffer matching [input]'s size and pixel format.
- (CVPixelBufferRef)outputBufferLike:(CVPixelBufferRef)input {
  const size_t width = CVPixelBufferGetWidth(input);
  const size_t height = CVPixelBufferGetHeight(input);
  const OSType format = CVPixelBufferGetPixelFormatType(input);

  os_unfair_lock_lock(&_lock);
  if (_pool == NULL || width != _poolWidth || height != _poolHeight ||
      format != _poolFormat) {
    if (_pool) {
      CVPixelBufferPoolRelease(_pool);
      _pool = NULL;
    }
    NSDictionary *attributes = @{
      (id)kCVPixelBufferPixelFormatTypeKey : @(format),
      (id)kCVPixelBufferWidthKey : @(width),
      (id)kCVPixelBufferHeightKey : @(height),
      (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
      (id)kCVPixelBufferMetalCompatibilityKey : @YES,
    };
    CVReturn status = CVPixelBufferPoolCreate(
        kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attributes, &_pool);
    if (status != kCVReturnSuccess) {
      _pool = NULL;
      os_unfair_lock_unlock(&_lock);
      return NULL;
    }
    _poolWidth = width;
    _poolHeight = height;
    _poolFormat = format;
  }
  CVPixelBufferPoolRef pool = _pool;
  CVPixelBufferRef output = NULL;
  CVReturn status =
      CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &output);
  os_unfair_lock_unlock(&_lock);

  return status == kCVReturnSuccess ? output : NULL;
}

@end

#pragma mark - Plugin

@implementation LiveBeautyPlugin

static LiveBeautyFrameProcessor *gProcessor = nil;
static NSString *gAttachedTrackId = nil;

+ (void)registerWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  gProcessor = [[LiveBeautyFrameProcessor alloc] init];

  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:kLiveBeautyChannel
                                  binaryMessenger:messenger];

  [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if ([call.method isEqualToString:@"attach"]) {
      result(@([self attach:call.arguments[@"trackId"]]));
    } else if ([call.method isEqualToString:@"detach"]) {
      [self detach];
      result(nil);
    } else if ([call.method isEqualToString:@"setBeauty"]) {
      [self applySettings:call.arguments];
      result(nil);
    } else if ([call.method isEqualToString:@"clearBeauty"]) {
      gProcessor.active = NO;
      result(nil);
    } else {
      result(FlutterMethodNotImplemented);
    }
  }];
}

+ (float)level:(NSDictionary *)arguments key:(NSString *)key {
  NSNumber *value = arguments[key];
  if (![value isKindOfClass:[NSNumber class]]) {
    return 0.0f;
  }
  return fmaxf(0.0f, fminf(1.0f, value.floatValue));
}

+ (void)applySettings:(NSDictionary *)arguments {
  if (![arguments isKindOfClass:[NSDictionary class]]) {
    return;
  }
  const float intensity = [self level:arguments key:@"intensity"];
  const float smooth = [self level:arguments key:@"smooth"] * intensity;
  const float brighten = [self level:arguments key:@"brighten"] * intensity;
  const float tone = [self level:arguments key:@"tone"] * intensity;
  const float sharpen = [self level:arguments key:@"sharpen"] * intensity;

  NSNumber *enabled = arguments[@"enabled"];
  const BOOL wanted = enabled == nil ? YES : enabled.boolValue;

  gProcessor.smooth = smooth;
  gProcessor.brighten = brighten;
  gProcessor.tone = tone;
  gProcessor.sharpen = sharpen;
  // `eyes` is accepted and ignored: the eye lift needs face landmarks, which
  // this version does not run.
  gProcessor.active = wanted && (smooth > 0.01f || brighten > 0.01f ||
                                 tone > 0.01f || sharpen > 0.01f);
}

+ (LocalVideoTrack *)localVideoTrack:(NSString *)trackId {
  FlutterWebRTCPlugin *plugin = [FlutterWebRTCPlugin sharedSingleton];
  if (plugin == nil) {
    return nil;
  }
  id<LocalTrack> track = plugin.localTracks[trackId];
  if (![track isKindOfClass:[LocalVideoTrack class]]) {
    return nil;
  }
  return (LocalVideoTrack *)track;
}

+ (BOOL)attach:(NSString *)trackId {
  if (![trackId isKindOfClass:[NSString class]] || trackId.length == 0) {
    return NO;
  }
  if ([trackId isEqualToString:gAttachedTrackId]) {
    return YES;
  }
  // A camera flip publishes a new track, so the old registration goes first.
  [self detach];

  LocalVideoTrack *track = [self localVideoTrack:trackId];
  if (track == nil) {
    NSLog(@"[LiveBeauty] attach: no local video track for id=%@", trackId);
    return NO;
  }
  [track addProcessing:gProcessor];
  gAttachedTrackId = trackId;
  NSLog(@"[LiveBeauty] processor attached to track=%@", trackId);
  return YES;
}

+ (void)detach {
  if (gAttachedTrackId == nil) {
    return;
  }
  LocalVideoTrack *track = [self localVideoTrack:gAttachedTrackId];
  gAttachedTrackId = nil;
  if (track != nil) {
    [track removeProcessing:gProcessor];
  }
}

@end
