//
//  Spread.m
//  Spread
//
//  Created by Huy Pham on 3/26/15.
//  Copyright (c) 2015 Katana. All rights reserved.
//

#define KEEP NO

#import "Spread.h"

#import "MapperUtils.h"

@interface SpreadAction: NSObject

@property (nonatomic, copy) NSString *event;
@property (nonatomic, copy) NSString *poolIdentifier;
@property (nonatomic, copy) void (^action)(id, SPool *);

@end

@implementation SpreadAction

@end

@interface Spread()

@property (nonatomic, strong) NSMutableArray *pools;
@property (nonatomic, strong) NSMutableArray *poolActions;
@property (nonatomic, strong) NSDictionary *networkHeader;
@property (nonatomic) NSInteger capacity;

@end

@implementation Spread

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)setNetworkHeader:(NSDictionary *)headers {
    [[self sharedInstance] setNetworkHeader:headers];
}

+ (NSDictionary *)getNetworkHeaders {
    return [[self sharedInstance] networkHeader];
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    [self commonInit];
    return self;
}

- (void)commonInit {
    _capacity = INT_MAX;
    _pools = [NSMutableArray array];
    _poolActions = [NSMutableArray array];
}

- (void)addPool:(SPool *)pool {
    @synchronized(_pools) {
        if ([_pools count] > self.capacity - 1) {
            for (SPool *spool in _pools) {
                if (!spool.keep) {
                    [_pools removeObject:spool];
                    break;
                }
            }
        }
        [[self pools] addObject:pool];
    }
}

+ (SPool *)getPool:(NSString *)identifier {
    NSArray *pools = [[self sharedInstance] pools];
    @synchronized(pools) {
        for (SPool *pool in pools) {
            if ([pool.identifier isEqualToString:identifier]) {
                return pool;
            }
        }
    }
    return nil;
}

+ (SPool *)registerClass:(Class)modelClass
       forPoolIdentifier:(NSString *)identifier {
    return [self registerClass:modelClass
             forPoolIdentifier:identifier
                          keep:KEEP];
}

+ (SPool *)registerClass:(Class)modelClass
       forPoolIdentifier:(NSString *)identifier
                    keep:(BOOL)keep {
    SPool *pool = [self getPool:identifier];
    @synchronized([[self sharedInstance] pools]) {
        if (!pool) {
            pool = [[SPool alloc] init];
            pool.identifier = identifier;
            pool.modelClass = modelClass;
            pool.keep = keep;
            [[self sharedInstance] addPool:pool];
            return pool;
        } else {
            NSAssert([modelClass isSubclassOfClass:[Mapper class]],
                     @"Model register must be SModel or subclass of SModel.");
            NSAssert([pool allModels].count == 0 || pool.modelClass == modelClass,
                     @"Pool contains model and has been registered with another model class.");
        }
        return pool;
    }
}

+ (void)removePoolWithIdentifier:(NSString *)identifier {
    // Remove pool action.
    NSMutableArray *actions = [[self sharedInstance] poolActions];
    NSMutableArray *actionToRemove = [NSMutableArray array];
    @synchronized (actions) {
        for (SpreadAction *action in actions) {
            if ([action.poolIdentifier isEqualToString:identifier]) {
                [actionToRemove addObject:action];
            }
        }
        [actions removeObjectsInArray:actionToRemove];
        // Remove pool.
        SPool *pool = [self getPool:identifier];
        [[[self sharedInstance] pools] removeObject:pool];
    }
}

+ (NSInteger)countIndentifer:(NSString *)identifier inArray:(NSArray *)array {
    NSInteger count = 0;
    for (NSString *string in array) {
        if ([identifier isEqualToString:string]) {
            count++;
        }
    }
    return count;
}

+ (void)registerEvent:(NSString *)event
      poolIdentifiers:(NSArray *)poolIdentifiers
               action:(void (^)(id, SPool *))action {
    for (NSString *poolIdentifier in poolIdentifiers) {
#ifdef DEBUG
        if ([self countIndentifer:poolIdentifier inArray:poolIdentifiers] > 1) {
            NSLog(@"[WARNING]: Duplicated pool identifier.");
        }
#endif
        SpreadAction *poolAction = [[SpreadAction alloc] init];
        poolAction.event = event;
        poolAction.poolIdentifier = poolIdentifier;
        poolAction.action = action;
        [[[self sharedInstance] poolActions] addObject:poolAction];
    }
}

+ (void)removeEvent:(NSString *)event
    poolIdentifiers:(NSArray *)poolIdentifiers {
    NSMutableArray *actions = [[self sharedInstance] poolActions];
    NSMutableArray *actionsToDelete = [NSMutableArray array];
    @synchronized (actions) {
        for (SpreadAction *action in actions) {
            if ([action.event isEqualToString:event]
                && [self countIndentifer:action.poolIdentifier inArray:poolIdentifiers] > 0) {
                [actionsToDelete addObject:action];
            }
        }
        [actions removeObjectsInArray:actionsToDelete];
    }
}

+ (void)removeEvent:(NSString *)event {
    NSMutableArray *actions = [[self sharedInstance] poolActions];
    NSMutableArray *actionsToDelete = [NSMutableArray array];
    @synchronized (actions) {
        for (SpreadAction *action in actions) {
            if ([action.event isEqualToString:event]) {
                [actionsToDelete addObject:action];
            }
        }
        [actions removeObjectsInArray:actionsToDelete];
    }
}

+ (void)removeAllEvent {
    [[[self sharedInstance] poolActions] removeAllObjects];
}

+ (Mapper *)addObject:(NSDictionary *)object
               toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    return [pool addObject:object];
}

+ (NSArray *)addObjects:(NSArray *)objects
                 toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    return [pool addObjects:objects];
}

+ (Mapper *)insertObject:(NSDictionary *)object
                 atIndex:(NSInteger)index
                  toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    return [pool insertObject:object
                      atIndex:index];
}

+ (NSArray *)insertObjects:(NSArray *)objects
                 atIndexes:(NSIndexSet *)indexes
                    toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    return [pool insertObjects:objects
                     atIndexes:indexes];
}

+ (void)addModels:(NSArray *)models
           toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    [pool addModels:models];
}

+ (void)addModel:(id)model
          toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    [pool addModel:model];
}

+ (void)insertModel:(id)model
            atIndex:(NSInteger)index
             toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    [pool insertModel:model
              atIndex:index];
}

+ (void)insertModels:(NSArray *)models
           atIndexes:(NSIndexSet *)indexes
              toPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    [pool insertModels:models
             atIndexes:indexes];
}

+ (void)removeModel:(id)model
           fromPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    if (pool) {
        [pool removeModel:model];
    }
}

+ (void)removeModels:(NSArray *)models
            fromPool:(NSString *)identifier {
    SPool *pool = [self getPool:identifier];
    [pool removeModels:models];
}

+ (void)outEvent:(NSString *)event
           value:(NSDictionary *)value {
    NSMutableArray *actions = [[self sharedInstance] poolActions];
    @synchronized (actions) {
        for (SpreadAction *poolAction in actions) {
            if ([poolAction.event isEqualToString:event]) {
                SPool *pool = [self getPool:poolAction.poolIdentifier];
                if (pool) {
                    poolAction.action(value, pool);
                } else {
                    [[[self sharedInstance] poolActions] removeObject:poolAction];
                }
            }
        }
    }
}

+ (void)setMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount {
    NSAssert(maxConcurrentOperationCount >= 0, @"Max concurrent must be geater than zero.");
    NSOperationQueue *sharedOperationQueue = [[MapperUtils sharedInstance] operationQueue];
    [sharedOperationQueue setMaxConcurrentOperationCount:maxConcurrentOperationCount];
}

+ (void)setCapacity:(NSInteger)capacity {
    NSAssert(capacity >= 0, @"Max capacity must be geater than zero.");
    [[self sharedInstance] setCapacity:capacity];
}

@end
