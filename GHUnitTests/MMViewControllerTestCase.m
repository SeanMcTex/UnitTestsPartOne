//
//  MMViewControllerTestCase.m
//  UnitTestsPartOne
//
//  Created by Sean McMains on 8/23/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import "MMViewControllerTestCase.h"

#import <objc/runtime.h>

@implementation MMViewControllerTestCase

// View controller tests are all UI tests
-(BOOL)shouldRunOnMainThread {
    return YES;
}

- (id)init
{
    self = [super init];
    if (self) {
        BOOL isASubclass = ![self isMemberOfClass:[UIViewController class]];
        if ( isASubclass ) {
            [self setUpDynamicTestMethods];
        }
    }
    return self;
}

-(void)setUpDynamicTestMethods {
    // register "test<className>creation" method
    if ( [self class] != [MMViewControllerTestCase class] ) {
        NSString *creationMethodName = [NSString stringWithFormat:@"test%@Creation", [self classUnderTest]];
        SEL creationSelector = sel_registerName( [creationMethodName UTF8String] );
        SEL creationTest = @selector(validateViewControllerCreated);    
        class_addMethod( [self class], creationSelector, [[self class] instanceMethodForSelector:creationTest ], "v@:");
        
        NSString *viewDidLoadMethodName = [NSString stringWithFormat:@"test%@ViewDidLoad", [self classUnderTest]];
        SEL viewDidLoadSelector = sel_registerName( [viewDidLoadMethodName UTF8String] );
        SEL viewDidLoadTest = @selector(validateViewDidLoad);        
        class_addMethod( [self class], viewDidLoadSelector, [[self class] instanceMethodForSelector:viewDidLoadTest ], "v@:");

        NSString *viewDidUnloadMethodName = [NSString stringWithFormat:@"test%@ViewDidUnload", [self classUnderTest]];
        SEL viewDidUnloadSelector = sel_registerName( [viewDidUnloadMethodName UTF8String] );
        SEL viewDidUnloadTest = @selector(validateViewDidUnload);        
        class_addMethod( [self class], viewDidUnloadSelector, [[self class] instanceMethodForSelector:viewDidUnloadTest ], "v@:");
}
}

# pragma mark - Standard non-dynamic test methods

-(void)setUp {
    [super setUp];
    self.viewControllerUnderTest = [[[self classUnderTest] alloc] init];
    
    NSUInteger count;
    Method *methods = class_copyMethodList([self class], &count);
    for (int i = 0; i < count; i++ ) {
        NSLog(@"%@", NSStringFromSelector( method_getName(methods[i])));
    }
}

-(void)tearDown {
    [super tearDown];
    self.viewControllerUnderTest = nil;
}

#pragma mark - Private Support Methods

-(void) validateViewControllerCreated {
    GHAssertNotNil(self.viewControllerUnderTest, @"View Controller not created successfully");
}

-(void)validateViewDidLoad {
    GHAssertNotNil(self.viewControllerUnderTest.view, @"View controller's view didn't load correctly");
}

-(void)validateViewDidUnload {
    [self.viewControllerUnderTest viewDidUnload];
}

-(Class)classUnderTest {
    NSAssert(NO, @"Class under test must be defined by subclass");
    return nil;
}

@end
