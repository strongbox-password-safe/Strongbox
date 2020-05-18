//
//  DeletedItem.m
//  Strongbox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DeletedItem.h"

@implementation DeletedItem

+ (instancetype)uuid:(NSUUID*)uuid {
    return [DeletedItem uuid:uuid date:NSDate.date];
}

+ (instancetype)uuid:(NSUUID *)uuid date:(NSDate *)date {
    return [[DeletedItem alloc] initWithUuid:uuid date:date];
}

- (instancetype)initWithUuid:(NSUUID*)uuid date:(NSDate*)date {
    self = [super init];
    if (self) {
        self.uuid = uuid;
        self.date = date;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ deleted %@", self.uuid, self.date];
}

@end
