//
//  MMViewControllerTestCase.h
//  UnitTestsPartOne
//
//  Created by Sean McMains on 8/23/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h>

/**
 This abstract class (or it would be abstract, if we were programming in Java)
 is designed to be a parent class for unit tests for View Controllers. It uses
 some extremely clever (read "probably buggy") programming to create a setup, 
 teardown, and validation of creation method for a class being tested.
 
 To use it, make a subclass of it, and return the application class you're 
 testing in the -(Class)classUnderTest method. This parent class will create
 a setup method that spins up core data with the test database, creates an
 instance of the class you specify, and verifies that the class was created
 successfully.
 
 You can, of course, add additional test for your view controller as you see
 fit in your subclass.
 */

@interface MMViewControllerTestCase : GHTestCase
@property (nonatomic, strong) UIViewController *viewControllerUnderTest;

/** 
 Override this method with the View Controller class you want to test.
 */
-(Class)classUnderTest;
@end
