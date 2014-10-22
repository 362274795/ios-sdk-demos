//
//  UserService.h
//  AVOSChatDemo
//
//  Created by lzw on 14-10-22.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDCommon.h"
#import "User.h"

@interface UserService : NSObject
+(void)findFriends:(AVArrayResultBlock)callback;

@end
