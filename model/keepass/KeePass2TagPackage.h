//
//  Kdb31TagPackage.h
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePass2TagPackage : NSObject

@property (nonatomic) NSDictionary<NSNumber *,NSObject *>* unknownHeaders;

@end

NS_ASSUME_NONNULL_END
