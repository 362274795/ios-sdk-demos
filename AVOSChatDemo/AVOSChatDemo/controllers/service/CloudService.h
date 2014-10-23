//
//  CloudService.h
//  AVOSChatDemo
//
//  Created by lzw on 14-10-24.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "User.h"
#import <AVOSCloud/AVOSCloud.h>
static NSString *kAddFriendFnName=@"addFriend";
static NSString *kRemoveFriendFnName=@"removeFriend";

@interface CloudService : NSObject
+(void)callCloudRelationFn:(User*)fromUser toUser:(User*)toUser action:(NSString*)action callback:(AVIdResultBlock)callback;
@end
