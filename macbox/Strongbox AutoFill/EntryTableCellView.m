//
//  EntryTableCellView.m
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "EntryTableCellView.h"
#import "OTPToken.h"
#import "OTPToken+Generation.h"
#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kEntryTableCellViewIdentifier = @"EntryTableCellView";

@interface EntryTableCellView ()

@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldSubtitle;
@property (weak) IBOutlet NSTextField *textFieldTopRight;
@property (weak) IBOutlet NSTextField *textFieldBottomRight;
@property (weak) IBOutlet NSImageView *image;
@property (weak) IBOutlet NSTextField *textFieldPath;

@end

@implementation EntryTableCellView 

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.textFieldTopRight.font = FontManager.shared.easyReadFont;
}

- (void)setContent:(NSString*)title username:(NSString*)username image:(NSImage*)image path:(NSString*)path database:(NSString*)database {
    [self setContent:title username:username totp:nil image:image path:path database:database];
}

- (void)setContent:(NSString*)title username:(NSString*)username totp:(OTPToken* _Nullable)totp image:(NSImage*)image path:(NSString*)path database:(NSString*)database {
    self.textFieldTitle.stringValue = title ? title : @"";
    self.textFieldSubtitle.stringValue = username ? username : @"";
    
    if ( totp ) {
        self.textFieldTopRight.stringValue = totp.password;
        self.textFieldTopRight.textColor = totp.color;
    }
    else {
        self.textFieldTopRight.stringValue = @"";
        self.textFieldTopRight.textColor = nil;
    }
    
    self.textFieldBottomRight.stringValue = database;
    self.textFieldBottomRight.hidden = database.length == 0;
    
    self.textFieldPath.stringValue = path;
    self.textFieldPath.hidden = path.length == 0;
    
    self.image.image = image;
    self.image.contentTintColor = NSColor.systemBlueColor;
}

@end
