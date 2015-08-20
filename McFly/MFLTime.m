#import "MFLTime.h"
#import "MFLJRSwizzle.h"

#pragma mark - MFLTimeEvent class

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

- (void)invoke {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.selector withObject:self.argument];
#pragma clang diagnostic pop
}

@end

#pragma mark - NSDate Interface
@implementation NSDate (MFLTime)

static BOOL opaqueTestMode__;

+ (void)afterEach {
    [self endOpaqueTestMode];
}

+ (void)beginOpaqueTestMode {
    if (opaqueTestMode__) { return; }
    [self toggleOpaqueTestMode];
    opaqueTestMode__ = YES;
}

+ (void)endOpaqueTestMode {
    if (!opaqueTestMode__) { return; }
    [self toggleOpaqueTestMode];
    opaqueTestMode__ = NO;
}

+ (void)toggleOpaqueTestMode {
    NSError *error;
    
    [[self class] mfljr_swizzleMethod:@selector(timeIntervalSinceNow) withMethod:@selector(replacementTimeIntervalSinceNow) error:&error];
    if (error) {
        [NSException exceptionWithName:@"SwizzleError" reason:[NSString stringWithFormat:@"Error swizzling: %@", error.description] userInfo:nil];
    }
}
#pragma mark Swizzled Methods for opaque test mode

- (NSTimeInterval)replacementTimeIntervalSinceNow {
    NSTimeInterval fakeTime = [self replacementTimeIntervalSinceNow] - MFLTime.sharedInstance.elapsedTime;
    return fakeTime;
}

@end

#pragma mark - NSObject Swizzle

@implementation NSObject (McFlyTime)

+ (void)load {
    NSError *error;
    [NSObject mfljr_swizzleMethod:@selector(performSelector:withObject:afterDelay:) withMethod:@selector(replacementPerformSelector:withObject:afterDelay:) error:&error];
    [NSObject mfljr_swizzleClassMethod:@selector(cancelPreviousPerformRequestsWithTarget:selector:object:) withClassMethod:@selector(replacementCancelPreviousPerformRequestsWithTarget:selector:object:) error:&error];
    [NSObject mfljr_swizzleClassMethod:@selector(cancelPreviousPerformRequestsWithTarget:) withClassMethod:@selector(replacementCancelPreviousPerformRequestsWithTarget:) error:&error];
}

- (void)replacementPerformSelector:(SEL)selector withObject:(id)argument afterDelay:(NSTimeInterval)delay {
    if (MFLTime.sharedInstance.dilationEnabled) {
        [MFLTime.sharedInstance performSelector:selector onTarget:self withArgument:argument afterDelay:delay];
    } else {
        [self replacementPerformSelector:selector withObject:argument afterDelay:delay];
    }
}

+ (void)replacementCancelPreviousPerformRequestsWithTarget:(id)target selector:(SEL)selector object:(id)argument {
    if (MFLTime.sharedInstance.dilationEnabled) {
        [MFLTime.sharedInstance removeScheduledEventForSelector:selector onTarget:target withArgument:argument];
    } else {
        [self replacementCancelPreviousPerformRequestsWithTarget:target selector:selector object:argument];
    }
}

+ (void)replacementCancelPreviousPerformRequestsWithTarget:(id)target {
    if (MFLTime.sharedInstance.dilationEnabled) {
        [MFLTime.sharedInstance removeScheduledEventsForTarget:target];
    } else {
        [self replacementCancelPreviousPerformRequestsWithTarget:target];
    }
}

@end

#pragma mark - MFLTime class

@interface MFLTime ()

@property (strong, nonatomic) NSMutableSet *scheduledEvents;
@property (assign, nonatomic) NSTimeInterval elapsedTime;

@end


static MFLTime *sharedInstance__;

@implementation MFLTime

+ (void)beforeEach {
    [MFLTime.sharedInstance reset];
}

+ (MFLTime *)sharedInstance {
    if (!sharedInstance__) {
        sharedInstance__ = [[MFLTime alloc] init];
    }
    return sharedInstance__;
}

- (id)init {
    if (self = [super init]) {
        self.scheduledEvents = [NSMutableSet set];
        self.dilationEnabled = NO;
    }
    return self;
}

- (void)reset {
    self.elapsedTime = 0;
    self.dilationEnabled = YES;
    [self.scheduledEvents removeAllObjects];
}

- (void)tick:(NSTimeInterval)seconds {
    self.elapsedTime += seconds;
    [self invokeScheduledEvents];
}

- (void)performSelector:(SEL)selector onTarget:(NSObject *)target withArgument:(id)argument afterDelay:(NSTimeInterval)delay {
    NSTimeInterval invocationTime = self.elapsedTime + delay;
    [self.scheduledEvents addObject:[[MFLTimeEvent alloc] initWithTarget:target selector:selector argument:argument invocationTime:invocationTime]];
}

- (void)removeScheduledEventForSelector:(SEL)selector onTarget:(NSObject *)target withArgument:(id)argument  {
    MFLTimeEvent *event = [[self.scheduledEvents objectsPassingTest:^BOOL(MFLTimeEvent *timeEvent, BOOL *stop) {
        return *stop = timeEvent.selector == selector && timeEvent.target == target && timeEvent.argument == argument;
    }] anyObject];
    if (event) {
        [self.scheduledEvents removeObject:event];
    }
}

- (void)removeScheduledEventsForTarget:(NSObject *)target {
    NSMutableSet *eventsToRemove = [[NSMutableSet alloc] init];
    for (MFLTimeEvent *event in self.scheduledEvents) {
        if (event.target == target) {
            [eventsToRemove addObject:event];
        }
    }
    
    for (MFLTimeEvent *event in [eventsToRemove allObjects]) {
        [self.scheduledEvents removeObject:event];
    }
}

#pragma mark - Private interface

- (void)invokeScheduledEvents {
    NSMutableArray *eventsToEvoke = [NSMutableArray array];
    
    for (MFLTimeEvent *event in self.scheduledEvents) {
        if (event.invocationTime <= self.elapsedTime) {
            [eventsToEvoke addObject:event];
        }
    }
    
    [self.scheduledEvents minusSet:[NSSet setWithArray:eventsToEvoke]];
    
    for (MFLTimeEvent *event in eventsToEvoke) {
        [event invoke];
    }
}

- (NSArray *)scheduledEventsInList {
    NSMutableArray *events = [[NSMutableArray alloc] init];
    
    return events;
}

@end
