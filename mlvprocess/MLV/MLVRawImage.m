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


#import "MLVRawImage.h"
#import "MLVRawImage+Inline.h"
#import "MLVPixelMap.h"
#import "lj92.h"

#import <AppKit/NSImage.h>

@implementation MLVRawImage {
    struct raw_info _rawInfo;
    void*           _rawBuffer;
    BOOL            _compressed;
    
    double          _verticalBandingCoeffs[8];
    int8_t          _verticalBandingCorrectionNeeded;
}

- (instancetype) initWithInfo:(struct raw_info)rawInfo buffer:(void*)rawBuffer compressed:(BOOL)compressed
{
    NSParameterAssert(rawBuffer);

    if ((self = [super init])) {
        _rawInfo = rawInfo;
        _rawBuffer = rawBuffer;
        _compressed = compressed;
    }
    return self;
}

- (struct raw_info*) rawInfo {
    return &(_rawInfo);
}

- (void*) rawBuffer {
    return _rawBuffer;
}

- (void) dealloc {
    if (_rawBuffer) {
        free(_rawBuffer);
    }
}

- (id) copyWithZone:(NSZone *)zone {
    void* rawBufferCopy = malloc(_rawInfo.frame_size);
    memcpy(rawBufferCopy, _rawBuffer, _rawInfo.frame_size);

    MLVRawImage* copy = [[MLVRawImage alloc] initWithInfo:_rawInfo buffer:rawBufferCopy compressed:_compressed];
    return copy;
}

- (void) _enumeratePixels:(void (^)(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by))callback
{
    register int32_t x, y, yadj, xadj, gadj;

    // The sensor bayer patterns are:
    //  0x02010100  0x01000201  0x01020001
    //      R G         G B         G R
    //      G B         R G         B G

    yadj = (_rawInfo.cfa_pattern == 0x01000201) ? 1 : 0;
    xadj = (_rawInfo.cfa_pattern == 0x01020001) ? 1 : 0;
    gadj = (_rawInfo.cfa_pattern == 0x02010100) ? 0 : 1;


    size_t h = (_rawInfo.height >> 1 ) << 1;

    for (y=0; y<h; y+=2) {
        for (x=0; x<_rawInfo.width; x+=2) {
            callback(x+xadj, y+xadj, x+1-gadj, y, x+gadj, y+1, x+1-xadj, y+1-yadj);
        }
    }
}

#pragma mark -

- (NSData*) highlightMap
{
    if (self.compressed) {
        return nil;
    }

    size_t halfW = _rawInfo.width/2;
    size_t halfH = _rawInfo.height/2;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2);
    size_t bytesPerPixel = 1;

    CGContextRef bitmapContext = CGBitmapContextCreate(nil, halfW, halfH, 8, halfW*bytesPerPixel, colorSpace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    __block uint8_t* pixelPtr = CGBitmapContextGetData(bitmapContext);

    [self _enumeratePixels:^(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by) {

        int32_t r = GetRawPixel(&_rawInfo, _rawBuffer, rx, ry);
        int32_t g1 = GetRawPixel(&_rawInfo, _rawBuffer, g1x, g1y);
        int32_t g2 = GetRawPixel(&_rawInfo, _rawBuffer, g2x, g2y);
        int32_t b = GetRawPixel(&_rawInfo, _rawBuffer, bx, by);

        int32_t l =  MAX(MAX(MAX(r, g1), g2), b); //(r+g1+g2+b) >> 2;
        l = RawTo8BitSRGB(l, 0, &_rawInfo);
        l = COERCE((MAX(0, l-204)*5), 0, 255);

        *pixelPtr = l;
        pixelPtr++;
    }];

    CGImageRef imageRef = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);

    NSBitmapImageRep* bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return [bitmapRep TIFFRepresentation];
}


#pragma mark - Repair Pixels

- (MLVPixelMap*) deadPixelMap {
    size_t h = (_rawInfo.height >> 1 ) << 1;
    MLVPixelMap* deadPixelMap = [[MLVPixelMap alloc] initWithCapacity:(_rawInfo.width*h)];


    __block NSUInteger numberOfDeadPixels = 0;
    MLVPixelMapPixel* pixelMapPtr = deadPixelMap.pixelMapPtr;

    int32_t black_level = _rawInfo.black_level;
    void (^findDeadPixel)(int32_t, int32_t) = ^void(int32_t cx, int32_t cy) {
        int32_t r = GetRawPixel(&_rawInfo, _rawBuffer, cx, cy);
        if (r == 0 || r < black_level-500) {
            pixelMapPtr[numberOfDeadPixels].x = (int32_t)cx;
            pixelMapPtr[numberOfDeadPixels].y = (int32_t)cy;
            numberOfDeadPixels++;
        }
    };


    [self _enumeratePixels:^(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by) {
        findDeadPixel(rx, ry);
        findDeadPixel(g1x, g1y);
        findDeadPixel(g2x, g2y);
        findDeadPixel(bx, by);
    }];


    deadPixelMap.numberOfPixels = numberOfDeadPixels;
    deadPixelMap.capacity = deadPixelMap.numberOfPixels;
    return deadPixelMap;
}

- (void) fixDeadPixelsBasedOnPixelMap:(nullable MLVPixelMap*)pixelMap
{
    NSParameterAssert(_rawBuffer);

    if (pixelMap) {
        int32_t black_level = _rawInfo.black_level;
        [pixelMap _enumeratePixels:^(MLVPixelMapPixel *pixel) {

            int32_t cx = pixel->x;
            int32_t cy = pixel->y;
            int32_t r = GetRawPixel(&_rawInfo, _rawBuffer, cx, cy);

            if (r == 0 || r < black_level-500) {
                int32_t interpolated_pixel = GetInterpolatedPixel(&_rawInfo, _rawBuffer, cx, cy);
                setRawPixel(&_rawInfo, _rawBuffer, cx, cy, interpolated_pixel);
            }

        }];
    }
    else
    {
        int32_t black_level = _rawInfo.black_level;
        void (^findAndFixDeadPixel)(int32_t, int32_t) = ^void(int32_t cx, int32_t cy) {
            int32_t r = GetRawPixel(&_rawInfo, _rawBuffer, cx, cy);
            if (r == 0 || r < black_level-500) {
                int32_t interpolated_pixel = GetInterpolatedPixel(&_rawInfo, _rawBuffer, cx, cy);
                setRawPixel(&_rawInfo, _rawBuffer, cx, cy, interpolated_pixel);
            }
        };


        [self _enumeratePixels:^(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by) {
            findAndFixDeadPixel(rx, ry);
            findAndFixDeadPixel(g1x, g1y);
            findAndFixDeadPixel(g2x, g2y);
            findAndFixDeadPixel(bx, by);
        }];
    }
}

- (void) fixFocusPixelsWithType:(MLVRawImageFocusPixelsType)type withCropX:(UInt16)cropX :(UInt16)cropY
{
    NSParameterAssert(_rawBuffer);

    MLVPixelMap* focusPixelMapRed;
    MLVPixelMap* focusPixelMapBlue;

    if (type & kMLVRawImageFocusPixelsTypeEOSM || type & kMLVRawImageFocusPixelsType650D || type & kMLVRawImageFocusPixelsType700D) {
        if (type & kMLVRawImageFocusPixelsType1808x728) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-1808x728-fullframe-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-1808x728-fullframe-blue.png"];
        }
        else if (type & kMLVRawImageFocusPixelsType1808x1190) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-1808x1190-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-1808x1190-blue.png"];
        }
        else if (type & kMLVRawImageFocusPixelsType1872x1060) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-1872x1058-crop-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-1872x1058-crop-blue.png"];
        }
        else if (type & kMLVRawImageFocusPixelsType2592x1108) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-2592x1108-zoom-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"eosm-650d-700d-2592x1108-zoom-blue.png"];
        }
    }
    else if (type & kMLVRawImageFocusPixelsType100D) {
        if (type & kMLVRawImageFocusPixelsType1808x1190) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"100d-1808x1190-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"100d-1808x1190-blue.png"];
        }
        else if (type & kMLVRawImageFocusPixelsType1872x1060) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"100d-1872x1060-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"100d-1872x1060-blue.png"];
        }
        else if (type & kMLVRawImageFocusPixelsType1808x728) {
            focusPixelMapRed = [[MLVPixelMap alloc] initWithImageName:@"100d-1808x728-red.png"];
            focusPixelMapBlue = [[MLVPixelMap alloc] initWithImageName:@"100d-1808x728-blue.png"];
        }
    }


    if (focusPixelMapRed && focusPixelMapBlue)
    {
        register int32_t yadj, xadj;
        yadj = (_rawInfo.cfa_pattern == 0x01000201) ? 1 : 0;
        xadj = (_rawInfo.cfa_pattern == 0x01020001) ? 1 : 0;


        [focusPixelMapRed _enumeratePixels:^(MLVPixelMapPixel *pixel) {
            int32_t x = pixel->x - cropX + xadj;
            int32_t y = pixel->y - cropY + xadj;

            if (x >= 0 && x < _rawInfo.width && y > 0 && y < _rawInfo.height) {
                int32_t ir = GetInterpolatedPixel(&_rawInfo, _rawBuffer, x, y);
                setRawPixel(&_rawInfo, _rawBuffer, x, y, ir);
            }
        }];

        [focusPixelMapBlue _enumeratePixels:^(MLVPixelMapPixel *pixel) {
            int32_t x = pixel->x - cropX +1-xadj;
            int32_t y = pixel->y - cropY +1-yadj;

            if (x >= 0 && x < _rawInfo.width && y > 0 && y < _rawInfo.height) {
                int32_t ib = GetInterpolatedPixel(&_rawInfo, _rawBuffer, x, y);
                setRawPixel(&_rawInfo, _rawBuffer, x, y, ib);
            }
        }];
    }
}

#pragma mark - Vertical Banding

- (uint32_t) calculatedWhiteLevel
{
    __block int32_t white = _rawInfo.white_level * 2 / 3;
    
    [self _enumeratePixels:^(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by) {
        white = MAX(white, GetRawPixel(&_rawInfo, _rawBuffer, rx, ry));
        white = MAX(white, GetRawPixel(&_rawInfo, _rawBuffer, g1x, g1y));
        white = MAX(white, GetRawPixel(&_rawInfo, _rawBuffer, g2x, g2y));
        white = MAX(white, GetRawPixel(&_rawInfo, _rawBuffer, bx, by));
    }];
    
    return white;
}


- (NSData*) findVerticalBandingCoefficients {
    int32_t range = 1 << 16;
    double halfRange = (range>>1);
    int32_t* histogram[8];
    int32_t num[8];
    
    memset(num, 0, sizeof(num));
    
    for(int32_t i=0; i<8; i++) {
        histogram[i] = (int32_t*)calloc(sizeof(int32_t), range);
    }
    
    register int32_t x, y;
    register int32_t white = _rawInfo.white_level;
    register int32_t black = _rawInfo.black_level;
    register int32_t cutoff_black = 1 << MAX(0, (_rawInfo.bits_per_pixel-9));
    
    void (^addHistogramValue)(int32_t*[8], int32_t[8], int32_t, int32_t, int32_t, int32_t) = ^void(int32_t* histogram[8], int32_t num[8], int32_t offset, int32_t p1, int32_t p2, int32_t weight) {
        if (MIN(p1,p2) < cutoff_black)
            return; /* too noisy */
        
        if (MAX(p1,p2) > white / 1.5)
            return; /* too bright */
        
        double p1f = p1 + (rand() % 1024) / 1024.0 - 0.5;
        double p2f = p2 + (rand() % 1024) / 1024.0 - 0.5;
        double factor = p1f / p2f;
        double ev = log2(factor);
        
        int32_t histogramOffset = COERCE((int)(halfRange + ev * halfRange), 0, range-1);
        histogram[offset][histogramOffset] += weight;
        num[offset] += weight;
    };
    
    
    for (y=0; y<_rawInfo.height; y++) {
        for (x=0; x<_rawInfo.width-8; x+=8) {
            int32_t pa = GetRawPixel(&_rawInfo, _rawBuffer, x, y) - black;
            int32_t pb = GetRawPixel(&_rawInfo, _rawBuffer, x+1, y) - black;
            int32_t pc = GetRawPixel(&_rawInfo, _rawBuffer, x+2, y) - black;
            int32_t pd = GetRawPixel(&_rawInfo, _rawBuffer, x+3, y) - black;
            int32_t pe = GetRawPixel(&_rawInfo, _rawBuffer, x+4, y) - black;
            int32_t pf = GetRawPixel(&_rawInfo, _rawBuffer, x+5, y) - black;
            int32_t pg = GetRawPixel(&_rawInfo, _rawBuffer, x+6, y) - black;
            int32_t ph = GetRawPixel(&_rawInfo, _rawBuffer, x+7, y) - black;
            
            int32_t pa2 = GetRawPixel(&_rawInfo, _rawBuffer, x+8, y) - black;
            int32_t pb2 = GetRawPixel(&_rawInfo, _rawBuffer, x+9, y) - black;
            
            addHistogramValue(histogram, num, 2, pa, pc, 3);
            addHistogramValue(histogram, num, 2, pa2, pc, 1);
            
            addHistogramValue(histogram, num, 3, pb, pd, 2);
            addHistogramValue(histogram, num, 3, pb2, pd, 2);
            
            addHistogramValue(histogram, num, 4, pa, pe, 2);
            addHistogramValue(histogram, num, 4, pa2, pe, 2);
            
            addHistogramValue(histogram, num, 5, pb, pf, 2);
            addHistogramValue(histogram, num, 5, pb2, pf, 2);
            
            addHistogramValue(histogram, num, 6, pa, pg, 1);
            addHistogramValue(histogram, num, 6, pa2, pg, 3);
            
            addHistogramValue(histogram, num, 7, pb, ph, 1);
            addHistogramValue(histogram, num, 7, pb2, ph, 3);
        }
    }
    
    _verticalBandingCoeffs[0] = 1;
    _verticalBandingCoeffs[1] = 1;
    
    for (int32_t j = 2; j < 8; j++)
    {
        if (num[j] < _rawInfo.frame_size / 128) continue;
        int32_t t = 0;
        for (int32_t k = 0; k < range; k++)
        {
            t += histogram[j][k];
            if (t >= num[j]>>1) {
                _verticalBandingCoeffs[j] = pow(2, (k-(halfRange))/(halfRange));
                break;
            }
        }
    }
    
    _verticalBandingCorrectionNeeded = 2;
    for (int32_t j = 0; j < 8; j++)
    {
        double c = _verticalBandingCoeffs[j];
        if (c < 0.998 || c > 1.002) {
            _verticalBandingCorrectionNeeded = 1;
            break;
        }
    }
    
    if (_verticalBandingCorrectionNeeded == 1) {
        return [NSData dataWithBytes:_verticalBandingCoeffs length:(sizeof(double)*8)];
    }
    
    return nil;
}

- (void) fixVerticalBandingWithCoefficients:(NSData*)coefficients
{
    if (_verticalBandingCorrectionNeeded == 0) {
        if (coefficients) {
            NSAssert(coefficients.length == sizeof(double)*8, @"coefficients have invalid length");
            memcpy(_verticalBandingCoeffs, coefficients.bytes, sizeof(double)*8);
            _verticalBandingCorrectionNeeded = 1;
        } else {
            [self findVerticalBandingCoefficients];
        }
        
    }
    
    if (_verticalBandingCorrectionNeeded == 2) {
        return;
    }
    
    
    register int32_t white = [self calculatedWhiteLevel];
    register int32_t black = _rawInfo.black_level;
    register int32_t cutoff_black = 1 << MAX(0, (_rawInfo.bits_per_pixel-8));
    register int32_t x, y;
    
    for (y=0; y<_rawInfo.height; y++) {
        for (x=0; x<_rawInfo.width; x+=8) {
            //int32_t pa = GetRawPixel(&_rawInfo, _rawBuffer, x, y);
            //int32_t pb = GetRawPixel(&_rawInfo, _rawBuffer, x+1, y);
            int32_t pc = GetRawPixel(&_rawInfo, _rawBuffer, x+2, y);
            int32_t pd = GetRawPixel(&_rawInfo, _rawBuffer, x+3, y);
            int32_t pe = GetRawPixel(&_rawInfo, _rawBuffer, x+4, y);
            int32_t pf = GetRawPixel(&_rawInfo, _rawBuffer, x+5, y);
            int32_t pg = GetRawPixel(&_rawInfo, _rawBuffer, x+6, y);
            int32_t ph = GetRawPixel(&_rawInfo, _rawBuffer, x+7, y);
            
            if (pc < white && pc > black + cutoff_black) {
                pc = MIN((int32_t)((pc - black) * _verticalBandingCoeffs[2] + black), white);
                setRawPixel(&_rawInfo, _rawBuffer, x+2, y, pc);
            }
            
            if (pd < white && pd > black + cutoff_black) {
                pd = MIN((int32_t)((pd - black) * _verticalBandingCoeffs[3] + black), white);
                setRawPixel(&_rawInfo, _rawBuffer, x+3, y, pd);
            }
            
            if (pe < white && pe > black + cutoff_black) {
                pe = MIN((int32_t)((pe - black) * _verticalBandingCoeffs[4] + black), white);
                setRawPixel(&_rawInfo, _rawBuffer, x+4, y, pe);
            }
            
            if (pf < white && pf > black + cutoff_black) {
                pf = MIN((int32_t)((pf - black) * _verticalBandingCoeffs[5] + black), white);
                setRawPixel(&_rawInfo, _rawBuffer, x+5, y, pf);
            }
            
            if (pg < white && pg > black + cutoff_black) {
                pg = MIN((int32_t)((pg - black) * _verticalBandingCoeffs[6] + black), white);
                setRawPixel(&_rawInfo, _rawBuffer, x+6, y, pg);
            }
            
            if (ph < white && ph > black + cutoff_black) {
                ph = MIN((int32_t)((ph - black) * _verticalBandingCoeffs[7] + black), white);
                setRawPixel(&_rawInfo, _rawBuffer, x+7, y, ph);
            }
        }
    }
}

#pragma mark - Bit depth conversion

- (MLVRawImage*) rawImageByChangingBitsPerPixel:(int32_t)bitsPerPixel
{
    struct raw_info new_raw_info = _rawInfo;
    new_raw_info.bits_per_pixel = bitsPerPixel;
    new_raw_info.pitch = _rawInfo.width * bitsPerPixel >> 3;
    new_raw_info.frame_size = new_raw_info.pitch * new_raw_info.height;


    void* new_raw_buffer = malloc(new_raw_info.frame_size);
    int32_t lessBits = _rawInfo.bits_per_pixel-bitsPerPixel;
    int32_t moreBits = bitsPerPixel - _rawInfo.bits_per_pixel;

    if (moreBits > 0) {
        [self _enumeratePixels:^(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by) {
            int32_t r = GetRawPixel(&_rawInfo, _rawBuffer, rx, ry);
            int32_t g1 = GetRawPixel(&_rawInfo, _rawBuffer, g1x, g1y);
            int32_t g2 = GetRawPixel(&_rawInfo, _rawBuffer, g2x, g2y);
            int32_t b = GetRawPixel(&_rawInfo, _rawBuffer, bx, by);

            r =  r << moreBits;
            g1 = g1 << moreBits;
            g2 = g2 << moreBits;
            b = b << moreBits;

            setRawPixel(&new_raw_info, new_raw_buffer, rx, ry, r);
            setRawPixel(&new_raw_info, new_raw_buffer, g1x, g1y, g1);
            setRawPixel(&new_raw_info, new_raw_buffer, g2x, g2y, g2);
            setRawPixel(&new_raw_info, new_raw_buffer, bx, by, b);
        }];

        new_raw_info.white_level = new_raw_info.white_level << moreBits;
        new_raw_info.black_level = new_raw_info.black_level << moreBits;
    }
    else if (lessBits > 0) {
        [self _enumeratePixels:^(int32_t rx, int32_t ry, int32_t g1x, int32_t g1y, int32_t g2x, int32_t g2y, int32_t bx, int32_t by) {
            int32_t r = GetRawPixel(&_rawInfo, _rawBuffer, rx, ry);
            int32_t g1 = GetRawPixel(&_rawInfo, _rawBuffer, g1x, g1y);
            int32_t g2 = GetRawPixel(&_rawInfo, _rawBuffer, g2x, g2y);
            int32_t b = GetRawPixel(&_rawInfo, _rawBuffer, bx, by);

            r =  r >> lessBits;
            g1 = g1 >> lessBits;
            g2 = g2 >> lessBits;
            b = b >> lessBits;

            setRawPixel(&new_raw_info, new_raw_buffer, rx, ry, r);
            setRawPixel(&new_raw_info, new_raw_buffer, g1x, g1y, g1);
            setRawPixel(&new_raw_info, new_raw_buffer, g2x, g2y, g2);
            setRawPixel(&new_raw_info, new_raw_buffer, bx, by, b);
        }];

        new_raw_info.white_level = new_raw_info.white_level >> lessBits;
        new_raw_info.black_level = new_raw_info.black_level >> lessBits;
    }
    else {
        free(new_raw_buffer);
        return NULL;
    }

    MLVRawImage* rawImage = [[MLVRawImage alloc] initWithInfo:new_raw_info buffer:new_raw_buffer compressed:NO];
    [self _copyMetadataToRawImage:rawImage];
    return rawImage;
}

- (void) _copyMetadataToRawImage:(MLVRawImage*)rawImage {
    rawImage.camName = self.camName;
    rawImage.camSerial = self.camSerial;
    rawImage.lensModel = self.lensModel;
    rawImage.date = self.date;
    rawImage.iso = self.iso;
    rawImage.focalLength = self.focalLength;
    rawImage.aperture = self.aperture;
    rawImage.shutter = self.shutter;
    rawImage.frameRate = self.frameRate;
    rawImage.whiteBalance = self.whiteBalance;
    rawImage.cameraMatrices = self.cameraMatrices;
}

#pragma mark - Decomression

- (MLVRawImage*) rawImageByDecompressingBuffer
{
#ifdef DEBUG
    NSDate* startDate = [NSDate date];
#endif
    
    lj92 lj92_handle;
    int lj92_width = 0;
    int lj92_height = 0;
    int lj92_bitdepth = 0;
    int lj92_components = 0;
    
    
    int ret = lj92_open(&lj92_handle, (uint8_t *)_rawBuffer, (int)_rawInfo.frame_size, &lj92_width, &lj92_height, &lj92_bitdepth, &lj92_components);
    int32_t out_size = lj92_width * lj92_height * lj92_components * sizeof(uint16_t);
    
    if(ret != LJ92_ERROR_NONE) {
        return nil;
    }
    
    uint16_t *decompressedRawBuffer = malloc(out_size);
    ret = lj92_decode(lj92_handle, decompressedRawBuffer, lj92_width, 0, NULL, 0);
    
    lj92_close(lj92_handle);
    
    if(ret != LJ92_ERROR_NONE) {
        free(decompressedRawBuffer);
        return nil;
    }
    
    
    struct raw_info decompressedRawInfo = _rawInfo;
    decompressedRawInfo.frame_size = out_size;
    decompressedRawInfo.bits_per_pixel = 16;
    decompressedRawInfo.pitch = decompressedRawInfo.width * sizeof(uint16_t);
    
    int32_t newFrameSize = (lj92_width * lj92_height * lj92_components * 14) >> 3;
    void* newRawBuffer = malloc(newFrameSize);
    
    struct raw_info newRawInfo = _rawInfo;
    newRawInfo.frame_size = newFrameSize;
    
    register int32_t yadj, xadj, gadj;
    yadj = (_rawInfo.cfa_pattern == 0x01000201) ? 1 : 0;
    xadj = (_rawInfo.cfa_pattern == 0x01020001) ? 1 : 0;
    gadj = (_rawInfo.cfa_pattern == 0x02010100) ? 0 : 1;
    
    
    dispatch_apply(_rawInfo.height >> 1, dispatch_get_global_queue(0, 0), ^(size_t i) {
        int32_t y = (int32_t)i << 1;
        
        register int32_t x;
        for (x=0; x<_rawInfo.width; x+=2) {
            
            int32_t rx = x+xadj;
            int32_t ry = y+yadj;
            
            int32_t g1x = x+1-gadj;
            int32_t g1y = y;
            
            int32_t g2x = x+gadj;
            int32_t g2y = y+1;
            
            int32_t bx = x+1-xadj;
            int32_t by = y+1-yadj;
            
            int32_t r = GetRawPixel(&decompressedRawInfo, decompressedRawBuffer, rx, ry);
            setRawPixel(&newRawInfo, newRawBuffer, rx, ry, r);
            
            int32_t g1 = GetRawPixel(&decompressedRawInfo, decompressedRawBuffer, g1x, g1y);
            setRawPixel(&newRawInfo, newRawBuffer, g1x, g1y, g1);
            
            int32_t g2 = GetRawPixel(&decompressedRawInfo, decompressedRawBuffer, g2x, g2y);
            setRawPixel(&newRawInfo, newRawBuffer, g2x, g2y, g2);
            
            int32_t b = GetRawPixel(&decompressedRawInfo, decompressedRawBuffer, bx, by);
            setRawPixel(&newRawInfo, newRawBuffer, bx, by, b);
        }
    });
    
    
    free(decompressedRawBuffer);
    
    MLVRawImage* rawImage = [[MLVRawImage alloc] initWithInfo:newRawInfo buffer:newRawBuffer compressed:NO];
#ifdef DEBUG
    DebugLog(@"decompress done in %lf", -[startDate timeIntervalSinceNow]);
#endif
    return rawImage;
}


@end
