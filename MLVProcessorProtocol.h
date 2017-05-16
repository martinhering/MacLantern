/*
 * Copyright (C) 2017 Martin Hering
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Lesser Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef MLVProcessorProtocol_h
#define MLVProcessorProtocol_h

#define kMLVAttributeKeyManufacturer         @"Manufacturer"            // NSString
#define kMLVAttributeKeyCamera               @"Camera"                  // NSString
#define kMLVAttributeKeyLens                 @"Lens"                    // NSString
#define kMLVAttributeKeyOriginalImageSize    @"Original Image Size"     // NSString(NSSize)
#define kMLVAttributeKeyScaledImageSize      @"Scaled Image Size"       // NSString(NSSize)
#define kMLVAttributeKeyBitsPerSample        @"Bits Per Sample"         // NSNumber
#define kMLVAttributeKeyExposureTime         @"Exposure Time"           // NSNumber: 1000000/x sec
#define kMLVAttributeKeyAperture             @"Aperture"                // NSNumber: y/100
#define kMLVAttributeKeyISO                  @"ISO"                     // NSNumber
#define kMLVAttributeKeyFocalLength          @"Focal Lengh"             // NSNumber
#define kMLVAttributeKeyCompression          @"Compression"             // NSString
#define kMLVAttributeKeyOriginalDate         @"Original Date"           // NSDate
#define kMLVAttributeKeyFileSize             @"File Size"               // NSNumber

#define kMLVAttributeKeyAudioSampleRate      @"Audio Sample Rate"       // NSNumber
#define kMLVAttributeKeyAudioBitsPerSample   @"Audio Bits Per Sample"   // NSNumber
#define kMLVAttributeKeyAudioChannels        @"Audio Channels"          // NSNumber

#define kMLVAttributeKeyDuration             @"Duration"                // NSNumber
#define kMLVAttributeKeyFrameTime            @"Frame Time"              // NSValue: CMTime
#define kMLVAttributeKeyVersion              @"Version"                 // NSNumber

#define kMLVAttributeKeyVideoBlocksCount     @"Video Blocks Count"      // NSNumber
#define kMLVAttributeKeyAudioBlocksCount     @"Audio Blocks Count"      // NSNumber

@protocol MLVProcessorProtocol

- (void) openFileWithURL:(NSURL*)url withReply:(void (^)(NSString *fileId, NSDictionary<NSString*, id>* attributes, NSError* error))reply;
- (void) closeFileWithId:(NSString*)fileId withReply:(void (^)(NSError* error))reply;

- (void) produceArchiveDataWithFileId:(NSString*)fileId withReply:(void (^)(NSData* archiveData, NSError* error))reply;
- (void) openFileWithArchiveData:(NSData*)data withReply:(void (^)(NSString *fileId, NSDictionary<NSString*, id>* attributes, NSError* error))reply;

@end

#endif /* MLVProcessorProtocol_h */
