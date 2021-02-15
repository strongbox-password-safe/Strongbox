//
//  DryRunReport.m
//  Strongbox
//
//  Created by Strongbox on 30/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DiffSummary.h"

@implementation DiffSummary

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.onlyInSecond = @[];
        self.edited = @[];
        self.historicalChanges = @[];
        self.moved = @[];
        self.reordered = @[];
        self.onlyInFirst = @[];
    }
    
    return self;
}

- (BOOL)diffExists {
    return (self.onlyInSecond.count + self.edited.count + self.moved.count + self.historicalChanges.count + self.onlyInFirst.count) > 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"created: [%@], edited: [%@], historicalChanges: [%@], moved: [%@], deleted: [%@]", self.onlyInSecond, self.edited, self.historicalChanges, self.moved, self.onlyInFirst];
}

@end
