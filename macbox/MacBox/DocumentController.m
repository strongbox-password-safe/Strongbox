//
//  DocumentController.m
//  MacBox
//
//  Created by Mark on 21/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "DocumentController.h"
#import "Document.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "CreateFormatAndSetCredentialsWizard.h"
#import "DatabaseModel.h"
#import "Settings.h"
#import "DatabasesManagerView.h"
#import "DatabasesManager.h"
#import "Alerts.h"
#import "Utils.h"
#import "NSArray+Extensions.h"

static NSString* const kStrongboxPasswordDatabaseDocumentType = @"Strongbox Password Database";

@implementation DocumentController

// Allow open any file type/extension...

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(nullable NSArray<NSString *> *)types {
    return [super runModalOpenPanel:openPanel forTypes:nil];
}

- (void)newDocument:(id)sender {
    CreateFormatAndSetCredentialsWizard* wizard = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
    
    NSString* loc = NSLocalizedString(@"mac_please_enter_master_credentials_for_this_database", @"Please Enter the Master Credentials for this Database");
    wizard.titleText = loc;
    wizard.databaseFormat = kKeePass4;
    wizard.createSafeWizardMode = YES;
    
    NSModalResponse returnCode = [NSApp runModalForWindow:wizard.window];

    if(returnCode != NSModalResponseOK) {
        return;
    }
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    
    NSString* loc2 = NSLocalizedString(@"mac_save_new_database",  @"Save New Password Database...");
    panel.title = loc2;

    NSString* loc3 = NSLocalizedString(@"mac_save_action",  @"Save");
    panel.prompt = loc3;
    
    NSString* loc4 = NSLocalizedString(@"mac_save_new_db_message",  @"You must save this new database before you can use it");
    panel.message = loc4;
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [DatabaseModel getAdaptor:wizard.databaseFormat];
    
    NSString* loc5 = NSLocalizedString(@"mac_untitled_database_filename_fmt", @"Untitled.%@");
    panel.nameFieldStringValue = [NSString stringWithFormat:loc5, adaptor.fileExtension ];
    
    NSInteger modalCode = [panel runModal];

    if (modalCode == NSModalResponseOK) {
        NSURL *URL = [panel URL];

        Document *document = [[Document alloc] initWithCredentials:wizard.databaseFormat
                                               compositeKeyFactors:wizard.confirmedCompositeKeyFactors];

        [document saveToURL:URL ofType:kStrongboxPasswordDatabaseDocumentType forSaveOperation:NSSaveOperation completionHandler:^(NSError * _Nullable errorOrNil) {
            if(errorOrNil) {
                return;
            }

            [self addDocument:document];
            [document makeWindowControllers];
            [document showWindows];
        }];
    }
}

- (void)openDocument:(id)sender {
    if(self.documents.count == 0) { // Empty Launch...
        if(DatabasesManager.sharedInstance.snapshot.count > 0 && Settings.sharedInstance.autoOpenFirstDatabaseOnEmptyLaunch) {
            [self openDatabase:DatabasesManager.sharedInstance.snapshot.firstObject];
        }
        else {
            [DatabasesManagerView show:NO];
        }
    }
    else {
        [self originalOpenDocument:sender];
    }
}

- (void)originalOpenDocument:(id)sender {
    return [super openDocument:sender];
}

- (void)openDatabase:(DatabaseMetadata *)database {
    [self openDatabase:database completion:^(NSError *error) {
        if(error) {
            [DatabasesManagerView show:NO];
        }
    }];
}

//

- (DatabaseMetadata *)getDatabaseByFileUrl:(NSURL *)url {
    // FUTURE: Check Storage type when impl sftp or webdav
    
    return [DatabasesManager.sharedInstance.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return [obj.fileUrl isEqual:url];
    }];
}

static NSString *getBookmarkFromUrlAsString(NSURL *url) {
    NSData *bookmark = nil;
    NSError *error = nil;
    bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
             includingResourceValuesForKeys:nil
                              relativeToURL:nil
                                      error:&error];
    if (error) {
        NSLog(@"Error while creating bookmark for URL (%@): %@", url, error);
        return nil;
    }
    
    NSString *fileIdentifier = [bookmark base64EncodedStringWithOptions:kNilOptions];
    
    return fileIdentifier;
}

- (void)addDatabaseToDatabases:(NSURL *)url {
    DatabaseMetadata *safe = [self getDatabaseByFileUrl:url];
    if(safe) {
//        NSLog(@"Database is already in Databases List... Not Adding");
        return;
    }
    
    NSString * fileIdentifier = getBookmarkFromUrlAsString(url);
    
    if(!fileIdentifier) {
        return;
    }
    
    safe = [[DatabaseMetadata alloc] initWithNickName:[url.lastPathComponent stringByDeletingPathExtension]
                                     storageProvider:kLocalDevice
                                             fileUrl:url
                                      storageInfo:fileIdentifier];
    
    [DatabasesManager.sharedInstance add:safe];
}

- (void)openDatabase:(DatabaseMetadata*)database completion:(void (^)(NSError* error))completion {
    if(database.storageProvider == kLocalDevice) {
        NSError *error = nil;
        BOOL bookmarkDataIsStale;

        NSData* bookmarkData = [[NSData alloc] initWithBase64EncodedString:database.storageInfo options:kNilOptions];
        
        if(bookmarkData == nil) {
            completion([Utils createNSError:@"Could not decode bookmark." errorCode:-1]);
            return;
        }
        
        NSURL* bookmarkFileURL = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                           options:NSURLBookmarkResolutionWithSecurityScope
                                                     relativeToURL:nil
                                               bookmarkDataIsStale:&bookmarkDataIsStale
                                                             error:&error];
        if(!bookmarkFileURL) {
            completion([Utils createNSError:@"Could not get bookmark URL." errorCode:-1]);
            return;
        }
        
        if(bookmarkDataIsStale) {
            if ([bookmarkFileURL startAccessingSecurityScopedResource]) {
                NSLog(@"Regenerating Bookmark -> bookmarkDataIsStale = %d => [%@]", bookmarkDataIsStale, bookmarkFileURL);
                
                NSString* fileIdentifier = getBookmarkFromUrlAsString(bookmarkFileURL);

                [bookmarkFileURL stopAccessingSecurityScopedResource];
                
                if(!fileIdentifier) {
                    completion([Utils createNSError:@"Could not regenerate stale bookmark." errorCode:-1]);
                    return;
                }

                database.storageInfo = fileIdentifier;
                database.fileUrl = bookmarkFileURL;
                
                [DatabasesManager.sharedInstance update:database];
            }
            else {
                NSLog(@"Regen Bookmark security failed....");
                completion([Utils createNSError:@"Regen Bookmark security failed." errorCode:-1]);
                return;
            }
        }

        BOOL access = [bookmarkFileURL startAccessingSecurityScopedResource];
        
        if(access) {
            [self openDocumentWithContentsOfURL:bookmarkFileURL
                                       display:YES
                             completionHandler:^(NSDocument * _Nullable document,
                                                 BOOL documentWasAlreadyOpen,
                                                 NSError * _Nullable error) {
                if(error) {
                    NSLog(@"openDocumentWithContentsOfURL Error = [%@]", error);
                }
                
                completion(error);
            }];
        }
        else {
            completion([Utils createNSError:@"Could not access security scope URL" errorCode:-1]);
        }
    }
}

@end
