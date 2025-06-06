//
//  TJPIMClient.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//  TCP框架入口 门面设计模式屏蔽底层实现

#import <Foundation/Foundation.h>
#import "TJPMessageProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPIMClient : NSObject

/// 单例类
+ (instancetype)shared;

/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
- (void)connectToHost:(NSString *)host port:(uint16_t)port forType:(TJPSessionType)type;

/// 发送消息  消息类型详见 TJPCoreTypes 头文件定义的 TJPContentType
- (void)sendMessage:(id<TJPMessageProtocol>)message;
- (void)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type;


/// 断开连接
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
