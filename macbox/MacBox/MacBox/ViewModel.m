//
//  ViewModel.m
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewModel.h"

@implementation ViewModel

- (instancetype)initWithData:(NSData*)data {
    if (self = [super init]) {
        _data = data; // TODO: Validate data is a safe?
        _locked = YES;
        return self;
    }
   
    return nil;
}

- (void)lock {
    _locked = YES;
}

- (BOOL)unlock:(NSString*)password error:(NSError**)error {
    if(!_locked) {
        return YES;
    }
    
    CoreModel *model = [[CoreModel alloc] initExistingWithDataAndPassword:self.data password:password error:error];
    
    if(model != nil) {
        self.unlockedDbModel = model;
        _locked = NO;
        return YES;
    }
    
    return NO;
}

@end
