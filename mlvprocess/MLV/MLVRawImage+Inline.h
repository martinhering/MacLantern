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

#ifndef MLVRawImage_Inline_h
#define MLVRawImage_Inline_h

#import "raw.h"

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



#endif /* MLVRawImage_Inline_h */
