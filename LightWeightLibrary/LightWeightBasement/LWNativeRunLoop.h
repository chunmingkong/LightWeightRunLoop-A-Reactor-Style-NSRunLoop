//
//  LWNativeLoop.h
//  LightWeightRunLoop
//
//  Created by wuyunfeng on 15/11/28.
//  Copyright © 2015年 com.wuyunfeng.open. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, LWNativeRunLoopEventFilter) {
    LWNativeRunLoopEventFilterRead = 0,
    LWNativeRunLoopEventFilterWrite = 1
};

typedef NS_OPTIONS(NSUInteger, LWNativeRunLoopFdType) {
    LWNativeRunLoopFdSocketServerType = 0,
    LWNativeRunLoopFdSocketClientType = 1,
    LWNativeRunLoopFdPlainType = 2
};

typedef void (*LWNativeRunLoopCallBack)(int fd, void *info, void *data, int length);

@interface LWNativeRunLoop : NSObject

- (void)nativeRunLoopFor:(NSInteger)timeoutMillis;

- (void)nativeWakeRunLoop;

- (void)nativeDestoryKernelFds;

- (void)addFd:(int)fd type:(LWNativeRunLoopFdType)type filter:(LWNativeRunLoopEventFilter)filter callback:(LWNativeRunLoopCallBack)callback data:(void *)info;

- (void)send:(NSData *)data toPort:(ushort)port;

- (void)send:(NSData *)data toFd:(int)fd;

@end
