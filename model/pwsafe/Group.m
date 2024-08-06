//
//  Group.m
//  StrongBox
//
//  Created by Mark McGuill on 27/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Group.h"

@implementation Group

+ (NSRegularExpression *)regex
{
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _regex = [NSRegularExpression regularExpressionWithPattern:@"^\\.{0,1}(.+?)((?<!\\\\)\\.|$)" options:0 error:Nil];
    });
    
    return _regex;
}

- (instancetype)initAsRootGroup {
    return [self initWithPathComponents:[NSArray array]];
}

- (instancetype)initWithPathComponents:(NSArray<NSString*> *)pathComponents {
    if( self = [super init]) {
        _pathComponents = [[NSArray alloc] initWithArray:pathComponents];
    }
    
    return self;
}

- (instancetype)initWithEscapedPathString:(NSString *)escapedPathString {
    if( self = [super init]) {
        _pathComponents = [self splitEscapedPathStringIntoPathComponents:escapedPathString];
    }
    
    return self;
}

- (NSArray<NSString*> *)splitEscapedPathStringIntoPathComponents:(NSString*)escapedPathString {
    NSString *subGroupFullSuffix = escapedPathString;
    NSMutableArray *subgroups = [[NSMutableArray alloc] init];
    
    while (subGroupFullSuffix.length > 0 && ![subGroupFullSuffix isEqualToString:@"."]) {
        NSTextCheckingResult *match = [Group.regex firstMatchInString:subGroupFullSuffix options:0  range:NSMakeRange(0, subGroupFullSuffix.length) ];
        
        if (match && match.numberOfRanges > 0 && [match rangeAtIndex:1].location != NSNotFound) {
            NSRange range = [match rangeAtIndex:1];
            
            NSString *subgroup = [subGroupFullSuffix substringWithRange:range];
            
            
            
            if(![subgroup isEqualToString:@"."]) {
                
                NSString* unescaped = [Group unescapeGroupName:subgroup];
                [subgroups addObject:unescaped];
            }
            
            subGroupFullSuffix = [subGroupFullSuffix substringFromIndex:range.location + range.length];
        }
        else {
            slog(@"Do not know how to process this group name/path. Skipping.");
        }
    }
    
    return subgroups;
}

- (NSString *)title {
    return _pathComponents.count == 0 ? @"" : _pathComponents.lastObject;
}

- (BOOL)isRootGroup {
    return _pathComponents.count == 0;
}

- (Group *)getParentGroup {
    if (self.isRootGroup) {
        return nil;
    }

    NSArray<NSString*> *parentComponents = [_pathComponents subarrayWithRange:NSMakeRange(0, _pathComponents.count - 1)];

    return [[Group alloc] initWithPathComponents:parentComponents];
}

- (BOOL)isSubgroupOf:(Group *)parentGroup {
    if (!parentGroup) {
        return !self.isRootGroup;
    }

    NSArray *parentComponents = parentGroup.pathComponents;
   
    if (_pathComponents.count <= parentComponents.count) {
        return NO;
    }

    NSArray *mySubComponents = [_pathComponents subarrayWithRange:NSMakeRange(0, parentComponents.count)];
    return [parentComponents isEqualToArray:mySubComponents];
}

- (Group *)getDirectAncestorOfParent:(Group *)parentGroup {
    if ([self isSubgroupOf:parentGroup]) {
        NSInteger count = parentGroup ? parentGroup.pathComponents.count : 0;
        
        NSArray<NSString *> *directAncestorComponents = [_pathComponents subarrayWithRange:NSMakeRange(0, count + 1)];
        
        return [[Group alloc] initWithPathComponents:directAncestorComponents];
    }
    
    return nil;
}

- (Group *)createChildGroupWithTitle:(NSString *)title {
    if (!title) {
        return nil;
    }
    
    NSString *trimmed = [title stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceCharacterSet]];
    
    if (trimmed.length == 0) {
        return nil;
    }
    
    NSMutableArray<NSString*> *childGroup = [_pathComponents mutableCopy];
    [childGroup addObject:trimmed];
    
    return [[Group alloc] initWithPathComponents:childGroup];
}

- (NSString*)escapedPathString {
    NSString *ret = @"";
    
    BOOL first = YES;
    for(NSString *component in _pathComponents) {
        NSString *escaped = [Group escapeGroupName:component];
        
        if(!first) {
            ret = [ret stringByAppendingString:[NSString stringWithFormat:@".%@", escaped]];
        }
        else {
            ret = [ret stringByAppendingString:escaped];
            first = NO;
        }
    }
    
    return ret;
}

+ (NSString *)unescapeGroupName:(NSString *)title {
    NSString *tmp = [title stringByReplacingOccurrencesOfString:@"\\."
                                                     withString:@"."];
    
    tmp = [tmp stringByReplacingOccurrencesOfString:@"\\\\"
                                         withString:@"\\"];
    
    return tmp;
}

+ (NSString *)escapeGroupName:(NSString *)groupName {
    NSString *tmp;
    
    tmp = [groupName stringByReplacingOccurrencesOfString:@"\\"
                                               withString:@"\\\\"];
    
    tmp = [tmp stringByReplacingOccurrencesOfString:@"."
                                         withString:@"\\."];
    
    return tmp;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (!object) {
        return self.isRootGroup;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[Group class]]) {
        return NO;
    }
    
    return [((Group*)object).pathComponents isEqualToArray:_pathComponents];
}

- (NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;

    for (NSString *component in _pathComponents){
        result = prime * result + component.hash;
    }
    
    return result;
}

@end
