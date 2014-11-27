//
//  CDAppDelegate.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/23/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDAppDelegate.h"
#import "CDCommon.h"
#import "CDLoginController.h"
#import "CDBaseTabBarController.h"
#import "CDBaseNavigationController.h"
#import "CDChatListController.h"
#import "CDContactListController.h"
#import "CDProfileController.h"

@implementation CDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    //DEBUG环境下打印应用环境信息
    [AVOSCloud setVerbosePolicy:kAVVerboseAuto];
#if USE_US
    [AVOSCloud useAVCloudUS];
#endif
    [AVOSCloud setApplicationId:AVOSAppID
                      clientKey:AVOSAppKey];
    //统计应用启动情况
    [AVAnalytics trackAppOpenedWithLaunchOptions:launchOptions];

    if (SYSTEM_VERSION >= 7.0) {
        [[UINavigationBar appearance] setBarTintColor:NAVIGATION_COLOR];
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
//        [UINavigationBar appearance].opaque = YES;
//        [[UINavigationBar appearance] setTranslucent:YES];
    } else {
        [[UINavigationBar appearance] setTintColor:NAVIGATION_COLOR];
    }
    [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [UIColor whiteColor], NSForegroundColorAttributeName, [UIFont boldSystemFontOfSize:17], NSFontAttributeName, nil]];
    if ([AVUser currentUser]) {
        [self toMain];
    } else {
        [self toLogin];
    }
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    if (SYSTEM_VERSION < 8.0) {
        [application registerForRemoteNotificationTypes:
         UIRemoteNotificationTypeBadge |
         UIRemoteNotificationTypeAlert |
         UIRemoteNotificationTypeSound];
    } else {
        [application performSelector:@selector(registerForRemoteNotifications)];
    }
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    //聊天接收推送消息必需
    AVInstallation *currentInstallation = [AVInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            [self showErrorWithTitle:@"Installation保存失败" error:error];
        }
    }];
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    [self showErrorWithTitle:@"开启推送失败" error:error];
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    //可选 通过统计功能追踪通过提醒打开应用的行为
    [AVAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
    
    //这儿你可以加入自己的代码 根据推送的数据进行相应处理
}

- (void)toLogin {
    CDLoginController *controller = [[CDLoginController alloc] init];
    self.window.rootViewController = controller;
}

- (void)toMain {
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    CDBaseTabBarController *tab = [[CDBaseTabBarController alloc] init];
    
    CDBaseController *controller = [[CDChatListController alloc] init];
    CDBaseNavigationController *nav = [[CDBaseNavigationController alloc] initWithRootViewController:controller];
    [tab addChildViewController:nav];
    
    controller = [[CDContactListController alloc] init];
    nav = [[CDBaseNavigationController alloc] initWithRootViewController:controller];
    [tab addChildViewController:nav];
    
    controller = [[CDProfileController alloc] init];
    nav = [[CDBaseNavigationController alloc] initWithRootViewController:controller];
    [tab addChildViewController:nav];
    
    self.window.rootViewController = tab;
}

- (void)showErrorWithTitle:(NSString *)title error:(NSError *)error {
    NSString *content = [NSString stringWithFormat:@"%@", error];
    NSLog(@"%@\n%@", title, content);
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:title
                                                   message:content
                                                  delegate:nil
                                         cancelButtonTitle:@"知道了"
                                         otherButtonTitles:nil, nil];
    [alert show];
}
@end
