//
//  DIYAV.m
//  DIYAV
//
//  Created by Jonathan Beilin on 1/22/13.
//  Copyright (c) 2013 DIY. All rights reserved.
//

#import "DIYAV.h"

#import "DIYAVDefaults.h"
#import "DIYAVUtilities.h"
#import "DIYAVPreview.h"

#import "Underscore.h"

NSString *const AVSettingFlash                  = @"AVSettingFlash";
NSString *const AVSettingOrientationForce       = @"AVSettingOrientationForce";
NSString *const AVSettingOrientationDefault     = @"AVSettingOrientationDefault";
NSString *const AVSettingCameraPosition         = @"AVSettingCameraPosition";
NSString *const AVSettingCameraHighISO          = @"AVSettingCameraHighISO";
NSString *const AVSettingPhotoPreset            = @"AVSettingPhotoPreset";
NSString *const AVSettingPhotoGravity           = @"AVSettingPhotoGravity";
NSString *const AVSettingVideoPreset            = @"AVSettingVideoPreset";
NSString *const AVSettingVideoGravity           = @"AVSettingVideoGravity";
NSString *const AVSettingVideoMaxDuration       = @"AVSettingVideoMaxDuration";
NSString *const AVSettingVideoFPS               = @"AVSettingVideoFPS";
NSString *const AVSettingSaveLibrary            = @"AVSettingSaveLibrary";

@interface DIYAV ()

@property NSDictionary              *options;

@property DIYAVPreview              *preview;
@property AVCaptureSession          *session;
@property AVCaptureDeviceInput      *videoInput;
@property AVCaptureDeviceInput      *audioInput;
@property AVCaptureStillImageOutput *stillImageOutput;
@property AVCaptureMovieFileOutput  *movieFileOutput;

@end

@implementation DIYAV

#pragma mark - Init

- (id)init
{
    if (self = [super init]) {
        // Properties - should get moved to DIYAV
        _captureMode            = DIYAVModePhoto;
        _session                = [[AVCaptureSession alloc] init];
        
        _preview                = [[DIYAVPreview alloc] initWithSession:_session];
        _videoInput             = nil;
        _audioInput             = nil;
        _stillImageOutput       = [[AVCaptureStillImageOutput alloc] init];
        _movieFileOutput        = [[AVCaptureMovieFileOutput alloc] init];
    }
    
    return self;
}

- (id)initWithOptions:(NSDictionary *)options
{
    NSDictionary *defaultOptions;
    defaultOptions = @{};
    
    // Dict -> Properties
    _options =  Underscore.dict(options)
                .defaults(defaultOptions)
                .pick(@[ @"path" ])
                .each(^(id key, id obj) {
                    [self setValue:obj forKey:key];
                })
                .unwrap;
    
    return self;
}

#pragma mark - Public methods

- (void)startSession
{
    if (self.session != nil && !self.session.isRunning) {
        [self.session startRunning];
    }
}

- (void)stopSession
{
    if (self.session != nil && self.session.isRunning) {
        [self.session stopRunning];
    }
}

- (void)focusAtPoint:(CGPoint)point inFrame:(CGRect)frame
{
    if (self.videoInput.device.isFocusPointOfInterestSupported && [self.videoInput.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        
        CGPoint focusPoint = [DIYAVUtilities convertToPointOfInterestFromViewCoordinates:point withFrame:frame withPreview:self.preview withPorts:self.videoInput.ports];
        NSError *error;
        if ([self.videoInput.device lockForConfiguration:&error]) {
            self.videoInput.device.focusPointOfInterest = focusPoint;
            self.videoInput.device.focusMode = AVCaptureFocusModeAutoFocus;
            [self.videoInput.device unlockForConfiguration];
        }
        else {
            [self.delegate AVDidFail:self withError:error];
        }
    }
}

- (void)capturePhoto
{
    if (self.session != nil) {
        
        // Connection
        AVCaptureConnection *stillImageConnection = [DIYAVUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
        if (DEVICE_ORIENTATION_FORCE) {
            stillImageConnection.videoOrientation = DEVICE_ORIENTATION_DEFAULT;
        } else {
            stillImageConnection.videoOrientation = [[UIDevice currentDevice] orientation];
        }
        
        // Capture image async block
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            [self.delegate AVCaptureOutputStill:imageDataSampleBuffer withError:error];
        }];
    } else {
        [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:500 userInfo:nil]];
    }
}

- (void)captureVideoStart
{
    if (self.session != nil) {
        [self setIsRecording:true];
        [self.delegate AVCaptureStarted:self];
        
        // Create URL to record to
        NSString *assetPath         = [DIYAVUtilities createAssetFilePath:@"mov"];
        NSURL *outputURL            = [[NSURL alloc] initFileURLWithPath:assetPath];
        NSFileManager *fileManager  = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:assetPath]) {
            NSError *error;
            if ([fileManager removeItemAtPath:assetPath error:&error] == NO) {
                [self.delegate AVDidFail:self withError:error];
            }
        }
        
        // Record in the correct orientation
        AVCaptureConnection *videoConnection = [DIYAVUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[self.movieFileOutput connections]];
        if ([videoConnection isVideoOrientationSupported] && !DEVICE_ORIENTATION_FORCE) {
            [videoConnection setVideoOrientation:[DIYAVUtilities getAVCaptureOrientationFromDeviceOrientation]];
        } else {
            [videoConnection setVideoOrientation:DEVICE_ORIENTATION_DEFAULT];
        }
        
        // Start recording
        [self.movieFileOutput startRecordingToOutputFileURL:outputURL recordingDelegate:self];
    }
}

- (void)captureVideoStop
{
    if (self.session != nil && self.isRecording)
    {
        [self setIsRecording:false];
        [self.delegate AVCaptureStopped:self];
        
        [self.movieFileOutput stopRecording];
    }
}

#pragma mark - Override

- (void)setCaptureMode:(DIYAVMode)captureMode
{
    // Super
    self->_captureMode = captureMode;
    
    //
    
    [self.delegate AVModeWillChange:self mode:captureMode];
    
    switch (captureMode) {
            // Photo mode
            // -------------------------------------
        case DIYAVModePhoto:
            if ([DIYAVUtilities isPhotoCameraAvailable]) {
                [self establishPhotoMode];
            } else {
                [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.cam" code:100 userInfo:nil]];
            }
            break;
            
            // Video mode
            // -------------------------------------
        case DIYAVModeVideo:
            if ([DIYAVUtilities isVideoCameraAvailable]) {
                [self establishVideoMode];
            } else {
                [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.cam" code:101 userInfo:nil]];
            }
            break;
    }
    
    [self.delegate AVModeDidChange:self mode:captureMode];
}

#pragma mark - Private methods

- (void)purgeMode
{
    [self stopSession];
    
    for (AVCaptureInput *input in self.session.inputs) {
        [self.session removeInput:input];
    }
    
    for (AVCaptureOutput *output in self.session.outputs) {
        [self.session removeOutput:output];
    }
    
    [self.preview removeFromSuperlayer];
}

- (void)establishPhotoMode
{
    [self purgeMode];
    
    // Flash & torch support
    // ---------------------------------
    [DIYAVUtilities setFlash:DEVICE_FLASH];
    
    // Inputs
    // ---------------------------------
    AVCaptureDevice *videoDevice    = [DIYAVUtilities camera];
    if (videoDevice) {
        NSError *error;
        self.videoInput             = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        [DIYAVUtilities setHighISO:DEVICE_HI_ISO];
        if (!error) {
            if ([self.session canAddInput:self.videoInput]) {
                [self.session addInput:self.videoInput];
            } else {
                [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:201 userInfo:nil]];
            }
        } else {
            [[self delegate] AVDidFail:self withError:error];
        }
    } else {
        [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:200 userInfo:nil]];
    }
    
    // Outputs
    // ---------------------------------
    NSDictionary *stillOutputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    self.stillImageOutput.outputSettings = stillOutputSettings;
    [self.session addOutput:self.stillImageOutput];
    
    // Preset
    // ---------------------------------
    self.session.sessionPreset = AVCaptureSessionPresetMedium;
    if ([self.session canSetSessionPreset:PHOTO_SESSION_PRESET]) {
        self.session.sessionPreset = PHOTO_SESSION_PRESET;
    }
    
    // Preview
    // ---------------------------------
    self.preview.videoGravity   = AVLayerVideoGravityResizeAspectFill;
//    self.preview.frame          = self.frame;
    [self.preview reset];
//    [self.layer addSublayer:self.preview];
    [self.delegate AVAttachPreviewLayer:self.preview];
    
    // Start session
    // ---------------------------------
    [self startSession];
}

- (void)establishVideoMode
{
    [self purgeMode];
    
    // Flash & torch support
    // ---------------------------------
    [DIYAVUtilities setFlash:DEVICE_FLASH];
    
    // Inputs
    // ---------------------------------
    AVCaptureDevice *videoDevice    = [DIYAVUtilities camera];
    if (videoDevice) {
        NSError *error;
        self.videoInput             = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        [DIYAVUtilities setHighISO:DEVICE_HI_ISO];
        if (!error) {
            if ([self.session canAddInput:self.videoInput]) {
                [self.session addInput:self.videoInput];
            } else {
                [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:201 userInfo:nil]];
            }
        } else {
            [[self delegate] AVDidFail:self withError:error];
        }
    } else {
        [self.delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:200 userInfo:nil]];
    }
    
    AVCaptureDevice *audioDevice    = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (audioDevice)
    {
        NSError *error              = nil;
        self.audioInput             = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        if (!error)
        {
            [self.session addInput:self.audioInput];
        } else {
            [self.delegate AVDidFail:self withError:error];
        }
    }
    
    // Outputs
    // ---------------------------------
    Float64 TotalSeconds                            = VIDEO_MAX_DURATION;			// Max seconds
    int32_t preferredTimeScale                      = VIDEO_FPS;                // Frames per second
    CMTime maxDuration                              = CMTimeMakeWithSeconds(TotalSeconds, preferredTimeScale);
    self.movieFileOutput.maxRecordedDuration        = maxDuration;
    self.movieFileOutput.minFreeDiskSpaceLimit      = DEVICE_DISK_MINIMUM;
    [self.session addOutput:self.movieFileOutput];
    AVCaptureConnection *CaptureConnection          = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
	// Set frame rate (if requried)
	CMTimeShow(CaptureConnection.videoMinFrameDuration);
	CMTimeShow(CaptureConnection.videoMaxFrameDuration);
    
	if (CaptureConnection.supportsVideoMinFrameDuration)
    {
        CaptureConnection.videoMinFrameDuration = CMTimeMake(1, VIDEO_FPS);
    }
	if (CaptureConnection.supportsVideoMaxFrameDuration)
    {
        CaptureConnection.videoMaxFrameDuration = CMTimeMake(1, VIDEO_FPS);
    }
    
	CMTimeShow(CaptureConnection.videoMinFrameDuration);
	CMTimeShow(CaptureConnection.videoMaxFrameDuration);
    
    // Preset
    // ---------------------------------
    self.session.sessionPreset = AVCaptureSessionPresetMedium;
    if ([self.session canSetSessionPreset:VIDEO_SESSION_PRESET]) {
        self.session.sessionPreset = VIDEO_SESSION_PRESET;
    }
    
    // Preview
    // ---------------------------------
    self.preview.videoGravity   = AVLayerVideoGravityResizeAspectFill;
//    self.preview.frame          = self.frame;
    [self.preview reset];
    [self.delegate AVAttachPreviewLayer:self.preview];
    
    // Start session
    // ---------------------------------
    [self startSession];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    [self.delegate AVcaptureOutput:captureOutput didFinishRecordingToOutputFileAtURL:outputFileURL fromConnections:connections error:error];
}

#pragma mark - Dealloc

- (void)dealloc
{
    [self purgeMode];
    self.delegate = nil;
}

@end
