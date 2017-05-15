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

- (void)testExample {

    NSURL* url = [NSURL fileURLWithPath:@"/Volumes/Media SSD/MLV/Nederland/M22-1047.MLV"];
    MLVFile* file = [[MLVFile alloc] initWithURL:url];

    MLVErrorCode errCode;
    MLVRawImage* rawImage = [file readVideoDataBlock:file.videoBlocks[0] errorCode:&errCode];
    
    NSData* dngData = rawImage.dngData;
    [dngData writeToFile:@"/Users/hering/Desktop/test.dng" atomically:YES];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
