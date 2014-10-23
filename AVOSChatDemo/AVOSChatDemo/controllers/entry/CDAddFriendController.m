//
//  CDAddFriendController.m
//  AVOSChatDemo
//
//  Created by lzw on 14-10-23.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "CDAddFriendController.h"
#import "User.h"
#import "UserService.h"
#import "CDBaseNavigationController.h"
#import "CDUserInfoController.h"

@interface CDAddFriendController (){
    NSArray *users;
}
@end

@implementation CDAddFriendController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_searchBar setDelegate:self];
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    [self searchUser:@""];
    // Do any additional setup after loading the view from its nib.
}

-(void)searchUser:(NSString *)name{
    [UserService findUsers:name withBlock:^(NSArray *objects, NSError *error) {
        if(objects){
            users=objects;
            [_tableView reloadData];
        }
    }];
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [users count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"tableCell"];
    if(!cell){
        cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"tableCell"];
    }
    User *user=(User*)users[indexPath.row];
    cell.textLabel.text=user.username;
    return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    //NSLog(@"select");
    User *user=users[indexPath.row];
    CDUserInfoController *controller=[[CDUserInfoController alloc] init];
    controller.user=user;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [searchBar resignFirstResponder];
    NSString* content=[searchBar text];
    [self searchUser:content];
}


@end
