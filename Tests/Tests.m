//
//  Tests.m
//  Tests
//
//  Created by Martin Hering on 15.05.17.
//  Copyright © 2017 Martin Hering. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MLVFile.h"
#import "MLVRawImage+DNG.h"
#import "MLVProcessorProtocol.h"

#define TEST_FILE_PATH @"/Users/hering/Desktop/M22-1234.MLV"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

static inline void hxRunInMainLoop(void(^block)(BOOL *done)) {
    __block BOOL done = NO;
    block(&done);
    while (!done) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }
}


//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

#pragma mark -

- (void)testConvertingDNG {

    NSURL* url = [NSURL fileURLWithPath:TEST_FILE_PATH];
    MLVFile* file = [[MLVFile alloc] initWithURL:url];

    MLVErrorCode errCode;
    MLVRawImage* rawImage = [file readVideoDataBlock:file.videoBlocks[0] errorCode:&errCode];
    
    NSData* dngData = rawImage.dngData;
    [dngData writeToFile:@"/Users/hering/Desktop/test.dng" atomically:YES];
}

- (void)testXPCProcessAttributes
{
    NSURL* url = [NSURL fileURLWithPath:TEST_FILE_PATH];

    hxRunInMainLoop(^(BOOL *done) {

        NSXPCConnection* xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"org.martinhering.mlvprocess"];
        xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MLVProcessorProtocol)];
        [xpcConnection resume];


        id remoteProxy = [xpcConnection remoteObjectProxy];
        [remoteProxy openFileWithURL:url withReply:^(NSString *fileId, NSDictionary<NSString*, id> *attributes, NSData *archiveData, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", attributes);

                [remoteProxy closeFileWithId:fileId withReply:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [xpcConnection invalidate];
                        *done = YES;
                    });
                }];
            });
        }];
    });
}

- (void)testXPCProcessArchiving
{
    NSURL* url = [NSURL fileURLWithPath:TEST_FILE_PATH];

    hxRunInMainLoop(^(BOOL *done) {

        NSXPCConnection* xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"org.martinhering.mlvprocess"];
        xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MLVProcessorProtocol)];
        [xpcConnection resume];

        id remoteProxy = [xpcConnection remoteObjectProxy];
        [remoteProxy openFileWithURL:url withReply:^(NSString *fileId, NSDictionary<NSString*, id> *fileAttributes, NSData *archiveData, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [remoteProxy closeFileWithId:fileId withReply:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{

                        [remoteProxy openFileWithArchiveData:archiveData withReply:^(NSString *fileId, NSDictionary<NSString *,id> *archiveAttributes, NSError *error) {
                            dispatch_async(dispatch_get_main_queue(), ^{

                                XCTAssertEqualObjects(fileAttributes, archiveAttributes);

                                [remoteProxy closeFileWithId:fileId withReply:^(NSError *error) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [xpcConnection invalidate];
                                        *done = YES;
                                    });
                                }];
                            });
                        }];
                    });
                }];
            });
        }];
    });
}

- (void)testXPCReadingDataBlock
{
    NSURL* url = [NSURL fileURLWithPath:TEST_FILE_PATH];

    hxRunInMainLoop(^(BOOL *done) {

        NSXPCConnection* xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"org.martinhering.mlvprocess"];
        xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MLVProcessorProtocol)];
        [xpcConnection resume];

        id remoteProxy = [xpcConnection remoteObjectProxy];
        [remoteProxy openFileWithURL:url withReply:^(NSString *fileId, NSDictionary<NSString*, id> *fileAttributes, NSData *archiveData, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{

                for(NSInteger i=0 ; i<100; i++) {
                    [remoteProxy readVideoFrameAtIndex:i fileId:fileId options:0 withReply:^(NSData *dngData, NSData* highlightMapData, NSDictionary<NSString *,id> *avSettings, NSError *error) {

                        NSLog(@"a");

                        if (i==100-1) {
                            [xpcConnection invalidate];
                            *done = YES;
                        }
                    }];
                }
            });
        }];
    });
    
    NSLog(@"a");
}

@end
