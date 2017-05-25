/*
 * Copyright (C) 2017 Martin Hering
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor,
 * Boston, MA  02110-1301, USA.
 */


#import <Foundation/Foundation.h>
#import "raw.h"
#import "MLVTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class MLVPixelMap;

typedef NS_ENUM(NSInteger, MLVRawImageFocusPixelsType) {
    kMLVRawImageFocusPixelsTypeNone          = 0,

    kMLVRawImageFocusPixelsTypeEOSM          = 1 << 0,
    kMLVRawImageFocusPixelsType100D          = 1 << 1,
    kMLVRawImageFocusPixelsType650D          = 1 << 2,
    kMLVRawImageFocusPixelsType700D          = 1 << 3,

    kMLVRawImageFocusPixelsType1808x728      = 1 << 16,
    kMLVRawImageFocusPixelsType1872x1060     = 1 << 17,
    kMLVRawImageFocusPixelsType1808x1190     = 1 << 18,
    kMLVRawImageFocusPixelsType2592x1108     = 1 << 19,
};

@interface MLVRawImage : NSObject <NSCopying>

- (instancetype) initWithInfo:(struct raw_info)rawInfo buffer:(void*)rawBuffer compressed:(BOOL)compressed;

@property (readonly) struct raw_info* rawInfo;
@property (readonly) void* rawBuffer;
@property (readonly) BOOL compressed;

@property (readonly) NSData* highlightMap;

// improve performance by creating a dead pixel map
@property (readonly) MLVPixelMap* deadPixelMap;
- (void) fixDeadPixelsBasedOnPixelMap:(nullable MLVPixelMap*)pixelMap;

- (void) fixFocusPixelsWithType:(MLVRawImageFocusPixelsType)type withCropX:(UInt16)cropX :(UInt16)cropY;

- (uint32_t) calculatedWhiteLevel;
- (NSData*) findVerticalBandingCoefficients;
- (void) fixVerticalBandingWithCoefficients:(nullable NSData*)coefficients;

- (MLVRawImage*) rawImageByChangingBitsPerPixel:(int32_t)bitsPerPixel;
- (MLVRawImage*) rawImageByDecompressingBuffer;

/* Metadata */
@property (nullable, strong) NSString* camName;
@property (nullable, strong) NSString* camSerial;
@property (nullable, strong) NSString* lensModel;
@property (nullable, strong) NSDate* date;
@property int32_t iso;
@property MLVRational focalLength;
@property MLVRational aperture;
@property MLVRational shutter;
@property MLVRational frameRate;
@property MLVWhiteBalance whiteBalance;
@property MLVCameraMatrices cameraMatrices;
@end

NS_ASSUME_NONNULL_END
