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

#import "MLVDataManager.h"
#import "MLVBatch.h"
#import "MLVJob.h"

@interface MLVDataManager ()
@property (strong, readwrite) NSOperationQueue* operationQueue;
@property (strong, readwrite) NSOperationQueue* fileSystemQueue;
@end

@implementation MLVDataManager

+ (MLVDataManager *)sharedManager
{
    static dispatch_once_t once;
    static MLVDataManager *gSharedDataManager;
    dispatch_once(&once, ^ { gSharedDataManager = [[MLVDataManager alloc] init]; });
    return gSharedDataManager;
}

- (instancetype) init {
    if ((self = [super init])) {

        _operationQueue = [[NSOperationQueue alloc] init];
        _fileSystemQueue = [[NSOperationQueue alloc] init];
        _fileSystemQueue.maxConcurrentOperationCount = 1;
        
        [self _restore];
    }

    return self;
}

- (void) _restore
{
    MLVBatch* batch = [[MLVBatch alloc] init];

    self.batches = @[batch];
}

@end
