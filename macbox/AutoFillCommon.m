//
//  AutoFillCommon.m
//  MacBox
//
//  Created by Strongbox on 29/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AutoFillCommon.h"
#import "NSString+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

static NSString* const kMailToScheme = @"mailto";

@implementation AutoFillCommon

+ (NSSet<NSString*>*)getUniqueUrlsForNode:(Model*)model
                                     node:(Node*)node {
    NSMutableArray<NSString*> *collectedUrls = [NSMutableArray array];
    
    DatabaseModel* database = model.database;
    
    
    
    NSString* urlField = [database dereference:node.fields.url node:node];
    if(urlField.length) {
        [collectedUrls addObject:urlField];
    }
    
    

    for ( NSString* altUrl in node.fields.alternativeUrls) {
        if(altUrl.length) {
            NSString* derefed = [database dereference:altUrl node:node];
            [collectedUrls addObject:derefed];
        }
    }
        
    
    
    if ( model.metadata.autoFillScanCustomFields ) {
        for(NSString* key in node.fields.customFields.allKeys) {
            if ( ![NodeFields isAlternativeURLCustomFieldKey:key] ) { 
                StringValue* strValue = node.fields.customFields[key];
                NSArray<NSString*> *foo = [self findUrlsInString:strValue.value];
                [collectedUrls addObjectsFromArray:foo];
            }
        }
    }
    
    

    if ( model.metadata.autoFillScanNotes ) {
        NSString* notesField = [database dereference:node.fields.notes node:node];

        if(notesField.length) {
            NSArray<NSString*> *foo = [AutoFillCommon findUrlsInString:notesField];
            [collectedUrls addObjectsFromArray:foo];
        }
    }
    
    
    
    
    NSMutableSet<NSString*> *uniqueUrls = [NSMutableSet set];
    for ( NSString* expUrl in collectedUrls ) {
        NSURL* parsed = expUrl.urlExtendedParseAddingDefaultScheme;
        if ( parsed && parsed.absoluteString ) {
            [uniqueUrls addObject:parsed.absoluteString];
        }
    }
         
    
    
    if ( model.metadata.includeAssociatedDomains ) {
        NSMutableArray<NSString*>* additional = NSMutableArray.array;
        
        for ( NSString* url in uniqueUrls ) {
            NSSet<NSString*>* equivs = [BrowserAutoFillManager getAssociatedDomainsWithUrl:url];
            
            if ( equivs.anyObject ) {

                [additional addObjectsFromArray:equivs.allObjects];
            }
        }
        
        if ( additional.count ) {

            
            for ( NSString* expUrl in additional ) {
                NSURL* parsed = expUrl.urlExtendedParseAddingDefaultScheme;
                if ( parsed && parsed.absoluteString ) {
                    [uniqueUrls addObject:parsed.absoluteString];
                }
            }
        }
    }
        
    return uniqueUrls;
}

+ (NSArray<NSString*>*)findUrlsInString:(NSString*)target {
    if(!target.length) {
        return @[];
    }
    
    NSError *error;
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    
    NSMutableArray<NSString*>* urls = [NSMutableArray array];
    
    if(detector) {
        NSArray *matches = [detector matchesInString:target
                                             options:0
                                               range:NSMakeRange(0, [target length])];
        for (NSTextCheckingResult *match in matches) {
            if ([match resultType] == NSTextCheckingTypeLink) {
                NSURL *url = [match URL];
                if(url && url.scheme && ![url.scheme isEqualToString:kOtpAuthScheme] && ![url.scheme isEqualToString:kMailToScheme]) {
                    [urls addObject:url.absoluteString];
                }
            }
        }
    }
    else {
        slog(@"Error finding Urls: %@", error);
    }
    
    return urls;
}

@end
