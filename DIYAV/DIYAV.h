//
//  DIYAV.h
//  DIYAV
//
//  Created by Jonathan Beilin on 1/22/13.
//  Copyright (c) 2013 DIY. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "DIYAVDefaults.h"

@class DIYAVPreview;
@class DIYAV;

typedef enum {
    DIYAVModePhoto,
    DIYAVModeVideo
} DIYAVMode;

// Settings
NSString *const AVSettingFlash;
NSString *const AVSettingOrientationForce;
NSString *const AVSettingOrientationDefault;
NSString *const AVSettingCameraPosition;
NSString *const AVSettingCameraHighISO;
NSString *const AVSettingPhotoPreset;
NSString *const AVSettingPhotoGravity;
NSString *const AVSettingVideoPreset;
NSString *const AVSettingVideoGravity;
NSString *const AVSettingVideoMaxDuration;
NSString *const AVSettingVideoFPS;
NSString *const AVSettingSaveLibrary;


//

@protocol DIYAVDelegate <NSObject>
@required
- (void)AVReady:(DIYAV *)av;
- (void)AVDidFail:(DIYAV *)av withError:(NSError *)error;

- (void)AVModeWillChange:(DIYAV *)av mode:(DIYAVMode)mode;
- (void)AVModeDidChange:(DIYAV *)av mode:(DIYAVMode)mode;

- (void)AVCaptureStarted:(DIYAV *)av;
- (void)AVCaptureStopped:(DIYAV *)av;
- (void)AVCaptureProcessing:(DIYAV *)av;
- (void)AVcaptureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;

- (void)AVAttachPreviewLayer:(CALayer *)layer;

- (void)AVCaptureOutputStill:(CMSampleBufferRef)imageDataSampleBuffer withError:(NSError *)error;
@end

//

@interface DIYAV : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (weak)        id<DIYAVDelegate>   delegate;
@property (nonatomic)   DIYAVMode           captureMode;
@property               BOOL                isRecording;

- (id)initWithOptions:(NSDictionary *)options;

- (void)startSession;
- (void)stopSession;
- (void)focusAtPoint:(CGPoint)point inFrame:(CGRect)frame;
- (void)capturePhoto;
- (void)captureVideoStart;
- (void)captureVideoStop;

@end
