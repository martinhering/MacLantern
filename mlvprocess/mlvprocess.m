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

#import "mlvprocess.h"
#import "MLVFile.h"
#import "MLVRawImage+DNG.h"

@implementation mlvprocess {
    NSMutableDictionary<NSString*, MLVFile*>* _openFiles;
}

- (void) openFileWithURL:(NSURL*)url withReply:(void (^)(NSString *fileId, NSDictionary<NSString*, id>* attributes, NSError* error))reply
{
    if (!_openFiles) {
        _openFiles = [[NSMutableDictionary alloc] init];
    }

    MLVFile* file = _openFiles[url.path];
    if (!file) {
        file = [[MLVFile alloc] initWithURL:url];
        _openFiles[url.path] = file;
    }

    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] init];
    reply(url.path, attributes, nil);
}

- (void) closeFileWithId:(NSString*)fileId withReply:(void (^)(NSError* error))reply
{
    MLVFile* file = _openFiles[fileId];
    if (!file) {
        NSError* error = NS_ERROR(-1, @"file is not open: %@", fileId);
        reply(error);
        return;
    }

    [_openFiles removeObjectForKey:fileId];
    reply(nil);
}


@end
