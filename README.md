# McFly
Hey McFly! Control the passage of time and scheduling of events during test execution. 

<p align="center">
![Hey McFly!](/../screenshots/McFlyTimeLogo.png?raw=true "Hey McFly!")
</p>

Good tests are fast tests. And the best tests test the most complicated interactions - asynchrony, network successes (and failures), what have you -- that's where the bugs live.

But testing things that are dependent on time passing means your tests sit and wait for time to pass. Then your tests take forever to run, you never bother to run them (or skimp on the important tests), your project falls apart due to temporal anomalies, and you never finish your flux capacitor. Not any more! Skip ahead to the good parts with McFly time.

## Implementation
McFly is implemented as two categories: one on NSDate that overrides its canonical mechanism for time representation, another on NSObject that overrides the `performSelector…` methods, plus a utility class, `MFLTime` used to control the hands of the clock.


## Examples

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



## Testing
Of course McFly is tested, using Cedar. Just run the tests on the 

## Usage & Contribution
McFly is free for usage with attribution; please contribute improvements via pull request.
Pull requests should include motivating test cases. 
McFly is based on some work by the inestimable Adam Milligan.

