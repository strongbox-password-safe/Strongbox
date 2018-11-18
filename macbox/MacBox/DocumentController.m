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

@implementation DocumentController

// Allow open any file type/extension...

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(nullable NSArray<NSString *> *)types {
    return [super runModalOpenPanel:openPanel forTypes:nil];
}

- (IBAction)onNewKeePass1Document:(id)sender {
    NSString* type = @"Strongbox File (KeePass 1)";
    
    [self newDocumentOfType:type];
}

- (IBAction)onNewKeePass2ClassicDocument:(id)sender {
    NSString* type = @"Strongbox File (KeePass 2 Classic)";
    
    [self newDocumentOfType:type];
}

- (IBAction)onNewKeePass2AdvancedDocument:(id)sender {
    NSString* type = @"Strongbox File (KeePass Advanced)";
    
    [self newDocumentOfType:type];
}

- (void)newDocumentOfType:(NSString*)type {
    NSError* error;

    Document* document = [self makeUntitledDocumentOfType:type error:&error];
    
    if(!document) {
        NSLog(@"Could not create document: %@", error);
        return;
    }
    
    [self addDocument:document];
    [document makeWindowControllers];
    [document showWindows];
}

@end
