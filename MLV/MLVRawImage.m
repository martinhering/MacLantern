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
#import "MLVPixelMap.h"
#import "lj92.h"

@implementation MLVRawImage {
    struct raw_info _rawInfo;
    void*           _rawBuffer;
    BOOL            _compressed;
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

/*
NS_INLINE uint8_t RawTo8BitSRGB(int32_t raw, int32_t wb, struct raw_info * raw_info)
{
    float ev = log2f(MAX(1, raw - raw_info->black_level)) + wb - 5;
    float max = log2f(raw_info->white_level - raw_info->black_level) - 5;
    int32_t out = ev * 255 / max;
    return (uint8_t)COERCE(out, 0, 255);
}


NS_INLINE uint8_t RawTo8BitLinear(int32_t raw, struct raw_info * raw_info)
{
    int32_t out = raw * 255 / (int32_t)( 1 << raw_info->bits_per_pixel);
    return (uint8_t)COERCE(out, 0, 255);
}
*/

NS_INLINE int32_t GetRawPixel(const struct raw_info * raw_info, void* raw_buffer, int32_t x, int32_t y) {

    switch (raw_info->bits_per_pixel) {
        case 10: {
            struct raw10_pixblock * p = raw_buffer + y * raw_info->pitch + (x>>3)*10;
            switch (x%8) {
                case /*a*/ 0: return p->a;
                case /*b*/ 1: return p->b_lo | (p->b_hi << 4);
                case /*c*/ 2: return p->c;
                case /*d*/ 3: return p->d_lo | (p->d_hi << 8);
                case /*e*/ 4: return p->e_lo | (p->e_hi << 2);
                case /*f*/ 5: return p->f;
                case /*g*/ 6: return p->g_lo | (p->g_hi << 6);
                case /*h*/ 7: return p->h;
            }
            return p->a;

        }
        case 12: {
            struct raw12_pixblock * p = raw_buffer + y * raw_info->pitch + (x>>3)*12;
            switch (x%8) {
                case /*a*/ 0: return p->a;
                case /*b*/ 1: return p->b_lo | (p->b_hi << 8);
                case /*c*/ 2: return p->c_lo | (p->c_hi << 4);
                case /*d*/ 3: return p->d;
                case /*e*/ 4: return p->e;
                case /*f*/ 5: return p->f_lo | (p->f_hi << 8);
                case /*g*/ 6: return p->g_lo | (p->g_hi << 4);
                case /*h*/ 7: return p->h;
            }
            return p->a;

        }
        case 14: {
            struct raw_pixblock * p = raw_buffer + y * raw_info->pitch + (x>>3)*14;
            switch (x%8) {
                case 0: return p->a;
                case 1: return p->b_lo | (p->b_hi << 12);
                case 2: return p->c_lo | (p->c_hi << 10);
                case 3: return p->d_lo | (p->d_hi << 8);
                case 4: return p->e_lo | (p->e_hi << 6);
                case 5: return p->f_lo | (p->f_hi << 4);
                case 6: return p->g_lo | (p->g_hi << 2);
                case 7: return p->h;
            }
            return p->a;
        }

        default:
            break;
    }
    return 0;
}

NS_INLINE void setRawPixel(const struct raw_info * raw_info, void* raw_buffer, int32_t x, int32_t y, int32_t px) {

    switch (raw_info->bits_per_pixel) {
        case 10: {
            struct raw10_pixblock * p = raw_buffer + y * raw_info->pitch + (x/8)*10;
            switch (x%8) {
                case /*a*/ 0: p->a = px; break;
                case /*b*/ 1: p->b_lo = px & 0xf;  p->b_hi = px >> 4; break;
                case /*c*/ 2: p->c = px; break;
                case /*d*/ 3: p->d_lo = px & 0xff; p->d_hi = px >> 8; break;
                case /*e*/ 4: p->e_lo = px & 0x3;  p->e_hi = px >> 2; break;
                case /*f*/ 5: p->f = px; break;
                case /*g*/ 6: p->g_lo = px & 0x3f; p->g_hi = px >> 6; break;
                case /*h*/ 7: p->h = px; break;
                default:
                    break;
            }
            break;
        }
        case 12: {
            struct raw12_pixblock * p = raw_buffer + y * raw_info->pitch + (x/8)*12;
            switch (x%8) {
                case /*a*/ 0: p->a = px; break;
                case /*b*/ 1: p->b_lo = px & 0xff;  p->b_hi = px >> 8; break;
                case /*c*/ 2: p->c_lo = px & 0xf;  p->c_hi = px >> 4; break;
                case /*d*/ 3: p->d = px; break;
                case /*e*/ 4: p->e = px; break;
                case /*f*/ 5: p->f_lo = px & 0xff; p->f_hi = px >> 8; break;
                case /*g*/ 6: p->g_lo = px & 0xf;  p->g_hi = px >> 4; break;
                case /*h*/ 7: p->h = px; break;
                default:
                    break;
            }
            break;
        }
        case 14: {
            struct raw_pixblock * p = raw_buffer + y * raw_info->pitch + (x/8)*14;
            switch (x%8) {
                case 0: p->a = px; break;
                case 1: p->b_lo = px & 0xfff;  p->b_hi = px >> 12; break;
                case 2: p->c_lo = px & 0x3ff;  p->c_hi = px >> 10; break;
                case 3: p->d_lo = px & 0xff;  p->d_hi = px >> 8; break;
                case 4: p->e_lo = px & 0x3f;  p->e_hi = px >> 6; break;
                case 5: p->f_lo = px & 0xf;  p->f_hi = px >> 4; break;
                case 6: p->g_lo = px & 0x3;  p->g_hi = px >> 2; break;
                case 7: p->h = px; break;
                default:
                    break;
            }
            break;
        }

        default:
            break;
    }
}

NS_INLINE int32_t GetInterpolatedPixel(struct raw_info * raw_info, void* raw_buffer, int32_t cx, int32_t cy) {
    int32_t black_level = raw_info->black_level;

    int32_t neighbors=0;
    int32_t numNeighbors=0;
    register int32_t x,y;
    for(x=cx-2; x<=cx+2; x+=2) {
        for(y=cy-2; y<=cy+2; y+=2) {
            if (x<0 || y<0 || x>=raw_info->width || y>=raw_info->height || (x==cx && y==cy)) {
                continue;
            }
            int32_t r = GetRawPixel(raw_info, raw_buffer, x, y);
            if (r < black_level-500) {
                continue;
            }
            neighbors += r;
            numNeighbors++;
        }
    }

    return (numNeighbors > 0) ? neighbors / numNeighbors : 0;
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
    return rawImage;
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
