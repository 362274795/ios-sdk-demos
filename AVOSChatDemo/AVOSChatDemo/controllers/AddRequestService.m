//
//  AddRequestService.m
//  AVOSChatDemo
//
//  Created by lzw on 14-10-23.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "AddRequestService.h"

@implementation AddRequestService

+(void)createAddRequest:(User *)toUser withCallback:(AVBooleanResultBlock)callback{
    User *curUser=[User currentUser];
    [self haveAddRequest:curUser toUser:toUser callback:^(BOOL had, NSError *error) {
        if(error==NULL){
            if(had){
                NSDictionary *details=@{NSLocalizedDescriptionKey:@"已经发出过请求了"};
                callback(false,[NSError errorWithDomain:@"world" code:0 userInfo:details]);
            }else{
                AddRequest* addRequest=[[AddRequest alloc] init];
                addRequest.fromUser=curUser;
                addRequest.toUser=toUser;
                addRequest.status=kAddRequestStatusWait;
                [addRequest saveInBackgroundWithBlock:callback];
            }
        }else{
            callback(false,error);
        }
    }];
}

+(void)haveAddRequest:(User *)fromUser toUser:(User *)toUser callback:(AVBooleanResultBlock)callback{
    AVQuery *q=[AddRequest query];
    [q whereKey:@"fromUser" equalTo:fromUser];
    [q whereKey:@"toUser" equalTo:toUser];
    [q whereKey:@"status" equalTo:@(kAddRequestStatusWait)];
    [q countObjectsInBackgroundWithBlock:^(NSInteger number, NSError *error) {
        if(error){
            callback(false,error);
        }else{
            if(number>0){
                callback(true,NULL);
            }else{
                callback(false,NULL);
            }
        }
    }];
}

+(void)findAddRequests:(AVArrayResultBlock)callback{
    User* curUser=[User currentUser];
    AVQuery *q=[AddRequest query];
    [q includeKey:@"fromUser"];
    [q whereKey:@"toUser" equalTo:curUser];
    [q findObjectsInBackgroundWithBlock:callback];
}
@end
