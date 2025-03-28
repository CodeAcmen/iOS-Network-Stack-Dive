//
//  TJPDynamicHeartbeat.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPDynamicHeartbeat.h"
#import "TJPConcreteSession.h"
#import "TJPSessionProtocol.h"
#import "TJPNetworkCondition.h"
#import "TJPSequenceManager.h"
#import "JZNetworkDefine.h"


@interface TJPDynamicHeartbeat ()

@property (nonatomic, strong) dispatch_queue_t heartbeatQueue;
//@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;
@end

@implementation TJPDynamicHeartbeat {
    dispatch_source_t _heartbeatTimer;
    __weak id<TJPSessionProtocol> _session;

}

- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval seqManager:(nonnull TJPSequenceManager *)seqManager {
    if (self = [super init]) {
        _networkCondition = [[TJPNetworkCondition alloc] init];
        _sequenceManager = seqManager;
        _baseInterval = baseInterval;
        _heartbeatQueue = dispatch_queue_create("com.tjp.dynamicHeartbeat.serialQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (void)startMonitoringForSession:(id<TJPSessionProtocol>)session {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_INFO(@"heartbeat 准备开始发送心跳");
        [self _startMonitoringForSession:session];
    });
}

- (void)_startMonitoringForSession:(id<TJPSessionProtocol>)session {
    _session = session;
    _currentInterval = _baseInterval;
    [_pendingHeartbeats removeAllObjects];
    
    TJPLOG_INFO(@"即将发送首个心跳包");

    //发送首个心跳包
    [self sendHeartbeat];
    
    if (_heartbeatTimer) {
        dispatch_source_cancel(_heartbeatTimer);
        _heartbeatTimer = nil;
    }
    
    //发送心跳包的定时器
    _heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.heartbeatQueue);
    //设置定时器的触发时间
    dispatch_source_set_timer(_heartbeatTimer, DISPATCH_TIME_NOW, _baseInterval * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    //设置定时器的事件处理顺序
    dispatch_source_set_event_handler(_heartbeatTimer, ^{
        [self sendHeartbeat];
    });
    //启动定时器
    dispatch_resume(_heartbeatTimer);
}

- (void)stopMonitoring {
    dispatch_async(self.heartbeatQueue, ^{
        if (self->_heartbeatTimer) {
            dispatch_source_cancel(self->_heartbeatTimer);
            self->_heartbeatTimer = nil;
        }
        [self.pendingHeartbeats removeAllObjects];
        self->_session = nil;
    });
}


- (void)adjustIntervalWithNetworkCondition:(TJPNetworkCondition *)condition {
    dispatch_async(self.heartbeatQueue, ^{
        //规则调整
        [self _calculateQualityLevel:condition];
        
        if (self->_heartbeatTimer == nil) {
            TJPLOG_ERROR(@"当前_heartbeatTimer定时器不存在,更新间隔失败,请检查!!!");
            return;
        }
        // 根据网络状态设置新间隔
        dispatch_source_set_timer(self->_heartbeatTimer, DISPATCH_TIME_NOW, self->_currentInterval * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    });
}

- (void)_calculateQualityLevel:(TJPNetworkCondition *)condition {
    if (condition.qualityLevel == TJPNetworkQualityPoor) {
        //恶劣网络大幅降低
        _currentInterval = _baseInterval * 2.5;
    }else if (condition.qualityLevel == TJPNetworkQualityFair || condition.qualityLevel == TJPNetworkQualityUnknown) {
        //未知网络&&网络不佳时降低频率
        _currentInterval = _baseInterval * 1.5;
    }else {
        //基于滑动窗口动态调整
        CGFloat rttFactor = condition.roundTripTime / 200.0;
        _currentInterval = _baseInterval * MAX(rttFactor, 1.0);
    }
    
    //增加随机扰动 抗抖动设计  单元测试时需要注释
    CGFloat randomFactor = 0.9 + (arc4random_uniform(200) / 1000.0); //0.9 - 1.1
    _currentInterval *= randomFactor;
    
    //再设置硬性限制 防止出现夸张边界问题  15-300s
    _currentInterval = MIN(MAX(_currentInterval, 15), 300);
}

- (void)sendHeartbeat {
    dispatch_async(self.heartbeatQueue, ^{
        id<TJPSessionProtocol> strongSession = self->_session;
        if (!strongSession) {
            return;
        }
        //获取序列号
        uint32_t sequence = [self.sequenceManager nextSequence];
        
        TJPLOG_INFO(@"心跳包正在组装,准备发出  序列号为: %u", sequence);
        
        //组装心跳包
        NSData *packet = [self buildHeartbeatPacket:sequence];
        TJPLOG_INFO(@"心跳包组装完成  序列号为: %u", sequence);
        
        //记录发送时间(毫秒级)
        NSDate *sendTime = [NSDate date];
        
        //将心跳包的序列号和发送时间存入 pendingHeartbeats
        [self.pendingHeartbeats setObject:sendTime forKey:@(sequence)];
            
        //发送心跳包
        TJPLOG_INFO(@"heartbeatManager 准备将心跳包移交给 session 发送数据");
        [self->_session sendHeartbeat:packet];
        
        //动态设置超时阈值 2倍 平均RTT
        self->_currentInterval = MAX(2 * self.networkCondition.roundTripTime / 1000.0, 3.0);
        
        //超时检测
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self->_currentInterval * NSEC_PER_SEC)), self.heartbeatQueue, ^{
            if (self.pendingHeartbeats[@(sequence)]) {
                TJPLOG_INFO(@"触发序列号 %u 的心跳超时检测", sequence);
                [self _removeHeartbeatsForSequence:sequence];
                [self handleHeaderbeatTimeoutForSequence:sequence];
            }
        });
    });
}

- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence {
    dispatch_async(self.heartbeatQueue, ^{
        NSDate *sendTime = self.pendingHeartbeats[@(sequence)];
        if (sendTime) {
            //计算RTT并更新网络状态
            NSTimeInterval rtt = [[NSDate date] timeIntervalSinceDate:sendTime] * 1000; //转毫秒
            [self.networkCondition updateRTTWithSample:rtt];
            [self.networkCondition updateLostWithSample:NO];
        }
        [self _removeHeartbeatsForSequence:sequence];
    });
}

- (void)handleHeaderbeatTimeoutForSequence:(uint32_t)sequence {
    id<TJPSessionProtocol> strongSession = _session;
    if (!strongSession) return;
    
    if (self.pendingHeartbeats[@(sequence)]) {
        TJPLOG_INFO(@"心跳包 %u 超时未确认", sequence);
        //更新丢包率
        [self.networkCondition updateLostWithSample:YES];
        //触发动态调整
        [self adjustIntervalWithNetworkCondition:self.networkCondition];
        
        [_session disconnectWithReason:TJPDisconnectReasonHeartbeatTimeout];
    }
}

- (void)_removeHeartbeatsForSequence:(uint32_t)sequence {
    if (!sequence) return;
    [self.pendingHeartbeats removeObjectForKey:@(sequence)];
}

- (NSData *)buildHeartbeatPacket:(uint32_t)sequence {
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.msgType = htons(TJPMessageTypeHeartbeat);
    //携带序列号
    header.sequence = htonl(sequence);
    
    NSData *packet = [NSData dataWithBytes:&header length:sizeof(header)];
    return packet;
    
}




- (NSMutableDictionary<NSNumber *,NSDate *> *)pendingHeartbeats {
    if (!_pendingHeartbeats) {
        _pendingHeartbeats = [NSMutableDictionary dictionary];
    }
    return _pendingHeartbeats;
}



@end
