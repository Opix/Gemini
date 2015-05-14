//
//  SearchTableViewController.m
//  Gemini
//
//  Created by GEMINI on 4/23/14.
//  Copyright (c) 2015 GEMINI. All rights reserved.
//
// References:
// 1) UISearchController for iOS 8:
// http://useyourloaf.com/blog/2015/02/16/updating-to-the-ios-8-search-controller.html

// 2) Indexed list:
// https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/TableView_iPhone/CreateConfigureTableView/CreateConfigureTableView.html

// 3) Creating segue not from a table row but from the entire view:
// http://stackoverflow.com/questions/9674685/creating-a-segue-programmatically

#import "AppDelegate.h"
#import "SearchTableViewController.h"
#import "Events.h"
#import "OneResultTableViewController.h"
#import "QuickResult.h"
#import "ColumnTableViewController.h"

#define SEARCH_EXACT    0
#define SEARCH_PARTIAL  1

@interface OneResultTableViewCell ()
@end

@implementation OneResultTableViewCell
@end

@interface HeaderTableViewCell ()
@end

@implementation HeaderTableViewCell
@end


@implementation SearchTableViewController
@synthesize currentKeyword;
@synthesize arraySearchResults;
@synthesize arrayDivisions;
@synthesize tableName, display3, display2, display1, display4, display5;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // http://stackoverflow.com/questions/12900446/how-to-use-uitableviewheaderfooterview
    // [self.tableView registerClass: [HeaderTableViewCell class] forHeaderFooterViewReuseIdentifier: @"headerCell"];
    
    bSearching = NO;
    socialMediaIndex = -1;
    
    arraySearchResults  = [[NSMutableArray alloc] init];
    arrayDivisions      = [[NSMutableArray alloc] init];
    display1            = @"Chip";
    display2            = @"";
    display3            = @"";
    display4            = @"";
    display5            = @"";
    
    NSString *deviceType = [UIDevice currentDevice].model;
    iPad                = [deviceType isEqualToString:@"iPad"];
    
    [_eventModel downloadDivisions: tableName];

    _searchController = [[UISearchController alloc] initWithSearchResultsController: nil];
    self.searchController.searchResultsUpdater = self;
    [self.searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    
    // we want to be the delegate for our filtered table so didSelectRowAtIndexPath is called for both tables
    self.searchController.delegate                              = self;
    self.searchController.dimsBackgroundDuringPresentation      = NO; // default is YES
    self.searchController.searchBar.delegate                    = self; // so we can monitor text changes + others
    self.searchController.hidesNavigationBarDuringPresentation  = NO;
    self.searchController.searchBar.placeholder                 = @"Enter last name or bib number";
    
    // self.searchController.searchBar.scopeButtonTitles = @[NSLocalizedString(@"Exact", @"Exact"), NSLocalizedString(@"Partial", @"Partial")];

    // Search is now just presenting a view controller. As such, normal view controller
    // presentation semantics apply. Namely that presentation will walk up the view controller
    // hierarchy until it finds the root view controller or one that defines a presentation context.
    //
    self.definesPresentationContext = YES;  // know where you want UISearchController to be displayed
    
    // Add another button if this event is not a future event.
    // The extra button is used to display different column.
    if (![self isFuture])
    {
        // Get the existing right button array, which already has Filter button.
        NSArray* btnArray = self.navigationItem.rightBarButtonItems;
        NSMutableArray *arrRightBarItems = [[NSMutableArray alloc] initWithArray: btnArray];
    
        // This is one way to add a custom button, but not used here since a system icon is used.
        /*
        UIButton *btnSetting = [UIButton buttonWithType:UIButtonTypeCustom];
        [btnSetting setTintColor: [UIColor whiteColor]];
        [btnSetting setImage:[UIImage imageNamed:@"Filter-26.png"] forState: UIControlStateNormal];
        btnSetting.frame = CGRectMake(0, 0, 32, 32);
        btnSetting.showsTouchWhenHighlighted= NO;
        [btnSetting addTarget:self action:@selector(filterByDivision:) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btnSetting];
        [arrRightBarItems addObject:barButtonItem];
         */

        UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemOrganize target: self action: @selector(changeDisplayColumn:)];

        [arrRightBarItems addObject: barButtonItem];
        
        // Reset the right button array.
        self.navigationItem.rightBarButtonItems = arrRightBarItems;
    }
}

// Catch when orientation changes:
// https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIContentContainer_Ref/index.html#//apple_ref/occ/intfm/UIContentContainer/viewWillTransitionToSize:withTransitionCoordinator:
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize: size withTransitionCoordinator: coordinator];
    // Need to refresh because the header width changes and therefore the header lines need to be recalculated.
    [self.tableView reloadData];
}

// http://stackoverflow.com/questions/16306260/setting-custom-header-view-in-uitableview
- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString* keyword = @"";
    BOOL bBlankKeyword = ([currentKeyword isEqualToString: @""] || !currentKeyword);
    
    if (!bBlankKeyword)
        keyword = [NSString stringWithFormat: @" (Keyword: %@)", currentKeyword];
    
    // Future events are up to 2 lines.  No column line.
    if ([self isFuture])
    {
        UITableViewCell *header = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"futureHeaderCell"];
        header.backgroundColor = [UIColor darkGrayColor];
        
        if (arraySearchResults.count != 1)
            header.textLabel.text   = [NSString stringWithFormat: @"%lu Entries%@", (unsigned long)arraySearchResults.count, keyword];
        else
            header.textLabel.text   = [NSString stringWithFormat: @"1 Entry%@", keyword];
        
        header.textLabel.textColor  = [UIColor whiteColor];
        header.textLabel.font       = [UIFont boldSystemFontOfSize: 17];
        return header;
    }
    else
    {
        HeaderTableViewCell *header = (HeaderTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"headerCell"];
                
        if (arraySearchResults.count != 1)
            header.labelResults.text = [NSString stringWithFormat: @"%lu Results%@", (unsigned long)arraySearchResults.count, keyword];
        else
            header.labelResults.text = [NSString stringWithFormat: @"1 Result%@", keyword];

        [header.labelDisplay1 setTitle: display1 forState: UIControlStateNormal];
        [header.labelDisplay2 setTitle: display2 forState: UIControlStateNormal];
        [header.labelDisplay3 setTitle: display3 forState: UIControlStateNormal];

        if (iPad)
        {
            [header.labelDisplay4 setTitle: display4 forState: UIControlStateNormal];
            [header.labelDisplay5 setTitle: display5 forState: UIControlStateNormal];
        }
        
        return header;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([self isFuture])
        return 44.0;

    return 60.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return arraySearchResults.count;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    return;
    
    [searchBar viewWithTag: 0];
    
    NSString* newKeyword = [searchBar text];
    
    if ([newKeyword isEqualToString: @""])
        return;
    
    if ([currentKeyword isEqualToString: newKeyword])
        return;
    
    [searchBar resignFirstResponder];
    currentKeyword = newKeyword;
    
    [_eventModel downloadResults: tableName keyword: currentKeyword exact: NO byDivision: NO displayColumn1: display1 displayColumn2: display2  displayColumn3: display3 displayColumn4: display4 displayColumn5: display5];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    QuickResult* oneResult = [arraySearchResults objectAtIndex: indexPath.row];
    
    if ([segue.identifier isEqualToString: @"displaySegue"])
    {
        self.columnTableViewController = [segue destinationViewController];
        [self.columnTableViewController setTableName: oneResult.tableName];
        [self.columnTableViewController setDisplayColumns: display1 display2: display2 display3: display3 display4: display4 display5: display5];
        bFromColumnTableView = YES;
        return;
    }
    
    self.oneResultsTableViewController = [segue destinationViewController];
    [self.oneResultsTableViewController setQuickResult: oneResult];
    [self.oneResultsTableViewController setCurrentEvent:currentEvent];
    [self.oneResultsTableViewController setTitle: [NSString stringWithFormat: @"%@ %@", oneResult.firstName, oneResult.lastName]];
}

-(void) dataDownloaded: (NSMutableData*) downloadedData
{
     NSError *error;
     NSArray*jsonArray = [NSJSONSerialization JSONObjectWithData: downloadedData options: NSJSONReadingAllowFragments error:&error];

    if (socialMediaIndex != -1)
    {
        NSMutableArray* columnArray = [[NSMutableArray alloc] initWithArray: [jsonArray objectAtIndex: 0]];
        NSMutableArray* dataArray   = [[NSMutableArray alloc] initWithArray: [jsonArray objectAtIndex: 1]];

        [columnArray insertObject: @"Race" atIndex: 0];
        [dataArray insertObject: self.title atIndex: 0];
        
        [self sendToSocialMedia: socialMediaIndex columns: columnArray  data: dataArray];

        socialMediaIndex = -1;
    }
    // Division is filled for the Division Filter.
    else if (!bSearching)
    {
        [arrayDivisions removeAllObjects];
    
        for (NSInteger i = 0; i < jsonArray.count; i++)
            [arrayDivisions addObject: jsonArray[i][0]];
        
        // Add "No Filter"
        [arrayDivisions insertObject: @"No Filter" atIndex: 0];
        
        bSearching = YES;
        currentKeyword = @"";
        
        [_eventModel downloadResults: tableName keyword: currentKeyword exact: NO byDivision: NO displayColumn1: display1 displayColumn2: display2  displayColumn3: display3 displayColumn4: display4  displayColumn5: display5];
    }
    else
    {
        [arraySearchResults removeAllObjects];
        
        // This is called by the search view controller.  No details needed:  `Overall`, `Bib`, `First Name`, `Last Name`, `Chip` or `Total Time`.
        // Loop through Json objects, create question objects and add them to our questions array
        for (int i = 0; i < jsonArray.count; i++)
        {
            NSArray *jsonElement = jsonArray[i];
            
            NSInteger primaryKey    = [jsonElement[1] integerValue];
            QuickResult* oneResult  = [[QuickResult alloc] initWithPrimaryKey: primaryKey];
            oneResult.overall       = [jsonElement[0] integerValue];
            oneResult.firstName     = [jsonElement[2] stringByReplacingOccurrencesOfString:@"\\'" withString:@"'"];
            oneResult.lastName      = [jsonElement[3] stringByReplacingOccurrencesOfString:@"\\'" withString:@"'"];
            
            // 3 more additional fields can be selected.
            if (jsonElement.count == 5)
                oneResult.display1  = jsonElement[4];
            else if (jsonElement.count == 6)
            {
                oneResult.display1  = jsonElement[4];
                oneResult.display2  = jsonElement[5];
            }
            else if (jsonElement.count == 7)
            {
                oneResult.display1  = jsonElement[4];
                oneResult.display2  = jsonElement[5];
                oneResult.display3  = jsonElement[6];
            }
            else if (iPad)
            {
                if (jsonElement.count == 8)
                {
                    oneResult.display1  = jsonElement[4];
                    oneResult.display2  = jsonElement[5];
                    oneResult.display3  = jsonElement[6];
                    oneResult.display4  = jsonElement[7];
                }
                else if (jsonElement.count == 9)
                {
                    oneResult.display1  = jsonElement[4];
                    oneResult.display2  = jsonElement[5];
                    oneResult.display3  = jsonElement[6];
                    oneResult.display4  = jsonElement[7];
                    oneResult.display5  = jsonElement[8];
                }
            }
            
            oneResult.tableName     = tableName;
            oneResult.raceTitle     = self.title;
            
            [arraySearchResults addObject: oneResult];
        }
        
        [self.tableView reloadData];
    }
}

- (IBAction) filterByDivision: (id)sender
{
    if (!arrayDivisions.count)
        return;
    
    UIActionSheet* sheet = [[UIActionSheet alloc] initWithTitle: @"Filter By" delegate:self cancelButtonTitle: @"Cancel" destructiveButtonTitle: NULL otherButtonTitles: NULL];
    
    for (NSInteger j = 0; j < arrayDivisions.count; j++)
        [sheet addButtonWithTitle: arrayDivisions[j]];
    
    [sheet showFromBarButtonItem: sender animated: YES];
}

- (IBAction) changeDisplayColumn: (id)sender
{
    [self performSegueWithIdentifier:@"displaySegue" sender:sender];
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // 0 = Cancel.
    if (buttonIndex > 0)
    {
        currentKeyword = [arrayDivisions objectAtIndex: buttonIndex - 1]; // -1 because of Cancel button.
        
        if ([currentKeyword isEqualToString: @"No Filter"])
            currentKeyword = @"";
        
        // Shared by iPhone and iPad; however, for iPhone, 4 and 5 are always blank.
        [_eventModel downloadResults: tableName keyword: currentKeyword exact: YES byDivision: YES displayColumn1: display1 displayColumn2: display2  displayColumn3: display3 displayColumn4: display4 displayColumn5: display5];
    }
}

- (void)setTableName: (NSString*) newTableName
{
    tableName = newTableName;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!arraySearchResults.count)
        return nil;
    
    QuickResult* oneResult  = [arraySearchResults objectAtIndex: indexPath.row];
    OneResultTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"oneResultCell" forIndexPath:indexPath];
    
    cell.labelName.text     = [NSString stringWithFormat: @"%@ %@ (#%ld)", oneResult.firstName, oneResult.lastName, (long)oneResult.bibNumber];
    
    // For future events, overall does not mean anything so leave it blank.
    if (![self isFuture])
        cell.labelPlace.text    = [NSString stringWithFormat: @"%ld", (long)oneResult.overall];
    
    cell.labelDisplay1.text = oneResult.display1;
    cell.labelDisplay2.text = oneResult.display2;
    cell.labelDisplay3.text = oneResult.display3;
    
    if (iPad)
    {
        cell.labelDisplay4.text = oneResult.display4;
        cell.labelDisplay5.text = oneResult.display5;
    }
    
    cell.labelCounter.text  = [NSString stringWithFormat: @"%ld", (long)(indexPath.row + 1)];

    // Change row color alternately
    if (indexPath.row % 2 != 0)
        cell.backgroundColor = [UIColor colorWithRed: 0.5 green: 0.5 blue: 0.50 alpha: 0.1];
    else
        cell.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

// Swipe to the left and show some actions.
// https://gist.github.com/scheinem/e36835db07486e9f7e64
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    QuickResult* oneResult  = [arraySearchResults objectAtIndex: indexPath.row];
    
    if ([self isFuture])
    {
#ifdef GEMINI_VERSION_2
        UITableViewRowAction *followAction = [UITableViewRowAction rowActionWithStyle: UITableViewRowActionStyleDefault title:@"Follow" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
 
            [_eventModel download1Result: oneResult.tableName firstName: oneResult.firstName lastName: oneResult.lastName bibNumber: oneResult.bibNumber];
        }];
        
        followAction.backgroundColor = [UIColor blueColor];
        
        UITableViewRowAction *updateAction = [UITableViewRowAction rowActionWithStyle: UITableViewRowActionStyleDefault title:@"Update" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            
            [_eventModel download1Result: oneResult.tableName firstName: oneResult.firstName lastName: oneResult.lastName bibNumber: oneResult.bibNumber];
        }];
        updateAction.backgroundColor = [UIColor greenColor];
        
        return @[followAction, updateAction];
#endif
        return nil;
    }
    else
    {
        UITableViewRowAction *faceBookAction = [UITableViewRowAction rowActionWithStyle: UITableViewRowActionStyleDefault title:@"FaceBook" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            socialMediaIndex = SEND_TO_FACEBOOK;
            [_eventModel download1Result: oneResult.tableName firstName: oneResult.firstName lastName: oneResult.lastName bibNumber: oneResult.bibNumber];
        }];
        faceBookAction.backgroundColor = [UIColor blueColor];

        UITableViewRowAction *emailAction = [UITableViewRowAction rowActionWithStyle: UITableViewRowActionStyleDefault title:@"Email" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            
            socialMediaIndex = SEND_TO_MAIL;
            [_eventModel download1Result: oneResult.tableName firstName: oneResult.firstName lastName: oneResult.lastName bibNumber: oneResult.bibNumber];        
        }];
        emailAction.backgroundColor = [UIColor greenColor];
        
        UITableViewRowAction *twitterAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Twitter" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            socialMediaIndex = SEND_TO_TWITTER;
            [_eventModel download1Result: oneResult.tableName firstName: oneResult.firstName lastName: oneResult.lastName bibNumber: oneResult.bibNumber];
        }];
        twitterAction.backgroundColor = [UIColor orangeColor];

        return @[twitterAction, faceBookAction, emailAction];
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    // No statement or algorithm is needed in here. Just the implementation
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    // update the filtered array based on the search text
    currentKeyword = searchController.searchBar.text;
    
    [_eventModel downloadResults: tableName keyword: currentKeyword exact: NO byDivision: NO displayColumn1: display1 displayColumn2: display2  displayColumn3: display3 displayColumn4: display4 displayColumn5: display5];
}

NSString *const ViewControllerTitleKey = @"ViewControllerTitleKey";
NSString *const SearchControllerIsActiveKey = @"SearchControllerIsActiveKey";
NSString *const SearchBarTextKey = @"SearchBarTextKey";
NSString *const SearchBarIsFirstResponderKey = @"SearchBarIsFirstResponderKey";

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    
    // encode the view state so it can be restored later
    
    // encode the title
    [coder encodeObject:self.title forKey:ViewControllerTitleKey];
    
    UISearchController *searchController = self.searchController;
    
    // encode the search controller's active state
    BOOL searchDisplayControllerIsActive = searchController.isActive;
    [coder encodeBool:searchDisplayControllerIsActive forKey:SearchControllerIsActiveKey];
    
    // encode the first responser status
    if (searchDisplayControllerIsActive) {
        [coder encodeBool:[searchController.searchBar isFirstResponder] forKey:SearchBarIsFirstResponderKey];
    }
    
    // encode the search bar text
    [coder encodeObject:searchController.searchBar.text forKey:SearchBarTextKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    
    // restore the title
    self.title = [coder decodeObjectForKey:ViewControllerTitleKey];
    
    // restore the active state:
    // we can't make the searchController active here since it's not part of the view
    // hierarchy yet, instead we do it in viewWillAppear
    //
    _searchControllerWasActive = [coder decodeBoolForKey:SearchControllerIsActiveKey];
    
    // restore the first responder status:
    // we can't make the searchController first responder here since it's not part of the view
    // hierarchy yet, instead we do it in viewWillAppear
    //
    _searchControllerSearchFieldWasFirstResponder = [coder decodeBoolForKey:SearchBarIsFirstResponderKey];
    
    // restore the text in the search field
    self.searchController.searchBar.text = [coder decodeObjectForKey:SearchBarTextKey];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // restore the searchController's active state
    if (self.searchControllerWasActive) {
        self.searchController.active = self.searchControllerWasActive;
        _searchControllerWasActive = NO;
        
        if (self.searchControllerSearchFieldWasFirstResponder) {
            [self.searchController.searchBar becomeFirstResponder];
            _searchControllerSearchFieldWasFirstResponder = NO;
        }
    }
    
    if (bFromColumnTableView)
    {
        bFromColumnTableView = NO;

        // If no change, then do nothing.
        if ([display1 isEqualToString: [self.columnTableViewController getDisplay1]] &&
            [display2 isEqualToString: [self.columnTableViewController getDisplay1]] &&
            [display3 isEqualToString: [self.columnTableViewController getDisplay1]])
            return;

        display1 = [self.columnTableViewController getDisplay1];
        display2 = [self.columnTableViewController getDisplay2];
        display3 = [self.columnTableViewController getDisplay3];
        
        if (iPad)
        {
            display4 = [self.columnTableViewController getDisplay4];
            display5 = [self.columnTableViewController getDisplay5];
        }
        
        // If nothing is selected, then do nothing.
        if (![display1 isEqualToString: @""] ||
            ![display2 isEqualToString: @""] ||
            ![display3 isEqualToString: @""])
        {
            BOOL bDivision = NO;
            
            // Check if current keyword is in the division array.
            for (NSInteger i = 0; i < arrayDivisions.count; i++)
            {
                if ([currentKeyword isEqualToString: arrayDivisions[i]])
                {
                    bDivision = YES;
                    break;
                }
            }
            
            [_eventModel downloadResults: tableName keyword: currentKeyword exact: NO byDivision: bDivision displayColumn1: display1 displayColumn2: display2  displayColumn3: display3 displayColumn4: display4 displayColumn5: display5];
        }
    }
    
    bFromColumnTableView = NO;
}

- (void)presentSearchController:(UISearchController *)searchController {
    
}

- (void)willPresentSearchController:(UISearchController *)searchController {
    // do something before the search controller is presented
}

- (void)didPresentSearchController:(UISearchController *)searchController {
    // do something after the search controller is presented
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    // do something before the search controller is dismissed
}

- (void)didDismissSearchController:(UISearchController *)searchController {
    // do something after the search controller is dismissed
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
}

// 1
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}
@end
