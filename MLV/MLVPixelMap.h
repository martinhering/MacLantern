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

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    int32_t x;
    int32_t y;
} MLVPixelMapPixel;

@interface MLVPixelMap : NSObject

- (instancetype) initWithImageName:(NSString*)imageName;
- (instancetype) initWithCapacity:(NSUInteger)capacity;

@property NSUInteger numberOfPixels;

// not thread save!
@property (readonly) MLVPixelMapPixel* pixelMapPtr;
@property NSUInteger capacity;

- (void) _enumeratePixels:(void (^)(MLVPixelMapPixel* pixel))callback;
@end


NS_ASSUME_NONNULL_END
