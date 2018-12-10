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

static NSString* const kStrongboxPasswordDatabaseDocumentType = @"Strongbox Password Database";

@implementation DocumentController

// Allow open any file type/extension...

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(nullable NSArray<NSString *> *)types {
    return [super runModalOpenPanel:openPanel forTypes:nil];
}

- (void)newDocument:(id)sender {
    CreateFormatAndSetCredentialsWizard* wizard = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
    
    wizard.titleText = @"Please Enter the Master Credentials for this Safe";
    wizard.databaseFormat = kKeePass;
    wizard.createSafeWizardMode = YES;
    
    NSModalResponse returnCode = [NSApp runModalForWindow:wizard.window];

    if(returnCode != NSModalResponseOK) {
        return;
    }
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"Save New Password Database...";
    panel.prompt = @"Save";
    panel.message = @"You must save this new database before you can use it";
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [DatabaseModel getAdaptor:wizard.databaseFormat];
    panel.nameFieldStringValue = [NSString stringWithFormat:@"Untitled.%@", adaptor.fileExtension ];
    
    NSInteger modalCode = [panel runModal];

    if (modalCode == NSModalResponseOK) {
        NSURL *URL = [panel URL];

        Document *document = [[Document alloc] initWithCredentials:wizard.databaseFormat password:wizard.confirmedPassword keyFileDigest:wizard.confirmedKeyFileDigest];

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

@end
