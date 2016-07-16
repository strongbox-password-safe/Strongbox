//
//  Group.m
//  StrongBox
//
//  Created by Mark McGuill on 27/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Group.h"

@implementation Group
{
    NSString *_fullPath;
}

-(id)init
{
    _fullPath = @"";
    
    return self;
}

-(id)init:(NSString*)fullPath
{
    _fullPath = fullPath ? fullPath : @"";
    
    return self;
}

-(NSString*) fullPath
{
    return _fullPath;
}

-(NSString*) fullPathDisplayString
{
    return [Group unescapeGroupName:_fullPath];
}

-(NSString*) pathPrefixDisplayString
{
    NSArray *pathComponents = [self splitGroup];
    
    if([pathComponents count] > 0)
    {
        NSArray *prefixRawComponents = [pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count] - 1)];
        
        NSMutableString *path = [[NSMutableString alloc] initWithString:@""];
        
        for(int i=0;i<[prefixRawComponents count];i++)
        {
            [path appendFormat:@"%@%@", [Group unescapeGroupName:prefixRawComponents[i]], (i == ([prefixRawComponents count] -1)) ? @"" : @"/"];
        }
        
        return path;
    }
    
    return @"";
}

-(NSString*) suffixDisplayString
{
    NSString * suffix = [[self splitGroup] lastObject];
    
    return [Group unescapeGroupName:suffix];
}

-(BOOL) isRootGroup
{
    return _fullPath == nil || [_fullPath length] == 0;
}

-(NSArray*)splitGroup
{
    NSString* subGroupFullSuffix = _fullPath;
    NSMutableArray * subgroups = [[NSMutableArray alloc] init];
    
    while([subGroupFullSuffix length] > 0 && ![subGroupFullSuffix isEqualToString:@"."])
    {
        // Regex here manages finding the immediate subgroup taking into account escape patterns and only selecting legitimate groups
        
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\.{0,1}(.+?)((?<!\\\\)\\.|$)" options:0 error:Nil];
        NSTextCheckingResult *match = [regex firstMatchInString:subGroupFullSuffix options:0  range:NSMakeRange(0, [subGroupFullSuffix length]) ];
        
        if(match && [match numberOfRanges] > 0 && [match rangeAtIndex:1].location != NSNotFound)
        {
            NSRange range = [match rangeAtIndex:1];
            
            NSString *subgroup = [subGroupFullSuffix substringWithRange:range];
            
            [subgroups addObject:subgroup];
            
            subGroupFullSuffix = [subGroupFullSuffix substringFromIndex:range.location + range.length];
        }
        else
        {
            NSLog(@"Eeeek?");
            break;
        }
    }
    
    return subgroups;
}

-(Group*)getParentGroup
{
    if([self isRootGroup]){
        return nil;
    }
    
    NSArray *myComponents = [self splitGroup];
    
    myComponents = [myComponents subarrayWithRange:NSMakeRange(0, myComponents.count - 1)];
    
    NSString* fp = [[NSString alloc] init];
    for (NSString *comp in myComponents) {
        fp = [NSString stringWithFormat:@"%@.%@", fp, comp];
    }
    
    return [[Group alloc] init:fp];
}

-(BOOL)isSubgroupOf:(Group*)parentGroup
{
    if(!parentGroup)
    {
        return !self.isRootGroup;
    }
    
    NSArray *parentComponents = [parentGroup splitGroup];
    NSArray *myComponents = [self splitGroup];
 
    if([myComponents count] <= [parentComponents count])
    {
        return NO;
    }
    
    NSArray *mySubComponents = [myComponents subarrayWithRange:NSMakeRange(0, [parentComponents count])];
    return [parentComponents isEqualToArray:mySubComponents];
}

-(BOOL)isDirectChildOf:(Group*)testGroup
{
    NSArray *testComponents = [testGroup splitGroup];
    NSArray *myComponents = [self splitGroup];
 
    if([myComponents count] > 0)
    {
        myComponents = [myComponents subarrayWithRange:NSMakeRange(0, myComponents.count - 1)];
    }
    
    return [testComponents isEqualToArray:myComponents];
}

-(BOOL)isSameGroupAs:(Group*)existing
{
    if(!existing)
    {
        return [self isRootGroup];
    }
    
    NSArray *existingComponents = [existing splitGroup];
    NSArray *myComponents = [self splitGroup];
    
    if([myComponents count] != [existingComponents count])
    {
        return NO;
    }
    
    return [existingComponents isEqualToArray:myComponents];
}

-(Group*)getImmediateChildGroupWithParentGroup:(Group*)parentGroup
{
    NSArray *parentComponents = parentGroup ? [parentGroup splitGroup] : [[NSArray alloc] init];
    NSArray *myComponents = [self splitGroup];
    
    if([myComponents count] <= [parentComponents count])
    {
        return nil;
    }
    
    NSArray *mySubComponents = [myComponents subarrayWithRange:NSMakeRange(0, [parentComponents count])];
    if([parentComponents isEqualToArray:mySubComponents])
    {
        NSString *immediateChild = [myComponents objectAtIndex:[parentComponents count]];
        NSString *fmt = [parentComponents count] > 0 ? [NSString stringWithFormat:@"%@.%@", parentGroup.fullPath, immediateChild] : immediateChild;
        
        // Definitely a subgroup
        
        return [[Group alloc] init:fmt];
    }
    
    return nil;
}

-(Group*)createChildGroupWithUITitle:(NSString*)title
{
    if(!title)
    {
        return nil;
    }
    
    NSString *trimmed = [title stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceCharacterSet]];
    
    if([trimmed length] == 0)
    {
        return nil;
    }
    
    NSString* escaped = [Group escapeGroupName:trimmed];
    
    NSString* fp = [self isRootGroup] ? escaped : [NSString stringWithFormat:@"%@.%@", _fullPath, escaped];
    
    return [[Group alloc] init:fp];
}

+ (NSString*)unescapeGroupName:(NSString *)title
{
    NSString *tmp = [title stringByReplacingOccurrencesOfString:@"\\."
                                                     withString:@"."];
    
    tmp = [tmp stringByReplacingOccurrencesOfString:@"\\\\"
                                         withString:@"\\"];
    
    return tmp;
}

+ (NSString*)escapeGroupName:(NSString *)groupName
{
    NSString *tmp;
    
    tmp = [groupName stringByReplacingOccurrencesOfString:@"\\"
                                               withString:@"\\\\"];
    
    tmp = [tmp stringByReplacingOccurrencesOfString:@"."
                                         withString:@"\\."];
    
    return tmp;
}

@end
