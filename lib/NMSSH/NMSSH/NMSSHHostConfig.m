#import "NMSSHHostConfig.h"

@implementation NMSSHHostConfig

- (id)init {
    if ((self = [super init])) {
        [self setHostPatterns:@[ ]];
        [self setIdentityFiles:@[ ]];
    }
    return self;
}

- (NSArray *)arrayByRemovingDuplicateElementsFromArray:(NSArray *)array {
    NSMutableArray *deduped = [NSMutableArray array];
    for (NSObject *object in array) {
        if (![deduped containsObject:object]) {
            [deduped addObject:object];
        }
    }
    return [deduped copy];
}

- (NSArray *)mergedArray:(NSArray *)firstArray withArray:(NSArray *)secondArray {
    NSArray *concatenated = [firstArray arrayByAddingObjectsFromArray:secondArray];
    return [self arrayByRemovingDuplicateElementsFromArray:concatenated];
}

- (void)mergeFrom:(NMSSHHostConfig *)other {
    [self setHostPatterns:[self mergedArray:self.hostPatterns
                                  withArray:other.hostPatterns]];
    if (!self.hostname) {
        [self setHostname:other.hostname];
    }
    if (!self.user) {
        [self setUser:other.user];
    }
    if (self.port == nil) {
        [self setPort:other.port];
    }
    [self setIdentityFiles:[self mergedArray:self.identityFiles
                                   withArray:other.identityFiles]];
}

@end

