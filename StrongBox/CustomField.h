//
//  CustomField.h
//  Strongbox
//
//  Created by Mark on 26/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomField : NSObject

@property NSString* key;
@property NSString* value;
@property BOOL protected;

@end

NS_ASSUME_NONNULL_END
