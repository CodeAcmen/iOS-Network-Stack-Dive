//
//  TJPNetworkConfig.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/23.
//  配置类

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPNetworkConfig : NSObject 

/// 主机
@property (nonatomic, copy) NSString *host;

/// 端口号
@property (nonatomic, assign) uint16_t port;

/// 最大重试次数 默认5
@property (nonatomic, assign) NSUInteger maxRetry;

/// 心跳时间 默认15秒
@property (nonatomic, assign) CGFloat heartbeat;

/// 基础延迟默认 2秒
@property (nonatomic, assign) NSTimeInterval baseDelay;

/// 连接超时  默认15秒
@property (nonatomic, assign) NSTimeInterval connectTimeout;

/// 是否在服务器关闭连接后重连
@property (nonatomic, assign) BOOL shouldReconnectAfterServerClose;

/// 是否在应用进入后台后重连
@property (nonatomic, assign) BOOL shouldReconnectAfterBackground;

/// 是否使用TLS
@property (nonatomic, assign) BOOL useTLS;

/// 指标收集级别，默认为基本级别
@property (nonatomic, assign) TJPMetricsLevel metricsLevel;

/// 指标上报间隔（秒），默认15秒
@property (nonatomic, assign) NSTimeInterval metricsReportInterval;

/// 是否将指标打印到控制台，默认为YES
@property (nonatomic, assign) BOOL metricsConsoleEnabled;


/// 初始化方法
+ (instancetype)configWithHost:(NSString *)host port:(uint16_t)port maxRetry:(NSUInteger)maxRetry heartbeat:(CGFloat)heartbeat;
+ (instancetype)defaultConfig;


@end

NS_ASSUME_NONNULL_END
