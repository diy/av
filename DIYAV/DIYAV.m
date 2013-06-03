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

#import "Underscore.h"

NSString *const DIYAVSettingFlash                  = @"DIYAVSettingFlash";
NSString *const DIYAVSettingOrientationForce       = @"DIYAVSettingOrientationForce";
NSString *const DIYAVSettingOrientationDefault     = @"DIYAVSettingOrientationDefault";
NSString *const DIYAVSettingCameraPosition         = @"DIYAVSettingCameraPosition";
NSString *const DIYAVSettingCameraHighISO          = @"DIYAVSettingCameraHighISO";
NSString *const DIYAVSettingPhotoPreset            = @"DIYAVSettingPhotoPreset";
NSString *const DIYAVSettingPhotoGravity           = @"DIYAVSettingPhotoGravity";
NSString *const DIYAVSettingVideoPreset            = @"DIYAVSettingVideoPreset";
NSString *const DIYAVSettingVideoGravity           = @"DIYAVSettingVideoGravity";
NSString *const DIYAVSettingVideoMaxDuration       = @"DIYAVSettingVideoMaxDuration";
NSString *const DIYAVSettingVideoFPS               = @"DIYAVSettingVideoFPS";
NSString *const DIYAVSettingSaveLibrary            = @"DIYAVSettingSaveLibrary";

@interface DIYAV ()
{
    NSDictionary                *_options;
    
    AVCaptureVideoPreviewLayer  *_preview;
    AVCaptureSession            *_session;
    AVCaptureDeviceInput        *_videoInput;
    AVCaptureDeviceInput        *_audioInput;
    AVCaptureStillImageOutput   *_stillImageOutput;
    AVCaptureMovieFileOutput    *_movieFileOutput;
}
@end

@implementation DIYAV

@synthesize delegate        = _delegate;
@synthesize captureMode     = _captureMode;
@synthesize isRecording     = _isRecording;
@synthesize flash           = _flash;
@synthesize cameraPosition  = _cameraPosition;

#pragma mark - Init

- (void)_setupWithOptions:(NSDictionary *)options
{
    // Options
    NSDictionary *defaultOptions;
    defaultOptions          = @{ DIYAVSettingFlash              : @false,
                                 DIYAVSettingOrientationForce   : @false,
                                 DIYAVSettingOrientationDefault : [NSNumber numberWithInt:AVCaptureVideoOrientationLandscapeRight],
                                 DIYAVSettingCameraPosition     : [NSNumber numberWithInt:AVCaptureDevicePositionBack],
                                 DIYAVSettingCameraHighISO      : @true,
                                 DIYAVSettingPhotoPreset        : AVCaptureSessionPresetPhoto,
                                 DIYAVSettingPhotoGravity       : AVLayerVideoGravityResizeAspectFill,
                                 DIYAVSettingVideoPreset        : AVCaptureSessionPreset1280x720,
                                 DIYAVSettingVideoGravity       : AVLayerVideoGravityResizeAspectFill,
                                 DIYAVSettingVideoMaxDuration   : @300,
                                 DIYAVSettingVideoFPS           : @30,
                                 DIYAVSettingSaveLibrary        : @true };
    
    _options                = Underscore.dict(options)
    .defaults(defaultOptions)
    .unwrap;
    
    _flash                  = [[_options valueForKey:DIYAVSettingFlash] boolValue];
    _cameraPosition         = [[_options valueForKey:DIYAVSettingCameraPosition] integerValue];
    
    // AV setup
    _captureMode            = DIYAVModePhoto;
    _session                = [[AVCaptureSession alloc] init];
    
    // Preview settings
    _preview                = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    
    _videoInput             = nil;
    _audioInput             = nil;
    _stillImageOutput       = [[AVCaptureStillImageOutput alloc] init];
    _movieFileOutput        = [[AVCaptureMovieFileOutput alloc] init];
    
    // Orientation
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
    [self orientationDidChange];
}

- (id)init
{
    self = [super init];
    if (self) {
        [self _setupWithOptions:@{}];
    }
    
    return self;
}

- (id)initWithOptions:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        if (!options) {
            options = @{};
        }
        [self _setupWithOptions:options];
    }
    
    return self;
}

#pragma mark - Public methods

- (void)startSession
{
    if (_session != nil && !_session.isRunning) {
        [_session startRunning];
    }
}

- (void)stopSession
{
    if (_session != nil && _session.isRunning) {
        [_session stopRunning];
    }
}

- (void)focusAtPoint:(CGPoint)point inFrame:(CGRect)frame
{
    if (_videoInput.device.isFocusPointOfInterestSupported && [_videoInput.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        
        CGPoint focusPoint = [DIYAVUtilities convertToPointOfInterestFromViewCoordinates:point withFrame:frame withPreview:_preview withPorts:_videoInput.ports];
        NSError *error;
        if ([_videoInput.device lockForConfiguration:&error]) {
            _videoInput.device.focusPointOfInterest = focusPoint;
            _videoInput.device.focusMode = AVCaptureFocusModeAutoFocus;
            [_videoInput.device unlockForConfiguration];
        }
        else {
            [_delegate AVDidFail:self withError:error];
        }
    }
}

- (void)capturePhoto
{
    if (_session != nil) {
        
        // Connection
        AVCaptureConnection *stillImageConnection = [DIYAVUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[_stillImageOutput connections]];
        if ([[_options valueForKey:DIYAVSettingOrientationForce] boolValue]) {
            stillImageConnection.videoOrientation = [[_options valueForKey:DIYAVSettingOrientationDefault] integerValue];
        }
        
        // Capture image async block
        [_stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            [_delegate AVCaptureOutputStill:imageDataSampleBuffer shouldSaveToLibrary:[[_options valueForKey:DIYAVSettingSaveLibrary] boolValue] withError:error];
        }];
    } else {
        [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:500 userInfo:nil]];
    }
}

- (void)captureVideoStart
{
    if ([DIYAVUtilities getFreeDiskSpace] < DEVICE_DISK_MINIMUM) {
        [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:500 userInfo:@{NSLocalizedDescriptionKey : @"Insufficient disk space to record video"}]];
    }
    
    else if (_session != nil) {
        [self setIsRecording:true];
        [_delegate AVCaptureStarted:self];
        
        // Create URL to record to
        NSString *assetPath         = [DIYAVUtilities createAssetFilePath:@"mov"];
        NSURL *outputURL            = [[NSURL alloc] initFileURLWithPath:assetPath];
        NSFileManager *fileManager  = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:assetPath]) {
            NSError *error;
            if ([fileManager removeItemAtPath:assetPath error:&error] == NO) {
                [_delegate AVDidFail:self withError:error];
            }
        }
        
        // Record in the correct orientation
        AVCaptureConnection *videoConnection = [DIYAVUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[_movieFileOutput connections]];
        
        if ([videoConnection isVideoOrientationSupported]){
            if([[_options valueForKey:DIYAVSettingOrientationForce] boolValue]) {
                [videoConnection setVideoOrientation:[[_options valueForKey:DIYAVSettingOrientationDefault] integerValue]];
            } else {
                [videoConnection setVideoOrientation:[DIYAVUtilities getAVCaptureOrientationFromDeviceOrientation]];
            }
        }
        
        // Start recording
        [_movieFileOutput startRecordingToOutputFileURL:outputURL recordingDelegate:self];
    }
}

- (void)captureVideoStop
{
    if (_session != nil && _isRecording)
    {
        [self setIsRecording:false];
        [_delegate AVCaptureStopped:self];
        
        [_movieFileOutput stopRecording];
    }
}

#pragma mark - Override

- (void)setFlash:(BOOL)flash
{
    self->_flash = flash;
    if (_captureMode == DIYAVModePhoto) {
        [DIYAVUtilities setFlash:_flash forCameraInPosition:_cameraPosition];
    }
    else if (_captureMode == DIYAVModeVideo) {
        [DIYAVUtilities setTorch:_flash forCameraInPosition:_cameraPosition];
    }
}

- (void)setCameraPosition:(int)cameraPosition
{
    self->_cameraPosition = cameraPosition;
    [self setCaptureMode:_captureMode];
}

- (void)setCaptureMode:(DIYAVMode)captureMode
{
    // Super
    self->_captureMode = captureMode;
    
    //
    
    [_delegate AVModeWillChange:self mode:captureMode];
    
    switch (captureMode) {
            // Photo mode
            // -------------------------------------
        case DIYAVModePhoto:
            if ([DIYAVUtilities isPhotoCameraAvailable]) {
                [self establishPhotoMode];
            } else {
                [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.cam" code:100 userInfo:nil]];
            }
            break;
            
            // Video mode
            // -------------------------------------
        case DIYAVModeVideo:
            if ([DIYAVUtilities isVideoCameraAvailable]) {
                [self establishVideoMode];
            } else {
                [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.cam" code:101 userInfo:nil]];
            }
            break;
    }
    
    [_delegate AVModeDidChange:self mode:captureMode];
}

#pragma mark - Private methods

- (void)purgeMode
{
    [self stopSession];
    
    for (AVCaptureInput *input in _session.inputs) {
        [_session removeInput:input];
    }
    
    for (AVCaptureOutput *output in _session.outputs) {
        [_session removeOutput:output];
    }
    
    [_preview removeFromSuperlayer];
}

- (void)establishPhotoMode
{
    [self purgeMode];
    
    // Flash & torch support
    // ---------------------------------
    [DIYAVUtilities setFlash:_flash forCameraInPosition:_cameraPosition];
    
    // Inputs
    // ---------------------------------
    AVCaptureDevice *videoDevice    = [DIYAVUtilities cameraInPosition:_cameraPosition];
    if (videoDevice) {
        NSError *error;
        _videoInput             = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        [DIYAVUtilities setHighISO:[[_options valueForKey:DIYAVSettingCameraHighISO] boolValue] forCameraInPosition:_cameraPosition];
        if (!error) {
            if ([_session canAddInput:_videoInput]) {
                [_session addInput:_videoInput];
            } else {
                [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:201 userInfo:nil]];
            }
        } else {
            [[self delegate] AVDidFail:self withError:error];
        }
    } else {
        [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:200 userInfo:nil]];
    }
    
    // Outputs
    // ---------------------------------
    NSDictionary *stillOutputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    _stillImageOutput.outputSettings = stillOutputSettings;
    [_session addOutput:_stillImageOutput];
    
    // Preset
    // ---------------------------------
    _session.sessionPreset = AVCaptureSessionPresetMedium;
    if ([_session canSetSessionPreset:[_options valueForKey:DIYAVSettingPhotoPreset]]) {
        _session.sessionPreset = [_options valueForKey:DIYAVSettingPhotoPreset];
    }
    
    // Preview
    // ---------------------------------
    _preview.videoGravity   = AVLayerVideoGravityResizeAspectFill;
    [self orientationDidChange];
    [_delegate AVAttachPreviewLayer:_preview];
    
    // Start session
    // ---------------------------------
    [self startSession];
}

- (void)establishVideoMode
{
    [self purgeMode];
    
    // Flash & torch support
    // ---------------------------------
    [DIYAVUtilities setTorch:_flash forCameraInPosition:_cameraPosition];
    
    // Inputs
    // ---------------------------------
    AVCaptureDevice *videoDevice    = [DIYAVUtilities cameraInPosition:_cameraPosition];
    if (videoDevice) {
        NSError *error;
        _videoInput             = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        [DIYAVUtilities setHighISO:[[_options valueForKey:DIYAVSettingCameraHighISO] boolValue] forCameraInPosition:_cameraPosition];
        if (!error) {
            if ([_session canAddInput:_videoInput]) {
                [_session addInput:_videoInput];
            } else {
                [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:201 userInfo:nil]];
            }
        } else {
            [[self delegate] AVDidFail:self withError:error];
        }
    } else {
        [_delegate AVDidFail:self withError:[NSError errorWithDomain:@"com.diy.av" code:200 userInfo:nil]];
    }
    
    AVCaptureDevice *audioDevice    = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (audioDevice)
    {
        NSError *error              = nil;
        _audioInput             = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        if (!error)
        {
            [_session addInput:_audioInput];
        } else {
            [_delegate AVDidFail:self withError:error];
        }
    }
    
    // Outputs
    // ---------------------------------
    Float64 TotalSeconds                            = [[_options valueForKey:DIYAVSettingVideoMaxDuration] floatValue];			// Max seconds
    int32_t preferredTimeScale                      = [[_options valueForKey:DIYAVSettingVideoFPS] integerValue];                // Frames per second
    CMTime maxDuration                              = CMTimeMakeWithSeconds(TotalSeconds, preferredTimeScale);
    _movieFileOutput.maxRecordedDuration        = maxDuration;
    _movieFileOutput.minFreeDiskSpaceLimit      = DEVICE_DISK_MINIMUM;
    [_session addOutput:_movieFileOutput];
    AVCaptureConnection *CaptureConnection          = [_movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
	// Set frame rate (if requried)
	CMTimeShow(CaptureConnection.videoMinFrameDuration);
	CMTimeShow(CaptureConnection.videoMaxFrameDuration);
    
	if (CaptureConnection.supportsVideoMinFrameDuration)
    {
        CaptureConnection.videoMinFrameDuration = CMTimeMake(1, [[_options valueForKey:DIYAVSettingVideoFPS] integerValue]);
    }
	if (CaptureConnection.supportsVideoMaxFrameDuration)
    {
        CaptureConnection.videoMaxFrameDuration = CMTimeMake(1, [[_options valueForKey:DIYAVSettingVideoFPS] integerValue]);
    }
    
	CMTimeShow(CaptureConnection.videoMinFrameDuration);
	CMTimeShow(CaptureConnection.videoMaxFrameDuration);
    
    // Preset
    // ---------------------------------
    _session.sessionPreset = AVCaptureSessionPresetMedium;
    if ([_session canSetSessionPreset:[_options valueForKey:DIYAVSettingVideoPreset]]) {
        _session.sessionPreset = [_options valueForKey:DIYAVSettingVideoPreset];
    }
    
    // Preview
    // ---------------------------------
    _preview.videoGravity   = AVLayerVideoGravityResizeAspectFill;
    [self orientationDidChange];
    [_delegate AVAttachPreviewLayer:_preview];
    
    // Start session
    // ---------------------------------
    [self startSession];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    [_delegate AVcaptureOutput:captureOutput didFinishRecordingToOutputFileAtURL:outputFileURL shouldSaveToLibrary:[[_options valueForKey:DIYAVSettingSaveLibrary] boolValue] fromConnections:connections error:error];
}

#pragma mark - Orientation management

- (void)orientationDidChange
{
    AVCaptureVideoOrientation newOrientation = [[_options valueForKey:DIYAVSettingOrientationDefault] integerValue];
    
    BOOL forceOrientation = [[_options valueForKey:DIYAVSettingOrientationForce] boolValue];
    AVCaptureConnection *connection;
    if (_captureMode == DIYAVModePhoto) {
        connection = [DIYAVUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[_stillImageOutput connections]];
    } else {
        connection = [DIYAVUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[_movieFileOutput connections]];
    }
    
    if (!forceOrientation && connection.isVideoOrientationSupported) {
        UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
        
        switch (deviceOrientation) {
            case UIDeviceOrientationPortrait:
                newOrientation = AVCaptureVideoOrientationPortrait;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                newOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                break;
            case UIDeviceOrientationLandscapeLeft:
                newOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIDeviceOrientationLandscapeRight:
                newOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            default:
                return;
                break;
        }
    }
    
    if (forceOrientation || connection.isVideoOrientationSupported) {
        CGSize newSize = [self sizeForOrientation:[self isOrientationLandscape:newOrientation]];
        connection.videoOrientation     = newOrientation;
        _preview.frame                  = CGRectMake(0, 0, newSize.width, newSize.height);
        
        //update preview orientation
        if([_preview respondsToSelector:@selector(connection)]){
            //iOS6+
            _preview.connection.videoOrientation = newOrientation;
        }else if([_preview respondsToSelector:@selector(orientation)]){
            //iOS5 -
            if(_preview.orientationSupported){
                _preview.orientation = newOrientation;
            }
        }
    }
}

- (BOOL)isOrientationLandscape:(AVCaptureVideoOrientation)videoOrientation
{
    BOOL isLandscape;
    
    switch (videoOrientation) {
        case AVCaptureVideoOrientationPortrait:
            isLandscape = false;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            isLandscape = false;
            break;
        case UIDeviceOrientationLandscapeLeft:
            isLandscape = true;
            break;
        case UIDeviceOrientationLandscapeRight:
            isLandscape = true;
            break;
        default:
            return false;
            break;
    }
    
    return isLandscape;
}

- (CGSize)sizeForOrientation:(BOOL)landscape
{
    CGFloat x = _preview.frame.size.width;
    CGFloat y = _preview.frame.size.height;
    
    if (landscape) {
        return (x > y) ? CGSizeMake(x, y) : CGSizeMake(y, x);
    }
    
    return (x <= y) ? CGSizeMake(x, y) : CGSizeMake(y, x);
}

#pragma mark - Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self purgeMode];
    _delegate = nil;
}

@end
