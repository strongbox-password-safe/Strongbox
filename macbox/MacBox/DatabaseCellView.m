//
//  DatabaseCellView.m
//  MacBox
//
//  Created by Strongbox on 18/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseCellView.h"
#import "ClickableTextField.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

@interface DatabaseCellView () <NSTextFieldDelegate>

@property (weak) IBOutlet ClickableTextField *textFieldName;
@property (weak) IBOutlet NSTextField *textFieldSubtitleLeft;
@property (weak) IBOutlet NSTextField *textFieldSubtitleTopRight;
@property (weak) IBOutlet NSTextField *textFieldSubtitleBottomRight;

@end

@implementation DatabaseCellView

- (void)setWithDatabase:(DatabaseMetadata*)metadata {
    [self setWithDatabase:metadata autoFill:NO];
}

- (void)setWithDatabase:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill {
    self.textFieldName.stringValue = metadata.nickName ? metadata.nickName : @"";
    
    NSString* storageInfo = autoFill ? metadata.autoFillStorageInfo : metadata.storageInfo;
    
    NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:storageInfo];
    url = url ? url : metadata.fileUrl; 
    self.textFieldSubtitleLeft.stringValue = url ? url.path : @"";
    
    NSString* fileSize = @"";
    NSString* fileMod = @"";
    
    if (url && !autoFill) {
        NSError* error;
        NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        if (error) {
            NSLog(@"Error getting attributes of database file: [%@]", error);
        }
        else {
            fileSize = friendlyFileSizeString(attr.fileSize);
            fileMod = attr.fileModificationDate.friendlyDateTimeStringPrecise;
        }
    }
    
    self.textFieldSubtitleTopRight.stringValue = fileSize;
    self.textFieldSubtitleBottomRight.stringValue = fileMod;
}

- (void)enableEditing:(BOOL)enable {
    self.textFieldName.editable = enable;
}

@end
