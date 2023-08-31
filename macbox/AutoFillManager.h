//
//  AutoFillManager.h
//  Strongbox
//
//  Created by Mark on 01/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"
#import "QuickTypeAutoFillDisplayFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillManager : NSObject 

+ (instancetype)sharedInstance;

@property (readonly) BOOL isOnForStrongbox;

- (void)updateAutoFillQuickTypeDatabase:(Model*)database
                           databaseUuid:(NSString*)databaseUuid
                          displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
                        alternativeUrls:(BOOL)alternativeUrls
                           customFields:(BOOL)customFields
                                  notes:(BOOL)notes
           concealedCustomFieldsAsCreds:(BOOL)concealedCustomFieldsAsCreds
         unConcealedCustomFieldsAsCreds:(BOOL)unConcealedCustomFieldsAsCreds
                               nickName:(NSString*)nickName;

- (void)clearAutoFillQuickTypeDatabase;

@end

NS_ASSUME_NONNULL_END
