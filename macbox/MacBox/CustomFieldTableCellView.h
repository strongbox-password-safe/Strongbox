//
//  CustomFieldTableCellView.h
//  Strongbox
//
//  Created by Mark on 28/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomFieldTableCellView : NSTableCellView

- (void)setContent:(NSString*)value;
- (void)setContent:(NSString*)value concealable:(BOOL)concealable;
- (void)setContent:(NSString*)value concealable:(BOOL)concealable concealed:(BOOL)concealed;
- (void)setContent:(NSString*)value concealable:(BOOL)concealable concealed:(BOOL)concealed singleLine:(BOOL)singleLine;
- (void)setContent:(NSString*)value concealable:(BOOL)concealable concealed:(BOOL)concealed singleLine:(BOOL)singleLine plainTextColor:(NSColor*_Nullable)plainTextColor;



@property NSString *value;
@property BOOL protected;
@property BOOL valueHidden;

@end

NS_ASSUME_NONNULL_END
