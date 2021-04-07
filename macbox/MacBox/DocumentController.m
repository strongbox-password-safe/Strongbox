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
#import "DatabasesManagerVC.h"
#import "DatabasesManager.h"
#import "MacAlerts.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import "BookmarksHelper.h"
#import "Serializator.h"
#import "MacUrlSchemes.h"
#import "SafeStorageProviderFactory.h"
#import "MacSyncManager.h"
#import "SampleItemsGenerator.h"
#import "Serializator.h"


static NSString* const kStrongboxPasswordDatabaseDocumentType = @"Strongbox Password Database";
static NSString* const kStrongboxPasswordDatabaseManagedSyncDocumentType = @"Strongbox Password Database (Non File)";

@interface DocumentController ()

@property BOOL hasDoneAppStartupTasks;
@property (readonly) NSArray<DatabaseMetadata*>* startupDatabases;

@end

@implementation DocumentController



- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel
                      forTypes:(nullable NSArray<NSString *> *)types {
    return [super runModalOpenPanel:openPanel forTypes:nil];
}

- (void)newDocument:(id)sender {
    CreateFormatAndSetCredentialsWizard* wizard = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
    
    NSString* loc = NSLocalizedString(@"mac_please_enter_master_credentials_for_this_database", @"Please Enter the Master Credentials for this Database");
    wizard.titleText = loc;
    wizard.initialDatabaseFormat = kKeePass4;
    wizard.createSafeWizardMode = YES;
    
    NSModalResponse returnCode = [NSApp runModalForWindow:wizard.window];

    if(returnCode != NSModalResponseOK) {
        return;
    }

    CompositeKeyFactors* ckf = [wizard generateCkfFromSelected:nil];

    [self createNewDatabase:ckf format:wizard.selectedDatabaseFormat keyFileBookmark:wizard.selectedKeyFileBookmark yubiKeyConfig:wizard.selectedYubiKeyConfiguration];
}

- (void)createNewDatabase:(CompositeKeyFactors*)ckf format:(DatabaseFormat)format keyFileBookmark:(NSString*)keyFileBookmark yubiKeyConfig:(YubiKeyConfiguration*)yubiKeyConfig {
    DatabaseModel* db = [[DatabaseModel alloc] initWithFormat:format compositeKeyFactors:ckf];
    [SampleItemsGenerator addSampleGroupAndRecordToRoot:db passwordConfig:Settings.sharedInstance.passwordGenerationConfig];
        
    [Serializator getAsData:db
                     format:db.originalFormat
                 completion:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( data && !userCancelled && !error ) {
                [self saveNewFileBasedDatabase:format database:db data:data keyFileBookmark:keyFileBookmark yubiKeyConfig:yubiKeyConfig];
            }
            else if (! userCancelled ) {
                NSLog(@"Error Saving New Database: [%@]", error);

                if (NSApplication.sharedApplication.keyWindow) {
                    [MacAlerts error:error window:NSApplication.sharedApplication.keyWindow];
                }
            }
        });
    }];
}

- (void)saveNewFileBasedDatabase:(DatabaseFormat)format
                        database:(DatabaseModel*)database
                            data:(NSData*)data
                 keyFileBookmark:(NSString*)keyFileBookmark
                   yubiKeyConfig:(YubiKeyConfiguration*)yubiKeyConfig {
    NSSavePanel *panel = [NSSavePanel savePanel];
    NSString* loc2 = NSLocalizedString(@"mac_save_new_database",  @"Save New Password Database...");
    panel.title = loc2;
    NSString* loc3 = NSLocalizedString(@"mac_save_action",  @"Save");
    panel.prompt = loc3;
    NSString* loc4 = NSLocalizedString(@"mac_save_new_db_message",  @"You must save this new database before you can use it");
    panel.message = loc4;
    NSString* ext = [Serializator getDefaultFileExtensionForFormat:format];
    NSString* loc5 = NSLocalizedString(@"mac_untitled_database_filename_fmt", @"Untitled.%@");
    panel.nameFieldStringValue = [NSString stringWithFormat:loc5, ext ];
    
    NSInteger modalCode = [panel runModal];

    if (modalCode != NSModalResponseOK) {
        return;
    }
    
    NSURL *URL = [panel URL];

    NSError* error;
    BOOL success = [data writeToURL:URL options:kNilOptions error:&error];
    if ( !success ) {
        NSLog(@"Error Saving New Database: [%@]", error);

        if (NSApplication.sharedApplication.keyWindow) {
            [MacAlerts error:error window:NSApplication.sharedApplication.keyWindow];
        }
        
        return;
    }
    
    NSURL* maybeManagedSyncUrl = [self maybeManagedSyncURL:URL];
    
    DatabaseMetadata* metadata = [DatabasesManager.sharedInstance addOrGet:maybeManagedSyncUrl];
    metadata.keyFileBookmark = keyFileBookmark;
    metadata.yubiKeyConfiguration = yubiKeyConfig;
    [DatabasesManager.sharedInstance update:metadata];

    [self openDatabase:metadata completion:^(NSError * _Nonnull error) {
        if ( error ) {
            if (NSApplication.sharedApplication.keyWindow) {
                [MacAlerts error:error window:NSApplication.sharedApplication.keyWindow];
            }
        }
    }];
}

- (NSURL*)maybeManagedSyncURL:(NSURL*)url {
    if ( !Settings.sharedInstance.useLegacyFileProvider ) {
        NSLog(@"Managing Sync for File Based Database: [%@]", url);
        return managedUrlFromFileUrl(url);
    }

     return url;
}

- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler {

    DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseByFileUrl:url];
    NSURL* maybeManaged = database ? url : [self maybeManagedSyncURL:url];

    [super openDocumentWithContentsOfURL:maybeManaged
                                 display:displayDocument
                       completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        if ( document && !error ) {
            if ( !database ) {
                [DatabasesManager.sharedInstance addOrGet:maybeManaged]; 
            }
        }
        
        completionHandler(document, documentWasAlreadyOpen, error);
    }];
}

- (void)originalOpenDocument:(id)sender {
    return [super openDocument:sender];
}

- (void)openDatabase:(DatabaseMetadata*)database completion:(void (^)(NSError* error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self openDatabaseWorker:database completion:completion]; 
    });
}

- (void)openDatabaseWorker:(DatabaseMetadata*)database completion:(void (^)(NSError* error))completion {
    NSURL* url = database.fileUrl;

    if ( [url.scheme isEqualToString:kStrongboxFileUrlScheme] ) { 
        if (database.storageInfo != nil) {
            NSError *error = nil;
            NSString* updatedBookmark;
            url = [BookmarksHelper getUrlFromBookmark:database.storageInfo
                                             readOnly:NO
                                      updatedBookmark:&updatedBookmark
                                                error:&error];
            
            if(url == nil) {
                NSLog(@"WARN: Could not resolve bookmark for database... will try the saved fileUrl...");
                url = database.fileUrl;
            }
            else {
                
                
                if (updatedBookmark) {
                    database.storageInfo = updatedBookmark;
                }
                
                database.fileUrl = url;
                [DatabasesManager.sharedInstance update:database];
            }
        }
        else {
            NSLog(@"WARN: Storage info/Bookmark unavailable! Falling back solely on fileURL");
        }
        
        [url startAccessingSecurityScopedResource];
    }
    else {
        NSLog(@"None Local Device Open Database: [%@] - sp=[%@]", url, [SafeStorageProviderFactory getStorageDisplayNameForProvider:database.storageProvider]);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
    if ( url ) {
        [self openDocumentWithContentsOfURL:url
                                    display:YES
                          completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
            if(error) {
                NSLog(@"openDocumentWithContentsOfURL Error = [%@]", error);
            }
            
            completion(error);
        }];
    }
    else {
        completion([Utils createNSError:@"Database Open - Could not read file URL" errorCode:-2413]);
    }});
}

- (NSString *)typeForContentsOfURL:(NSURL *)url
                             error:(NSError *__autoreleasing  _Nullable *)outError {
    if ( ![url.scheme isEqualToString:kStrongboxFileUrlScheme]) {
        return kStrongboxPasswordDatabaseManagedSyncDocumentType;
    }

    return [super typeForContentsOfURL:url error:outError];
}

- (void)openDocument:(id)sender {
    
    
    
    
    
    
    
    
    
    
    
    
    NSLog(@"openDocument: document count = [%ld]", self.documents.count);
    
    if ( self.hasDoneAppStartupTasks ) {
        NSWindow* keyWindow = NSApplication.sharedApplication.keyWindow;
        
        NSLog(@"openDocument - regular call - Once off startup tasks are done. - Key Window = [%@]", keyWindow);
        
        
        
         
        if( 
            
            NSApplication.sharedApplication.keyWindow == nil ) {
            NSLog(@"No open docs and no key window => Do empty launch tasks");
            [self performEmptyLaunchTasksIfNecessary];
        }
        else {
            [self originalOpenDocument:sender];
        }
    }
    else {
        NSLog(@"openDocument - startup call - Doing once off startup tasks are done.");

        [self doAppStartupTasksOnceOnly];
    }
}

- (void)onAppStartup {
    NSLog(@"applicationDidFinishLaunching => onAppStartup: document count = [%ld]", self.documents.count);

    [self doAppStartupTasksOnceOnly];
}

- (void)doAppStartupTasksOnceOnly {
    if ( !self.hasDoneAppStartupTasks ) {
        self.hasDoneAppStartupTasks = YES;
        
        NSLog(@"doAppStartupTasksOnceOnly - Doing tasks as they have not yet been done");

        if( self.startupDatabases.count ) {
            [self launchStartupDatabases];
        }
        else if(self.documents.count == 0) { 
            [DatabasesManagerVC show];
        }
        
        [MacSyncManager.sharedInstance backgroundSyncOutstandingUpdates];
    }
    else {
        NSLog(@"doAppStartupTasksOnceOnly - Tasks Already Done - NOP");
    }
}

- (void)performEmptyLaunchTasksIfNecessary {
    NSLog(@"performEmptyLaunchTasks...");
    
    if( self.documents.count == 0 ) { 
        NSLog(@"performEmptyLaunchTasks: document count = [%ld]", self.documents.count);
        
        if( self.startupDatabases.count ) {
            [self launchStartupDatabases];
        }
        else {
            [DatabasesManagerVC show];
        }
    }
}

- (NSArray<DatabaseMetadata*>*)startupDatabases {
    NSArray<DatabaseMetadata*> *startupDatabases = [DatabasesManager.sharedInstance.snapshot filter:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return obj.launchAtStartup;
    }];

    return startupDatabases;
}

- (void)launchStartupDatabases {
    NSArray<DatabaseMetadata*>* startupDatabases = self.startupDatabases;
    
    NSLog(@"Found %ld startup databases. Launching...", startupDatabases.count);
    
    for ( DatabaseMetadata* db in startupDatabases ) {
        [self openDatabase:db completion:^(NSError *error) { }];
    }
}



+ (void)restoreWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler {
    NSLog(@"restoreWindowWithIdentifier...");
    
    if ([state containsValueForKey:@"StrongboxNonFileRestorationStateURL"] ) {
        NSURL *nonFileRestorationStateURL = [state decodeObjectForKey:@"StrongboxNonFileRestorationStateURL"];
        
        if ( nonFileRestorationStateURL ) {
            NSLog(@"restoreWindowWithIdentifier... custom URL");

            [[self sharedDocumentController] reopenDocumentForURL:nonFileRestorationStateURL
                                                withContentsOfURL:nonFileRestorationStateURL
                                                          display:NO
                                                completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
                NSWindow *resultWindow = nil;
                 
                if (!documentWasAlreadyOpen) {
                    if ( !document.windowControllers.count ) {
                         [document makeWindowControllers];
                    }
                    
                    if ( 1 == document.windowControllers.count ) {
                        resultWindow = document.windowControllers.firstObject.window;
                    }
                    else {
                        for (NSWindowController *wc in document.windowControllers) {
                            if ( [wc.window.identifier isEqual:identifier] ) {
                                resultWindow = wc.window;
                                break;
                            }
                        }
                    }
                }
                
                completionHandler(resultWindow, error);
            }];
        }
        
        return;
    }

    [super restoreWindowWithIdentifier:identifier state:state completionHandler:completionHandler];
}

- (Document*)documentForDatabase:(DatabaseMetadata*)database {
    NSArray<Document*> *docs = self.documents;

    return [docs firstOrDefault:^BOOL(Document * _Nonnull obj) {
        DatabaseMetadata* metadata = obj.databaseMetadata;
        return (metadata != nil) && [metadata.uuid isEqualToString:database.uuid];
    }];
}

- (BOOL)databaseIsDocumentWindow:(DatabaseMetadata *)database {
    return [self documentForDatabase:database] != nil;
}

- (BOOL)databaseIsUnlockedInDocumentWindow:(DatabaseMetadata *)database {
    Document* doc = [self documentForDatabase:database];
    
    if ( doc && doc.viewModel ) {
        return !doc.viewModel.locked;
    }
    
    return NO;
}

- (void)closeDocumentWindowForDatabase:(DatabaseMetadata *)database {
    Document* doc = [self documentForDatabase:database];
    
    if ( doc ) {
        [doc close];
    }
}

@end
