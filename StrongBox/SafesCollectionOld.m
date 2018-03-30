//
//  SafesCollection.m
//  StrongBox
//
//  Created by Mark on 22/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesCollectionOld.h"
#import "SafeMetaData.h"
#import "Utils.h"

@interface SafesCollectionOld ()

@property (nonatomic, nonnull) NSMutableDictionary<NSString*, SafeMetaData*> *theCollection;

@end

@implementation SafesCollectionOld

+ (instancetype)sharedInstance {
    static SafesCollectionOld *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SafesCollectionOld alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        
        self.theCollection = [[NSMutableDictionary alloc] init];
        
        [self load];
        
        return self;
    }
    else {
        return nil;
    }
}

- (BOOL)internalNoSaveAdd:(SafeMetaData *)safe {
    [self.theCollection setObject:safe forKey:safe.nickName];
    
    return YES;
}


//////////////////////////////////////////////////////////////////////////////////////////

- (void)load {
    self.theCollection = [NSMutableDictionary dictionary];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *existingSafes = [userDefaults arrayForKey:@"safes"];
    
    for (NSDictionary *safeDict in existingSafes) {
        SafeMetaData *safe = [SafeMetaData fromDictionary:safeDict];
        
        // TODO: Failure should only ever happen on initial load of 1.12.0 where someone has somehow got 2 identically named safes...
        // virtually impossible
        
        if(![self internalNoSaveAdd:safe]) {
            safe.nickName = [[NSUUID UUID] UUIDString];
            [self internalNoSaveAdd:safe];
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<SafeMetaData*>*)sortedSafes {
    NSArray *snapshot = _theCollection.allValues;
    return [snapshot sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString* str1 = ((SafeMetaData*)obj1).nickName;
        NSString* str2 = ((SafeMetaData*)obj2).nickName;
        
        return [Utils finderStringCompare:str1 string2:str2];
    }];
}

@end
