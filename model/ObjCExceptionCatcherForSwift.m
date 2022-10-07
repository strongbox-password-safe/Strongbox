//
//  ObjCExceptionCatcherForSwift.m
//  Strongbox
//
//  Created by Strongbox on 17/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "ObjCExceptionCatcherForSwift.h"

@implementation ObjCExceptionCatcherForSwift

+ (BOOL)catchException:(void (^)(void))tryBlock error:(NSError *__autoreleasing  _Nullable *)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:exception.userInfo];
        return NO;
    }
}



@end
