//
//  DIYAV.h
//  DIYAV
//
//  Created by Jonathan Beilin on 1/22/13.
//  Copyright (c) 2013 DIY. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class DIYAVPreview;
@class DIYAV;

//

typedef enum {
    DIYCamModePhoto,
    DIYCamModeVideo
} DIYCamMode;

@protocol DIYAVDelegate <NSObject>
@required
- (void)AVReady:(DIYAV *)av;
- (void)AVDidFail:(DIYAV *)av withError:(NSError *)error;

- (void)AVModeWillChange:(DIYAV *)av mode:(DIYCamMode)mode;
- (void)AVModeDidChange:(DIYAV *)av mode:(DIYCamMode)mode;

- (void)AVCaptureStarted:(DIYAV *)av;
- (void)AVCaptureStopped:(DIYAV *)av;
- (void)AVCaptureProcessing:(DIYAV *)av;
- (void)AVCaptureComplete:(DIYAV *)av withAsset:(NSDictionary *)asset;
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;

- (void)AVAttachPreviewLayer:(CALayer *)layer;
@end

//

@interface DIYAV : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (weak) id<DIYAVDelegate> delegate;

@end
