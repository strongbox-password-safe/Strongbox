//
//  AutoFillCommon.m
//  MacBox
//
//  Created by Strongbox on 29/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AutoFillCommon.h"
#import "NSString+Extensions.h"

static NSString* const kOtpAuthScheme = @"otpauth";
static NSString* const kMailToScheme = @"mailto";

@implementation AutoFillCommon

+ (NSSet<NSString*>*)getUniqueUrlsForNode:(DatabaseModel*)database
                                     node:(Node*)node
                          alternativeUrls:(BOOL)alternativeUrls
                             customFields:(BOOL)customFields
                                    notes:(BOOL)notes {
    NSMutableSet<NSString*> *uniqueUrls = [NSMutableSet set];
    NSMutableArray<NSString*> *explicitUrls = [NSMutableArray array];
    
    
    
    NSString* urlField = [database dereference:node.fields.url node:node];
    if(urlField.length) {
        [explicitUrls addObject:urlField];
    }
    
    
    
    if ( alternativeUrls ) {
        for ( NSString* altUrl in node.fields.alternativeUrls) {
            if(altUrl.length) {
                NSString* derefed = [database dereference:altUrl node:node];
                [explicitUrls addObject:derefed];
            }
        }
    }
    
    

    for ( NSString* expUrl in explicitUrls ) {
        NSURL* parsed = expUrl.urlExtendedParse;

        if ( parsed ) {
            NSURLComponents* components = [NSURLComponents componentsWithURL:parsed resolvingAgainstBaseURL:NO];
            
            if ( !components.scheme.length ) { 
                NSString* urlString = [NSString stringWithFormat:@"https:
                [uniqueUrls addObject:urlString];
            }
            else {
                [uniqueUrls addObject:expUrl];
            }
        }
        else {
            [uniqueUrls addObject:expUrl];
        }
    }
    
    
    
    if ( customFields ) {
        for(NSString* key in node.fields.customFields.allKeys) {
            if ( ![NodeFields isAlternativeURLCustomFieldKey:key] ) { 
                StringValue* strValue = node.fields.customFields[key];
                NSArray<NSString*> *foo = [self findUrlsInString:strValue.value];
                [uniqueUrls addObjectsFromArray:foo];
            }
        }
    }
    
    

    if ( notes) {
        NSString* notesField = [database dereference:node.fields.notes node:node];

        if(notesField.length) {
            NSArray<NSString*> *foo = [AutoFillCommon findUrlsInString:notesField];
            [uniqueUrls addObjectsFromArray:foo];
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
