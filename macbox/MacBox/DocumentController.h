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

- (IBAction)originalOpenDocument:(id _Nullable)sender;
- (void)originalOpenDocumentWithFileSelection;

- (void)openDatabase:(MacDatabasePreferences*)database completion:(void (^_Nullable)(Document*_Nullable document, NSError* _Nullable error))completion;

- (Document*_Nullable)documentForDatabase:(NSString*)uuid;

- (void)onAppStartup;
- (void)launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable;

@end

NS_ASSUME_NONNULL_END
