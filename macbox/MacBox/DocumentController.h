//
//  DocumentController.h
//  MacBox
//
//  Created by Mark on 21/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDatabasePreferences.h"
#import "DatabaseModel.h"
#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface DocumentController : NSDocumentController

- (void)originalOpenDocument:(id _Nullable)sender;
- (void)openDatabase:(MacDatabasePreferences*)database completion:(void (^_Nullable)(NSError* error))completion;

- (Document*_Nullable)documentForDatabase:(NSString*)uuid;

- (void)onAppStartup;
- (void)launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable;

- (void)serializeAndAddDatabase:(DatabaseModel*)db
                         format:(DatabaseFormat)format
                keyFileBookmark:(NSString*)keyFileBookmark
                  yubiKeyConfig:(YubiKeyConfiguration*)yubiKeyConfig;

@end

NS_ASSUME_NONNULL_END
