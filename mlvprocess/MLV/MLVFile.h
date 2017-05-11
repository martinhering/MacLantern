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

@class CIContext;
@class CIImage;
@class MLVRawImage;

@class MLVAudioBlock, MLVVideoBlock;
@class MLVLensBlock, MLVExposureBlock, MLVRAWInfoBlock, MLVCameraInfoBlock, MLVWAVInfoBlock, MLVFileBlock;



@interface MLVFile : NSObject <NSSecureCoding>

- (instancetype) initWithURL:(NSURL*)URL;
- (void) changeURL:(NSURL*)url;

@property (readonly, getter=isMissing) BOOL missing;  // file is missing
@property (readonly, getter=isValid) BOOL valid;      // file index is invalid

@property (readonly) NSURL* url;
@property (readonly) CMTime frameTime;
@property (readonly) NSTimeInterval duration;
@property (readonly) NSTimeInterval firstTime;
@property (readonly) UInt64 fileSize;
@property (readonly) NSArray<MLVVideoBlock*>* videoBlocks;
@property (readonly) NSArray<MLVAudioBlock*>* audioBlocks;

@property (readonly) NSDictionary* audioSettings;
@property (readonly) NSDictionary* imageSettings;

- (NSData*) readAudioDataBlock:(MLVAudioBlock*)block errorCode:(MLVErrorCode*)errorCode;
- (MLVRawImage*) readVideoDataBlock:(MLVVideoBlock*)block errorCode:(MLVErrorCode*)errorCode;

@property (readonly) MLVFileBlock* mainheader;
@property (readonly) MLVCameraInfoBlock* idntInfo;
@property (readonly) MLVLensBlock* lensInfo;
@property (readonly) MLVExposureBlock* expoInfo;
@property (readonly) MLVRAWInfoBlock* rawiInfo;
@property (readonly) MLVWAVInfoBlock* waviInfo;
@end

NS_ASSUME_NONNULL_END
