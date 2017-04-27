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


#import "MLVPixelMap.h"
#import <AppKit/NSImage.h>

@implementation MLVPixelMap {
    NSUInteger _capacity;
}

+ (NSMutableDictionary<NSString*, MLVPixelMap*> *)sharedPixelMapCache
{
    static dispatch_once_t once;
    static NSMutableDictionary<NSString*, MLVPixelMap*> *__pixelMapCache;
    dispatch_once(&once, ^ { __pixelMapCache = [[NSMutableDictionary alloc] init]; });
    return __pixelMapCache;
}


- (instancetype) initWithImageName:(NSString*)imageName {
    NSParameterAssert(imageName);

    __block MLVPixelMap* pixelMap;
    dispatch_sync(dispatch_get_main_queue(), ^{
        pixelMap = [MLVPixelMap sharedPixelMapCache][imageName];
    });

    if (pixelMap) {
        return pixelMap;
    }

    NSImage* image = [NSImage imageNamed:imageName];

    NSBitmapImageRep* bitmapRep;
    for(NSImageRep* imageRep in image.representations) {
        if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapRep = (NSBitmapImageRep*)imageRep;
            break;
        }
    }

    if (!bitmapRep) {
        bitmapRep = [[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
    }

    if ((self = [self initWithCapacity:bitmapRep.pixelsHigh*bitmapRep.pixelsWide])) {

        MLVPixelMapPixel* pixelMapPtr = _pixelMapPtr;

        NSInteger x,y,i=0;
        for(y=0; y<bitmapRep.pixelsHigh; y++) {
            for(x=0; x<bitmapRep.pixelsWide; x++) {
                NSUInteger p[4];
                [bitmapRep getPixel:p atX:x y:y];

                if (p[0] < 255) {
                    pixelMapPtr[i].x = (int32_t)(x<<1);
                    pixelMapPtr[i].y = (int32_t)(y<<1);
                    i++;
                }
            }
        }

        _numberOfPixels = i;
        _capacity = i;
        _pixelMapPtr = realloc(_pixelMapPtr, sizeof(MLVPixelMapPixel)*_numberOfPixels);

        dispatch_sync(dispatch_get_main_queue(), ^{
            [MLVPixelMap sharedPixelMapCache][imageName] = self;
        });
    }
    return self;
}

- (instancetype) initWithCapacity:(NSUInteger)capacity {
    if ((self = [self init])) {
        _capacity = capacity;
        if (capacity > 0) {
            _pixelMapPtr = malloc(sizeof(MLVPixelMapPixel)*capacity);
        }
    }
    return self;
}

- (void) dealloc {
    if (_pixelMapPtr) {
        free(_pixelMapPtr);
    }
}

- (NSUInteger) capacity {
    return _capacity;
}
- (void) setCapacity:(NSUInteger)capacity {
    if (_capacity != capacity) {
        _capacity = capacity;

        if (capacity > 0) {
            if (!_pixelMapPtr) {
                _pixelMapPtr = malloc(sizeof(MLVPixelMapPixel)*capacity);
            }
            else {
                _pixelMapPtr = realloc(_pixelMapPtr, sizeof(MLVPixelMapPixel)*capacity);
            }
        }
        else {
            free(_pixelMapPtr);
            _pixelMapPtr = NULL;
        }
    }
}

- (void) _enumeratePixels:(void (^)(MLVPixelMapPixel* pixel))callback {
    NSParameterAssert(callback);
    for(NSInteger i=0; i<self.numberOfPixels; i++) {
        MLVPixelMapPixel* pixel = &(_pixelMapPtr[i]);
        callback(pixel);
    }
}
@end
