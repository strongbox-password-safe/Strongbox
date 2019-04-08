//
//  SprCompilation.m
//  Strongbox
//
//  Created by Mark on 05/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SprCompilation.h"
#import "Utils.h"
#import "NSDictionary+Extensions.h"
#import "NSArray+Extensions.h"

static NSString* const kTitleOperation = @"TITLE";
static NSString* const kUsernameOperation = @"USERNAME";
static NSString* const kPasswordOperation = @"PASSWORD";
static NSString* const kNotesOperation = @"NOTES";
static NSString* const kUrlOperation = @"URL";
static NSString* const kCustomFieldOperation = @"S:";
static NSString* const kReferenceOperation = @"REF:";

static NSString* const kReferenceFieldTitle = @"T";
static NSString* const kReferenceFieldUsername = @"U";
static NSString* const kReferenceFieldPassword = @"P";
static NSString* const kReferenceFieldUrl = @"A";
static NSString* const kReferenceFieldNotes = @"N";
static NSString* const kReferenceFieldId = @"I";
static NSString* const kReferenceFieldCustomFields = @"O";

static NSString* const kUrlSubOperationRemoveScheme = @"RMVSCM";
static NSString* const kUrlSubOperationScheme = @"SCM";
static NSString* const kUrlSubOperationHost = @"HOST";
static NSString* const kUrlSubOperationPort = @"PORT";
static NSString* const kUrlSubOperationPath = @"PATH";
static NSString* const kUrlSubOperationQuery = @"QUERY";
static NSString* const kUrlSubOperationUserInfo = @"USERINFO";
static NSString* const kUrlSubOperationUserName = @"USERNAME";
static NSString* const kUrlSubOperationPassword = @"PASSWORD";

static NSString* const kSprCompilerRegex = @"\\{(TITLE|USERNAME|URL(:(RMVSCM|HOST|SCM|PORT|PATH|QUERY|USERNAME|USERINFO|PASSWORD))*|PASSWORD|NOTES|S:(.*?)|REF:((T|U|P|A|N|I)@(T|U|P|A|N|I|O):(.*?))){1}\\}";

@implementation SprCompilation

+ (instancetype)sharedInstance {
    static SprCompilation *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SprCompilation alloc] init];
    });
    
    return sharedInstance;
}

+ (NSRegularExpression *)regex
{
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSError* error;
    
        _regex = [NSRegularExpression regularExpressionWithPattern:kSprCompilerRegex
                                                           options:kNilOptions
                                                             error:&error];
        if(error) {
            NSLog(@"Error compiling Regex: %@", error);
        }
    });
    
    return _regex;
}

- (NSString *)sprCompile:(NSString *)test node:(Node *)node rootNode:(Node *)rootNode error:(NSError **)error {
    return [self sprCompile:test node:node rootNode:rootNode error:error depth:0];
}

- (NSString *)sprCompile:(NSString *)test node:(Node *)node rootNode:(Node *)rootNode error:(NSError **)error depth:(NSUInteger)depth {
    if(!test.length) {
        return @"";
    }
    
    NSString* ret = test;
    NSTextCheckingResult* match = [[SprCompilation regex] firstMatchInString:test options:kNilOptions range:NSMakeRange(0, test.length)];

    if(match) {
        NSError* matchError;
        NSString* compiled = [self sprCompileRegexMatch:match test:test node:node rootNode:rootNode error:&matchError];

        if(!compiled) {
            NSLog(@"Failed to compile Error: [%@]", matchError);
            if(error) {
                *error = matchError;
            }
        }

        ret = [test stringByReplacingCharactersInRange:match.range withString:compiled];
        
        if(depth < 10) { // Prevent endless self references killing us
            ret = [self sprCompile:ret node:node rootNode:rootNode error:error depth:depth+1];
        }
        else {
            NSLog(@"Depth/Recurse Limit Exceeded in SPR Compile... Will not attempt Further.");
        }
    }
    
    return ret;
}

- (NSString*)sprCompileRegexMatch:(NSTextCheckingResult*)match test:(NSString*)test node:(Node*)node rootNode:(Node *)rootNode error:(NSError**)error {
//    // Debug
//    for(int i = 0;i < match.numberOfRanges;i++) {
//        NSRange range = [match rangeAtIndex:i];
//        if(range.location != NSNotFound) {
//            NSLog(@"Range %d: (%lu,%lu) [%@]", i, (unsigned long)range.location, (unsigned long)range.length, [test substringWithRange:range]);
//        }
//        else {
//            NSLog(@"Range %d: <Not Found>", i);
//        }
//    }

    if(match.numberOfRanges != 9) {
        *error = [Utils createNSError:@"Incorrect number of ranges found. Cannot Compile" errorCode:-1];
        return nil;
    }

    NSString* operation = ([match rangeAtIndex:1].location == NSNotFound) ? nil : [test substringWithRange:[match rangeAtIndex:1]];
    if(!operation) {
        *error = [Utils createNSError:@"Operation not found. Cannot Compile" errorCode:-1];
        return nil;
    }
    
    if([operation isEqualToString:kTitleOperation]) {
        return node.title;
    }
    else if([operation isEqualToString:kUsernameOperation]) {
        return node.fields.username;
    }
    else if([operation isEqualToString:kPasswordOperation]) {
        return node.fields.password;
    }
    else if([operation isEqualToString:kNotesOperation]) {
        return node.fields.notes;
    }
    else if([operation hasPrefix:kCustomFieldOperation]) {
        NSString* key = ([match rangeAtIndex:4].location == NSNotFound) ? nil : [test substringWithRange:[match rangeAtIndex:4]];
        
        if(key) {
            StringValue* string = [node.fields.customFields objectForCaseInsensitiveKey:key]; // KeePass is case insensitive on keys here!
            return string ? string.value : test; // KeePass Windows client returns the original string, not blank/empty
        }
        else {
            return test;
        }
    }
    else if([operation hasPrefix:kUrlOperation]) {
        return [self sprCompileUrl:match test:test node:node rootNode:rootNode error:error]; // error:error];
    }
    else if([operation hasPrefix:kReferenceOperation]) {
        return [self sprCompileReference:match test:test node:node rootNode:rootNode error:error];
    }
    else {
        *error = [Utils createNSError:@"Unknown Operation. Cannot Compile" errorCode:-1];
        return nil;
    }
    
    return nil;
}

-(NSString*)sprCompileReference:(NSTextCheckingResult*)match test:(NSString*)test node:(Node*)node rootNode:(Node *)rootNode error:(NSError**)error {
    NSString* desiredField = ([match rangeAtIndex:6].location == NSNotFound) ? nil : [test substringWithRange:[match rangeAtIndex:6]];
    NSString* searchByField = ([match rangeAtIndex:7].location == NSNotFound) ? nil : [test substringWithRange:[match rangeAtIndex:7]];
    NSString* searchTarget = ([match rangeAtIndex:8].location == NSNotFound) ? nil : [test substringWithRange:[match rangeAtIndex:8]];

    if(!desiredField || !searchByField || !searchTarget) {
        *error = [Utils createNSError:@"Field reference missing one of required parameters" errorCode:-2];
        return nil;
    }
    
    NSLog(@"desiredField = [%@], searchByField = [%@], searchTarget = [%@]", desiredField, searchByField, searchTarget);
    
    Node* target = [self findReferencedNode:searchByField searchTarget:searchTarget rootNode:rootNode error:error];
    
    if(!target) {
        return test; // No Match? Return As Is
    }
    
    if([desiredField isEqualToString:kReferenceFieldTitle]) {
        return target.title;
    }
    else if([desiredField isEqualToString:kReferenceFieldUsername]) {
        return target.fields.username;
    }
    else if([desiredField isEqualToString:kReferenceFieldPassword]) {
        return target.fields.password;
    }
    else if([desiredField isEqualToString:kReferenceFieldUrl]) {
        return target.fields.url;
    }
    else if([desiredField isEqualToString:kReferenceFieldNotes]) {
        return target.fields.notes;
    }
    else if([desiredField isEqualToString:kReferenceFieldId]) {
        return [self keePassStringIdFromUuid:target.uuid];
    }
    else {
        *error = [Utils createNSError:@"Field reference desired field unknown" errorCode:-4];
        return nil;
    }
}

- (Node*)findReferencedNode:(NSString*)searchByField searchTarget:(NSString*)searchTarget rootNode:(Node*)rootNode error:(NSError**)error {
    Node* target = nil;
    
    if([searchByField isEqualToString:kReferenceFieldId]) {
        NSUUID* uuidTarget = [self uuidFromKeePassStringId:searchTarget];
        
        if(!uuidTarget) {
            *error = [Utils createNSError:@"Field reference ID not correct format or length" errorCode:-2];
            return nil;
        }
        
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && [node.uuid isEqual:uuidTarget];
        }];
    }
    else if([searchByField isEqualToString:kReferenceFieldTitle]) {
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && [node.title localizedCaseInsensitiveContainsString:searchTarget];
        }];
    }
    else if([searchByField isEqualToString:kReferenceFieldUsername]) {
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && [node.fields.username localizedCaseInsensitiveContainsString:searchTarget];
        }];
    }
    else if([searchByField isEqualToString:kReferenceFieldPassword]) {
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && [node.fields.password localizedCaseInsensitiveContainsString:searchTarget];
        }];
    }
    else if([searchByField isEqualToString:kReferenceFieldUrl]) {
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && [node.fields.url localizedCaseInsensitiveContainsString:searchTarget];
        }];
    }
    else if([searchByField isEqualToString:kReferenceFieldNotes]) {
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && [node.fields.notes localizedCaseInsensitiveContainsString:searchTarget];
        }];
    }
    else if([searchByField isEqualToString:kReferenceFieldCustomFields]) {
        target = [rootNode findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            if(node.isGroup) {
                return NO;
            }
            else {
                StringValue* strValue = [node.fields.customFields.allValues firstOrDefault:^BOOL(StringValue * _Nonnull obj) {
                    return [obj.value localizedCaseInsensitiveContainsString:searchTarget];
                }];
                
                return strValue != nil;
            }
        }];
    }
    
    return target;
}

-(NSString*)sprCompileUrl:(NSTextCheckingResult*)match test:(NSString*)test node:(Node*)node rootNode:(Node*)rootNode error:(NSError**)error {
    NSString* subOperation = ([match rangeAtIndex:3].location == NSNotFound) ? nil : [test substringWithRange:[match rangeAtIndex:3]];
    //NSLog(@"%@", components);
    
    if(!subOperation) {
        return node.fields.url;
    }

    // This is a bit of a hack :( but using parts of a url doesn't fit in super well here. We need to fully dereference
    // This field before attempting to break it up... but we need to be careful to limit it too.
    
    NSString* dereferencedUrl = [self sprCompile:node.fields.url node:node rootNode:rootNode error:error];
    NSURLComponents* components = [NSURLComponents componentsWithString:dereferencedUrl];
    
    if([subOperation isEqualToString:kUrlSubOperationScheme]) {
        return (components && components.scheme) ? components.scheme : @"";
    }
    else if([subOperation isEqualToString:kUrlSubOperationHost]) {
        return (components && components.host) ? components.host : @"";
    }
    else if([subOperation isEqualToString:kUrlSubOperationPath]) {
        return (components && components.path) ? components.path : @"";
    }
    else if([subOperation isEqualToString:kUrlSubOperationUserName]) {
        return (components && components.user) ? components.user : @"";
    }
    else if([subOperation isEqualToString:kUrlSubOperationPassword]) {
        return (components && components.password) ? components.password : @"";
    }
    else if([subOperation isEqualToString:kUrlSubOperationPort]) {
        if(components && components.rangeOfPort.location != NSNotFound) {
            return [dereferencedUrl substringWithRange:components.rangeOfPort];
        }
        else {
            return @"";
        }
    }
    else if([subOperation isEqualToString:kUrlSubOperationRemoveScheme]) {
        if(components && components.rangeOfScheme.location != NSNotFound) {
            NSString* foo = [dereferencedUrl stringByReplacingCharactersInRange:components.rangeOfScheme withString:@""];
            if([foo hasPrefix:@"://"]) {
                return [foo stringByReplacingCharactersInRange:NSMakeRange(0, 3) withString:@""];
            }
            return foo;
        }
        else {
            return dereferencedUrl;
        }
    }
    else if([subOperation isEqualToString:kUrlSubOperationQuery]) {
        if(components && components.rangeOfQuery.location != NSNotFound) {
            return [NSString stringWithFormat:@"?%@", [dereferencedUrl substringWithRange:components.rangeOfQuery]];
        }
        else {
            return @"";
        }
    }
    else if([subOperation isEqualToString:kUrlSubOperationUserInfo]) {
        if(components && (components.rangeOfUser.location != NSNotFound || components.rangeOfPassword.location != NSNotFound)) {
            if(components.password) {
                return [NSString stringWithFormat:@"%@:%@", components.user ? components.user : @"", components.password ? components.password : @""];
            }
            else {
                return components.user;
            }
        }
        else {
            return @"";
        }
    }
    else {
        *error = [Utils createNSError:@"Unknown URL Sub Operation. Cannot Compile" errorCode:-1];
        return nil;
    }
}

- (BOOL)isSprCompilable:(NSString*)test {
    return test.length ? ([[SprCompilation regex] firstMatchInString:test options:kNilOptions range:NSMakeRange(0, test.length)] != nil) : NO;
}

- (NSArray*)matches:(NSString*)test {
    if(!test.length) {
        return @[];
    }
    
    return [[SprCompilation regex] matchesInString:test options:kNilOptions range:NSMakeRange(0, test.length)];
}

- (NSString*)keePassStringIdFromUuid:(NSUUID*)uuid {
    // 46C9B1FF-BD4A-BC4B-BB26-0C6190BAD20C => 46C9B1FFBD4ABC4BBB260C6190BAD20C
    
    uuid_t uid;
    [uuid getUUIDBytes:(uint8_t*)&uid];
    
    return [Utils hexadecimalString:[NSData dataWithBytes:uid length:sizeof(uuid_t)]];
}

- (NSUUID*)uuidFromKeePassStringId:(NSString*)searchTarget {
    if(searchTarget.length != 32) {
        return nil;
    }
    
    // 46C9B1FFBD4ABC4BBB260C6190BAD20C => 46C9B1FF-BD4A-BC4B-BB26-0C6190BAD20C;
    
    NSData* uuidData = [Utils dataFromHexString:searchTarget];
    return [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
}

@end
