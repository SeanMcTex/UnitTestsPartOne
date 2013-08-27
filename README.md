# Unit Tests That Write Themselves: Part One

Unit tests are fantastic. They make  code more robust, refactoring less scary, help developers design programs well, and allow machines do more of the monkey work involved in creating a robust app.

But let's face it: unit tests aren’t always the most fun to write. Worse yet, if developers are trying to achieve high code coverage or adhere to Test Driven Development, they will often end up with a *lot* of repetitive tests.

This is a state of affairs that wouldn't stand for a minute in application code, but which often passes without a second thought in test code. But if we're serious about testing, this should bother us. We should strive to keep our tests as [^1]DRY as we keep our app.

How do we achieve this? In this article, we'll implement a superclass for test suites with common elements, and see how to use the Objective-C runtime to make sure those tests are named meaningfully. (Teaser: in the followup article, we'll see a technique that delves deeper into runtime kung-fu to write entire test cases automatically.)

If you'd like to follow along with some working code, you can download a sample project [from GitHub](https://github.com/SeanMcTex/UnitTestsPartOne). Choose the GHUnitTests target and run in the simulator to try it out.

## A Note on Platforms and Testing Frameworks
The examples in this article are written with iOS, Objective-C, and GHUnit in mind, because that's what I work with regularly. The concepts, however, should theoretically translate across to other languages and testing frameworks without much fuss.

Some of the runtime tricks here, however, rely on the testing framework doing things in a certain order. (Specifically, test cases need to be fully instantiated before the testing framework asks them what tests they have available.) GHUnit does things this way. XCTest does not, so this technique would have to be modified somewhat to work with that framework.

## Superclasses for Super Tests

As with application code, when there are a lot of commonalities across classes, it's time to start thinking about building a superclass to provide a single, happy home for that common code. Since most iOS apps have a wealth of view controllers, let's consider what sorts of things to test for all of them and how this approach can help.

First off, let's create a parent class to use for all of our test cases for any view controllers in our app. Your header will look something like this if you're using GHUnit:

	@interface UIViewControllerTestCase : GHTestCase
	@property (nonatomic, strong) UIViewController *viewControllerUnderTest;
	@end

Note that we've included a property for the view controller that's being tested. Having a common place for this will allow us to run tests both in the common superclass and in the view controller-specific test classes.

In order to reduce the duplication required for our `setUp` and `tearDown`methods, we'll do the job of creating an instance of our test class right here. But how do we know what class is under test, and how do we create an instance of it once we know?

Here are our `setUp` and `tearDown` methods, which all our subclasses will inherit from and use.

	- (void)setUp {
		[super setUp];
		self.viewControllerUnderTest = [[[self classUnderTest] alloc] init];
	}

	- (void)tearDown {
		[super tearDown];
		self.viewControllerUnderTest = nil;
	}

	- (Class)classUnderTest {
		NSAssert( NO, @"Class under test must be defined by subclass");
		return nil;
	}

As you can  see, trying to run this directly will trigger the assertion. We've set things up this way because Objective-C doesn't have the notion of abstract classes. When we write our MainViewController and its corresponding test class MainViewControllerTests, we would implement the test class to inherit from this class like this:

	@interface MainViewControllerTests : UIViewControllerTestCase
	@end
	
	@implementation MainViewControllerTests
	
	- (Class)classUnderTest {
		return [MainViewController class];
	}
	
	@end

(If you need to do extra setup for a specific view controller, you can of course implement `setUp` and simply call `[super setUp]` within it to take advantage of the functionality the superclass provides.)

## Using the Runtime Library for Meaningfully Named Tests

With the foundation in place, it's time to add a test to verify that the view controller can indeed be instantiated. We could simply add a "testViewControllerCreation" method all of the subclassed test cases would pick up and run. However, if that test failed, simply looking at its name wouldn't give any clues as to *which* view controller couldn't be created. In order to make the test as informative as we'd like, we can use the Objective-C runtime to add a method with an appropriate name to the subclassed test case like so:

	#import <objc/runtime.h>
	
	- (id)init {
		self = [super init];
		if ( self ) {
			[self setUpDynamicTestMethods];
		}
		return self;
	}

	- (void)setUpDynamicTestMethods {
	    // register "test<className>creation" method
    
	    NSString *creationMethodName = [NSString stringWithFormat:@"test%@Creation", NSStringFromClass([self classUnderTest]) ];
	    SEL creationSelector = sel_registerName( [creationMethodName UTF8String] );
	    SEL creationTest = @selector(validateViewControllerCreated);    
	    class_addMethod( [self class], creationSelector, [[self class] instanceMethodForSelector:creationTest ], "v@:");
	}

	- (void) validateViewControllerCreated {
	    GHAssertNotNil(self.viewControllerUnderTest, @"View Controller not created successfully");
	    GHAssertTrue([self.viewControllerUnderTest isMemberOfClass:[self classUnderTest]], @"Test instance is incorrect class");
	}

There's some interesting (and probably unfamiliar) stuff going on in this code, so let's break it down a bit. 

First off, in order to do any mucking about with the runtime, you'll need to include the `runtime.h` headers. These provide the magical ability to examine and modify objects and classes in memory. We can see what methods are defined on an object, examine properties and instance variable, and even (as we'll be doing) add methods dynamically.

Our init method simply calls `setUpDynamicTestMethods`, which is where the juicy stuff happens. Let's break it down line by line.

First, we decide what the name of the test method should be and assign it to a string. If we're testing `MainViewController`, for example, then creationMethodName gets set to "testMainViewControllerCreation". (Remember, the subclass of this abstract class defines the `classUnderTest`.)

	NSString *creationMethodName = [NSString stringWithFormat:@"test%@Creation", [self classUnderTest]];

Next, we'll use the arcane powers granted to us by `runtime.h` to create a selector with this new name on the fly. (A selector is Objective-C's way of referring to a particular call that you can make on an object. It normally maps directly to a function named the same as the selector, but as we'll see, that can actually be changed.)

	SEL creationSelector = sel_registerName( [creationMethodName UTF8String] );

The actual test code is in the `validateViewControllerCreated` method. In order to use that code, we'll need to grab a selector for that method:

	SEL creationTest = @selector(validateViewControllerCreated);

And finally, with these pieces in place, we can add a new method to our class. Remember, while this code is physically in the abstract superclass (UIViewControllerTestCase), when this is run, it will apply to the concrete subclass (MainViewControllerTests).

	class_addMethod( [self class], creationSelector, [[self class] instanceMethodForSelector:creationTest ], "v@:");

The `class_addMethod` functionality is provided by the runtime library. We pass the class to which we want to add a method and our newly-created dynamically-named selector for the method. The third parameter is the implementation of the function that we want to connect up to the new selector, so we use `instanceMethodForSelector` to get a reference to the function from the selector.

The last parameter is a strange one. It is a string representation of the parameter types that our new method expects and returns. Since we're returning void, the first character is "v". All method implementations in Objective-C include a `self` and `_cmd` parameter, so the second and third characters are always "@:". If we passed any of our own parameters into the `validateViewController` method, we would include additional characters at the end of this string to indicate those parameter types.

Once this code executes, our `MainViewControllerTests` object now has a `testMainViewControllerCreation` method, *even though neither it nor its parent class has such a class in its code*. Even better, whenever we create a new subclass of `MainViewControllerTests`, it will get a setUp method, a tearDown method, and an appropriately named test for view controller creation, all just by specifying the class under test.

## Conclusion

This is just a starting point, of course. You can also test `dealloc` methods to verify that they'll run without incident, call `viewWillAppear` and `viewDidAppear` methods in order to make sure they're running error-free, etc. If there are common behaviors among all view controllers in an app (rotation support, required restorationIdentifiers or a specific backgroundColor), you can add additional test methods here to check those as well.

We've seen how to create a parent class for your tests to reduce duplication. This approach often results in the class hierarchy for your tests mirroring the class hierarchy for your app. It nearly always results in tests that are faster to write and easier to maintain.

In the next article in this series, we'll explore a more advanced method that dives deeper into the Objective-C runtime to create entire test cases automatically without having to write *any* additional code for new classes. It's a great technique that frequently catches coding errors without the programmer having to give any extra thought to tests.

In the meantime, if you're keen to learn more about the magic powers that the runtime library can give you, check out Apple's [Objective-C Runtime Programming Guide](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008048).


[^1]:DRY stands for "Don't Repeat Yourself". It's a useful shorthand for the idea that repetition makes code harder to maintain. (A friend of mine refers to duplicating functionality by copying and pasting as "Editor Inheritance").
