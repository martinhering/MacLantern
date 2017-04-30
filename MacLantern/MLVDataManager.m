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
        [self _restore];
    }

    return self;
}

- (void) _restore
{
    MLVBatch* batch = [[MLVBatch alloc] init];

    MLVJob* job1 = [[MLVJob alloc] init];
    job1.name = @"Job 1";

    MLVJob* job2 = [[MLVJob alloc] init];
    job2.name = @"Job 2";

    batch.jobs = @[job1, job2];

    MLVBatch* batch2 = [[MLVBatch alloc] init];

    MLVJob* job3 = [[MLVJob alloc] init];
    job3.name = @"Job 3";

    MLVJob* job4 = [[MLVJob alloc] init];
    job4.name = @"Job 4";

    batch2.jobs = @[job3, job4];

    self.batches = @[batch, batch2];
}

@end
