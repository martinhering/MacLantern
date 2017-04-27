/*
 * Copyright (C) 2013 Magic Lantern Team
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

/**
* RAW pixels (document mode, as with dcraw -D -o 0):

    01 23 45 67 89 AB ... (raw_info.width-1)
    ab cd ef gh ab cd ...

    v-------------------------- first pixel should be red
0   RG RG RG RG RG RG ...   <-- first line (even)
1   GB GB GB GB GB GB ...   <-- second line (odd)
2   RG RG RG RG RG RG ...
3   GB GB GB GB GB GB ...
...
(raw_info.height-1)
*/

#include "stdint.h"

#ifndef _raw_h_
#define _raw_h_

/**
 * 14-bit encoding:

 hi          lo
 aaaaaaaa aaaaaabb
 bbbbbbbb bbbbcccc
 cccccccc ccdddddd
 dddddddd eeeeeeee
 eeeeeeff ffffffff
 ffffgggg gggggggg
 gghhhhhh hhhhhhhh
 */

struct raw_pixblock
{
    unsigned int b_hi: 2;
    unsigned int a: 14;

    unsigned int c_hi: 4;
    unsigned int b_lo: 12;

    unsigned int d_hi: 6;
    unsigned int c_lo: 10;

    unsigned int e_hi: 8;
    unsigned int d_lo: 8;

    unsigned int f_hi: 10;
    unsigned int e_lo: 6;

    unsigned int g_hi: 12;
    unsigned int f_lo: 4;

    unsigned int h: 14;
    unsigned int g_lo: 2;
} __attribute__((packed,aligned(2)));

/**
 * 12-bit encoding:

 hi          lo
 aaaaaaaa aaaabbbb
 bbbbbbbb cccccccc
 ccccdddd dddddddd
 eeeeeeee eeeeffff
 ffffffff gggggggg
 gggghhhh hhhhhhhh
 */

struct raw12_pixblock
{
    unsigned int b_hi: 4;
    unsigned int a: 12;

    unsigned int c_hi: 8;
    unsigned int b_lo: 8;

    unsigned int d: 12;
    unsigned int c_lo: 4;

    unsigned int f_hi: 4;
    unsigned int e: 12;

    unsigned int g_hi: 8;
    unsigned int f_lo: 8;

    unsigned int h: 12;
    unsigned int g_lo: 4;
} __attribute__((packed,aligned(2)));

/**
 * 10-bit encoding:

 hi          lo
 aaaaaaaa aabbbbbb
 bbbbcccc ccccccdd
 dddddddd eeeeeeee
 eeffffff ffffgggg
 gggggghh hhhhhhhh
 */

struct raw10_pixblock
{
    unsigned int b_hi: 6;
    unsigned int a: 10;

    unsigned int d_hi: 2;
    unsigned int c: 10;
    unsigned int b_lo: 4;

    unsigned int e_hi: 8;
    unsigned int d_lo: 8;

    unsigned int g_hi: 4;
    unsigned int f: 10;
    unsigned int e_lo: 2;
    
    unsigned int h:10;
    unsigned int g_lo: 6;

} __attribute__((packed,aligned(2)));


/* raw image info (geometry, calibration levels, color, DR etc); parts of this were copied from CHDK */
struct raw_info {
    uint32_t api_version;           // increase this when changing the structure
    uint32_t reserved;              // this was buffer
    
    int32_t height, width, pitch;
    int32_t frame_size;
    int32_t bits_per_pixel;         // 14

    int32_t black_level;            // autodetected
    int32_t white_level;            // somewhere around 13000 - 16000, varies with camera, settings etc
                                    // would be best to autodetect it, but we can't do this reliably yet
    union                           // DNG JPEG info
    {
        struct
        {
            int32_t x, y;           // DNG JPEG top left corner
            int32_t width, height;  // DNG JPEG size
        } jpeg;
        struct
        {
            int32_t origin[2];
            int32_t size[2];
        } crop;
    };
    union                       // DNG active sensor area (Y1, X1, Y2, X2)
    {
        struct
        {
            int32_t y1, x1, y2, x2;
        } active_area;
        int32_t dng_active_area[4];
    };
    int32_t exposure_bias[2];       // DNG Exposure Bias (idk what's that)
    int32_t cfa_pattern;            // stick to 0x02010100 (RGBG) if you can
    int32_t calibration_illuminant1;
    int32_t color_matrix1[18];      // DNG Color Matrix
    int32_t dynamic_range;          // EV x100, from analyzing black level and noise (very close to DxO)
};


#endif
