//
//  CDAddFriendController.m
//  AVOSChatDemo
//
//  Created by lzw on 14-10-22.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "CDAddFriendController.h"
#import "CDTextField.h"

@interface CDAddFriendController ()<UITextFieldDelegate>

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
    self.view.frame=CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    CGFloat originX=10;
    CGFloat orginY=10;
    CGFloat width=self.view.frame.size.width;
    CGFloat height=self.view.frame.size.height;
    UIImage *image;
    int buttonWidth=100;
    CGFloat textWidth=width-buttonWidth;
    image=[UIImage imageNamed:@"input_bg_top"];
    CGFloat textHeight=image.size.height;
    CDTextField *textField=[[CDTextField alloc] initWithFrame:CGRectMake(originX, orginY, textWidth, textHeight)];
    textField.background=image;
    textField.horizontalPadding=10;
    textField.verticalPadding=10;
    textField.placeholder=@"请输入用户名";
    textField.contentVerticalAlignment=UIControlContentHorizontalAlignmentCenter;
    textField.returnKeyType=UIReturnKeyGo;
    [self.view addSubview:textField];
    //textField.delegate=self;

    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
