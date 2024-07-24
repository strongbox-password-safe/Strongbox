//
//  EntryTableCellView.h
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OTPToken.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kEntryTableCellViewIdentifier;

@interface EntryTableCellView : NSTableCellView

- (void)setContent:(NSString*)title username:(NSString*)username image:(NSImage*)image path:(NSString*)path database:(NSString*)database;
- (void)setContent:(NSString*)title username:(NSString*)username totp:(OTPToken* _Nullable)totp image:(NSImage*)image path:(NSString*)path database:(NSString*)database;

@end

NS_ASSUME_NONNULL_END
