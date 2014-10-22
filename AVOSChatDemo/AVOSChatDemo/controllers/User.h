//
//  User.h
//  AVOSChatDemo
//
//  Created by lzw on 14-10-22.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "CDCommon.h"

@interface User : AVUser<AVSubclassing>

@property (retain) AVRelation *friends;

@end
