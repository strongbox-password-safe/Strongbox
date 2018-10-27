//
//  Entry.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextStringElementHandler.h"
#import "GenericTextUuidElementHandler.h"
#import "Times.h"
#import "String.h"

// <Entry>
//    <UUID>Xz38+tBIR4+k30EGYO3lbg==</UUID>
//    <IconID>0</IconID>
//    <ForegroundColor />
//    <BackgroundColor />
//    <OverrideURL />
//    <Tags />
//    <Times />
//    <String>
//        <Key>Title</Key>
//        <Value>Entry 1</Value>
//    </String>
//    <String>
//        <Key>UserName</Key>
//        <Value />
//    </String>
//    <String>
//        <Key>Password</Key>
//        <Value Protected="True">h1oBlPCq</Value>
//    </String>
//    <String>
//        <Key>URL</Key>
//        <Value />
//    </String>
//    <String>
//        <Key>Notes</Key>
//        <Value />
//    </String>
//    <AutoType>
//        <Enabled>True</Enabled>
//        <DataTransferObfuscation>0</DataTransferObfuscation>
//    </AutoType>
//    <History />
// </Entry>


NS_ASSUME_NONNULL_BEGIN

@interface Entry : BaseXmlDomainObjectHandler

@property (nonatomic) GenericTextUuidElementHandler* uuid;
@property (nonatomic) Times* times;
@property (nonatomic) NSMutableArray<String*> *strings;

// TODO:
//    <IconID>0</IconID>
//    <History />

// Customized Getters/Setters for well-known fields - basically views on the strings collection

@property (nonatomic) NSString* title;
@property (nonatomic) NSString* username;
@property (nonatomic) NSString* password;
@property (nonatomic) NSString* url;
@property (nonatomic) NSString* notes;

// TODO: Add Custom Field or Remove? How about edit?
@property (nonatomic, readonly) NSDictionary<NSString*, NSString*> *customFields;


@end

NS_ASSUME_NONNULL_END
