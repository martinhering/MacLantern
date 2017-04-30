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

#import "MLVBatch.h"
#import "MLVJob.h"
#import "MLVTypes.h"

@implementation MLVBatch

- (NSString*) name {
    if (_name) {
        return _name;
    }

    NSMutableArray<NSString*>* jobNames = [[NSMutableArray alloc] init];
    for(MLVJob* job in self.jobs) {
        [jobNames addObject:job.name];
    }
    return (jobNames.count > 0) ? [jobNames componentsJoinedByString:@", "] : @"Untitled";
}

- (void) addJobWithURL:(NSURL*)url
{
    [self _addJobWithURL:url level:0];
}

- (void) _addJobWithURL:(NSURL*)url level:(NSInteger)level
{
    NSFileManager* fman = [NSFileManager defaultManager];

    NSError* error;
    NSDictionary<NSURLResourceKey, id> *urlResources = [url resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    if (error) {
        ErrLog(@"error getting URL resources: %@", error);
        return;
    }

    if ([urlResources[NSURLIsDirectoryKey] boolValue]) {
        if (level == 0) {
            self.name = [url.lastPathComponent stringByDeletingPathExtension];
        }
        NSDirectoryEnumerator<NSURL*>* enumerator = [fman enumeratorAtURL:url
                                               includingPropertiesForKeys:nil
                                                                  options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles
                                                             errorHandler:^BOOL(NSURL *url, NSError *error) {
                                                                 return YES;
                                                             }];
        for (NSURL *fileURL in enumerator) {
            [self _addJobWithURL:fileURL level:level+1];
        }
        return;
    }

    if ([url.pathExtension caseInsensitiveCompare:@"mlv"] != NSOrderedSame) {
        return;
    }

     MLVJob* job = [[MLVJob alloc] init];
     job.url = url;

     [job readFileWithCompletion:^(BOOL success, NSError *error) {

     }];

     if (!self.jobs) {
         self.jobs = @[];
     }
     [[self mutableArrayValueForKey:@"jobs"] addObject:job];
}

@end
