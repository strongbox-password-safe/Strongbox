//
//  TextFieldAutoSuggest.h
//  StrongBox
//
//  Created by Mark on 03/06/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef NSArray<NSString*>* (^SuggestionProvider)(NSString *text);

@interface TextFieldAutoSuggest : NSObject

@property (nonatomic) NSUInteger maxVisibleSuggestions;

- (instancetype)initForTextField:(UITextField*)textField
                  viewController:(UIViewController*)viewController
             suggestionsProvider:(SuggestionProvider)suggestionsProvider;

@end
