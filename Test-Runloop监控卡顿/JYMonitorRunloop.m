//
//  JYMonitorRunloop.m
//  Test-Runloop监控卡顿
//
//  Created by 王笑宇 on 2020/12/18.
//

#import "JYMonitorRunloop.h"

@interface JYMonitorRunloop()

@property (nonatomic, strong) dispatch_semaphore_t dispatchSemaphore;
@property (nonatomic, assign) CFRunLoopObserverRef runloopObserver;
@property (nonatomic, assign) CFRunLoopActivity runLoopActivity;
@property (nonatomic, assign) NSUInteger timeoutCount;

@end

@implementation JYMonitorRunloop

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static JYMonitorRunloop *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[JYMonitorRunloop alloc] init];
    });
    return  instance;
}

void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    NSLog(@"Runloop状态改变: %@", [[JYMonitorRunloop shared] activity:activity]);
    [[JYMonitorRunloop shared] setRunLoopActivity:activity];
    dispatch_semaphore_t semaphore = [JYMonitorRunloop shared].dispatchSemaphore;
    dispatch_semaphore_signal(semaphore);
}

- (void)beginMointor {
    [JYMonitorRunloop shared].dispatchSemaphore = dispatch_semaphore_create(0);
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    //self.runloopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, &runLoopObserverCallBack, &context);
    self.runloopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MAX, &runLoopObserverCallBack, &context);
    // 将观察者添加到主线程runloop的common模式下的观察中
    CFRunLoopAddObserver(CFRunLoopGetMain(), self.runloopObserver, kCFRunLoopCommonModes);
    // 创建子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int i = 0;
        while (YES) {
            // 阻塞子线程,如果发现阻塞了3次, Runloop状态还不改变,说明有卡顿.
            long semaphoreWait = dispatch_semaphore_wait(self->_dispatchSemaphore, dispatch_time(DISPATCH_TIME_NOW, 100*NSEC_PER_MSEC));
            NSLog(@"%d semaphore = %ld, %@", i++, semaphoreWait, [self activity:self.runLoopActivity]);
            if (semaphoreWait != 0) { // 只要dispatch_semaphore_signal执行,semaphoreWait就为0
                if (!self.runloopObserver) {
                    self.timeoutCount = 0;
                    self.dispatchSemaphore = 0;
                    self.runLoopActivity = 0;
                    return;
                }
                // 两个runloop的状态,BeforeSources和AfterWaiting这两个状态区间时间能够检测是否卡顿
                if (self.runLoopActivity == kCFRunLoopBeforeSources || self.runLoopActivity == kCFRunLoopAfterWaiting) {
                    // 出现三次结果
                    if (self.timeoutCount++ < 3) { // 一直在kCFRunLoopBeforeSources或者kCFRunLoopAfterWaiting状态超过三次
                        NSLog(@"continue: %@", [self activity:self.runLoopActivity]);
                        continue;
                    }
                    NSLog(@"检测到卡顿了😎, %lu", (unsigned long)self.timeoutCount);
                } // end activity
            } // end semaphore wait
            self.timeoutCount = 0;
        } // end while
    });
}

- (NSString *)activity:(CFRunLoopActivity)activity {
    switch (activity) {
        case kCFRunLoopEntry:
            return  @"kCFRunLoopEntry";
        case kCFRunLoopBeforeTimers:
            return  @"kCFRunLoopBeforeTimers";
        case kCFRunLoopBeforeSources:
            return  @"kCFRunLoopBeforeSources";
        case kCFRunLoopBeforeWaiting:
            return  @"kCFRunLoopBeforeWaiting";
        case kCFRunLoopAfterWaiting:
            return  @"kCFRunLoopAfterWaiting";
        case kCFRunLoopExit:
            return  @"kCFRunLoopExit";
        default:
            return @"kCFRunLoopAllActivities";
    }
}

@end
