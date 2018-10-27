//
//  XmlStrongBoxModelAdaptor.m
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlStrongBoxModelAdaptor.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "Utils.h"
#import "KeePassConstants.h"

@implementation XmlStrongBoxModelAdaptor

- (KeepassMetaDataAndNodeModel*)fromXmlModelToStrongboxModel:(RootXmlDomainObject*)existingRootXmlDocument
                                                       error:(NSError**)error {
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    
    KeePassGroup * rootXmlGroup = getExistingRootKeePassGroup(existingRootXmlDocument);
    
    Node* rootNode = [adaptor toModel:rootXmlGroup error:error];
    
    if(!rootNode) {
        NSLog(@"Could not build node model from xml root document.");
        
        if (error != nil) {
            *error = [Utils createNSError:@"Could not parse this safe." errorCode:-1];
        }
        
        return nil;
    }
    
    // Metadata
    
    KeePassDatabaseMetadata* metadata = [[KeePassDatabaseMetadata alloc] init];
    
    if(existingRootXmlDocument.keePassFile.meta.generator.text) {
        metadata.generator = existingRootXmlDocument.keePassFile.meta.generator.text;
    }
    
    return [[KeepassMetaDataAndNodeModel alloc] initWithMetadata:metadata nodeModel:rootNode];
}

- (RootXmlDomainObject*)toXmlModelFromStrongboxModel:(KeepassMetaDataAndNodeModel*)metadataAndNodeModel
                             existingRootXmlDocument:(RootXmlDomainObject*)existingRootXmlDocument
                                               error:(NSError**)error {
    // 1. Convert from Strongbox Node Model back to Keepass Xml model respecting any existing tags/attributes etc
    
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* rootXmlGroup = [adaptor fromModel:metadataAndNodeModel.rootNode error:error];
    
    if(!rootXmlGroup) {
        NSLog(@"Could not serialize groups/entries.");
        return nil;
    }

    RootXmlDomainObject *ret = existingRootXmlDocument;
    
    if(!ret) {
        ret = [[RootXmlDomainObject alloc] initWithDefaultsAndInstantiatedChildren];
    }
    
    // 2. Metadata
    
    ret.keePassFile.root.rootGroup = rootXmlGroup;
    ret.keePassFile.meta.generator.text = metadataAndNodeModel.metadata.generator;
    
    return ret;
}

static KeePassGroup *getExistingRootKeePassGroup(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    // Possible that one of these intermediates are nil... safety
    
    KeePassFile *keepassFileElement = existingRootXmlDocument == nil ? nil : existingRootXmlDocument.keePassFile;
    Root* rootXml = keepassFileElement == nil ? nil : keepassFileElement.root;
    KeePassGroup *rootXmlGroup = rootXml == nil ? nil : rootXml.rootGroup;
    
    return rootXmlGroup;
}


@end
