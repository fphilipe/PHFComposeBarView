//
//  PHFComposeBarViewExampleUITests.m
//  PHFComposeBarViewExampleUITests
//
//  Created by Philipe Fatio on 30.01.17.
//  Copyright © 2017 Philipe Fatio. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface PHFComposeBarViewExampleUITests : XCTestCase

@end

@implementation PHFComposeBarViewExampleUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (void)tearDown {
    [super tearDown];
}

- (void)testExample {
    NSString *message = @"Here is some sample text. It's a few lines long but not too long. I think that should do it.";

    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    [[app staticTexts][@"Placeholder"] tap];
    [[app textViews][@"Input"] typeText:message];
    [[app buttons][@"Submit"] tap];

    NSString *output = [[app textViews][@"Main"] value];
    XCTAssert([output containsString:message], "Message text not found in output.");
    
    [[app buttons][@"Utility"] tap];
    output = [[app textViews][@"Main"] value];
    XCTAssert([output containsString:@"Utility button pressed"], "Message text not found in output.");
}

@end
