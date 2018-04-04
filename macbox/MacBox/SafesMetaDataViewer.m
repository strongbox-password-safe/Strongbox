//
//  SafesMetaDataViewer.m
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafesMetaDataViewer.h"
#import "SafesList.h"

@interface SafesMetaDataViewer ()

@property (nonatomic, strong) NSArray<SafeMetaData*>* safes;

@end

@implementation SafesMetaDataViewer

- (void)windowDidLoad {
    [super windowDidLoad];

//    SafeMetaData* safe = [[SafeMetaData alloc] initWithNickName:@"Blah" storageProvider:kLocalDevice fileName:@"filename" fileIdentifier:@"fileId"];
//    [SafesList.sharedInstance add:safe];
//    
    self.safes = SafesList.sharedInstance.snapshot;
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

- (IBAction)onOk:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onRemoveCurrent:(id)sender {
    if(self.tableView.selectedRow != -1) {
        SafeMetaData *safe = [self.safes objectAtIndex:self.tableView.selectedRow];
        [SafesList.sharedInstance remove:safe.uuid];
        
        [safe removeTouchIdPassword];
        
        self.safes = SafesList.sharedInstance.snapshot;
        [self.tableView reloadData];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.safes.count;
}

-(id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"MyView" owner:self];
    
    SafeMetaData* safe = [self.safes objectAtIndex:row];
    
    NSObject *obj = [safe valueForKey:tableColumn.identifier];
    result.textField.stringValue = obj == nil ? @"(nil)" : [obj description];
    
    return result;
}

@end
