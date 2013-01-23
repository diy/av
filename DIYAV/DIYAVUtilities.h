//
//  DIYAVUtilities.h
//  DIYAV
//
//  Created by Jonathan Beilin on 1/22/13.
//  Copyright (c) 2013 DIY. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class DIYAVPreview;

@interface DIYAVUtilities : NSObject

+ (AVCaptureDevice *)camera;
+ (BOOL)isPhotoCameraAvailable;
+ (BOOL)isVideoCameraAvailable;
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

+ (void)setFlash:(BOOL)flash;
+ (void)setHighISO:(BOOL)highISO;

+ (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates withFrame:(CGRect)frame withPreview:(DIYAVPreview *)preview withPorts:(NSArray *)ports;

@end
