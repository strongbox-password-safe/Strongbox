//
//  DatabaseSynchronizer.m
//  Strongbox
//
//  Created by Strongbox on 18/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseSynchronizer.h"
#import "DatabaseModel.h"

@interface DatabaseSynchronizer ()

@property DatabaseModel* mine;
@property DatabaseModel* theirs;

@end

@implementation DatabaseSynchronizer

+ (instancetype)newSynchronizerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs {
    return [[DatabaseSynchronizer alloc] initSynchronizerFor:mine theirs:theirs];
}

- (instancetype)initSynchronizerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs {
    self = [super init];
    if (self) {
        self.mine = mine;
        self.theirs = theirs;
    }
    return self;
}

- (void)getDiff {
    // TODO: Is root group the right base? or should we be doing it from the very root?
    
    // Credentials Changed
    // Additions
    // Deletions
    // Moves
}

@end
