//
//  AutoFillCommon.m
//  MacBox
//
//  Created by Strongbox on 29/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AutoFillCommon.h"
#import "NSString+Extensions.h"

static NSString* const kMailToScheme = @"mailto";

@implementation AutoFillCommon

+ (NSSet<NSString*>*)getUniqueUrlsForNode:(DatabaseModel*)database
                                     node:(Node*)node
                          alternativeUrls:(BOOL)alternativeUrls
                             customFields:(BOOL)customFields
                                    notes:(BOOL)notes {
    NSMutableArray<NSString*> *collectedUrls = [NSMutableArray array];
    
    
    
    NSString* urlField = [database dereference:node.fields.url node:node];
    if(urlField.length) {
        [collectedUrls addObject:urlField];
    }
    
    
    
    if ( alternativeUrls ) {
        for ( NSString* altUrl in node.fields.alternativeUrls) {
            if(altUrl.length) {
                NSString* derefed = [database dereference:altUrl node:node];
                [collectedUrls addObject:derefed];
            }
        }
    }
        
    
    
    if ( customFields ) {
        for(NSString* key in node.fields.customFields.allKeys) {
            if ( ![NodeFields isAlternativeURLCustomFieldKey:key] ) { 
                StringValue* strValue = node.fields.customFields[key];
                NSArray<NSString*> *foo = [self findUrlsInString:strValue.value];
                [collectedUrls addObjectsFromArray:foo];
            }
        }
    }
    
    

    if ( notes) {
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
        NSLog(@"Error finding Urls: %@", error);
    }
    
    return urls;
}

@end
