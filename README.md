# McFly
Hey McFly! Control the passage of time and scheduling of events during test execution. 

![Hey McFly!](/../screenshots/McFlyTimeLogo.png?raw=true "Hey McFly!")

Good tests are fast tests. And the best tests test the most complicated interactions - asynchrony, network successes (and failures), what have you -- that's where the bugs live.

But testing things that are dependent on time passing means your tests sit and wait for time to pass. Then your tests take forever to run, you never bother to run them (or skimp on the important tests), your project falls apart due to temporal anomalies, and you never finish your flux capacitor. Not any more! Skip ahead to the good parts with McFly time.

## Implementation Overview
McFly is implemented as two categories: one on NSDate that overrides its canonical mechanism for time representation, another on NSObject that overrides the `performSelector…` methods, plus a utility class, `MFLTime` used to control the hands of the clock.


## Usage Examples

### Old and Busted

Here's the old way: make a semaphore and spin a runloop. 

```objective-c
- (void)testAnimationResult {
    // Create a semaphore object
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    [UIView animateWithDuration:4.5 animations:^{
        // Some animation
    } completion:^(BOOL finished) {
        // Signal the operation is complete
        dispatch_semaphore_signal(sem);
    }];
    
    // Wait for the operation to complete, but not forever
    double delayInSeconds = 5.0;  // How long until it's too long?
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    long timeoutResult = dispatch_semaphore_wait(sem, timeout);
    
    // Perform any tests (these could also go in the completion block,
    // but it's usually clearer to put them here.
    XCTAssertTrue(timeoutResult == 0, @"Semaphore timed out without completing.");
    XCTAssertTrue(1 == 0, @"Error: 1 does not equal 0, of course!");
}
```

At five-ish seconds per test, you're gonna have a bad time.

### New Hotness

```objective-c
context(@"if the top row is not visible", ^{
    beforeEach(^{
        [NSDate beginTimeDilation]; // activate the flux capacitor
        [controller initiatingAction];
    });
    
    it(@"should float a 'New Stuff' widget at the top of the list", ^{
        controller.widgetsAddedButton.alpha should equal(1);
        controller.widgetsAddedButtonTopConstraint.constant
        should be_greater_than(controller.topLayoutGuide.length);
    });
    
    context(@"after 3 seconds", ^{
        beforeEach(^{
            [[MFLTime sharedInstance] tick:3];
        });
        
        it(@"should remove the 'New Widgets' button", ^{
            controller.widgetsAddedButton.alpha should equal(0);
        });
    });
});
```

This test runs with no delay. 

### Date Comparison
Aha! But what about clocks? If I am doing something like `[NSDate timeIntervalSinceDate:anotherDate]`, won’t it be wrong? Nope. 

```objective-c
@implementation NSDate (MFLTime)

+ (void)toggleTimeDilation {
    NSError *error;

    [[self class] mfjr_swizzleMethod:@selector(timeIntervalSinceReferenceDate) 
  withMethod:@selector(replacementTimeIntervalSinceReferenceDate) error:&error];
    if (error) {
        [NSException exceptionWithName:@"SwizzleError" 
reason:[NSString stringWithFormat:@"Error swizzling: %@", error.description] userInfo:nil];
    }
}

#pragma mark Swizzled Methods

- (NSTimeInterval)replacementTimeIntervalSinceReferenceDate {
    return [self replacementTimeIntervalSinceReferenceDate] +
                 MFLTime.sharedInstance.elapsedTime;
}

@end
```

## Implementation Details
When active, McFly swizzles (thanks, Jon Rentzsch!) `NSObject`'s `performSelector…` methods. Calls to those methods result in a helper object (detailed below) added to a queue on the `MFLTime` controller instead of to the runtime's queue. To make time 'pass', a developer can just `tick:` the desired number of seconds, and appropriate queued messages will be sent. 

McFly uses a helper class, `MFLTimeEvent`, to record events that are so queued. This class does nothing more than record the `selector`, `target`, and `argument` of events that are pushed into the queue.

```objective-c
@interface MFLTimeEvent : NSObject

@property (retain, nonatomic) NSObject *target;
@property (assign, nonatomic) SEL selector;
@property (retain, nonatomic) id argument;
@property (assign, nonatomic) NSTimeInterval invocationTime;

- (id)initWithTarget:(NSObject *)target selector:(SEL)selector argument:(id)argument invocationTime:(NSTimeInterval)invocationTime;
- (void)invoke;

@end

@implementation MFLTimeEvent

- (id)initWithTarget:(NSObject *)target selector:(SEL)selector argument:(id)argument invocationTime:(NSTimeInterval)invocationTime {
    if (self = [super init]) {
        self.target = target;
        self.selector = selector;
        self.argument = argument;
        self.invocationTime = invocationTime;
    }
    return self;
}
```

When execution time comes, the events are invoked:

```objective-c
- (void)invoke {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.selector withObject:self.argument];
#pragma clang diagnostic pop
}
```

### Convenience Categories
McFly includes a few other convenience categories, too, in addition to the ones described. For example, this one short-circuits animations.

```objective-c
@implementation UIView (InstantaneousAnimation)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

+ (void)animateWithDuration:(NSTimeInterval)duration
                 animations:(void (^)(void))animations
                 completion:(void (^)(BOOL))completion {

    if (animations) {
        animations();
    }

    if (completion) {
        completion(YES);
    }
}

#pragma clang diagnostic pop

@end
```

## Testing
Of course McFly is tested, using Cedar. Just run the tests on the included app.

## Usage & Contribution
McFly is free for usage with attribution; please contribute improvements via pull request.

Pull requests should include motivating test cases and stick to the style demonstrated. Please don't make me deal with K & R style braces.

McFly is based on some work by the inestimable Adam Milligan, expanded by Matt Edmonds and Joshua Marker.


