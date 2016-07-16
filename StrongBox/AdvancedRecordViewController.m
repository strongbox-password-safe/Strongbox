//
//  AdvancedRecordViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 18/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AdvancedRecordViewController.h"
#import "core-model/Field.h"

@interface AdvancedRecordViewController ()

@end

@implementation AdvancedRecordViewController
{
    NSMutableDictionary* displayFields;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self refreshView];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
}

- (void)refreshView
{
    if(displayFields == nil)
    {
        displayFields = [[NSMutableDictionary alloc] init];
    }
    else
    {
        [displayFields removeAllObjects];
    }
    
    for(Field *field in [self.record getAllFields])
    {
        NSString *key = field.prettyTypeString;

        [displayFields setObject:field forKey:key];
    }
    
    [self.tableView reloadData];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [displayFields count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FieldCell" forIndexPath:indexPath];
    
    id key = [[displayFields allKeys] objectAtIndex:[indexPath row]];
    
    Field *field = [displayFields objectForKey:key];
    
    cell.textLabel.text = field.prettyTypeString;
    cell.detailTextLabel.text = field.prettyDataString;
    
    // Configure the cell...
    
    return cell;
}

@end
