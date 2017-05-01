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


#import "MLVBlock.h"
#import "mlv.h"

@interface MLVBlock ()
- (NSData*) _blockData;
- (void) _setBlockData:(NSData*)blockData;
@end

@implementation MLVBlock {
    UInt16 _fileNum;
    UInt64 _filePosition;
    mlv_hdr_t _block;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super init])) {
        _fileNum = fileNum;
        _filePosition = filePosition;
        memcpy(&_block, blockBuffer, sizeof(mlv_hdr_t));
    }
    return self;
}

- (MLVBlockType) type {
    return (_block.blockType[0] << 24) | (_block.blockType[1] << 16) | (_block.blockType[2] << 8) | (_block.blockType[3]);
}

- (UInt32) size {
    return CFSwapInt32LittleToHost(_block.blockSize);
}

- (UInt64) timestamp {
    return CFSwapInt64LittleToHost(_block.timestamp);
}

- (UInt16) fileNum {
    return _fileNum;
}

- (UInt64) filePosition {
    return _filePosition;
}

- (NSTimeInterval) time {
    return self.timestamp / 1000000.0;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder {
    if ((self = [self init])) {
        _fileNum = [aDecoder decodeIntegerForKey:@"_fileNum"];
        _filePosition = [aDecoder decodeIntegerForKey:@"_filePosition"];

        NSData* headerData = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"header"];
        [self _setHeaderData:headerData];

        NSData* blockData = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"block"];
        [self _setBlockData:blockData];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:_fileNum forKey:@"_fileNum"];
    [aCoder encodeInteger:_filePosition forKey:@"_filePosition"];

    NSData* headerData = [self _headerData];
    if (headerData) {
        [aCoder encodeObject:headerData forKey:@"header"];
    }

    NSData* blockData = [self _blockData];
    if (blockData) {
        [aCoder encodeObject:blockData forKey:@"block"];
    }
}

- (NSData*) _headerData {
    return [NSData dataWithBytes:&_block length:sizeof(mlv_hdr_t)];
}

- (void) _setHeaderData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_block, blockData.bytes, sizeof(mlv_hdr_t));
    }
    else {
        memset(&_block, 0, sizeof(mlv_hdr_t));
    }
}

- (NSData*) _blockData {
    return nil;
}

- (void) _setBlockData:(NSData*)blockData {
}
@end

#pragma mark -

@implementation MLVFileBlock {
    mlv_file_hdr_t _fileBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_fileBlock, blockBuffer, sizeof(mlv_file_hdr_t));
    }
    return self;
}

- (NSString*) version {
    return [NSString stringWithUTF8String:(const char *)_fileBlock.versionString];
}

- (UInt64) guid {
    return CFSwapInt64LittleToHost(_fileBlock.fileGuid);
}

- (UInt16) fileCount {
    return CFSwapInt16LittleToHost(_fileBlock.fileCount);
}

- (MLVFileFlags) fileFlags {
    return CFSwapInt32LittleToHost(_fileBlock.fileFlags);
}

- (MLVFileVideoClass) videoClass {
    return CFSwapInt16LittleToHost(_fileBlock.videoClass);
}

- (MLVFileAudioClass) audioClass {
    return CFSwapInt16LittleToHost(_fileBlock.audioClass);
}

- (UInt32) numberOfVideoFrames {
    return CFSwapInt32LittleToHost(_fileBlock.videoFrameCount);
}

- (UInt32) numberOfAudioFrames {
    return CFSwapInt32LittleToHost(_fileBlock.audioFrameCount);
}

- (CMTime) sourceFps {
    double sourceFPS = (double)CFSwapInt32LittleToHost(_fileBlock.sourceFpsNom) / (double)CFSwapInt32LittleToHost(_fileBlock.sourceFpsDenom);

    if (sourceFPS != floor(sourceFPS)) {
        NSArray<NSNumber*>* rates = @[@(24), @(30), @(60), @(120)];

        double minDistance = (double)INT_MAX;
        NSNumber* nearestRate;
        for(NSNumber* rate in rates) {
            double myRate = rate.doubleValue * 1000.0 / 1001.0;
            double distance = fabs(myRate-sourceFPS);
            if (distance < minDistance) {
                minDistance = distance;
                nearestRate = rate;
            }
        }

        return CMTimeMake(nearestRate.doubleValue*1000, 1001);
    }

    return CMTimeMake(CFSwapInt32LittleToHost(_fileBlock.sourceFpsNom), CFSwapInt32LittleToHost(_fileBlock.sourceFpsDenom));
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_fileBlock length:sizeof(mlv_file_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_fileBlock, blockData.bytes, sizeof(mlv_file_hdr_t));
    }
    else {
        memset(&_fileBlock, 0, sizeof(mlv_file_hdr_t));
    }
}

@end

#pragma mark -

@implementation MLVVideoBlock {
    mlv_vidf_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_vidf_hdr_t));
    }
    return self;
}

- (UInt32) frameNumber {
    return CFSwapInt32LittleToHost(_myBlock.frameNumber);
}

- (UInt16) cropPosX {
    return CFSwapInt16LittleToHost(_myBlock.cropPosX);
}

- (UInt16) cropPosY {
    return CFSwapInt16LittleToHost(_myBlock.cropPosY);
}

- (UInt16) panPosX {
    return CFSwapInt16LittleToHost(_myBlock.panPosX);
}

- (UInt16) panPosY {
    return CFSwapInt16LittleToHost(_myBlock.panPosY);
}

- (UInt32) frameSpace {
    return CFSwapInt32LittleToHost(_myBlock.frameSpace);
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_vidf_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_vidf_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_vidf_hdr_t));
    }
}

@end

#pragma mark -

@implementation MLVAudioBlock {
    mlv_audf_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_audf_hdr_t));
    }
    return self;
}

- (UInt32) frameNumber {
    return CFSwapInt32LittleToHost(_myBlock.frameNumber);
}

- (UInt32) frameSpace {
    return CFSwapInt32LittleToHost(_myBlock.frameSpace);
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_audf_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_audf_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_audf_hdr_t));
    }
}

@end

#pragma mark -

@implementation MLVRAWInfoBlock {
    mlv_rawi_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_rawi_hdr_t));
    }
    return self;
}

- (UInt16) xRes {
    return CFSwapInt16LittleToHost(_myBlock.xRes);
}

- (UInt16) yRes {
    return CFSwapInt16LittleToHost(_myBlock.yRes);
}

- (struct raw_info) rawInfoStruct {
    return _myBlock.raw_info;
}

- (UInt32) bitsPerPixel {
    return _myBlock.raw_info.bits_per_pixel;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_rawi_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_rawi_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_rawi_hdr_t));
    }
}
@end

#pragma mark -


@implementation MLVRAWCaptureInfoBlock {
    mlv_rawc_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_rawc_hdr_t));
    }
    return self;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_rawc_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_rawc_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_rawc_hdr_t));
    }
}
@end

#pragma mark -

@implementation MLVWAVInfoBlock {
    mlv_wavi_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_wavi_hdr_t));
    }
    return self;
}

- (UInt16) format {
    return CFSwapInt16LittleToHost(_myBlock.format);
}

- (UInt16) channels {
    return CFSwapInt16LittleToHost(_myBlock.channels);
}

- (UInt32) sampleRate {
    return CFSwapInt32LittleToHost(_myBlock.samplingRate);
}

- (UInt32) bytesPerSecond {
    return CFSwapInt32LittleToHost(_myBlock.bytesPerSecond);
}

- (UInt16) bitsPerSample {
    return CFSwapInt16LittleToHost(_myBlock.bitsPerSample);
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_wavi_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_wavi_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_wavi_hdr_t));
    }
}
@end

#pragma mark -

@implementation MLVInfoBlock {
    mlv_info_hdr_t _myBlock;
    NSString* _stringValue;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition stringValue:(NSString*)stringValue {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_info_hdr_t));
        _stringValue = stringValue;
    }
    return self;
}

- (NSString*) stringValue {
    return _stringValue;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_info_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_info_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_info_hdr_t));
    }
}
@end

#pragma mark -

@implementation MLVExposureBlock {
    mlv_expo_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_expo_hdr_t));
    }
    return self;
}

- (UInt32) isoMode {
    return CFSwapInt32LittleToHost(_myBlock.isoMode);
}

- (UInt32) isoValue {
    return CFSwapInt32LittleToHost(_myBlock.isoValue);
}

- (UInt32) isoAnalog {
    return CFSwapInt32LittleToHost(_myBlock.isoAnalog);
}

- (UInt32) digitalGain {
    return CFSwapInt32LittleToHost(_myBlock.digitalGain);
}

- (UInt64) shutterValue {
    return CFSwapInt64LittleToHost(_myBlock.shutterValue);
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_expo_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_expo_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_expo_hdr_t));
    }
}

@end

#pragma mark -

@implementation MLVLensBlock {
    mlv_lens_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_lens_hdr_t));
    }
    return self;
}

- (UInt16) focalLength {
    return CFSwapInt16LittleToHost(_myBlock.focalLength);
}

- (UInt16) focalDistance {
    return CFSwapInt16LittleToHost(_myBlock.focalDist);
}

- (UInt16) aperture {
    return CFSwapInt16LittleToHost(_myBlock.aperture);
}

- (BOOL) stabilizerMode {
    return (_myBlock.stabilizerMode == 1);
}

- (BOOL) autofocusMode {
    return (_myBlock.autofocusMode == 1);
}

- (UInt32) flags {
    return CFSwapInt32LittleToHost(_myBlock.flags);
}

- (UInt32) lensId {
    return CFSwapInt32LittleToHost(_myBlock.lensID);
}

- (NSString*) lensName {
    return [NSString stringWithUTF8String:(const char*)_myBlock.lensName];
}

- (NSString*) lensSerial {
    return [NSString stringWithUTF8String:(const char*)_myBlock.lensSerial];
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_lens_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_lens_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_lens_hdr_t));
    }
}

@end

#pragma mark -

@implementation MLVTimecodeBlock {
    mlv_rtci_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_rtci_hdr_t));
    }
    return self;
}

- (NSDate*) date {
    NSDateComponents* dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = _myBlock.tm_mday;
    dateComponents.month = _myBlock.tm_mon;
    dateComponents.year = 1900 + _myBlock.tm_year;
    dateComponents.hour = _myBlock.tm_hour;
    dateComponents.minute = _myBlock.tm_min;
    dateComponents.second = _myBlock.tm_sec;
    dateComponents.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:_myBlock.tm_gmtoff];

    NSCalendar* gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    return [gregorianCalendar dateFromComponents:dateComponents];
}

- (NSDate*) dateWithTimeInterval:(NSTimeInterval)time
{
    NSDateComponents* dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = _myBlock.tm_mday;
    dateComponents.month = _myBlock.tm_mon;
    dateComponents.year = 1900 + _myBlock.tm_year;
    dateComponents.hour = _myBlock.tm_hour;
    dateComponents.minute = _myBlock.tm_min;
    dateComponents.second = _myBlock.tm_sec;
    dateComponents.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:_myBlock.tm_gmtoff];

    NSCalendar* gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate* date = [gregorianCalendar dateFromComponents:dateComponents];
    return [date dateByAddingTimeInterval:time];
}

- (NSString*) dngDateTimeWithTimestamp:(UInt64)timestamp
{
    UInt64 ms = 500000 + timestamp;
    int sec = (int)(ms / 1000000LLU);
    ms %= 1000;

    struct tm tm;
    tm.tm_sec = _myBlock.tm_sec + sec;
    tm.tm_min = _myBlock.tm_min;
    tm.tm_hour = _myBlock.tm_hour;
    tm.tm_mday = _myBlock.tm_mday;
    tm.tm_mon = _myBlock.tm_mon;
    tm.tm_year = _myBlock.tm_year;
    tm.tm_wday = _myBlock.tm_wday;
    tm.tm_yday = _myBlock.tm_yday;
    tm.tm_isdst = _myBlock.tm_isdst;

    if(mktime(&tm) != -1)
    {
        char datetime_str[32];
        strftime(datetime_str, 20, "%Y:%m:%d %H:%M:%S", &tm);
        return [NSString stringWithUTF8String:datetime_str];
    }

    return nil;
}

- (NSString*) dngSubSecTimeWithTimestamp:(UInt64)timestamp
{
    timestamp %= 1000LLU;

    char subsec_str[8];
    snprintf(subsec_str, sizeof(subsec_str), "%03lld", timestamp);
    return [NSString stringWithUTF8String:subsec_str];

    return nil;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_rtci_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_rtci_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_rtci_hdr_t));
    }
}

@end

#pragma mark -

@implementation MLVCameraInfoBlock {
    mlv_idnt_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_idnt_hdr_t));
    }
    return self;
}

- (NSString*) cameraName {
    return [NSString stringWithUTF8String:(const char*)_myBlock.cameraName];
}

- (MLVCameraModel) cameraModel {
    return CFSwapInt32LittleToHost(_myBlock.cameraModel);
}

- (NSString*) cameraSerial {
    return [NSString stringWithUTF8String:(const char*)_myBlock.cameraSerial];
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_idnt_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_idnt_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_idnt_hdr_t));
    }
}

- (BOOL) copyStandardLightAColorMatrix:(int32_t*)outMatrix {
    struct camMatrices {
        MLVCameraModel model;
        int colorMatrix2[9];
    };
    
    static const struct camMatrices cameraMatrixes[] = {
        { kMLVCameraModel5D3,   {7234, -1413, -600, -3631, 11150, 2850, -382, 1335, 6437} },
        { kMLVCameraModel100D,  {6985, -1611, -397, -3596, 10749, 3295, -349, 1136, 6512 } },
        { kMLVCameraModelEOSM,  {7357, 1377, 909, 2729, 9630, -2359, 104, -1940, 10087} },
        { kMLVCameraModel700D,  {6985, -1611, -397, -3596, 10749, 3295, -349, 1136, 6512} },
        { kMLVCameraModel70D,   {7546, -1435, -929, -3846, 11488, 2692, -332, 1209, 6370} },
        { kMLVCameraModel5D2,   {5309, -229, -336, -6241, 13265, 3337, -817, 1215, 6664} },
        { kMLVCameraModel7D,    {11620, -6350, 5, -2558, 10146, 2813, 24, 858, 6926} },
        { kMLVCameraModel6D,    {7546, -1435, -929, -3846, 11488, 2692, -332, 1209, 6370} },
        { kMLVCameraModel60D,   {7428, -1897, -491, -3505, 10963, 2929, -337, 1242, 6413} },
        { kMLVCameraModel50D,   {5852, -578, -41, -4691, 11696, 3427, -886, 2323, 6879} },
        { kMLVCameraModel550D,  {7755, -2449, -349, -3106, 10222, 3362, -156, 986, 6409} },
        { kMLVCameraModel600D,  {7164, -1916, -431, -3361, 10600, 3200, -272, 1058, 6442} },
        { kMLVCameraModel650D,  {6985, -1611, -397, -3596, 10749, 3295, -349, 1136, 6512} },
        { kMLVCameraModel1100D, {6873, -1696, -529, -3659, 10795, 3313, -362, 1165, 7234} },
        { 0, {0,0,0,0,0,0,0,0,0} }
    };
    
    
    MLVCameraModel model = self.cameraModel;
    NSInteger i=0;
    MLVCameraModel myModel = 0;
    BOOL found = NO;
    do {
        myModel = cameraMatrixes[i].model;
        if (myModel == model) {
            for(int j=0; j<9; j++) {
                outMatrix[j<<1] = cameraMatrixes[i].colorMatrix2[j];
                outMatrix[(j<<1)+1] = 10000;
            }
            found = YES;
            break;
        }
        i++;
    } while(myModel != 0);

    return found;
}

@end

#pragma mark -

@implementation MLVIsoBlock
@end

@implementation MLVStyleBlock {
    mlv_styl_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_styl_hdr_t));
    }
    return self;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_styl_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_styl_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_styl_hdr_t));
    }
}
@end

#pragma mark -

@implementation MLVElectronicLevelBlock {
    mlv_elvl_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_elvl_hdr_t));
    }
    return self;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_elvl_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_elvl_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_elvl_hdr_t));
    }
}
@end

#pragma mark -

@implementation MLVWhiteBalanceBlock {
    mlv_wbal_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_wbal_hdr_t));
    }
    return self;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_wbal_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_wbal_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_wbal_hdr_t));
    }
}

- (MLVWhiteBalance) _wbValuesForKelvin:(uint32_t)kelvin
{
    typedef struct {
        uint32_t kelvin;
        uint32_t red;
        uint32_t green;
        uint32_t blue;
    } wb_t;
    
    wb_t wbValues[76] = {
        {2500,1174,1024,3168},
        {2600,1218,1024,3057},
        {2700,1265,1024,2954},
        {2800,1316,1024,2849},
        {2900,1358,1024,2781},
        {3000,1402,1024,2717},
        {3100,1440,1024,2602},
        {3200,1479,1024,2497},
        {3300,1515,1024,2427},
        {3400,1553,1024,2356},
        {3500,1591,1024,2289},
        {3600,1626,1024,2236},
        {3700,1659,1024,2180},
        {3800,1694,1024,2127},
        {3900,1725,1024,2085},
        {4000,1753,1024,2044},
        {4100,1786,1024,2005},
        {4200,1817,1024,1967},
        {4300,1843,1024,1935},
        {4400,1869,1024,1903},
        {4500,1896,1024,1872},
        {4600,1924,1024,1843},
        {4700,1949,1024,1811},
        {4800,1971,1024,1783},
        {4900,1990,1024,1756},
        {5000,2013,1024,1730},
        {5100,2032,1024,1705},
        {5200,2052,1024,1678},
        {5300,2072,1024,1659},
        {5400,2093,1024,1641},
        {5500,2114,1024,1623},
        {5600,2136,1024,1606},
        {5700,2153,1024,1591},
        {5800,2171,1024,1574},
        {5900,2189,1024,1560},
        {6000,2208,1024,1544},
        {6100,2226,1024,1533},
        {6200,2241,1024,1522},
        {6300,2255,1024,1509},
        {6400,2270,1024,1498},
        {6500,2284,1024,1485},
        {6600,2300,1024,1475},
        {6700,2315,1024,1464},
        {6800,2330,1024,1452},
        {6900,2346,1024,1442},
        {7000,2362,1024,1431},
        {7100,2378,1024,1423},
        {7200,2389,1024,1415},
        {7300,2399,1024,1407},
        {7400,2411,1024,1398},
        {7500,2422,1024,1391},
        {7600,2433,1024,1383},
        {7700,2450,1024,1374},
        {7800,2461,1024,1367},
        {7900,2473,1024,1360},
        {8000,2485,1024,1351},
        {8100,2497,1024,1344},
        {8200,2509,1024,1337},
        {8300,2521,1024,1329},
        {8400,2533,1024,1324},
        {8500,2539,1024,1319},
        {8600,2551,1024,1314},
        {8700,2558,1024,1307},
        {8800,2564,1024,1303},
        {8900,2576,1024,1298},
        {9000,2583,1024,1291},
        {9100,2589,1024,1287},
        {9200,2602,1024,1282},
        {9300,2608,1024,1277},
        {9400,2615,1024,1271},
        {9500,2628,1024,1266},
        {9600,2635,1024,1262},
        {9700,2641,1024,1256},
        {9800,2655,1024,1251},
        {9900,2661,1024,1247},
        {10000,2668,1024,1241}
    };
    
    MLVWhiteBalance result_wb = {0,0,0,0,0,0};
    
    wb_t min_wb = {0,0,0,0};
    int64_t min_dist = INT_MAX;
    for(NSInteger i=0; i<76; i++) {
        wb_t wb = wbValues[i];
        int64_t dist = llabs((int64_t)wb.kelvin - (int64_t)kelvin);
        if (dist < min_dist) {
            min_wb = wb;
            min_dist = dist;
        }
        else {
            break;
        }
    }
    
    result_wb.red = MLVRationalMake(1024, min_wb.red);
    result_wb.blue = MLVRationalMake(1024, min_wb.blue);
    result_wb.green = MLVRationalMake(1024, min_wb.green);
    
    return result_wb;
}

- (MLVWhiteBalance) wbValues {
    /* WB_AUTO 0, WB_SUNNY 1, WB_SHADE 8, WB_CLOUDY 2, WB_TUNGSTEN 3, WB_FLUORESCENT 4, WB_FLASH 5, WB_CUSTOM 6, WB_KELVIN 9 */
    MLVWhiteBalance wb;
    
    switch (_myBlock.wb_mode) {
        case 0 /*WB_AUTO*/:
            return [self _wbValuesForKelvin:4500];
            
        case 1 /*WB_SUNNY*/:
            return [self _wbValuesForKelvin:5200];
            
        case 2 /*WB_CLOUDY*/:
            return [self _wbValuesForKelvin:6000];
            
        case 3 /*WB_TUNGSTEN*/:
            return [self _wbValuesForKelvin:3200];
            
        case 4 /*WB_FLUORESCENT*/:
            wb.red = MLVRationalMake(1024, 1796);
            wb.green = MLVRationalMake(1024, 1024);
            wb.blue = MLVRationalMake(1024, 2399);
            return wb;
            
        case 5 /*WB_FLASH*/:
            wb.red = MLVRationalMake(1024, 2284);
            wb.green = MLVRationalMake(1024, 1024);
            wb.blue = MLVRationalMake(1024, 1520);
            return wb;
            
        case 6 /*WB_FLASH*/:
            wb.red = MLVRationalMake(1024, _myBlock.wbgain_r);
            wb.green = MLVRationalMake(1024, _myBlock.wbgain_g);
            wb.blue = MLVRationalMake(1024, _myBlock.wbgain_b);
            return wb;
            
        case 8 /*WB_SHADE*/:
            return [self _wbValuesForKelvin:7000];
            break;
            
        case 9 /*WB_KELVIN*/:
            return [self _wbValuesForKelvin:_myBlock.kelvin];
            break;
            
        default:
            break;
    }
    
    return [self _wbValuesForKelvin:4500];
}
@end

#pragma mark -

@implementation MLVMarkerBlock {
    mlv_mark_hdr_t _myBlock;
}

- (instancetype) initWithBlockBuffer:(void*)blockBuffer fileNum:(UInt16)fileNum filePosition:(UInt64)filePosition {
    if ((self = [super initWithBlockBuffer:blockBuffer fileNum:fileNum filePosition:filePosition])) {
        memcpy(&_myBlock, blockBuffer, sizeof(mlv_mark_hdr_t));
    }
    return self;
}

- (NSData*) _blockData {
    return [NSData dataWithBytes:&_myBlock length:sizeof(mlv_mark_hdr_t)];
}

- (void) _setBlockData:(NSData*)blockData {
    if (blockData) {
        memcpy(&_myBlock, blockData.bytes, sizeof(mlv_mark_hdr_t));
    }
    else {
        memset(&_myBlock, 0, sizeof(mlv_mark_hdr_t));
    }
}
@end
