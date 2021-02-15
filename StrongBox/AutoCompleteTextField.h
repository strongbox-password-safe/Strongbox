//
//  AutoCompleteTextField.h
//  Strongbox-iOS
//
//  Created by Mark on 26/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString*_Nullable (^SuggestionProvider)(NSString *text);

@interface AutoCompleteTextField : UITextField

@property (nonatomic, strong) SuggestionProvider suggestionProvider;
@property (nonatomic, copy) void (^onEdited)(NSString* text);

@end

NS_ASSUME_NONNULL_END
