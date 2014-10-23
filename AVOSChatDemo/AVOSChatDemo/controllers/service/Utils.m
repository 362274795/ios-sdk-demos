//
//  Utils.m
//  AVOSChatDemo
//
//  Created by lzw on 14-10-24.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "Utils.h"

@implementation Utils
+(void)alert:(NSString*)msg{
    UIAlertView *alertView=[[UIAlertView alloc]
                             initWithTitle:nil message:msg delegate:nil
                             cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alertView show];
}
@end
