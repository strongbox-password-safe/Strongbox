//
//  CustomFieldViewModel.h
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomFieldViewModel : NSObject

+ (instancetype)customFieldWithKey:(NSString*)key value:(NSString*)value protected:(BOOL)protected;

- (BOOL)isDifferentFrom:(CustomFieldViewModel*)other;



@property (readonly) NSString* key;
@property (readonly) NSString* value;
@property (readonly) BOOL protected;
@property BOOL concealedInUI;

@end

NS_ASSUME_NONNULL_END
