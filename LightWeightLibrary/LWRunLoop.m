//
//  LWRunLoop.m
//  lwrunloop
//
//  Created by wuyunfeng on 15/10/27.
//  Copyright © 2015年 wuyunfeng open source. All rights reserved.
//

#import "LWRunLoop.h"
// unix standard
#include <sys/unistd.h>

//SYNOPSIS For Kevent
#include <sys/event.h>
#include <sys/types.h>
#include <sys/time.h>

#include <fcntl.h>


#include <pthread.h>
#include <sys/errno.h>

#include "NSThread+Looper.h"

#define MAX_EVENT_COUNT 16

static pthread_once_t mTLSKeyOnceToken = PTHREAD_ONCE_INIT;
static pthread_key_t mTLSKey;
static LWRunLoop *instance;

int _mWakeReadPipeFd;
int _mWakeWritePipeFd;
int _kq;

SEL _action;
id _target;

@implementation LWRunLoop
{
//    int _mWakeReadPipeFd;
//    int _mWakeWritePipeFd;
//    int _kq;
    SEL _action;
    id _target;
}


#pragma mark - C TLS
void initTLSKey(void)
{
    pthread_key_create(&mTLSKey, destructor);
}

void destructor()
{
    NSLog(@"destructor");
    instance = nil;
    close(_kq);
    close(_mWakeReadPipeFd);
    close(_mWakeWritePipeFd);
}


#pragma mark - Object-C
+ (instancetype)currentLWRunLoop
{
    
    int result = pthread_once(& mTLSKeyOnceToken, initTLSKey);
    NSAssert(result == 0, @"pthread_once failure");

    instance = (__bridge LWRunLoop *)pthread_getspecific(mTLSKey);

    if (instance == nil) {
        instance = [[[self class] alloc] init];
        pthread_setspecific(mTLSKey, (__bridge const void *)(instance));
    }
    
    return instance;
}


- (instancetype)init
{
    if (self = [super init]) {
        [self innerInit];
    }
    
    return self;
}


- (void)innerInit
{
    int wakeFds[2];
    
    int result = pipe(wakeFds);
    NSAssert(result == 0, @"Failure in pipe().  errno=%d", errno);
    
    _mWakeReadPipeFd = wakeFds[0];
    _mWakeWritePipeFd = wakeFds[1];
    
    result = fcntl(_mWakeReadPipeFd, F_SETFL, O_NONBLOCK);
    NSAssert(result == 0, @"Failure in fcntl() for read wake fd.  errno=%d", errno);
    
    result = fcntl(_mWakeWritePipeFd, F_SETFL, O_NONBLOCK);
    NSAssert(result == 0, @"Failure in fcntl() for write wake fd.  errno=%d", errno);
    
    _kq = kqueue();
    NSAssert(_kq != -1, @"Failure in kqueue().  errno=%d", errno);

    [self registerFds];

}

- (void)registerFds
{
    struct kevent changes[1];
    EV_SET(changes, _mWakeReadPipeFd, EVFILT_READ, EV_ADD, 0, 0, NULL);
    int ret = kevent(_kq, changes, 1, NULL, 0, NULL);
    NSAssert(ret != -1, @"Failure in kevent().  errno=%d", errno);
}


- (void)run
{
    [[NSThread currentThread] setLooper];

    struct kevent events[MAX_EVENT_COUNT];
    while (true) {

        int ret = kevent(_kq, NULL, 0, events, MAX_EVENT_COUNT, NULL);

        for (int i = 0; i < ret; i++)
        {
            int eventFd = (int)events[i].ident;
            if (eventFd == _mWakeReadPipeFd) {
                [self handleReadWake];
                [self registerFds];
                break;
            }
        }
    }
}

- (void)handleReadWake
{
    char buffer[16];
    ssize_t nRead;
    do {
        nRead = read(_mWakeReadPipeFd, buffer, sizeof(buffer));
        if ([_target respondsToSelector:_action]) {
            [_target performSelector:_action withObject:nil];
        }
    } while ((nRead == -1 && errno == EINTR) || nRead == sizeof(buffer));
}

- (void)handleWriteWake
{
    ssize_t nWrite;
    do {
        nWrite = write(_mWakeWritePipeFd, "W", 1);
    } while (nWrite == -1 && errno == EINTR);
    
    if (nWrite != 1) {
        if (errno != EAGAIN) {
            NSLog(@"Could not write wake signal, errno=%d", errno);
        }
    }
}

- (void)postTarget:(id)target withAction:(SEL)aSel
{
    _target = target;
    _action = aSel;
    [self handleWriteWake];
}

- (void)dealloc
{
    NSLog(@"dealloc");
}

@end