//
//  FieldReferenceTests.m
//  StrongboxTests
//
//  Created by Mark on 05/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Node.h"
#import "SprCompilation.h"

@interface FieldReferenceTests : XCTestCase

@end

@implementation FieldReferenceTests

static NSString* const kSampleNodeTitle = @"Entry Title";
static NSString* const kSampleNodeUsername = @"Entry Username";
static NSString* const kSampleNodeUrl = @"https://user:pw@www.strongboxsafe.com:80/path/abc.php?q=e&s=t";
static NSString* const kSampleNodePassword = @"Entry Password";
static NSString* const kSampleNodeNotes = @"Entry Notes";
static NSString* const kSampleCustomFieldKey = @"Foo";
static NSString* const kSampleCustomFieldValue = @"Bar";

static NSString* const kSampleReferencedUuid = @"46C9B1FF-BD4A-BC4B-BB26-0C6190BAD20C";
static NSString* const kSampleReferencedNodePassword = @"ladder";
static NSString* const kSampleReferencedNodeTitle = @"Referenced Entry Title";
static NSString* const kSampleReferencedNodeUsername = @"Referenced Entry Username";
static NSString* const kSampleReferencedNodeUrl = @"https://user:pw@www.strongbox.com:80/path/abc.php?q=e&s=t";
static NSString* const kSampleReferencedNodeNotes = @"{URL:HOST}";
static NSString* const kSampleReferencedNodeCustomFieldKey = @"Key";
static NSString* const kSampleReferencedNodeCustomFieldValue = @"Value";

- (Node*)buildSampleEntryNode:(NSString*)url {
    Node* root = [[Node alloc] initAsRoot:nil];
    
    Node* entry = [[Node alloc] initAsRecord:kSampleNodeTitle parent:root];
    entry.fields.username = kSampleNodeUsername;
    entry.fields.url = url ? url : kSampleNodeUrl;
    entry.fields.password = kSampleNodePassword;
    entry.fields.notes = kSampleNodeNotes;
    entry.fields.customFields[kSampleCustomFieldKey] = [StringValue valueWithString:kSampleCustomFieldValue];
    
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:@"46C9B1FF-BD4A-BC4B-BB26-0C6190BAD20C"];
    Node* referencedEntry = [[Node alloc] initAsRecord:kSampleReferencedNodeTitle parent:root fields:[[NodeFields alloc] init] uuid:uuid];
    
    referencedEntry.fields.username = kSampleReferencedNodeUsername;
    referencedEntry.fields.password = kSampleReferencedNodePassword;
    referencedEntry.fields.url = kSampleReferencedNodeUrl;
    referencedEntry.fields.notes = kSampleReferencedNodeNotes;
    referencedEntry.fields.customFields[kSampleReferencedNodeCustomFieldKey] = [StringValue valueWithString:kSampleReferencedNodeCustomFieldValue];
    
    [root addChild:entry];
    [root addChild:referencedEntry];
    
    return root;
}

- (NSString*)compileAndAssertEqual:(NSString*)test shouldProduce:(NSString*)shouldProduce {
    return [self compileAndAssertEqual:test shouldProduce:shouldProduce url:nil];
}

- (NSString*)compileAndAssertEqual:(NSString*)test shouldProduce:(NSString*)shouldProduce url:(NSString*)url {
    Node* root = [self buildSampleEntryNode:url];
    Node* entry = root.childRecords[0];
    
    NSError* error;
    NSString* compiled = [SprCompilation.sharedInstance sprCompile:test node:entry rootNode:root error:&error];
    
    NSLog(@"compiled = [%@]", compiled);
    
    XCTAssertTrue([compiled isEqualToString:shouldProduce]);
    if(error) {
        NSLog(@"error = %@", error);
    }
    
    return compiled;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)testCompiledSampleWithMultipleReferences {
    NSString* test = @"This is an SPR Field: {REF:T@T:Referenced Entry titl} and so is this: {TITLE}";
    [self compileAndAssertEqual:test shouldProduce:@"This is an SPR Field: Referenced Entry Title and so is this: Entry Title"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)testCompiledSampleFieldReferenceTT {
    NSString* test = @"{REF:T@T:Referenced Entry titl}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

- (void)testCompiledSampleFieldReferenceTU {
    NSString* test = @"{REF:T@U:referenced entry username}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

- (void)testCompiledSampleFieldReferenceTP {
    NSString* test = @"{REF:T@P:adder}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

- (void)testCompiledSampleFieldReferenceTPNoMatch {
    NSString* test = @"{REF:T@P:222233dder}";
    [self compileAndAssertEqual:test shouldProduce:@"{REF:T@P:222233dder}"];
}

- (void)testCompiledSampleFieldReferenceTA {
    NSString* test = @"{REF:T@A:strongbox.com}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

- (void)testCompiledSampleFieldReferenceTN {
    NSString* test = @"{REF:T@N:{URL}"; // Weird find by SPR field test
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

- (void)testCompiledSampleFieldReferenceTO {
    NSString* test = @"{REF:T@O:Value}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

//////////////

- (void)testCompiledSampleFieldReferenceTI {
    NSString* test = @"{REF:T@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeTitle];
}

- (void)testCompiledSampleFieldReferenceUI {
    NSString* test = @"{REF:U@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeUsername];
}

- (void)testCompiledSampleFieldReferencePI {
    NSString* test = @"{REF:P@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodePassword];
}

- (void)testCompiledSampleFieldReferenceAI {
    NSString* test = @"{REF:A@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    [self compileAndAssertEqual:test shouldProduce:kSampleReferencedNodeUrl];
}

- (void)testCompiledSampleFieldReferenceNI {
    NSString* test = @"{REF:N@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    [self compileAndAssertEqual:test shouldProduce:@"www.strongboxsafe.com"]; // This one has a second levewl reference to URL:HOST!
}

- (void)testCompiledSampleFieldReferenceII {
    NSString* test = @"{REF:I@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    [self compileAndAssertEqual:test shouldProduce:@"46C9B1FFBD4ABC4BBB260C6190BAD20C"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)testCompiledSampleCompilablesCustomFieldsCaseInsensitive {
    NSString* test = @"{S:foo}";
    [self compileAndAssertEqual:test shouldProduce:kSampleCustomFieldValue];
}

- (void)testCompiledSampleCompilablesCustomFields {
    NSString* test = @"{S:Foo}";
    [self compileAndAssertEqual:test shouldProduce:kSampleCustomFieldValue];
}

- (void)testCompiledSampleCompilablesCustomFieldsNotPresent {
    NSString* test = @"{S:Foo2}";
    [self compileAndAssertEqual:test shouldProduce:@"{S:Foo2}"];
}

- (void)testCompiledSampleCompilablesCustomFieldsBlankKey {
    NSString* test = @"{S:}";
    [self compileAndAssertEqual:test shouldProduce:@"{S:}"];
}

- (void)testCompiledSampleCompilablesCustomFieldsNoKey {
    NSString* test = @"{S}";
    [self compileAndAssertEqual:test shouldProduce:@"{S}"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)testCompiledSampleCompilableUrlRmvScm {
    NSString* test = @"{URL:RMVSCM}";
    [self compileAndAssertEqual:test shouldProduce:@"user:pw@www.strongboxsafe.com:80/path/abc.php?q=e&s=t"];
}

- (void)testCompiledSampleCompilableUrlRmvScmNoScheme {
    NSString* test = @"{URL:RMVSCM}";
    [self compileAndAssertEqual:test shouldProduce:@"www.strongboxsafe.com" url:@"www.strongboxsafe.com"];
}

- (void)testCompiledSampleCompilableUrlRmvScmNotUrl {
    NSString* test = @"{URL:RMVSCM}";
    [self compileAndAssertEqual:test shouldProduce:@"foo" url:@"foo"];
}

- (void)testCompiledSampleCompilableUrlScm {
    NSString* test = @"{URL:SCM}";
    [self compileAndAssertEqual:test shouldProduce:@"https"];
}

- (void)testCompiledSampleCompilableUrlScmNoScheme {
    NSString* test = @"{URL:SCM}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"www.strongboxsafe.com"];
}

- (void)testCompiledSampleCompilableUrlScmNotUrl {
    NSString* test = @"{URL:SCM}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"foo"];
}

- (void)testCompiledSampleCompilableUrlHost {
    NSString* test = @"{URL:HOST}";
    [self compileAndAssertEqual:test shouldProduce:@"www.strongboxsafe.com"];
}

- (void)testCompiledSampleCompilableUrlHostNotProperUrl {
    NSString* test = @"{URL:HOST}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"host.com"];
}

- (void)testCompiledSampleCompilableUrlPort {
    NSString* test = @"{URL:PORT}";
    [self compileAndAssertEqual:test shouldProduce:@"80"];
}

- (void)testCompiledSampleCompilableUrlPortNoPort {
    NSString* test = @"{URL:PORT}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"https://host.com/path"];
}

- (void)testCompiledSampleCompilableUrlPortNoUrl {
    NSString* test = @"{URL:PORT}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"host"];
}

- (void)testCompiledSampleCompilableUrlPath {
    NSString* test = @"{URL:PATH}";
    [self compileAndAssertEqual:test shouldProduce:@"/path/abc.php"];
}

- (void)testCompiledSampleCompilableUrlQuery {
    NSString* test = @"{URL:QUERY}";
    [self compileAndAssertEqual:test shouldProduce:@"?q=e&s=t"];
}

- (void)testCompiledSampleCompilableUrlUserInfo {
    NSString* test = @"{URL:USERINFO}";
    [self compileAndAssertEqual:test shouldProduce:@"user:pw"];
}

- (void)testCompiledSampleCompilableUrlUserInfoNoUserInfo {
    NSString* test = @"{URL:USERINFO}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"https://www.host.com"];
}

- (void)testCompiledSampleCompilableUrlUserInfoNotAUrl {
    NSString* test = @"{URL:USERINFO}";
    [self compileAndAssertEqual:test shouldProduce:@"" url:@"foo"];
}

- (void)testCompiledSampleCompilableUrlUserInfoOnlyUserName {
    NSString* test = @"{URL:USERINFO}";
    [self compileAndAssertEqual:test shouldProduce:@"user" url:@"https://user@www.host.com"];
}

- (void)testCompiledSampleCompilableUrlUsername {
    NSString* test = @"{URL:USERNAME}";
    [self compileAndAssertEqual:test shouldProduce:@"user"];
}

- (void)testCompiledSampleCompilableUrlPassword {
    NSString* test = @"{URL:PASSWORD}";
    [self compileAndAssertEqual:test shouldProduce:@"pw"];
}

- (void)testCompiledSampleCompilableUrl {
    NSString* test = @"{URL}";
    [self compileAndAssertEqual:test shouldProduce:kSampleNodeUrl];
}

- (void)testCompiledSampleCompilablePassword {
    NSString* test = @"{PASSWORD}";
    [self compileAndAssertEqual:test shouldProduce:kSampleNodePassword];
}

- (void)testCompiledSampleCompilableNotes {
    NSString* test = @"{NOTES}";
    [self compileAndAssertEqual:test shouldProduce:kSampleNodeNotes];
}

- (void)testCompiledSampleCompilableUsername {
    NSString* test = @"{USERNAME}";
    [self compileAndAssertEqual:test shouldProduce:kSampleNodeUsername];
}

- (void)testCompiledSampleCompilableTitle {
    NSString* test = @"{TITLE}";
    [self compileAndAssertEqual:test shouldProduce:kSampleNodeTitle];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Regex Tests

- (void)testIsSprCompilableBrokenTokenNewLines {
    NSArray* validSamples = @[@"\n{T\nITLE}",
                              @"{TI\r\nTLE}"];
    
    for (NSString* test in validSamples) {
        XCTAssertFalse([SprCompilation.sharedInstance isSprCompilable:test]);
    }
}

- (void)testIsSprCompilableNewLines {
    NSArray* validSamples = @[@"This record has a {TITLE} like so\n but also a new line",
                              @"\n{TITLE}",
                              @"\r\n{TITLE}"];
    
    for (NSString* test in validSamples) {
        XCTAssertTrue([SprCompilation.sharedInstance isSprCompilable:test]);
    }
}
                              
- (void)testIsSprCompilableSampleCompilables {
    NSArray* validSamples = @[@"{TITLE}",
                              @"{USERNAME}",
                              @"{URL}",
                              @"{URL:RMVSCM}",
                              @"{URL:SCM}",
                              @"{URL:HOST}",
                              @"{URL:PORT}",
                              @"{URL:PATH}",
                              @"{URL:QUERY}",
                              @"{URL:USERINFO}",
                              @"{URL:USERNAME}",
                              @"{URL:PASSWORD}",
                              @"{PASSWORD}",
                              @"{NOTES}",
                              @"{S:FieldName}",
                              @"{REF:P@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:A@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:N@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:I@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@T:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@U:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@P:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@A:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@N:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@O:46C9B1FFBD4ABC4BBB260C6190BAD20C}"];

    for (NSString* test in validSamples) {
        XCTAssertTrue([SprCompilation.sharedInstance isSprCompilable:test]);
    }
}

- (void)testIsSprCompilableSampleNonCompilables {
    NSArray* validSamples = @[@"{TITLE",
                              @"{UERNAME}",
                              @"URL}",
                              @"{URL:MVSCM}",
                              @"{URL:SC}",
                              @"{URL:HOT}",
                              @"{URL:POR}",
                              @"{URL:ATH}",
                              @"{URL:QERY}",
                              @"{URL:USERNFO}",
                              @"{URLUSERNAME}",
                              @"URL:PASSWORD}",
                              @"{PSSWORD}",
                              @"NOTES",
                              @"{S:FieldName",
                              @"{RF:P@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:N@:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:Q@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@Q:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@U:46C9B1FFBD4ABC4BBB260C6190BAD20C",
                              @"REF:T@P:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:TA:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@N46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@1:46C9B1FFBD4ABC4BBB260C6190BAD20C}",
                              @"{REF:T@o:46C9B1FFBD4ABC4BBB260C6190BAD20C}"];
    
    for (NSString* test in validSamples) {
        BOOL result = [SprCompilation.sharedInstance isSprCompilable:test];
        
        if(result) {
            NSLog(@"[%@] passed when it shouldn't have", test);
        }
        
        XCTAssertFalse(result);
    }
}


- (void)testIsSprCompilableMultipleCompilable {
    NSString* test = @"{REF:T@I:46C9B1FFBD4ABC4BBB260C6190BAD20C} Blah Blah {REF:U@I:46C9B1FFBD4ABC4BBB260C6190BAD20C}";
    NSArray* matches = [SprCompilation.sharedInstance matches:test];
    
    //NSLog(@"Matches = [%@]", matches);
    
    for (NSTextCheckingResult* result in matches) {
        NSLog(@"Match: [%@]", [test substringWithRange:result.range]);
    }
    
    XCTAssertTrue(matches.count == 2);
}

- (void)testIsSprCompilablePerfOnNonCompilable {
    NSString* test = @"{TITLE2}";
    [SprCompilation.sharedInstance isSprCompilable:test];
    
    [self measureBlock:^{
        for(int i=0;i<10000;i++) {
            [SprCompilation.sharedInstance isSprCompilable:test];
        }
    }];
}

- (void)testIsSprCompilablePerfOnCompilable {
    NSString* test = @"{TITLE}";
    [SprCompilation.sharedInstance isSprCompilable:test];
    
    [self measureBlock:^{
        for(int i=0;i<10000;i++) {
            [SprCompilation.sharedInstance isSprCompilable:test];
        }
    }];
}


@end
