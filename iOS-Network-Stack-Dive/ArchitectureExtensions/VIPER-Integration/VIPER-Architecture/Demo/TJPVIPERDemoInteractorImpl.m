//
//  TJPVIPERDemoInteractorImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPVIPERDemoInteractorImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPVIPERDemoCellModel.h"
#import "TJPCacheManager.h"
#import "TJPMemoryCache.h"


@interface TJPVIPERDemoInteractorImpl ()

@property (nonatomic, assign) NSInteger totalCount;

@property (nonatomic, strong) TJPCacheManager *cacheManager;

@property (nonatomic, strong) RACCommand <TJPVIPERDemoCellModel *, NSObject *>*selectedDemoDetilCommand;


@end

@implementation TJPVIPERDemoInteractorImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        _totalCount = 0;
        // 初始化缓存管理器，选择使用内存缓存策略
        _cacheManager = [[TJPCacheManager alloc] initWithCacheStrategy:[[TJPMemoryCache alloc] init]];
    }
    return self;
}

- (void)fetchDataForPageWithCompletion:(NSInteger)page success:(void (^)(NSArray * _Nullable, NSInteger))success failure:(void (^)(NSError * _Nullable))failure {
    
    NSString *api = @"https://www.tjp.example.demo.api";
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@_page_%ld", api, page];
    
    NSArray *cachedData = [self.cacheManager loadCacheForKey:cacheKey];
    if (cachedData) {
        TJPLOG_INFO(@"Returning api:%@ cached data for page %ld", api, page);
        if (success) {
            success(cachedData, _totalCount);
        }
        return;
    }
    
    //网络请求类 请求服务器数据
    sleep(0.5);
    
    
    NSMutableArray *itemsArray = [NSMutableArray array];

    for (int i = 0; i < 10; i++) {
        TJPVIPERDemoCellModel *model = [TJPVIPERDemoCellModel new];
        model.detailId = @(i + 1);
        model.title = [NSString stringWithFormat:@"标题 --- %i", i];
        model.selectedCommand = self.selectedDemoDetilCommand;
        [itemsArray addObject:model];
    }
    
    _totalCount = 50;
    [self.cacheManager saveCacheWithData:itemsArray forKey:cacheKey expireTime:TJPCacheExpireTimeShort];

    if (success) {
        success(itemsArray, _totalCount);
    }
}

- (RACCommand<TJPVIPERDemoCellModel *,NSObject *> *)selectedDemoDetilCommand {
    if (nil == _selectedDemoDetilCommand) {
        @weakify(self)
        _selectedDemoDetilCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPVIPERDemoCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedDemoDetilCommand;
}

@end
