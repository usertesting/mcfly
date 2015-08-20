#import <Foundation/Foundation.h>

@protocol MFLTimeEvent;

#pragma mark - NSDate Interface
@interface NSDate (MFLTime)
+ (void)beginOpaqueTestMode;
+ (void)endOpaqueTestMode;
@end

@interface MFLTime : NSObject

@property (assign, nonatomic, readonly) NSTimeInterval elapsedTime;
@property (assign, nonatomic, readwrite) BOOL dilationEnabled;

+ (MFLTime *)sharedInstance;

- (void)reset;
- (void)tick:(NSTimeInterval)seconds;
- (void)performSelector:(SEL)selector onTarget:(NSObject *)target withArgument:(id)argument afterDelay:(NSTimeInterval)delay;
- (void)removeScheduledEventForSelector:(SEL)selector onTarget:(NSObject *)target withArgument:(id)argument;
- (void)removeScheduledEventsForTarget:(NSObject *)target;

@end
