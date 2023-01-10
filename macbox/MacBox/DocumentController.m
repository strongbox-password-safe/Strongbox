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

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

static NSString* const kStrongboxPasswordDatabaseDocumentType = @"Strongbox Password Database";
static NSString* const kStrongboxPasswordDatabaseManagedSyncDocumentType = @"Strongbox Password Database (Non File)";

@interface DocumentController ()

@property BOOL hasDoneAppStartupTasks;
@property (readonly) NSArray<MacDatabasePreferences*>* startupDatabases;

@end

@implementation DocumentController



- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel
                      forTypes:(nullable NSArray<NSString *> *)types {
    return [super runModalOpenPanel:openPanel forTypes:nil];
}

- (void)newDocument:(id)sender {
    

    [DBManagerPanel.sharedInstance show];
    
    CreateFormatAndSetCredentialsWizard* wizard = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
    
    NSString* loc = NSLocalizedString(@"mac_please_enter_master_credentials_for_this_database", @"Please Enter the Master Credentials for this Database");
    wizard.titleText = loc;
    wizard.initialDatabaseFormat = kKeePass4;
    wizard.createSafeWizardMode = YES;
    
    [DBManagerPanel.sharedInstance.window beginSheet:wizard.window
                                   completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK) {
            return;
        }
        
        NSError* error;
        
        CompositeKeyFactors* ckf = [wizard generateCkfFromSelectedFactors:DBManagerPanel.sharedInstance.contentViewController error:&error];
        
        if ( ckf ) {
            [self createNewDatabase:ckf format:wizard.selectedDatabaseFormat
                    keyFileBookmark:wizard.selectedKeyFileBookmark
                      yubiKeyConfig:wizard.selectedYubiKeyConfiguration];
        }
        else {
            [MacAlerts error:error window:DBManagerPanel.sharedInstance.window];
        }
    }];
}

- (void)createNewDatabase:(CompositeKeyFactors*)ckf
                   format:(DatabaseFormat)format
          keyFileBookmark:(NSString*)keyFileBookmark
            yubiKeyConfig:(YubiKeyConfiguration*)yubiKeyConfig {
    DatabaseModel* db = [[DatabaseModel alloc] initWithFormat:format compositeKeyFactors:ckf];
    
    [SampleItemsGenerator addSampleGroupAndRecordToRoot:db passwordConfig:Settings.sharedInstance.passwordGenerationConfig];
    
    [self serializeAndAddDatabase:db format:format keyFileBookmark:keyFileBookmark yubiKeyConfig:yubiKeyConfig];
}

- (void)serializeAndAddDatabase:(DatabaseModel*)db
                         format:(DatabaseFormat)format
                keyFileBookmark:(NSString*)keyFileBookmark
                  yubiKeyConfig:(YubiKeyConfiguration*)yubiKeyConfig {
    NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory];
    [outputStream open];
    
    [Serializator getAsData:db
                     format:db.originalFormat
               outputStream:outputStream completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
        [outputStream close];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( !userCancelled && !error ) {
                NSData* data = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
                
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
    
    NSURL* maybeManagedSyncUrl = managedUrlFromFileUrl(URL);
    
    MacDatabasePreferences* dbm = [MacDatabasePreferences addOrGet:maybeManagedSyncUrl];
    
    if ( !Settings.sharedInstance.doNotRememberKeyFile ) {
        dbm.keyFileBookmark = keyFileBookmark;
    }
    
    dbm.yubiKeyConfiguration = yubiKeyConfig;
    dbm.showAdvancedUnlockOptions = keyFileBookmark != nil || yubiKeyConfig != nil;
    
    BOOL rememberKeyFile = !Settings.sharedInstance.doNotRememberKeyFile;
    
    if ( rememberKeyFile ) {
        dbm.keyFileBookmark = keyFileBookmark;
    }
    
    dbm.yubiKeyConfiguration = yubiKeyConfig;
    dbm.showAdvancedUnlockOptions = keyFileBookmark != nil || yubiKeyConfig != nil;
    
    [self openDatabase:dbm completion:^(NSError * _Nonnull error) {
        if ( error ) {
            if (NSApplication.sharedApplication.keyWindow) {
                [MacAlerts error:error window:NSApplication.sharedApplication.keyWindow];
            }
        }
    }];
}

- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler {
    NSError* error;
    if ( ![Serializator isValidDatabase:url error:&error] ) {
        if (NSApplication.sharedApplication.keyWindow) {
            [MacAlerts info:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
            informativeText:NSLocalizedString(@"safesvc_import_manual_url_invalid", @"Invalid Database")
                     window:NSApplication.sharedApplication.keyWindow
                 completion:^{
                completionHandler(nil, NO, nil);
            }];
        }
    }
    else {
        [self openDocumentWithContentsOfURLContinuation:url display:displayDocument completionHandler:completionHandler];
    }
}

- (void)openDocumentWithContentsOfURLContinuation:(NSURL *)url
                                          display:(BOOL)displayDocument
                                completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler {
    MacDatabasePreferences* database = [MacDatabasePreferences fromUrl:url];
    
    NSLog(@"openDocumentWithContentsOfURL: [%@] => Metadata = [%@]", url, database);
    
    NSURL* maybeManaged = database ? url : managedUrlFromFileUrl(url);
    
    [super openDocumentWithContentsOfURL:maybeManaged
                                 display:displayDocument
                       completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        if ( document && !error ) {
            if ( !database ) {
                [MacDatabasePreferences addOrGet:maybeManaged]; 
            }
        }
        
        completionHandler(document, documentWasAlreadyOpen, error);
    }];
}

- (IBAction)originalOpenDocument:(id)sender {
    return [super openDocument:sender];
}

- (void)openDatabase:(MacDatabasePreferences*)database completion:(void (^)(NSError* error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self openDatabaseWorker:database completion:completion]; 
    });
}

- (void)openDatabaseWorker:(MacDatabasePreferences*)database completion:(void (^)(NSError* error))completion {
    NSURL* url = database.fileUrl;
    
    NSLog(@"Local Device Open Database: [%@] - sp=[%@]", url, [SafeStorageProviderFactory getStorageDisplayNameForProvider:database.storageProvider]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( url ) {
            [self openDocumentWithContentsOfURLContinuation:url
                                                    display:YES
                                          completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
                if(error) {
                    NSLog(@"openDocumentWithContentsOfURL Error = [%@]", error);
                }
                
                if ( completion ) {
                    completion(error);
                }
            }];
        }
        else {
            if ( completion ) {
                completion([Utils createNSError:@"Database Open - Could not read file URL" errorCode:-2413]);
            }
        }
    });
}

- (NSString *)typeForContentsOfURL:(NSURL *)url
                             error:(NSError *__autoreleasing  _Nullable *)outError {
    if ( ![url.scheme isEqualToString:kStrongboxFileUrlScheme]) {
        return kStrongboxPasswordDatabaseManagedSyncDocumentType;
    }
    
    return [super typeForContentsOfURL:url error:outError];
}

- (void)openDocument:(id)sender {
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    /*************************************************************************************************************/
    
    




























    
    /*************************************************************************************************************/
    
    
    
    
    
}

- (void)onAppStartup {
    NSLog(@"✅ DocumentController::onAppStartup: document count = [%ld]", self.documents.count);
    
    [self doAppStartupTasksOnceOnly];
}

- (void)doAppStartupTasksOnceOnly {
    if ( !self.hasDoneAppStartupTasks ) {
        [self doAppStartupTasksOnceOnly2];
    }
    else {
        NSLog(@"doAppStartupTasksOnceOnly - Tasks Already Done - NOP");
    }
}

- (void)doAppStartupTasksOnceOnly2 {
    self.hasDoneAppStartupTasks = YES;
    
    NSLog(@"doAppStartupTasksOnceOnly - Doing tasks as they have not yet been done");
    
    AppDelegate* appDelegate = NSApplication.sharedApplication.delegate;
    if ( appDelegate.isWasLaunchedAsLoginItem && Settings.sharedInstance.showSystemTrayIcon ) {
        NSLog(@"DocumentController::doAppStartupTasksOnceOnly2 -> Strongbox was launched as a Login Item && running as menu bar app - Silent Mode not launching databases or any UI...");
    }
    else {
        if( self.startupDatabases.count ) {
            [self launchStartupDatabases];
        }
        else if ( self.documents.count == 0 ) {
            if ( Settings.sharedInstance.showDatabasesManagerOnAppLaunch ) {
                NSLog(@"DocumentController::doAppStartupTasksOnceOnly2 -> Empty Startup - Showing Databases Manager because so configured");
                
                [DBManagerPanel.sharedInstance show];
            }
            else {
                NSLog(@"DocumentController::doAppStartupTasksOnceOnly2 -> Empty Startup - Not Showing DB Manager because so configured...");
            }
        }
    }
}

- (void)launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable {
    NSLog(@"✅ DocumentController::launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable...");

    if( self.documents.count == 0 ) { 
        NSLog(@"launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable: document count = [%ld]", self.documents.count);
        
        if( self.startupDatabases.count ) {
            [self launchStartupDatabases];
        }
        else {
            NSLog(@"launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable - No Startup DBs - Showing Manager...");
            
            [DBManagerPanel.sharedInstance show];
        }
    }
}

- (NSArray<MacDatabasePreferences*>*)startupDatabases {
    NSArray<MacDatabasePreferences*> *startupDatabases = [MacDatabasePreferences filteredDatabases:^BOOL(MacDatabasePreferences * _Nonnull database) {
        return database.launchAtStartup;
    }];
    
    return startupDatabases;
}

- (void)launchStartupDatabases {
    NSArray<MacDatabasePreferences*>* startupDatabases = self.startupDatabases;
    
    NSLog(@"Found %ld startup databases. Launching...", startupDatabases.count);
    
    for ( MacDatabasePreferences* db in startupDatabases ) {
        [self openDatabase:db completion:^(NSError *error) { }];
    }
}



+ (void)restoreWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler {
    
    
    if ([state containsValueForKey:@"StrongboxNonFileRestorationStateURL"] ) {
        NSURL *nonFileRestorationStateURL = [state decodeObjectForKey:@"StrongboxNonFileRestorationStateURL"];
        
        if ( nonFileRestorationStateURL ) {
            
            
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

- (Document*)documentForDatabase:(NSString*)uuid {
    NSArray<Document*> *docs = self.documents;
    
    return [docs firstOrDefault:^BOOL(Document * _Nonnull obj) {
        MacDatabasePreferences* metadata = obj.databaseMetadata;
        return (metadata != nil) && [metadata.uuid isEqualToString:uuid];
    }];
}

- (BOOL)allowsAutomaticShareMenu { 
    return NO;
}

- (BOOL)respondsToSelector:(SEL)aSelector{
    
    
    if ( @available(macOS 10.12, *) ){
        if ( aSelector == @selector(newWindowForTab:) ) {
            return NO;
        }
    }
    
    return [super respondsToSelector:aSelector];
}

@end
