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

#import "MLVJob.h"
#import "MLVDataManager.h"
#import "MLVProcessorProtocol.h"

@interface MLVJob ()
@property (nonatomic, strong) NSXPCConnection* xpcConnection;
@property (nonatomic, strong) NSString* fileId;
@property (readonly) id<MLVProcessorProtocol> remoteProxy;
@end

@implementation MLVJob

- (void) dealloc {
    NSAssert(!_xpcConnection, @"deallocation of MLVJob without prior invalidation");
}


- (void) setUrl:(NSURL *)url {
    if (_url != url) {
        _url = url;

        self.name = [url.lastPathComponent stringByDeletingPathExtension];
    }
}


- (id<MLVProcessorProtocol>) remoteProxy {
    return [_xpcConnection remoteObjectProxy];
}

- (BOOL) readFileWithCompletion:(void (^)(BOOL success, NSError* error))completion
{
    NSParameterAssert(completion);

    if (!_xpcConnection) {
        _xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"org.martinhering.mlvprocess"];
        _xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MLVProcessorProtocol)];
        [_xpcConnection resume];
    }

    self.readingFile = YES;
    [self.remoteProxy openFileWithURL:self.url
                            withReply:^(NSString *fileId, NSDictionary<NSString*, id> *attributes, NSData* archiveData,NSError *error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (error) {
                                        ErrLog(@"error opening file: %@", error);
                                    }
                                    else {
                                        DebugLog(@"file open: %@", fileId);
                                        self.fileId = fileId;
                                    }

                                    self.readingFile = NO;
                                    completion((error == nil), error);
                                });
                            }];

    return YES;
}

- (BOOL) invalidateWithCompletion:(void (^)(BOOL success, NSError* error))completion
{
    NSParameterAssert(completion);
    
    if (!self.remoteProxy) {
        return NO;
    }

    [self.remoteProxy closeFileWithId:self.fileId withReply:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                ErrLog(@"error closing file: %@", error);
            }
            else {
                self.fileId = nil;
            }

            completion((error == nil), error);
        });
    }];

    return YES;
}
@end
