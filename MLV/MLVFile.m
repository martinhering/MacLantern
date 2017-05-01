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

#import "MLVFile.h"
#import "mlv.h"
#import "MLVBlock.h"
#import "MLVRawImage.h"

#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <CoreImage/CoreImage.h>
#import <sys/stat.h>


#define MLV_FILE_VERSION 1

@interface MLVFile ()
@property (nonatomic, strong) NSURL* url;
@property (readwrite) BOOL missing;
@end

@implementation MLVFile {
    NSURL* _url;

    FILE **in_files;
    int in_file_count;

    MLVFileBlock*               _mainheader;
    MLVLensBlock*               _lensInfo;
    MLVExposureBlock*           _expoInfo;
    MLVCameraInfoBlock*         _idntInfo;
    MLVWhiteBalanceBlock*       _wbalInfo;
    MLVWAVInfoBlock*            _waviInfo;
    MLVRAWInfoBlock*            _rawiInfo;
    MLVRAWCaptureInfoBlock*     _rawcInfo;
    MLVElectronicLevelBlock*    _elvlInfo;
    MLVStyleBlock*              _stylInfo;
    MLVTimecodeBlock*           _rtciInfo;

    NSArray<MLVVideoBlock*>*    _videoBlocks;
    NSArray<MLVAudioBlock*>*    _audioBlocks;

    NSTimeInterval              _duration;
    NSTimeInterval              _firstTime;
    UInt64                      _fileSize;

    NSInteger                   _version;
}

- (instancetype) initWithURL:(NSURL*)URL
{
    if ((self = [super init])) {
        _version = MLV_FILE_VERSION;
        _url = URL;

        if ([self _open] != kMLVErrorCodeNone) {
            self.missing = YES;
            return nil;
        }
        
        [self readBlockInfos];
    }

    return self;
}

- (void) dealloc {
    [self _close];
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder {
    if ((self = [self init])) {
        _version = [aDecoder decodeIntegerForKey:@"_version"];
        _url = [aDecoder decodeObjectOfClass:[NSURL class] forKey:@"_url"];

        if ([self _open] != kMLVErrorCodeNone) {
            self.missing = YES;
        }

        _mainheader = [aDecoder decodeObjectOfClass:[MLVFileBlock class] forKey:@"_mainheader"];
        _lensInfo = [aDecoder decodeObjectOfClass:[MLVLensBlock class] forKey:@"_lensInfo"];
        _expoInfo = [aDecoder decodeObjectOfClass:[MLVExposureBlock class] forKey:@"_expoInfo"];
        _idntInfo = [aDecoder decodeObjectOfClass:[MLVCameraInfoBlock class] forKey:@"_idntInfo"];
        _wbalInfo = [aDecoder decodeObjectOfClass:[MLVWhiteBalanceBlock class] forKey:@"_wbalInfo"];
        _waviInfo = [aDecoder decodeObjectOfClass:[MLVWAVInfoBlock class] forKey:@"_waviInfo"];
        _rawiInfo = [aDecoder decodeObjectOfClass:[MLVRAWInfoBlock class] forKey:@"_rawiInfo"];
        _rawcInfo = [aDecoder decodeObjectOfClass:[MLVRAWCaptureInfoBlock class] forKey:@"_rawcInfo"];
        _elvlInfo = [aDecoder decodeObjectOfClass:[MLVElectronicLevelBlock class] forKey:@"_elvlInfo"];
        _stylInfo = [aDecoder decodeObjectOfClass:[MLVStyleBlock class] forKey:@"_stylInfo"];
        _rtciInfo = [aDecoder decodeObjectOfClass:[MLVTimecodeBlock class] forKey:@"_rtciInfo"];
        _videoBlocks = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"_videoBlocks"];
        _audioBlocks = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"_audioBlocks"];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_url forKey:@"_url"];
    [aCoder encodeObject:_mainheader forKey:@"_mainheader"];
    if (_lensInfo) {
        [aCoder encodeObject:_lensInfo forKey:@"_lensInfo"];
    }
    if (_expoInfo) {
        [aCoder encodeObject:_expoInfo forKey:@"_expoInfo"];
    }
    if (_idntInfo) {
        [aCoder encodeObject:_idntInfo forKey:@"_idntInfo"];
    }
    if (_wbalInfo) {
        [aCoder encodeObject:_wbalInfo forKey:@"_wbalInfo"];
    }
    if (_waviInfo) {
        [aCoder encodeObject:_waviInfo forKey:@"_waviInfo"];
    }
    if (_rawiInfo) {
        [aCoder encodeObject:_rawiInfo forKey:@"_rawiInfo"];
    }
    if (_rawcInfo) {
        [aCoder encodeObject:_rawiInfo forKey:@"_rawcInfo"];
    }
    if (_elvlInfo) {
        [aCoder encodeObject:_elvlInfo forKey:@"_elvlInfo"];
    }
    if (_stylInfo) {
        [aCoder encodeObject:_stylInfo forKey:@"_stylInfo"];
    }
    if (_rtciInfo) {
        [aCoder encodeObject:_rtciInfo forKey:@"_rtciInfo"];
    }
    if (_videoBlocks) {
        [aCoder encodeObject:_videoBlocks forKey:@"_videoBlocks"];
    }
    if (_audioBlocks) {
        [aCoder encodeObject:_audioBlocks forKey:@"_audioBlocks"];
    }
    [aCoder encodeInteger:_version forKey:@"_version"];
}

- (BOOL) isValid {
    return (_version != MLV_FILE_VERSION);
}

- (void) changeURL:(NSURL*)url {
    [self _close];

    _url = url;

    if ([self _open] != kMLVErrorCodeNone) {
        self.missing = YES;
    }
    else {
        self.missing = NO;
    }
}

#pragma mark -

- (CMTime) frameTime {
    CMTime sourceFps = _mainheader.sourceFps;
    return CMTimeMake(sourceFps.timescale, (CMTimeScale)sourceFps.value);
}

- (NSTimeInterval) firstTime {
    if (_firstTime == 0) {
        MLVVideoBlock* firstVideoBlock = _videoBlocks.firstObject;
        _firstTime = firstVideoBlock.time;
    }
    return _firstTime;
}

- (NSTimeInterval) duration {

    if (_duration == 0) {

        MLVVideoBlock* firstVideoBlock = _videoBlocks.firstObject;
        MLVVideoBlock* lastVideoBlock = _videoBlocks.lastObject;

        _duration = (lastVideoBlock.time - firstVideoBlock.time) + CMTimeGetSeconds([self frameTime]);
    }
    return _duration;
}

#pragma mark -

- (FILE **) _load:(const char *)base_filename numberOfChunks:(int *)entries
{
    int seq_number = 0;
    size_t max_name_len = strlen(base_filename) + 16;
    char *filename = malloc(max_name_len);

    strncpy(filename, base_filename, max_name_len - 1);
    FILE **files = malloc(sizeof(FILE*));


    files[0] = fopen(filename, "rb");
    if(!files[0])
    {
        free(filename);
        free(files);
        return NULL;
    }

    DebugLog(@"File %s opened\n", filename);

    struct stat st;
    stat(filename, &st);
    _fileSize += st.st_size;

    (*entries)++;
    while(seq_number < 99)
    {
        FILE **realloc_files = realloc(files, (*entries + 1) * sizeof(FILE*));

        if(!realloc_files)
        {
            free(filename);
            free(files);
            return NULL;
        }

        files = realloc_files;

        /* check for the next file M00, M01 etc */
        char seq_name[8];

        sprintf(seq_name, "%02d", seq_number);
        seq_number++;

        strcpy(&filename[strlen(filename) - 2], seq_name);

        /* try to open */
        files[*entries] = fopen(filename, "rb");
        if(files[*entries])
        {
            DebugLog(@"File %s opened\n", filename);
            (*entries)++;
        }
        else
        {
            DebugLog(@"File %s not existing.\n", filename);
            break;
        }
    }
    
    free(filename);
    return files;
}

- (MLVErrorCode) _open
{

    NSFileManager* fman = [[NSFileManager alloc] init];

    /* option */
    const char* input_filename = [fman fileSystemRepresentationWithPath:self.url.path];


    /* open files */
    @synchronized (self) {
        in_files = NULL;
        in_file_count = 0;

        in_files = [self _load:input_filename numberOfChunks:&in_file_count];
    }

    if(!in_files || !in_file_count)
    {
        DebugLog(@"Failed to open file '%s'\n", input_filename);
        return kMLVErrorCodeFile;
    }

    return kMLVErrorCodeNone;
}

- (void) _close
{
    @synchronized (self) {
        for(int f=0; f<in_file_count; f++) {
            fclose(in_files[f]);
        }

        if (in_files) {
            free(in_files);
            in_files = NULL;
        }
        in_file_count = 0;
    }
}

- (MLVErrorCode) readBlockInfos
{
    NSMutableArray<MLVVideoBlock*>* videoBlocks = [[NSMutableArray alloc] init];
    NSMutableArray<MLVAudioBlock*>* audioBlocks = [[NSMutableArray alloc] init];


    int blocks_processed = 0;
    char info_string[256] = "(MLV Video without INFO blocks)";

    int in_file_num = 0;
    FILE *in_file = in_files[in_file_num];


    DebugLog(@"Processing...\n");
    uint64_t position_previous = 0;
    do
    {
        mlv_hdr_t buf;
        uint64_t position = 0;

read_headers:

//        DebugLog(@"B:%d/%d V:%d/%d A:%d/%d\n", blocks_processed, block_xref?block_xref->entryCount:0, vidf_frames_processed, total_vidf_count, audf_frames_processed, total_audf_count);


        position = ftello(in_file);

        if(fread(&buf, sizeof(mlv_hdr_t), 1, in_file) != 1)
        {
            DebugLog(@"Reached end of chunk %d/%d after %i blocks\n", in_file_num + 1, in_file_count, blocks_processed);

            if(in_file_num < (in_file_count - 1))
            {
                in_file_num++;
                in_file = in_files[in_file_num];
            }
            else
            {
                break;
            }

            blocks_processed = 0;

            goto read_headers;
        }

        /* jump back to the beginning of the block just read */
        fseeko(in_file, position, SEEK_SET);

        position = ftello(in_file);

        /* unexpected block header size? */
        if(buf.blockSize < sizeof(mlv_hdr_t) || buf.blockSize > 50 * 1024 * 1024)
        {
            ErrLog(@"Invalid block size at position 0x%08llu", position);
            return kMLVErrorCodeFile;
        }

        UInt64 blockPosition = position;
        MLVBlock* hdrBlock = [[MLVBlock alloc] initWithBlockBuffer:&buf fileNum:in_file_num filePosition:position];

//        DebugLog(@"hdrBlock %c%c%c%c", hdrBlock.type >> 24, (hdrBlock.type >> 16) & 0xFF, (hdrBlock.type >> 8) & 0xFF, hdrBlock.type & 0xFF);

        /* file header */
        if(hdrBlock.type == kMLVBlockTypeMLVInfo)
        {
            mlv_file_hdr_t file_hdr;
            size_t hdr_size = MIN(sizeof(mlv_file_hdr_t), buf.blockSize);

            /* read the whole header block, but limit size to either our local type size or the written block size */
            if(fread(&file_hdr, hdr_size, 1, in_file) != 1)
            {
                ErrLog(@"File ends in the middle of a block");
                return kMLVErrorCodeFile;
            }
            fseeko(in_file, position + file_hdr.blockSize, SEEK_SET);

            MLVFileBlock* mainheader = [[MLVFileBlock alloc] initWithBlockBuffer:&file_hdr fileNum:in_file_num filePosition:position];

            /* is this the first file? */
            if(file_hdr.fileNum == 0) {
                _mainheader = mainheader;
            }
            else
            {
                /* no, its another chunk */
                if(_mainheader.guid != mainheader.guid) {
                    ErrLog(@"Error: GUID within the file chunks mismatch!");
                    break;
                }
            }

        }
        else
        {
            if(_mainheader.size == 0)
            {
                ErrLog(@"Missing file header");
                return kMLVErrorCodeFile;
            }

            if(hdrBlock.type == kMLVBlockTypeAudio)
            {
                mlv_audf_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_audf_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                MLVAudioBlock* block = [[MLVAudioBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition];
                [audioBlocks addObject:block];

                fseeko(in_file, position + block_hdr.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeVideo)
            {
                mlv_vidf_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_vidf_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                MLVVideoBlock* block = [[MLVVideoBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition];
                [videoBlocks addObject:block];

                fseeko(in_file, position + block_hdr.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeLens)
            {
                mlv_lens_hdr_t lens_info;
                size_t hdr_size = MIN(sizeof(mlv_lens_hdr_t), buf.blockSize);

                if(fread(&lens_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _lensInfo = [[MLVLensBlock alloc] initWithBlockBuffer:&lens_info fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + lens_info.blockSize, SEEK_SET);

            }
            else if(hdrBlock.type == kMLVBlockTypeInfo)
            {
                mlv_info_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_info_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                /* get the string length and malloc a buffer for that string */
                size_t str_length = block_hdr.blockSize - hdr_size;

                NSString* stringValue;
                if(str_length)
                {
                    char *buf = malloc(str_length + 1);

                    if(fread(buf, str_length, 1, in_file) != 1)
                    {
                        free(buf);
                        ErrLog(@"File ends in the middle of a block");
                        return kMLVErrorCodeFile;
                    }

                    strncpy(info_string, buf, sizeof(info_string));

                    buf[str_length] = '\000';
                    stringValue = [NSString stringWithUTF8String:(const char*)buf];

                    free(buf);
                }

                MLVInfoBlock* block = [[MLVInfoBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition stringValue:stringValue];
                DebugLog(@"info");
            }
            else if(hdrBlock.type == kMLVBlockTypeElectronicLevel)
            {
                mlv_elvl_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_elvl_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _elvlInfo = [[MLVElectronicLevelBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + block_hdr.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeStyle)
            {
                mlv_styl_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_styl_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _stylInfo = [[MLVStyleBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + block_hdr.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeWhiteBalance)
            {
                mlv_wbal_hdr_t wbal_info;
                size_t hdr_size = MIN(sizeof(mlv_wbal_hdr_t), buf.blockSize);

                if(fread(&wbal_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _wbalInfo = [[MLVWhiteBalanceBlock alloc] initWithBlockBuffer:&wbal_info fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + wbal_info.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeIdentification)
            {
                mlv_idnt_hdr_t idnt_info;
                size_t hdr_size = MIN(sizeof(mlv_idnt_hdr_t), buf.blockSize);

                if(fread(&idnt_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _idntInfo = [[MLVCameraInfoBlock alloc] initWithBlockBuffer:&idnt_info fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + idnt_info.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeRTCI)
            {
                mlv_rtci_hdr_t rtci_info;
                size_t hdr_size = MIN(sizeof(mlv_rtci_hdr_t), buf.blockSize);

                if(fread(&rtci_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                if (!_rtciInfo) {
                    _rtciInfo = [[MLVTimecodeBlock alloc] initWithBlockBuffer:&rtci_info fileNum:in_file_num filePosition:blockPosition];
                }

                /* skip remaining data, if there is any */
                fseeko(in_file, position + rtci_info.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeMarker)
            {
                mlv_mark_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_mark_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                MLVMarkerBlock* block = [[MLVMarkerBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition];
                DebugLog(@"marker: %d", block_hdr.type);

                /* skip remaining data, if there is any */
                fseeko(in_file, position + block_hdr.blockSize, SEEK_SET);

//                blockInfo[@"button"] = @(block_hdr.type);
            }
            else if(hdrBlock.type == kMLVBlockTypeExposure)
            {
                mlv_expo_hdr_t expo_info;
                size_t hdr_size = MIN(sizeof(mlv_expo_hdr_t), buf.blockSize);

                if(fread(&expo_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _expoInfo = [[MLVExposureBlock alloc] initWithBlockBuffer:&expo_info fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + expo_info.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeRawInfo)
            {
                mlv_rawi_hdr_t rawi_info;
                size_t hdr_size = MIN(sizeof(mlv_rawi_hdr_t), buf.blockSize);

                if(fread(&rawi_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                if (rawi_info.xRes != rawi_info.raw_info.width)
                {
                    rawi_info.raw_info.width = rawi_info.xRes;
                    rawi_info.raw_info.pitch = rawi_info.raw_info.width * rawi_info.raw_info.bits_per_pixel / 8;
                    rawi_info.raw_info.active_area.x1 = 0;
                    rawi_info.raw_info.active_area.x2 = rawi_info.raw_info.width;
                    rawi_info.raw_info.jpeg.x = 0;
                    rawi_info.raw_info.jpeg.width = rawi_info.raw_info.width;
                }

                if (rawi_info.yRes != rawi_info.raw_info.height)
                {
                    rawi_info.raw_info.height = rawi_info.yRes;
                    rawi_info.raw_info.active_area.y1 = 0;
                    rawi_info.raw_info.active_area.y2 = rawi_info.raw_info.height;
                    rawi_info.raw_info.jpeg.y = 0;
                    rawi_info.raw_info.jpeg.height = rawi_info.raw_info.height;
                }

                _rawiInfo = [[MLVRAWInfoBlock alloc] initWithBlockBuffer:&rawi_info fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + rawi_info.blockSize, SEEK_SET);
            }

            else if(hdrBlock.type == kMLVBlockTypeRawCaptureInfo)
            {
                mlv_rawc_hdr_t rawc_info;
                size_t hdr_size = MIN(sizeof(mlv_rawc_hdr_t), buf.blockSize);

                if(fread(&rawc_info, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _rawcInfo = [[MLVRAWCaptureInfoBlock alloc] initWithBlockBuffer:&rawc_info fileNum:in_file_num filePosition:blockPosition];
            }

            else if(hdrBlock.type == kMLVBlockTypeWavInfo)
            {
                mlv_wavi_hdr_t block_hdr;
                size_t hdr_size = MIN(sizeof(mlv_wavi_hdr_t), buf.blockSize);

                if(fread(&block_hdr, hdr_size, 1, in_file) != 1)
                {
                    ErrLog(@"File ends in the middle of a block");
                    return kMLVErrorCodeFile;
                }

                _waviInfo = [[MLVWAVInfoBlock alloc] initWithBlockBuffer:&block_hdr fileNum:in_file_num filePosition:blockPosition];

                /* skip remaining data, if there is any */
                fseeko(in_file, position + block_hdr.blockSize, SEEK_SET);

            }
            else if(hdrBlock.type == kMLVBlockTypeNull)
            {
                fseeko(in_file, position + buf.blockSize, SEEK_SET);
            }
            else if(hdrBlock.type == kMLVBlockTypeBackup)
            {
                fseeko(in_file, position + buf.blockSize, SEEK_SET);
            }
            else
            {
                DebugLog(@"Unknown Block: %c%c%c%c, skipping\n", buf.blockType[0], buf.blockType[1], buf.blockType[2], buf.blockType[3]);

                fseeko(in_file, position + buf.blockSize, SEEK_SET);
            }
        }
        
        /* count any read block, no matter if header or video frame */
        blocks_processed++;
        
        position_previous = position;
//
//        if (blockInfo.count > 0 && ![blockInfo[@"code"] isEqualToString:@"NULL"]) {
//            [blockInfos addObject:blockInfo];
//        }
    }
    while(!feof(in_file));
    
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"time" ascending:YES];
    _videoBlocks = [videoBlocks sortedArrayUsingDescriptors:@[sortDescriptor]];
    _audioBlocks = [audioBlocks sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    [self willChangeValueForKey:@"frameTime"];
    [self didChangeValueForKey:@"frameTime"];
    
    [self willChangeValueForKey:@"duration"];
    [self didChangeValueForKey:@"duration"];
    
abort:

    return kMLVErrorCodeNone;
}


- (NSDictionary*) audioSettings {

    if (!_waviInfo) {
        return nil;
    }

    NSMutableDictionary* audioSettings = [[NSMutableDictionary alloc] init];
    audioSettings[AVFormatIDKey] = @(kAudioFormatLinearPCM);
    audioSettings[AVSampleRateKey] = @(_waviInfo.sampleRate);
    audioSettings[AVNumberOfChannelsKey] = @(_waviInfo.channels);
    audioSettings[AVLinearPCMIsBigEndianKey] = @(NO);
    audioSettings[AVLinearPCMIsFloatKey] = @(NO);
    audioSettings[AVLinearPCMBitDepthKey] = @(_waviInfo.bitsPerSample);
    audioSettings[AVLinearPCMIsNonInterleaved] = @(NO);

    return audioSettings;
}

- (NSDictionary*) imageSettings {
    NSParameterAssert(_rawiInfo);

    NSMutableDictionary* imageSettings = [[NSMutableDictionary alloc] init];
    imageSettings[AVVideoWidthKey] = @(_rawiInfo.xRes);
    imageSettings[AVVideoHeightKey] = @(_rawiInfo.yRes);

    return imageSettings;
}

- (NSDictionary*) rawInfoWithBlockInfos:(NSArray*)blockInfos
{
    for(NSDictionary* blockInfo in blockInfos) {
        if ([blockInfo[@"code"] isEqualToString:@"RAWI"]) {
            return blockInfo;
        }
    }
    return nil;
}

- (NSData*) readAudioDataBlock:(MLVAudioBlock*)block errorCode:(MLVErrorCode*)errorCode
{
    NSParameterAssert(block);
    NSParameterAssert(errorCode);

    UInt16 file_num = block.fileNum;
    uint64_t offset = block.filePosition;
    size_t space = block.frameSpace;
    size_t size = block.size;
    size_t hdr_size = sizeof(mlv_audf_hdr_t);

    FILE* in_file = in_files[file_num];

    fseeko(in_file, offset+space+hdr_size, SEEK_SET);

    size_t dataSize = size-hdr_size-space;
    void* data_buf = malloc(dataSize);

    if (fread(data_buf, dataSize, 1, in_file) != 1) {
        *errorCode = kMLVErrorCodeFile;
        free(data_buf);
        return nil;
    }

    NSData* data = [NSData dataWithBytesNoCopy:data_buf length:dataSize freeWhenDone:YES];
    return data;
}

- (MLVRawImage*) readVideoDataBlock:(MLVVideoBlock*)block errorCode:(MLVErrorCode*)errorCode
{
    NSParameterAssert(block);
    NSParameterAssert(errorCode);
    
#ifdef DEBUG
    NSDate* startDate = [NSDate date];
#endif
    
    if (!block) {
        return nil;
    }
    
    UInt16 file_num = block.fileNum;
    UInt64 offset = block.filePosition;
    size_t space = block.frameSpace;
    size_t size = block.size;
    size_t hdr_size = sizeof(mlv_vidf_hdr_t);
    
    if (file_num >= in_file_count) {
        return nil;
    }
    
    size_t dataSize = size-hdr_size-space;
    if (dataSize == 0) {
        return nil;
    }
    
    void* raw_buffer = malloc(dataSize);
    
    @synchronized (self) {
        FILE* in_file = in_files[file_num];
        
        fseeko(in_file, offset+space+hdr_size, SEEK_SET);
        
        if (fread(raw_buffer, dataSize, 1, in_file) != 1) {
            *errorCode = kMLVErrorCodeFile;
            free(raw_buffer);
            return nil;
        }
    }
    
    MLVFileVideoClass videoClass = _mainheader.videoClass;
    //    BOOL lzma = (videoClass & kMLVFileVideoClassFlagLZMA);
    //    BOOL delta = (videoClass & kMLVFileVideoClassFlagDelta);
    
    
    struct raw_info raw_info = _rawiInfo.rawInfoStruct;
    raw_info.frame_size = (int32_t)dataSize;
    
    
    BOOL compressed = ((videoClass & kMLVFileVideoClassFlagLJ92) > 0);
    
    MLVRawImage* rawImage = [[MLVRawImage alloc] initWithInfo:raw_info buffer:raw_buffer compressed:compressed];
    if (compressed) {
        MLVRawImage* decompressedRawImage = [rawImage rawImageByDecompressingBuffer];
        if (decompressedRawImage) {
            rawImage = decompressedRawImage;
            compressed = NO;
        }
    }
    
    
    if (!compressed) {
        
        MLVRawImageFocusPixelsType type = kMLVRawImageFocusPixelsTypeNone;
        
        NSInteger rawBufWidth = 0;
        NSInteger rawBufHeight = 0;
        NSInteger rawBufWidthZoomRecording = 0;
        
        switch (_idntInfo.cameraModel) {
            case kMLVCameraModelEOSM:
                type = kMLVRawImageFocusPixelsTypeEOSM;
                
                rawBufWidth = (block.cropPosX > 0) ? 80 + raw_info.width + (block.cropPosX-80)*2 : raw_info.width;
                rawBufHeight = (block.cropPosY > 0) ? 10 + raw_info.height + (block.cropPosY-10)*2 : raw_info.height;
                rawBufWidthZoomRecording = (block.cropPosX > 0) ? 128 + raw_info.width + (block.cropPosX)*2 : raw_info.width;
                break;
                
            case kMLVCameraModel650D:
                type = kMLVRawImageFocusPixelsType650D;
                
                rawBufWidth = (block.cropPosX > 0) ? 64 + raw_info.width + (block.cropPosX-64)*2 : raw_info.width;
                rawBufHeight = (block.cropPosY > 0) ? 26 + raw_info.height + (block.cropPosY-26)*2 : raw_info.height;
                break;
                
            case kMLVCameraModel700D:
                type = kMLVRawImageFocusPixelsType700D;
                
                rawBufWidth = (block.cropPosX > 0) ? 64 + raw_info.width + (block.cropPosX-64)*2 : raw_info.width;
                rawBufHeight = (block.cropPosY > 0) ? 26 + raw_info.height + (block.cropPosY-26)*2 : raw_info.height;
                break;
                
            case kMLVCameraModel100D:
                type = kMLVRawImageFocusPixelsType100D;
                
                rawBufWidth = (block.cropPosX > 0) ? 64 + raw_info.width + (block.cropPosX-64)*2 : raw_info.width;
                rawBufHeight = (block.cropPosY > 0) ? 26 + raw_info.height + (block.cropPosY-26)*2 : raw_info.height;
                
            default:
                break;
        }
        
        
        if (rawBufWidth == 1808) {
            if (rawBufHeight > 1000) {
                type |= kMLVRawImageFocusPixelsType1808x1190;
            } else {
                type |= kMLVRawImageFocusPixelsType1808x728;
            }
        }
        else if (rawBufWidth == 1872) {
            type |= kMLVRawImageFocusPixelsType1872x1060;
        }
        else if (rawBufWidth == 2592 || rawBufWidthZoomRecording == 2592) {
            type |= kMLVRawImageFocusPixelsType2592x1108;
        }
        
        
        if (type > kMLVRawImageFocusPixelsTypeNone) {
            [rawImage fixFocusPixelsWithType:type withCropX:block.cropPosX: block.cropPosY];
        }
        
        if (raw_info.bits_per_pixel < 14) {
            MLVRawImage* newRawImage = [rawImage rawImageByChangingBitsPerPixel:14];
            if (newRawImage) {
                rawImage = newRawImage;
            }
        }
    }
    
    
    
    CMTime fps = _mainheader.sourceFps;
    
    rawImage.camName = _idntInfo.cameraName;
    rawImage.lensModel = _lensInfo.lensName;
    rawImage.camSerial = _idntInfo.cameraSerial;
    rawImage.iso = _expoInfo.isoValue;
    rawImage.frameRate = MLVRationalMake((int32_t)fps.value, (int32_t)fps.timescale);
    rawImage.iso = _expoInfo.isoValue;
    rawImage.aperture = MLVRationalMake(_lensInfo.aperture, 100);
    rawImage.focalLength = MLVRationalMake(_lensInfo.focalLength, 1);
    rawImage.shutter = MLVRationalMake(1, (int32_t)(1000000.0f/(float)_expoInfo.shutterValue));
    rawImage.whiteBalance = _wbalInfo.wbValues;
    rawImage.date = [_rtciInfo dateWithTimeInterval:block.time];
    
#warning needs to be tested
    MLVCameraMatrices cameraMatrices;
    cameraMatrices.calibrationIlluminant1 = raw_info.calibration_illuminant1;
    memcpy(cameraMatrices.colorMatrix1, raw_info.color_matrix1, sizeof(int32_t)*18);
    
    cameraMatrices.calibrationIlluminant1 = 0;
    if ([self.idntInfo copyStandardLightAColorMatrix:cameraMatrices.colorMatrix2]) {
        cameraMatrices.calibrationIlluminant1 = 17;
    }
    rawImage.cameraMatrices = cameraMatrices;
    
#ifdef DEBUG
    DebugLog(@"processed image in %lf sec", -[startDate timeIntervalSinceNow]);
#endif
    
    return rawImage;
}
@end
