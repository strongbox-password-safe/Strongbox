//
//  StaticTableViewController.m
//  StaticTableViewController 2.0
//
//  Created by Peter Paulis on 31.1.2013.
//  Copyright (c) 2013 Peter Paulis. All rights reserved.
//

#import "StaticDataTableViewController.h"

#define kBatchOperationNone     0
#define kBatchOperationInsert   1
#define kBatchOperationDelete   2
#define kBatchOperationUpdate   3

////////////////////////////////////////////////////////////////////////
#pragma mark - OriginalRow
////////////////////////////////////////////////////////////////////////

@interface OriginalRow : NSObject

@property (nonatomic, assign) BOOL hidden;

@property (nonatomic, assign) BOOL hiddenReal;

@property (nonatomic, assign) BOOL hiddenPlanned;

@property (nonatomic, assign) int batchOperation;

@property (nonatomic, weak) UITableViewCell * cell;

@property (nonatomic, strong) NSIndexPath * originalIndexPath;

@property (nonatomic, assign) CGFloat height;

- (void)update;

@end

@implementation OriginalRow

- (id)init {
    self = [super init];
    
    if (self) {
        self.height = CGFLOAT_MAX;
    }
    
    return self;
}

- (BOOL)hidden {
    return (self.hiddenPlanned);
}

- (void)setHidden:(BOOL)hidden {
    
    if ((!self.hiddenReal) && (hidden)) {
        self.batchOperation = kBatchOperationDelete;
    } else if ((self.hiddenReal) && (!hidden)) {
        self.batchOperation = kBatchOperationInsert;
    }
    
    self.hiddenPlanned = hidden;
}

- (void)update {
    
    if (!self.hidden) {
        if (self.batchOperation == kBatchOperationNone) {
            self.batchOperation = kBatchOperationUpdate;
        }
    }
}

@end

////////////////////////////////////////////////////////////////////////
#pragma mark - OriginalSection
////////////////////////////////////////////////////////////////////////

@interface OriginalSection : NSObject

@property (nonatomic, strong) NSString * label;

@property (nonatomic, strong) NSMutableArray * rows;

@end

@implementation OriginalSection

- (NSInteger)numberOfVissibleRows {
    NSInteger count = 0;
    for (OriginalRow * or in self.rows) {
        if (!or.hidden) {
            ++count;
        }
    }
    
    return count;
}

- (NSInteger)vissibleRowIndexWithTableViewCell:(UITableViewCell *)cell {
    
    NSInteger i = 0;
    for (OriginalRow * or in self.rows) {
        
        if (or.cell == cell) {
            return i;
        }
        
        if (!or.hidden) {
            ++i;
        }
    }
    
    return -1;
}

@end

////////////////////////////////////////////////////////////////////////
#pragma mark - OriginalTable
////////////////////////////////////////////////////////////////////////

@interface OriginalTable : NSObject

@property (nonatomic, strong) NSMutableArray * sections;

@property (nonatomic, weak) UITableView * tableView;

@property (nonatomic, strong) NSMutableArray * insertIndexPaths;

@property (nonatomic, strong) NSMutableArray * deleteIndexPaths;

@property (nonatomic, strong) NSMutableArray * updateIndexPaths;

@property (nonatomic, strong) NSMutableArray * reloadSectionsIndexes;

@end

@implementation OriginalTable

- (id)initWithTableView:(UITableView *)tableView {
    
    self = [super init];
    if (self) {
        
        NSInteger numberOfSections = [tableView numberOfSections];
        self.sections = [[NSMutableArray alloc] initWithCapacity:numberOfSections];
        
        NSInteger totalNumberOfRows = 0;
        for (NSInteger i = 0; i < numberOfSections; ++i) {
            OriginalSection * originalSection = [OriginalSection new];
            
            NSInteger numberOfRows = [tableView numberOfRowsInSection:i];
            totalNumberOfRows += numberOfRows;
            originalSection.rows = [[NSMutableArray alloc] initWithCapacity:numberOfRows];
            for (NSInteger ii = 0; ii < numberOfRows; ++ii) {
                OriginalRow * tableViewRow = [OriginalRow new];
                
                NSIndexPath * ip = [NSIndexPath indexPathForRow:ii inSection:i];
                tableViewRow.cell = [tableView.dataSource tableView:tableView cellForRowAtIndexPath:ip];
                
                NSAssert(tableViewRow.cell != nil, @"cannot be nil");
                
                tableViewRow.originalIndexPath = [NSIndexPath indexPathForRow:ii inSection:i];
                
                originalSection.rows[ii] = tableViewRow;
            }
            
            self.sections[i] = originalSection;
        }
     
        self.insertIndexPaths = [[NSMutableArray alloc] initWithCapacity:totalNumberOfRows];
        self.deleteIndexPaths = [[NSMutableArray alloc] initWithCapacity:totalNumberOfRows];
        self.updateIndexPaths = [[NSMutableArray alloc] initWithCapacity:totalNumberOfRows];
        self.reloadSectionsIndexes = [[NSMutableArray alloc] initWithCapacity:numberOfSections];
        
        self.tableView = tableView;
        
    }
    
    return self;
}

- (OriginalRow *)originalRowWithIndexPath:(NSIndexPath *)indexPath {
    
    OriginalSection * oSection = self.sections[indexPath.section];
    OriginalRow * oRow = oSection.rows[indexPath.row];
    
    return oRow;
}

- (OriginalRow *)vissibleOriginalRowWithIndexPath:(NSIndexPath *)indexPath {
    
    OriginalSection * oSection = self.sections[indexPath.section];
    NSInteger vissibleIndex = -1;
    for (int i = 0; i < [oSection.rows count]; ++i) {
        
        OriginalRow * oRow = [oSection.rows objectAtIndex:i];
        
        if (!oRow.hidden) {
            ++vissibleIndex;
        }
        
        if (indexPath.row == vissibleIndex) {
            return oRow;
        }
        
    }
    
    return nil;
}

- (OriginalRow *)originalRowWithTableViewCell:(UITableViewCell *)cell {
    
    for (NSInteger i = 0; i < [self.sections count]; ++i) {
    
        OriginalSection * os = self.sections[i];
    
        for (NSInteger ii = 0; ii < [os.rows count]; ++ii) {
            
            if ([os.rows[ii] cell] == cell) {
                return os.rows[ii];
            }
            
        }
        
    }
    
    return nil;
}

- (NSIndexPath *)indexPathForInsertingOriginalRow:(OriginalRow *)originalRow {
    
    OriginalSection * oSection = self.sections[originalRow.originalIndexPath.section];
    NSInteger vissibleIndex = -1;
    for (NSInteger i = 0; i < originalRow.originalIndexPath.row; ++i) {
        
        OriginalRow * oRow = [oSection.rows objectAtIndex:i];
        
        if (!oRow.hidden) {
            ++vissibleIndex;
        }
        
    }
    
    return [NSIndexPath indexPathForRow:vissibleIndex + 1 inSection:originalRow.originalIndexPath.section];
    
}

- (NSIndexPath *)indexPathForDeletingOriginalRow:(OriginalRow *)originalRow {
    
    OriginalSection * oSection = self.sections[originalRow.originalIndexPath.section];
    NSInteger vissibleIndex = -1;
    for (NSInteger i = 0; i < originalRow.originalIndexPath.row; ++i) {
        
        OriginalRow * oRow = [oSection.rows objectAtIndex:i];
        
        if (!oRow.hiddenReal) {
            ++vissibleIndex;
        }
        
    }
    
    return [NSIndexPath indexPathForRow:vissibleIndex + 1 inSection:originalRow.originalIndexPath.section];
    
}

- (void)prepareUpdates {
    
    [self.insertIndexPaths removeAllObjects];
    [self.deleteIndexPaths removeAllObjects];
    [self.updateIndexPaths removeAllObjects];
    
    [self.reloadSectionsIndexes removeAllObjects];
    
    NSInteger sectionIndex = 0;
    for (OriginalSection * os in self.sections) {
        
        BOOL visibleBefore = NO;
        BOOL visibleAfter = NO;
        
        for (OriginalRow * or in os.rows) {
        
            visibleBefore = visibleBefore || !or.hiddenReal;
            
            if (or.batchOperation == kBatchOperationDelete) {
                
                NSIndexPath * ip = [self indexPathForDeletingOriginalRow:or];
                [self.deleteIndexPaths addObject:ip];
                
            } else if (or.batchOperation == kBatchOperationInsert) {
            
                NSIndexPath * ip = [self indexPathForInsertingOriginalRow:or];
                [self.insertIndexPaths addObject:ip];
                
            } else if (or.batchOperation == kBatchOperationUpdate) {
                
                NSIndexPath * ip = [self indexPathForInsertingOriginalRow:or];
                [self.updateIndexPaths addObject:ip];
                
            }
            
            visibleAfter = visibleAfter || !or.hiddenPlanned;
            
        }
        
        if (visibleBefore != visibleAfter) {
            [self.reloadSectionsIndexes addObject:@(sectionIndex)];
        }
        ++sectionIndex;
        
    }
    
    // we must do this AFTER all updates calculations, so the indexes dont mess up
    for (OriginalSection * os in self.sections) {
        
        for (OriginalRow * or in os.rows) {
            
            or.hiddenReal = or.hiddenPlanned;
            or.batchOperation = kBatchOperationNone;
            
        }
        
    }
    
}

@end

////////////////////////////////////////////////////////////////////////
#pragma mark - StaticDataTableViewController
////////////////////////////////////////////////////////////////////////

@interface StaticDataTableViewController ()

@property (nonatomic, strong) OriginalTable * originalTable;

@end

@implementation StaticDataTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.insertTableViewRowAnimation = UITableViewRowAnimationRight;
    self.deleteTableViewRowAnimation = UITableViewRowAnimationLeft;
    self.reloadTableViewRowAnimation = UITableViewRowAnimationMiddle;
    
    self.originalTable = [[OriginalTable alloc] initWithTableView:self.tableView];
    
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Public
////////////////////////////////////////////////////////////////////////

- (void)updateCell:(UITableViewCell *)cell {
    
    OriginalRow * row = [self.originalTable originalRowWithTableViewCell:cell];
    [row update];
    
}

- (void)updateCells:(NSArray *)cells {
    for (UITableViewCell * cell in cells) {
        [self updateCell:cell];
    }
}

- (void)cell:(UITableViewCell *)cell setHidden:(BOOL)hidden {
    
    OriginalRow * row = [self.originalTable originalRowWithTableViewCell:cell];
    [row setHidden:hidden];
    
}

- (void)cells:(NSArray *)cells setHidden:(BOOL)hidden {
    for (UITableViewCell * cell in cells) {
        [self cell:cell setHidden:hidden];
    }
}

- (void)cell:(UITableViewCell *)cell setHeight:(CGFloat)height {
    
    OriginalRow * row = [self.originalTable originalRowWithTableViewCell:cell];
    [row setHeight:height];
    
}

- (void)cells:(NSArray *)cells setHeight:(CGFloat)height {
    for (UITableViewCell * cell in cells) {
        [self cell:cell setHeight:height];
    }
}

- (BOOL)cellIsHidden:(UITableViewCell *)cell {
    return [[self.originalTable originalRowWithTableViewCell:cell] hidden];
}

- (BOOL)isCellHidden:(UITableViewCell *)cell {
    return [[self.originalTable originalRowWithTableViewCell:cell] hidden];
}

- (void)reloadDataAnimated:(BOOL)animated {

    [self reloadDataAnimated:animated insertAnimation:self.insertTableViewRowAnimation reloadAnimation:self.reloadTableViewRowAnimation deleteAnimation:self.deleteTableViewRowAnimation];
    
}

- (void)reloadDataAnimated:(BOOL)animated insertAnimation:(UITableViewRowAnimation)insertAnimation reloadAnimation:(UITableViewRowAnimation)reloadAnimation deleteAnimation:(UITableViewRowAnimation)deleteAnimation {

    [self.originalTable prepareUpdates];
    
    if (!animated) {
    
        [self.tableView reloadData];
        
    } else {
        
        [self.tableView beginUpdates];
        
        [self.tableView reloadRowsAtIndexPaths:self.originalTable.updateIndexPaths withRowAnimation:reloadAnimation];
        
        [self.tableView insertRowsAtIndexPaths:self.originalTable.insertIndexPaths withRowAnimation:insertAnimation];
        
        [self.tableView deleteRowsAtIndexPaths:self.originalTable.deleteIndexPaths withRowAnimation:deleteAnimation];
        
        if ([self.originalTable.reloadSectionsIndexes count] > 0) {
        
            for (NSNumber * i in self.originalTable.reloadSectionsIndexes) {
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:[i integerValue]] withRowAnimation:self.reloadTableViewRowAnimation];
            }
            
        }
        
        [self.tableView endUpdates];
        
    }
    
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Public / Should Overwrite
////////////////////////////////////////////////////////////////////////

- (BOOL)showHeaderForSection:(NSInteger)section vissibleRows:(NSInteger)vissibleRows {
    return vissibleRows > 0;
}

- (BOOL)showFooterForSection:(NSInteger)section vissibleRows:(NSInteger)vissibleRows {
    return vissibleRows > 0;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - TableView Data Source
////////////////////////////////////////////////////////////////////////

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView numberOfRowsInSection:section];
    }
    
    return [self.originalTable.sections[section] numberOfVissibleRows];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView cellForRowAtIndexPath:indexPath];
    }
    
    OriginalRow * or = [self.originalTable vissibleOriginalRowWithIndexPath:indexPath];
    
    NSAssert(or.cell != nil, @"Original cell cannot be nil, make sure to use a static table view");
    
    return or.cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.originalTable != nil) {
        OriginalRow * or = [self.originalTable vissibleOriginalRowWithIndexPath:indexPath];
        
        if (or.height != CGFLOAT_MAX) {
            return or.height;
        }
        
        indexPath = or.originalIndexPath;
    }
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView titleForHeaderInSection:section];
    }
    
    OriginalSection * os = self.originalTable.sections[section];
    if ([self showHeaderForSection:section vissibleRows:[os numberOfVissibleRows]]) {
        return [super tableView:tableView titleForHeaderInSection:section];
    } else {
        return nil;
    }
    
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView viewForHeaderInSection:section];
    }

    OriginalSection * os = self.originalTable.sections[section];
    if ([self showHeaderForSection:section vissibleRows:[os numberOfVissibleRows]]) {
        return [super tableView:tableView viewForHeaderInSection:section];
    } else {
        return nil;
    }

}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView heightForHeaderInSection:section];
    }
    
    OriginalSection * os = self.originalTable.sections[section];
    if ([self showHeaderForSection:section vissibleRows:[os numberOfVissibleRows]]) {
        return [super tableView:tableView heightForHeaderInSection:section];
    } else {
        return CGFLOAT_MIN;
    }

}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView titleForFooterInSection:section];
    }
    
    OriginalSection * os = self.originalTable.sections[section];
    if ([self showFooterForSection:section vissibleRows:[os numberOfVissibleRows]]) {
        return [super tableView:tableView titleForFooterInSection:section];
    } else {
        return nil;
    }
    
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView viewForFooterInSection:section];
    }
    
    OriginalSection * os = self.originalTable.sections[section];
    if ([self showFooterForSection:section vissibleRows:[os numberOfVissibleRows]]) {
        return [super tableView:tableView viewForFooterInSection:section];
    } else {
        return nil;
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    
    if (self.originalTable == nil) {
        return [super tableView:tableView heightForFooterInSection:section];
    }
    
    OriginalSection * os = self.originalTable.sections[section];
    if ([self showHeaderForSection:section vissibleRows:[os numberOfVissibleRows]]) {
        return [super tableView:tableView heightForFooterInSection:section];
    } else {
        return CGFLOAT_MIN;
    }
    
}

@end
