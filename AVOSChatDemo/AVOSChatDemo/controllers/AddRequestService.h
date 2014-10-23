//
//  AddRequestService.h
//  AVOSChatDemo
//
//  Created by lzw on 14-10-23.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "User.h"
#import "AddRequest.h"

@interface AddRequestService : NSObject

+(void)createAddRequest:(User*)toUser withCallback:(AVBooleanResultBlock)callback;

+(void)findAddRequests:(AVArrayResultBlock)callback;

@end
