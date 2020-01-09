//
//  DocumentController.h
//  MacBox
//
//  Created by Mark on 21/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

@interface DocumentController : NSDocumentController

- (void)originalOpenDocument:(id)sender;
- (void)openDatabase:(DatabaseMetadata*)database completion:(void (^)(NSError* error))completion;
- (void)addDatabaseToDatabases:(NSURL*)url;
- (DatabaseMetadata*)getDatabaseByFileUrl:(NSURL*)url;

@end
