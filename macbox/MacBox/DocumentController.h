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

- (Document*_Nullable)documentForDatabase:(MacDatabasePreferences*)database;
- (BOOL)databaseIsDocumentWindow:(MacDatabasePreferences*)database;
- (BOOL)databaseIsUnlockedInDocumentWindow:(MacDatabasePreferences*)database;
- (void)closeDocumentWindowForDatabase:(MacDatabasePreferences *)database;

- (void)onAppStartup;
- (void)performEmptyLaunchTasksIfNecessary;

- (void)serializeAndAddDatabase:(DatabaseModel*)database
                         format:(DatabaseFormat)format;

@end

NS_ASSUME_NONNULL_END
