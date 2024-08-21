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
#import "CreateDatabaseOrSetCredentialsWizard.h"
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

static BOOL didRestoreAWindowAtStartup;

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
    [DBManagerPanel.sharedInstance showAndBeginAddDatabaseSequenceWithCreateMode:YES newModel:nil];
}

- (IBAction)originalOpenDocument:(id)sender {
    [DBManagerPanel.sharedInstance showAndBeginAddDatabaseSequenceWithCreateMode:NO newModel:nil];
}

- (void)originalOpenDocumentWithFileSelection {
    return [super openDocument:nil];
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


- (void)openDatabase:(MacDatabasePreferences*)database completion:(void (^)(Document* document, NSError* error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self openDatabaseWorker:database completion:completion]; 
    });
}

- (void)openDatabaseWorker:(MacDatabasePreferences*)database completion:(void (^)(Document*_Nullable document, NSError*_Nullable error))completion {
    NSURL* url = database.fileUrl;
    
    slog(@"Local Device Open Database: [%@] - sp=[%@]", url, [SafeStorageProviderFactory getStorageDisplayNameForProvider:database.storageProvider]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( url ) {
            [self openDocumentWithContentsOfURLContinuation:url
                                                    display:YES
                                          completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
                if(error) {
                    slog(@"openDocumentWithContentsOfURL Error = [%@]", error);
                }
                
                if ( completion ) {
                    completion((Document*)document, error);
                }
            }];
        }
        else {
            if ( completion ) {
                completion(nil, [Utils createNSError:@"Database Open - Could not read file URL" errorCode:-2413]);
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
    slog(@"🔴 openDocument");
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    /*************************************************************************************************************/
    
    




























    
    /*************************************************************************************************************/
    
    
    
    
    
}

- (void)onAppStartup {

    
    [self doAppStartupTasksOnceOnly];
}

- (void)doAppStartupTasksOnceOnly {
    if ( !self.hasDoneAppStartupTasks ) {
        [self doAppStartupTasksOnceOnly2];
    }
    else {
        slog(@"doAppStartupTasksOnceOnly - Tasks Already Done - NOP");
    }
}

- (void)doAppStartupTasksOnceOnly2 {
    self.hasDoneAppStartupTasks = YES;
    

    
    AppDelegate* appDelegate = NSApplication.sharedApplication.delegate;
    if ( appDelegate.isWasLaunchedAsLoginItem && Settings.sharedInstance.showSystemTrayIcon ) {
        slog(@"DocumentController::doAppStartupTasksOnceOnly2 -> Strongbox was launched as a Login Item && running as menu bar app - Silent Mode not launching databases or any UI...");
    }
    else {
        if( self.startupDatabases.count ) {
            [self launchStartupDatabases];
        }
        else {
            if ( didRestoreAWindowAtStartup ) { 
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self checkForEmptyLaunch];
                });
            }
            else {
                [self checkForEmptyLaunch];
            }
        }
    }
}

- (void)checkForEmptyLaunch {
    if ( self.documents.count == 0 ) {
        if ( Settings.sharedInstance.showDatabasesManagerOnAppLaunch ) {

            
            [DBManagerPanel.sharedInstance show];
        }
        else {

        }
    }
    else {

    }
}

- (void)launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable {
    slog(@"✅ DocumentController::launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable...");

    if( self.documents.count == 0 ) { 
        slog(@"launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable: document count = [%ld]", self.documents.count);
        
        if( self.startupDatabases.count ) {
            [self launchStartupDatabases];
        }
        else {
            slog(@"launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable - No Startup DBs - Showing Manager...");
            
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
    
    slog(@"Found %ld startup databases. Launching...", startupDatabases.count);
    
    for ( MacDatabasePreferences* db in startupDatabases ) {
        [self openDatabase:db completion:^(Document * _Nullable document, NSError * _Nullable error) { }];
    }
}



+ (void)restoreWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler {

    
    if ([state containsValueForKey:kDocumentRestorationNSCoderKeyForUrl] ) {
        NSString *nonFileRestorationStateURL = [state decodeObjectOfClass:NSString.class forKey:kDocumentRestorationNSCoderKeyForUrl];
        
        if ( nonFileRestorationStateURL ) {

            
            NSURL* url = [NSURL URLWithString:nonFileRestorationStateURL];
            if (!url ) {
                slog(@"🔴 restoreWindowWithIdentifier... could not cast string to URL: [%@]", nonFileRestorationStateURL);
                return;
            }
            
            didRestoreAWindowAtStartup = YES;
            
            [[self sharedDocumentController] reopenDocumentForURL:url
                                                withContentsOfURL:url
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
    
    
    if ( aSelector == @selector(newWindowForTab:) ) {
        return NO;
    }
    
    return [super respondsToSelector:aSelector];
}

@end
