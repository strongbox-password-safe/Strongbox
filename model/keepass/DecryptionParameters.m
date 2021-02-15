//
//  DecryptionParameters.m
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DecryptionParameters.h"

@implementation DecryptionParameters

- (NSString *)description {
    return [NSString stringWithFormat:@"compressionFlags = [%d], innerRandomStreamId = [%d], transformSeed = [%@], transformRounds = [%llu], masterSeed = [%@], encryptionIv = [%@]",
            self.compressionFlags, self.innerRandomStreamId, self.transformSeed, self.transformRounds, self.masterSeed, self.encryptionIv];
}

@end
