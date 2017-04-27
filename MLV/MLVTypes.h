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

#ifndef MLVTypes_h
#define MLVTypes_h

typedef struct {
    NSInteger nom;
    NSInteger denom;
} MLVRational;

NS_INLINE MLVRational MLVRationalMake(NSInteger nom, NSInteger denom) {
    MLVRational rational;
    rational.nom = nom;
    rational.denom = denom;
    return rational;
}

typedef struct {
    MLVRational red;
    MLVRational green;
    MLVRational blue;
} MLVWhiteBalance;

typedef struct {
    int32_t calibrationIlluminant1;
    int32_t colorMatrix1[18];    // CalibrationIlluminant1 D65
    
    int32_t calibrationIlluminant2;
    int32_t colorMatrix2[18];    // CalibrationIlluminant2 Standard Light A
} MLVCameraMatrices;

typedef NS_ENUM(NSInteger, MLVErrorCode) {
    kMLVErrorCodeNone           = 0,
    kMLVErrorCodeParameter      = 1,
    kMLVErrorCodeFile           = 3,
    kMLVErrorCodeMemory         = 4,
    kMLVErrorCodeCompression    = 5,
};

typedef NS_ENUM(UInt32, MLVCameraModel) {
    kMLVCameraModel10D      = 0x80000168,
    kMLVCameraModel300D     = 0x80000170,
    kMLVCameraModel20D      = 0x80000175,
    kMLVCameraModel450D     = 0x80000176,
    kMLVCameraModel350D     = 0x80000189,
    kMLVCameraModel40D      = 0x80000190,
    kMLVCameraModel5D       = 0x80000213,
    kMLVCameraModel5D2      = 0x80000218,
    kMLVCameraModel30D      = 0x80000234,
    kMLVCameraModel400D     = 0x80000236,
    kMLVCameraModel7D       = 0x80000250,
    kMLVCameraModel500D     = 0x80000252,
    kMLVCameraModel1000D    = 0x80000254,
    kMLVCameraModel50D      = 0x80000261,
    kMLVCameraModel550D     = 0x80000270,
    kMLVCameraModel5D3      = 0x80000285,
    kMLVCameraModel600D     = 0x80000286,
    kMLVCameraModel60D      = 0x80000287,
    kMLVCameraModel1100D    = 0x80000288,
    kMLVCameraModel650D     = 0x80000301,
    kMLVCameraModel6D       = 0x80000302,
    kMLVCameraModel70D      = 0x80000325,
    kMLVCameraModel700D     = 0x80000326,
    kMLVCameraModelEOSM     = 0x80000331,
    kMLVCameraModel100D     = 0x80000346
};

#define COERCE(x,lo,hi) MAX(MIN((x),(hi)),(lo))

#define WEAK_SELF __weak typeof(self) weakSelf = self;
#define STRONG_SELF typeof(self) self = weakSelf;

#ifdef DEBUG
#define DebugLog(format, args...) if (format != nil) NSLog(@"[%@:%d] %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:format, ##args])
#define ErrLog(format, args...) if (format != nil) NSLog(@"[%@:%d] ***%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:format, ##args])
#else
#define DebugLog(format, args...)
#define DebugErrLog(format, args...)
#define ErrLog(format, args...) if (format != nil) NSLog(@"[%@:%d] ***%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:format, ##args])
#endif

#define NS_ERROR(x_code, x_description, x_args...) [NSError errorWithDomain:NSStringFromClass([self class]) code:x_code userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:x_description, ##x_args]}];


#endif /* MLVTypes_h */
