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

#import "mlvprocess.h"
#import "MLVFile.h"
#import "MLVBlock.h"
#import "MLVRawImage+DNG.h"

#define METADATA_VERSION 3

@implementation mlvprocess {
    NSMutableDictionary<NSString*, MLVFile*>* _openFiles;
}

- (NSMutableDictionary<NSString*, id>*) _attributesWithFile:(MLVFile*)file
{
    NSMutableDictionary<NSString*, id>* attributes = [[NSMutableDictionary alloc] init];
    attributes[kMLVAttributeKeyVideoBlocksCount] = @(file.videoBlocks.count);
    attributes[kMLVAttributeKeyAudioBlocksCount] = @(file.audioBlocks.count);
    attributes[kMLVAttributeKeyVersion] = @(METADATA_VERSION);
    attributes[kMLVAttributeKeyDuration] = @(file.duration);
    attributes[kMLVAttributeKeyFrameTime] = [NSString stringWithFormat:@"%lld/%ld", file.frameTime.value, (long)file.frameTime.timescale];

    MLVCameraInfoBlock* idntInfo = file.idntInfo;
    MLVLensBlock* lensInfo = file.lensInfo;
    MLVExposureBlock* expoInfo = file.expoInfo;
    MLVRAWInfoBlock* rawiInfo = file.rawiInfo;

    attributes[kMLVAttributeKeyManufacturer] = @"Canon";

    if (idntInfo.cameraName) {
        attributes[kMLVAttributeKeyCamera] = idntInfo.cameraName;
    }

    if (lensInfo.lensName) {
        attributes[kMLVAttributeKeyLens] = lensInfo.lensName;
    }

    attributes[kMLVAttributeKeyOriginalImageSize] = NSStringFromSize(NSMakeSize(rawiInfo.xRes, rawiInfo.yRes));
    attributes[kMLVAttributeKeyBitsPerSample] = @(rawiInfo.bitsPerPixel);


    if (expoInfo.isoValue > 0) {
        attributes[kMLVAttributeKeyISO] = @(expoInfo.isoValue);
    }

    if (expoInfo.shutterValue > 0) {
        attributes[kMLVAttributeKeyExposureTime] = @(expoInfo.shutterValue);
    }

    if (lensInfo.aperture > 0) {
        attributes[kMLVAttributeKeyAperture] = @(lensInfo.aperture);
    }

    if (lensInfo.focalLength > 0) {
        attributes[kMLVAttributeKeyFocalLength] = @(lensInfo.focalLength);
    }

    if (file.fileSize > 0) {
        attributes[kMLVAttributeKeyFileSize] = @(file.fileSize);
    }

    if (file.waviInfo.sampleRate > 0) {
        attributes[kMLVAttributeKeyAudioSampleRate] = @(file.waviInfo.sampleRate);
    }

    if (file.waviInfo.bitsPerSample > 0) {
        attributes[kMLVAttributeKeyAudioBitsPerSample] = @(file.waviInfo.bitsPerSample);
    }

    if (file.waviInfo.channels > 0) {
        attributes[kMLVAttributeKeyAudioChannels] = @(file.waviInfo.channels);
    }

    UInt16 videoClassFlags = (file.mainheader.videoClass & 0xe0);
    switch (videoClassFlags) {
        case kMLVFileVideoClassFlagLZMA:
            attributes[kMLVAttributeKeyCompression] = @"LZMA";
            break;
        case kMLVFileVideoClassFlagDelta:
            attributes[kMLVAttributeKeyCompression] = @"Delta";
            break;
        case kMLVFileVideoClassFlagLJ92:
            attributes[kMLVAttributeKeyCompression] = @"Lossless JPEG";
            break;
        default:
            break;
    }
    return attributes;
}

- (void) openFileWithURL:(NSURL*)url withReply:(void (^)(NSString *fileId, NSDictionary<NSString*, id>* attributes, NSData* archiveData, NSError* error))reply
{
    if (!_openFiles) {
        _openFiles = [[NSMutableDictionary alloc] init];
    }

    NSString* fileId = [[NSUUID UUID] UUIDString];
    MLVFile* file = _openFiles[fileId];
    if (!file) {
        file = [[MLVFile alloc] initWithURL:url];
        _openFiles[fileId] = file;
    }

    NSMutableDictionary<NSString*, id>* attributes = [self _attributesWithFile:file];
    NSData* archiveData = [NSKeyedArchiver archivedDataWithRootObject:file];
    reply(fileId, attributes, archiveData, nil);
}

- (void) closeFileWithId:(NSString*)fileId withReply:(void (^)(NSError* error))reply
{
    MLVFile* file = _openFiles[fileId];
    if (!file) {
        NSError* error = NS_ERROR(-1, @"file is not open: %@", fileId);
        reply(error);
        return;
    }

    [_openFiles removeObjectForKey:fileId];
    reply(nil);
}

- (void) openFileWithArchiveData:(NSData*)data withReply:(void (^)(NSString *fileId, NSDictionary<NSString*, id>* attributes, NSError* error))reply
{
    if (!_openFiles) {
        _openFiles = [[NSMutableDictionary alloc] init];
    }

    NSString* fileId = [[NSUUID UUID] UUIDString];
    MLVFile* file = _openFiles[fileId];
    if (!file) {
        file = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        _openFiles[fileId] = file;
    }

    NSMutableDictionary<NSString*, id>* attributes = [self _attributesWithFile:file];
    reply(fileId, attributes, nil);
}

- (void) readVideoFrameAtIndex:(NSInteger)frameIndex fileId:(NSString*)fileId options:(MLVProcessorOptions)options withReply:(void (^)(NSData* dngData, NSData* highlightMap, NSDictionary<NSString*, id>* avSettings, NSError* error))reply
{
    MLVFile* file = _openFiles[fileId];
    if (!file) {
        NSError* error = NS_ERROR(-1, @"file is not open: %@", fileId);
        reply(nil, nil, nil, error);
        return;
    }

    NSArray<MLVVideoBlock*>* videoBlocks = file.videoBlocks;
    if (frameIndex < 0 || frameIndex >= videoBlocks.count) {
        NSError* error = NS_ERROR(-1, @"video frame index is invalid: %ld/%ld", frameIndex, videoBlocks.count);
        reply(nil, nil, nil, error);
        return;
    }

    MLVVideoBlock* videoBlock = videoBlocks[frameIndex];
    MLVErrorCode errorCode = kMLVErrorCodeNone;
    MLVRawImage* rawImage = [file readVideoDataBlock:videoBlock errorCode:&errorCode];

    if (errorCode != kMLVErrorCodeNone) {
        NSError* error = NS_ERROR(-1, @"error while reading video block: %ld", errorCode);
        reply(nil, nil, nil, error);
        return;
    }

    reply(rawImage.dngData, rawImage.highlightMap, file.imageSettings, nil);
}

- (void) readAudioFrameAtIndex:(NSInteger)frameIndex fileId:(NSString*)fileId options:(MLVProcessorOptions)options withReply:(void (^)(NSData* audioData, NSDictionary<NSString*, id>* avSettings, NSError* error))reply
{
    MLVFile* file = _openFiles[fileId];
    if (!file) {
        NSError* error = NS_ERROR(-1, @"file is not open: %@", fileId);
        reply(nil, nil, error);
        return;
    }

    NSArray<MLVAudioBlock*>* audioBlocks = file.audioBlocks;
    if (frameIndex < 0 || frameIndex >= audioBlocks.count) {
        NSError* error = NS_ERROR(-1, @"audio frame index is invalid: %ld/%ld", frameIndex, audioBlocks.count);
        reply(nil, nil, error);
        return;
    }

    MLVAudioBlock* audioBlock = audioBlocks[frameIndex];
    MLVErrorCode errorCode = kMLVErrorCodeNone;
    NSData* data = [file readAudioDataBlock:audioBlock errorCode:&errorCode];

    if (errorCode != kMLVErrorCodeNone) {
        NSError* error = NS_ERROR(-1, @"error while reading audio block: %ld", errorCode);
        reply(nil, nil, error);
        return;
    }

    reply(data, file.audioSettings, nil);
}

@end
