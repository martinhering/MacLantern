/*
 * DNG saving routines ported from CHDK
 * Original code copyright (C) CHDK (GPLv2);
 * Adapted code copyright (C) Martin Hering 2017
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


#import "MLVRawImage+DNG.h"
#import "MLVRawImage+Inline.h"

#define T_BYTE      1
#define T_ASCII     2
#define T_SHORT     3
#define T_LONG      4
#define T_RATIONAL  5
#define T_SBYTE     6
#define T_UNDEFINED 7
#define T_SSHORT    8
#define T_SLONG     9
#define T_SRATIONAL 10
#define T_FLOAT     11
#define T_DOUBLE    12
#define T_PTR       0x100   // Stored as long/short etc in DNG header, referenced by pointer in IFD (must be pointer to int variable)
#define T_SKIP      0x200   // Tag value to be skipped (for marking GPS entries if camera does not have GPS)

#define BADPIX_CFA_INDEX    6   // Index of CFAPattern value in badpixel_opcodes array

#define dng_th_width 256
#define dng_th_height 168

struct dir_entry {
    uint16_t tag;
    uint16_t type;
    uint32_t count;
    uint32_t offset;
    void* offset_ptr;
};


@implementation MLVRawImage (DNG)

- (int32_t) _findTagIndex:(struct dir_entry *)ifd :(int32_t)num :(uint16_t)tag
{
    int32_t i;
    for (i = 0; i < num; i++) {
        if (ifd[i].tag == tag) {
            return i;
        }
    }

    return -1;
}

// Index of specific entries in ifd0 below.
#define CAMERA_NAME_INDEX               [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x110]
#define THUMB_DATA_INDEX                [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x111]
#define ORIENTATION_INDEX               [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x112]
#define CHDK_VER_INDEX                  [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x131]
#define ARTIST_NAME_INDEX               [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x13B]
#define SUBIFDS_INDEX                   [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x14A]
#define COPYRIGHT_INDEX                 [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x8298]
#define EXIF_IFD_INDEX                  [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0x8769]
#define DNG_VERSION_INDEX               [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0xC612]
#define UNIQUE_CAMERA_MODEL_INDEX       [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0xC614]
#define CAMERA_MATRIX_2_INDEX           [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0xC622]
#define CALIBRATION_ILLUMINANT_2_INDEX  [self _findTagIndex:ifd0 :DIR_SIZE(ifd0) :0xC65B]

#define CAM_MAKE                    "Canon"

// Index of specific entries in ifd1 below.
#define RAW_DATA_INDEX              [self _findTagIndex:ifd1 :DIR_SIZE(ifd1) :0x111]
#define BADPIXEL_OPCODE_INDEX       [self _findTagIndex:ifd1 :DIR_SIZE(ifd1) :0xC740]

// Index of specific entries in exif_ifd below.
#define EXPOSURE_PROGRAM_INDEX      [self _findTagIndex:exif_ifd :DIR_SIZE(exif_ifd) :0x8822]
#define METERING_MODE_INDEX         [self _findTagIndex:exif_ifd :DIR_SIZE(exif_ifd) :0x9207]
#define FLASH_MODE_INDEX            [self _findTagIndex:exif_ifd :DIR_SIZE(exif_ifd) :0x9209]
#define SSTIME_INDEX                [self _findTagIndex:exif_ifd :DIR_SIZE(exif_ifd) :0x9290]
#define SSTIME_ORIG_INDEX           [self _findTagIndex:exif_ifd :DIR_SIZE(exif_ifd) :0x9291]



- (int32_t) _getSizeOfType:(int32_t)type
{
    switch(type & 0xFF)
    {
        case T_BYTE:
        case T_SBYTE:
        case T_UNDEFINED:
        case T_ASCII:     return 1;
        case T_SHORT:
        case T_SSHORT:    return 2;
        case T_LONG:
        case T_SLONG:
        case T_FLOAT:     return 4;
        case T_RATIONAL:
        case T_SRATIONAL:
        case T_DOUBLE:    return 8;
        default:          return 0;
    }
}

#define DIR_SIZE(ifd)   (sizeof(ifd)/sizeof(ifd[0]))
#define TIFF_HDR_SIZE (8)



- (BOOL) _createHeaderAndReturnBuf:(void**)outHeaderBuf headerSize:(int32_t*)outHeaderSize
{
    NSParameterAssert(outHeaderBuf);
    NSParameterAssert(outHeaderSize);

    int32_t i,j;
    int32_t extra_offset;
    int32_t raw_offset;

    struct raw_info *raw_info = self.rawInfo;

    MLVCameraMatrices camMatrices = self.cameraMatrices;

    const char* lensModel = (self.lensModel) ? self.lensModel.UTF8String : "";
    const char* imageDesc = "Magic Lantern Raw Image";
    const char* name = (self.camName) ? self.camName.UTF8String : "";
    const char* serial = (self.camSerial) ? self.camSerial.UTF8String : "";
    const char* artistName = "";
    const char* copyright = "";
    const char* software = "mlvprocess";
    const char* dateTime = "";
    const char* subSecTime = "";

    int32_t frameRate[] = {
        (int32_t)self.frameRate.nom,
        (int32_t)self.frameRate.denom
    };

    int16_t iso = self.iso;

    int32_t asShotNeutral[] = {
        (int32_t)self.whiteBalance.red.nom,
        (int32_t)self.whiteBalance.red.denom,
        (int32_t)self.whiteBalance.green.nom,
        (int32_t)self.whiteBalance.green.denom,
        (int32_t)self.whiteBalance.blue.nom,
        (int32_t)self.whiteBalance.blue.denom,
    };

    int32_t shutterFactor = (self.shutter.denom > 0 ) ? 1000000 / self.shutter.denom : 0;
    int32_t shutter[] = {
        (int32_t)self.shutter.nom * shutterFactor,
        (int32_t)self.shutter.denom * shutterFactor
    };

    int32_t aperture[] = {
        (int32_t)self.aperture.nom,
        (int32_t)self.aperture.denom,
    };

    int32_t focalLength[] = {
        (int32_t)self.focalLength.nom,
        (int32_t)self.focalLength.denom,
    };

    int32_t analogBalance[] = {1,1,1,1,1,1};

    int16_t previewBitsPerSample[] = {8,8,8};
    int32_t resolution[] = {180,1};

    uint32_t bpOpcode[7];
    bpOpcode[0] = htonl(1);            // number of opcodes
    bpOpcode[1] = htonl(4);            // opcode-id (FixBadPixelsConstant)
    bpOpcode[2] = htonl(0x01030000);   // version
    bpOpcode[3] = htonl(1);            // flags: 1=optional
    bpOpcode[4] = htonl(8);            // number of bytes of parameters
    bpOpcode[5] = htonl(0);            // constant
    bpOpcode[6] = htonl(0);            // bayer phase


    int32_t baselineNoise[] = {1,1};
    int32_t baselineSharpness[] = {4,3};
    int32_t linearResponseLimit[] = {1,1};


    struct dir_entry ifd0[]={
        {0xFE,   T_LONG,            1,  1, NULL},                                    // NewSubFileType: Preview Image
        {0x100,  T_LONG,            1,  dng_th_width, NULL},                         // ImageWidth
        {0x101,  T_LONG,            1,  dng_th_height, NULL},                        // ImageLength
        {0x102,  T_SHORT|T_PTR,     3,  0, (void*)previewBitsPerSample},      // BitsPerSample: 8,8,8
        {0x103,  T_SHORT,           1,  1, NULL},                                    // Compression: Uncompressed
        {0x106,  T_SHORT,           1,  2, NULL},                                    // PhotometricInterpretation: RGB
        {0x10E,  T_ASCII|T_PTR,     (uint32_t)strlen(imageDesc)+1, 0, (void*)imageDesc},        // ImageDescription
        {0x10F,  T_ASCII|T_PTR,     sizeof(CAM_MAKE), 0, CAM_MAKE},            // Make
        {0x110,  T_ASCII|T_PTR,     (uint32_t)strlen(name)+1, 0, (void*)name},                             // Model: Filled at header generation.
        {0x111,  T_LONG,            1,  0, NULL},                                    // StripOffsets: Offset
        {0x112,  T_SHORT,           1,  1, NULL},                                    // Orientation: 1 - 0th row is top, 0th column is left
        {0x115,  T_SHORT,           1,  3, NULL},                                    // SamplesPerPixel: 3
        {0x116,  T_SHORT,           1,  dng_th_height, NULL},                        // RowsPerStrip
        {0x117,  T_LONG,            1,  dng_th_width*dng_th_height*3, NULL},         // StripByteCounts = preview size
        {0x11C,  T_SHORT,           1,  1, NULL},                                    // PlanarConfiguration: 1
        {0x131,  T_ASCII|T_PTR,     (uint32_t)strlen(software)+1, 0, (void*)software},                                    // Software
        {0x132,  T_ASCII|T_PTR,     (uint32_t)strlen(dateTime)+1, 0, (void*)dateTime},                               // DateTime
        {0x13B,  T_ASCII|T_PTR,     (uint32_t)strlen(artistName)+1, 0, (void*)artistName},                             // Artist: Filled at header generation.
        {0x14A,  T_LONG,            1,  0, NULL},                                    // SubIFDs offset
        {0x8298, T_ASCII|T_PTR,     (uint32_t)strlen(copyright)+1, 0, (void*)copyright},                              // Copyright
        {0x8769, T_LONG,            1,  0, NULL},                                    // EXIF_IFD offset
        {0x9216, T_BYTE,            4,  0x00000001, NULL},                           // TIFF/EPStandardID: 1.0.0.0
        {0xA431, T_ASCII|T_PTR,     (uint32_t)strlen(serial)+1, 0, (void*)serial},              // Exif.Photo.BodySerialNumber
        {0xA434, T_ASCII|T_PTR,     (uint32_t)strlen(lensModel)+1, 0, (void*)lensModel},        // Exif.Photo.LensModel
        {0xC612, T_BYTE,            4,  0x00000301, NULL},                           // DNGVersion: 1.3.0.0
        {0xC613, T_BYTE,            4,  0x00000301, NULL},                           // DNGBackwardVersion: 1.1.0.0
        {0xC614, T_ASCII|T_PTR,     (uint32_t)strlen(name)+1, 0, (void*)name},                             // UniqueCameraModel. Filled at header generation.
        {0xC621, T_SRATIONAL|T_PTR, 9,  0, &(camMatrices.colorMatrix1)},
        {0xC622, T_SRATIONAL|T_PTR, 9,  0, &(camMatrices.colorMatrix2)},
        {0xC627, T_RATIONAL|T_PTR,  3,  0, (void*)analogBalance},
        {0xC628, T_RATIONAL|T_PTR,  3,  0, asShotNeutral},
        {0xC62A, T_SRATIONAL|T_PTR, 1,  0, raw_info->exposure_bias},           // BaselineExposure
        {0xC62B, T_RATIONAL|T_PTR,  1, 0, (void*)baselineNoise},
        {0xC62C, T_RATIONAL|T_PTR,  1, 0, (void*)baselineSharpness},
        {0xC62E, T_RATIONAL|T_PTR,  1, 0, (void*)linearResponseLimit},
        {0xC65A, T_SHORT,      1,   camMatrices.calibrationIlluminant1, NULL},    // CalibrationIlluminant1 D65
        {0xC65B, T_SHORT,      1,   camMatrices.calibrationIlluminant2, NULL},    // CalibrationIlluminant2 Standard Light A
        {0xC764, T_SRATIONAL|T_PTR, 1,  0, frameRate},
    };

    struct dir_entry ifd1[]={
        {0xFE,   T_LONG,       1,  0, NULL},                                    // NewSubFileType: Main Image
        {0x100,  T_LONG|T_PTR, 1,  0, &raw_info->width},                        // ImageWidth
        {0x101,  T_LONG|T_PTR, 1,  0, &raw_info->height},                       // ImageLength
        {0x102,  T_SHORT|T_PTR,1,  0, &raw_info->bits_per_pixel},               // BitsPerSample
        {0x103,  T_SHORT,      1,  (self.compressed) ? 7 : 1, NULL},            // Compression: Uncompressed
        {0x106,  T_SHORT,      1,  0x8023, NULL},                               // PhotometricInterpretation: CFA
        {0x111,  T_LONG,       1,  0, NULL},                                    // StripOffsets: Offset
        {0x115,  T_SHORT,      1,  1, NULL},                                    // SamplesPerPixel: 1
        {0x116,  T_SHORT|T_PTR,1,  0, &raw_info->height},                       // RowsPerStrip
        {0x117,  T_LONG|T_PTR, 1,  0, &raw_info->frame_size},                   // StripByteCounts = CHDK RAW size
        {0x11A,  T_RATIONAL|T_PTR,   1,  0, (void*)resolution},                // XResolution
        {0x11B,  T_RATIONAL|T_PTR,   1,  0, (void*)resolution},                // YResolution
        {0x11C,  T_SHORT,      1,  1, NULL},                                    // PlanarConfiguration: 1
        {0x128,  T_SHORT,      1,  2, NULL},                                    // ResolutionUnit: inch
        {0x828D, T_SHORT,      2,  0x00020002, NULL},                           // CFARepeatPatternDim: Rows = 2, Cols = 2
        {0x828E, T_BYTE|T_PTR, 4,  0, &raw_info->cfa_pattern},
        {0xC61A, T_LONG|T_PTR, 1,  0, &raw_info->black_level},                  // BlackLevel
        {0xC61D, T_LONG|T_PTR, 1,  0, &raw_info->white_level},                  // WhiteLevel
        {0xC61F, T_LONG|T_PTR, 2,  0, &raw_info->crop.origin},
        {0xC620, T_LONG|T_PTR, 2,  0, &raw_info->crop.size},
        {0xC68D, T_LONG|T_PTR, 4,  0, &raw_info->dng_active_area},
        {0xC740, T_UNDEFINED|T_PTR, sizeof(bpOpcode), 0, &bpOpcode},
    };

    struct dir_entry exif_ifd[]={
        {0x829A, T_RATIONAL|T_PTR,  1,  0,                          shutter},                       // Shutter speed
        {0x829D, T_RATIONAL|T_PTR,  1,  0,                          aperture},                      // Aperture
        {0x8827, T_SHORT|T_PTR,     1,  0,                          &iso},                          // ISOSpeedRatings
        {0x9000, T_UNDEFINED,       4,                              0x31323230, NULL},              // ExifVersion: 2.21
        {0x9003, T_ASCII|T_PTR,     (uint32_t)strlen(dateTime)+1,   0, (void*)dateTime},            // DateTimeOriginal
        {0x920A, T_RATIONAL|T_PTR,  1,                              0,  focalLength},               // FocalLength
        {0x9290, T_ASCII|T_PTR,     (uint32_t)strlen(subSecTime)+1, 0, (void*)subSecTime},          // DateTime milliseconds
        {0x9291, T_ASCII|T_PTR,     (uint32_t)strlen(subSecTime)+1, 0, (void*)subSecTime},          // DateTimeOriginal milliseconds
    };

    struct {
        struct dir_entry* entry;
        int32_t count;                  // Number of entries to be saved
        int32_t entry_count;            // Total number of entries
    } ifd_list[] =
    {
        {ifd0,      DIR_SIZE(ifd0),     DIR_SIZE(ifd0)},
        {ifd1,      DIR_SIZE(ifd1),     DIR_SIZE(ifd1)},
        {exif_ifd,  DIR_SIZE(exif_ifd), DIR_SIZE(exif_ifd)},
    };

    ifd0[DNG_VERSION_INDEX].offset = htonl(0x01030000);

    ifd1[BADPIXEL_OPCODE_INDEX].type &= ~T_SKIP;
    // Set CFAPattern value
    switch (raw_info->cfa_pattern)
    {
        case 0x02010100:
            bpOpcode[BADPIX_CFA_INDEX] = htonl(1);              // BayerPhase = 1 (top left pixel is green in a green/red row)
            break;
        case 0x01020001:
            bpOpcode[BADPIX_CFA_INDEX] = htonl(0);              // BayerPhase = 0 (top left pixel is red)
            break;
        case 0x01000201:
            bpOpcode[BADPIX_CFA_INDEX] = htonl(3);              // BayerPhase = 3 (top left pixel is blue)
            break;
        case 0x00010102:
            bpOpcode[BADPIX_CFA_INDEX] = htonl(2);              // BayerPhase = 2 (top left pixel is green in a green/blue row)
            break;
    }

    // filling EXIF fields
    int32_t ifd_count = DIR_SIZE(ifd_list);

    // skip color matrix 2, if no data
    int32_t* cameraMatrix2 = (int32_t*)ifd0[CAMERA_MATRIX_2_INDEX].offset_ptr;
    if (cameraMatrix2[0] == 0) {
        ifd0[CAMERA_MATRIX_2_INDEX].type |= T_SKIP;
        ifd0[CALIBRATION_ILLUMINANT_2_INDEX].type |= T_SKIP;
        ifd_list[0].count -= 2;
    }

    // calculating offset of RAW data and count of entries for each IFD
    raw_offset=TIFF_HDR_SIZE;

    for (j=0;j<ifd_count;j++)
    {
        raw_offset+=6; // IFD header+footer
        for(i=0; i<ifd_list[j].entry_count; i++)
        {
            struct dir_entry* entry = &(ifd_list[j].entry[i]);

            if ((entry->type & T_SKIP) == 0)  // Exclude skipped entries (e.g. GPS info if camera doesn't have GPS)
            {
                raw_offset+=12; // IFD directory entry size
                int32_t size_ext= [self _getSizeOfType:(entry->type)]*entry->count;
                if (size_ext>4) raw_offset+=size_ext+(size_ext&1);
            }
            else {
                NSLog(@"skip");
            }
        }
    }

    // creating buffer for writing data
    raw_offset=(raw_offset/512+1)*512;

    uint8_t* headerBuffer = malloc(raw_offset);
    memset(headerBuffer, 0, raw_offset);

    if (!headerBuffer) {
        return NO;
    }

    *outHeaderBuf = headerBuffer;
    *outHeaderSize = raw_offset;

    __block int32_t headerBufferOffset = 0;
    void (^AppendToBuf)(void*, int32_t) = ^void(void* var, int32_t size) {
        memcpy(headerBuffer+headerBufferOffset,var,size);
        headerBufferOffset += size;
    };

    void (^AppendValueToBuf)(int32_t, int32_t) = ^void(int32_t val, int32_t size) {
        AppendToBuf(&val, size);
    };


    //  writing offsets for EXIF IFD and RAW data and calculating offset for extra data

    extra_offset=TIFF_HDR_SIZE;

    ifd0[SUBIFDS_INDEX].offset = TIFF_HDR_SIZE + ifd_list[0].count * 12 + 6;                            // SubIFDs offset
    ifd0[EXIF_IFD_INDEX].offset = TIFF_HDR_SIZE + (ifd_list[0].count + ifd_list[1].count) * 12 + 6 + 6; // EXIF IFD offset
    ifd0[THUMB_DATA_INDEX].offset = raw_offset;                                     //StripOffsets for thumbnail
    ifd1[RAW_DATA_INDEX].offset = raw_offset + dng_th_width * dng_th_height * 3;    //StripOffsets for main image

    for (j=0;j<ifd_count;j++)
    {
        extra_offset += 6 + ifd_list[j].count * 12; // IFD header+footer
    }

    // TIFF file header
    AppendValueToBuf(0x4949, sizeof(int16_t));
    AppendValueToBuf(42, sizeof(int16_t));
    AppendValueToBuf(TIFF_HDR_SIZE, sizeof(int32_t));

    // writing IFDs
    for (j=0;j<ifd_count;j++)
    {
        int32_t size_ext;
        AppendValueToBuf(ifd_list[j].count, sizeof(int16_t));
        for(i=0; i<ifd_list[j].entry_count; i++)
        {
            struct dir_entry* entry = &(ifd_list[j].entry[i]);

            if ((entry->type & T_SKIP) == 0)
            {
                uint16_t tag = entry->tag;
                uint32_t type = entry->type & 0xFF;
                uint32_t count = entry->count;

                AppendValueToBuf(tag, sizeof(int16_t));
                AppendValueToBuf(type, sizeof(int16_t));
                AppendValueToBuf(entry->count, sizeof(int32_t));

                size_ext=[self _getSizeOfType:type]*count;
                if (size_ext<=4)
                {
                    if (entry->type & T_PTR)
                    {
                        AppendToBuf(entry->offset_ptr, sizeof(int32_t));
                    }
                    else
                    {
                        AppendValueToBuf(entry->offset, sizeof(int32_t));
                    }
                }
                else
                {
                    AppendValueToBuf(extra_offset, sizeof(int32_t));
                    extra_offset += size_ext+(size_ext&1);
                }
            }
        }
        AppendValueToBuf(0, sizeof(int32_t));
    }

    // writing extra data

    for (j=0;j<ifd_count;j++)
    {
        int32_t size_ext;
        for(i=0; i<ifd_list[j].entry_count; i++)
        {
            struct dir_entry* entry = &(ifd_list[j].entry[i]);

            if ((entry->type & T_SKIP) == 0)
            {
//                uint16_t tag = entry->tag;
                uint32_t type = entry->type & 0xFF;
                uint32_t count = entry->count;

                size_ext=[self _getSizeOfType:type]*count;
                if (size_ext>4)
                {
                    AppendToBuf(entry->offset_ptr, size_ext);
                    if (size_ext&1) {
                        AppendValueToBuf(0, 1);
                    }
                }
            }
        }
    }

    return YES;
}


NS_INLINE void reverse_bytes_order(int8_t* buf, int32_t count)
{
    int16_t* buf16 = (int16_t*) buf;
    register int32_t i;
    for (i = 0; i < count/2; i++) {
        buf16[i] = CFSwapInt16(buf16[i]);
    }
}

- (void*) _createThumbnail
{
    void* thumbnailBuf = malloc(dng_th_width*dng_th_height*3);
    if (!thumbnailBuf) {
        return NULL;
    }

    if (!self.compressed) {
        register int32_t i, j, x, y, yadj, xadj;
        register char *buf = thumbnailBuf;

        struct raw_info* rawInfo = self.rawInfo;
        void* rawBuffer = self.rawBuffer;

        yadj = (rawInfo->cfa_pattern == 0x01000201) ? 1 : 0;
        xadj = (rawInfo->cfa_pattern == 0x01020001) ? 1 : 0;

        for (i=0; i<dng_th_height; i++) {
            for (j=0; j<dng_th_width; j++) {
                x = rawInfo->active_area.x1 + ((rawInfo->jpeg.x + (rawInfo->jpeg.width  * j) / dng_th_width)  & 0xFFFFFFFE) + xadj;
                y = rawInfo->active_area.y1 + ((rawInfo->jpeg.y + (rawInfo->jpeg.height * i) / dng_th_height) & 0xFFFFFFFE) + yadj;

                *buf++ = RawTo8BitSRGB(GetRawPixel(rawInfo, rawBuffer, x,y), 0, rawInfo);        // red pixel
                *buf++ = RawTo8BitSRGB(GetRawPixel(rawInfo, rawBuffer, x+1,y), -1, rawInfo);      // green pixel
                *buf++ = RawTo8BitSRGB(GetRawPixel(rawInfo, rawBuffer, x+1,y+1), 0, rawInfo);    // blue pixel
            }
        }
    }
    else {
        memset(thumbnailBuf, 0, dng_th_width*dng_th_height*3);
    }

    return thumbnailBuf;
}


- (NSData*) dngData
{
    struct raw_info* rawInfo = self.rawInfo;
    void* rawBuffer = self.rawBuffer;

    void* headerBuf = NULL;
    int32_t headerSize;
    if (![self _createHeaderAndReturnBuf:&headerBuf headerSize:&headerSize]) {
        return nil;
    }

    void* thumbnailBuf = [self _createThumbnail];
    if (!thumbnailBuf) {
        free(headerBuf);
        return nil;
    }

    size_t data_size = headerSize + dng_th_width*dng_th_height*3 + rawInfo->frame_size;
    void* data_ptr = malloc(data_size);
    void* buf_ptr = data_ptr;

    memcpy(buf_ptr, headerBuf, headerSize);
    buf_ptr += headerSize;

    memcpy(buf_ptr, thumbnailBuf, dng_th_width*dng_th_height*3);
    buf_ptr += dng_th_width*dng_th_height*3;

    memcpy(buf_ptr, rawBuffer, rawInfo->frame_size);
    if (!self.compressed) {
        reverse_bytes_order(buf_ptr, rawInfo->frame_size);
    }

    free(headerBuf);
    free(thumbnailBuf);

    NSData* data = [NSData dataWithBytesNoCopy:data_ptr length:data_size freeWhenDone:YES];

    return data;
}


@end
