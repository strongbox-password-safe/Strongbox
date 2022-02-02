//
//  EditCustomFieldController.h
//  MacBox
//
//  Created by Strongbox on 24/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CustomField.h"

NS_ASSUME_NONNULL_BEGIN

@interface EditCustomFieldController : NSViewController

+ (instancetype)fromStoryboard;

@property CustomField* field;
@property (nonatomic, copy) void (^onSetField)(NSString* key, NSString* value, BOOL protected);
@property NSSet<NSString*> *existingKeySet;
@property NSSet<NSString*> *customFieldKeySet;

@end

NS_ASSUME_NONNULL_END
