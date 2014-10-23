//
//  AddRequest.h
//  AVOSChatDemo
//
//  Created by lzw on 14-10-23.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <AVOSCloud/AVOSCloud.h>
#import "User.h"

@interface AddRequest : AVObject<AVSubclassing>

@property User *fromUser;
@property User *toUser;
@property int status;

@end
