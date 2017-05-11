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
#import <CoreMedia/CoreMedia.h>

#import "MLVTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(UInt32, MLVBlockType) {
    kMLVBlockTypeMLVInfo            = 'MLVI',
    kMLVBlockTypeVideo              = 'VIDF',
    kMLVBlockTypeAudio              = 'AUDF',
    kMLVBlockTypeLens               = 'LENS',
    kMLVBlockTypeInfo               = 'INFO',
    kMLVBlockTypeElectronicLevel    = 'ELVL',
    kMLVBlockTypeStyle              = 'STYL',
    kMLVBlockTypeWhiteBalance       = 'WBAL',
    kMLVBlockTypeIdentification     = 'IDNT',
    kMLVBlockTypeRTCI               = 'RTCI',
    kMLVBlockTypeMarker             = 'MARK',
    kMLVBlockTypeExposure           = 'EXPO',
    kMLVBlockTypeRawInfo            = 'RAWI',
    kMLVBlockTypeRawCaptureInfo     = 'RAWC',
    kMLVBlockTypeWavInfo            = 'WAVI',
    kMLVBlockTypeNull               = 'NULL',
    kMLVBlockTypeBackup             = 'BKUP',
};


@interface MLVBlock : NSObject <NSSecureCoding>

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)position;

@property (readonly) MLVBlockType type;
@property (readonly) UInt32 size;
@property (readonly) UInt64 timestamp;

@property (readonly) UInt16 fileNum;
@property (readonly) UInt64 filePosition;
@property (readonly) NSTimeInterval time;

@end

#pragma mark -

typedef NS_ENUM(UInt32, MLVFileFlags) {
    kMLVFileFlagsNone               = 0,
    kMLVFileFlagsOutOfOrderData     = 1,
    kMLVFileFlagsDroppedFrames      = 2,
    kMLVFileFlagsSingleImageMode    = 4,
    kMLVFileFlagsStopped            = 8
};

typedef NS_ENUM(UInt16, MLVFileVideoClass) {
    kMLVFileVideoClassNone      = 0x00,
    kMLVFileVideoClassRAW       = 0x01,
    kMLVFileVideoClassYUV       = 0x02,
    kMLVFileVideoClassJPEG      = 0x03,
    kMLVFileVideoClassH264      = 0x04,

    kMLVFileVideoClassFlagLZMA  = 0x80,
    kMLVFileVideoClassFlagDelta = 0x40,
    kMLVFileVideoClassFlagLJ92  = 0x20,
};

typedef NS_ENUM(UInt16, MLVFileAudioClass) {
    kMLVFileAudioClass      = 0x00,
    kMLVFileAudioClassWAV   = 0x01,
    kMLVFileAudioClassLZMA  = 0x80,
};

@interface MLVFileBlock : MLVBlock
@property (readonly) NSString* version;
@property (readonly) UInt64 guid;

@property (readonly) UInt16 fileCount;
@property (readonly) MLVFileFlags fileFlags;
@property (readonly) MLVFileVideoClass videoClass;
@property (readonly) MLVFileAudioClass audioClass;
@property (readonly) UInt32 numberOfVideoFrames;
@property (readonly) UInt32 numberOfAudioFrames;
@property (readonly) CMTime sourceFps;
@end



@interface MLVVideoBlock : MLVBlock
@property (readonly) UInt32 frameNumber;
@property (readonly) UInt16 cropPosX;
@property (readonly) UInt16 cropPosY;
@property (readonly) UInt16 panPosX;
@property (readonly) UInt16 panPosY;
@property (readonly) UInt32 frameSpace;

@end

@interface MLVAudioBlock : MLVBlock
@property (readonly) UInt32 frameNumber;
@property (readonly) UInt32 frameSpace;
@end

@interface MLVRAWInfoBlock : MLVBlock
@property (readonly) UInt16 xRes;
@property (readonly) UInt16 yRes;
@property (readonly) UInt32 bitsPerPixel;
@property (readonly) struct raw_info rawInfoStruct;
@end

@interface MLVRAWCaptureInfoBlock : MLVBlock
@end

@interface MLVWAVInfoBlock : MLVBlock
@property (readonly) UInt16 format;
@property (readonly) UInt16 channels;
@property (readonly) UInt32 sampleRate;
@property (readonly) UInt32 bytesPerSecond;
@property (readonly) UInt16 bitsPerSample;
@end

@interface MLVInfoBlock : MLVBlock
- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition stringValue:(NSString*)stringValue;
@property (readonly) NSString* stringValue;
@end


@interface MLVExposureBlock : MLVBlock
@property (readonly) UInt32 isoMode;
@property (readonly) UInt32 isoValue;
@property (readonly) UInt32 isoAnalog;
@property (readonly) UInt32 digitalGain;
@property (readonly) UInt64 shutterValue;
@end

@interface MLVLensBlock : MLVBlock
@property (readonly) UInt16 focalLength;
@property (readonly) UInt16 focalDistance;
@property (readonly) UInt16 aperture;
@property (readonly) BOOL stabilizerMode;
@property (readonly) BOOL autofocusMode;
@property (readonly) UInt32 flags;
@property (readonly) UInt32 lensId;
@property (readonly) NSString* lensName;
@property (readonly) NSString* lensSerial;
@end

@interface MLVTimecodeBlock : MLVBlock
@property (readonly) NSDate* date;
- (NSString*) dngDateTimeWithTimestamp:(UInt64)timestamp;
- (NSString*) dngSubSecTimeWithTimestamp:(UInt64)timestamp;
- (NSDate*) dateWithTimeInterval:(NSTimeInterval)time;
@end

@interface MLVCameraInfoBlock : MLVBlock
@property (readonly) NSString* cameraName;
@property (readonly) MLVCameraModel cameraModel;
@property (readonly) NSString* cameraSerial;
- (BOOL) copyStandardLightAColorMatrix:(int32_t*)outMatrix;
@end

@interface MLVIsoBlock : MLVBlock
@end

@interface MLVStyleBlock : MLVBlock
@end

@interface MLVElectronicLevelBlock : MLVBlock
@end

@interface MLVWhiteBalanceBlock : MLVBlock
@property (readonly) MLVWhiteBalance wbValues;
@end

@interface MLVMarkerBlock : MLVBlock
@end

NS_ASSUME_NONNULL_END
