//
//  NENPingManager.h
//  NENPingDemo
//
//  Created by minihao on 2019/1/4.
//  Copyright © 2019 minihao. All rights reserved.
//  https://github.com/nenseso/NenPingManager

#import "NENSinglePinger.h"

@interface NENAddressItem : NSObject

@property (nonatomic, copy, readonly) NSString *hostName;
/// average delay time
@property (nonatomic, assign, readonly) double delayMillSeconds;

@property (nonatomic, strong) NSMutableArray *delayTimes;

- (instancetype)initWithHostName:(NSString *)hostName;

@end

typedef void(^CompletionHandler)(NSString * string, NSArray *array);

NS_ASSUME_NONNULL_BEGIN

@interface NENPingManager : NSObject

- (void)getFatestAddress:(NSArray *)addressList completionHandler:(CompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
