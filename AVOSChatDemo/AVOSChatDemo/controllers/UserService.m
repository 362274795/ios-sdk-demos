//
//  UserService.m
//  AVOSChatDemo
//
//  Created by lzw on 14-10-22.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "UserService.h"

@implementation UserService

+(void)findFriends:(AVArrayResultBlock )block{
    User *user=[User currentUser];
    AVRelation *relation=[user relationforKey:@"friends"];
    //    //设置缓存有效期
    //    query.maxCacheAge = 4 * 3600;
    AVQuery *q=[relation query];
    q.cachePolicy=kAVCachePolicyNetworkElseCache;
    [q findObjectsInBackgroundWithBlock:block];
}

// should exclude friends
+(void)findUsers:(NSString *)partName withBlock:(AVArrayResultBlock)block{
    AVQuery *q=[User query];
    [q setCachePolicy:kAVCachePolicyNetworkElseCache];
    [q whereKey:@"username" containsString:partName];
    User *curUser=[User currentUser];
    [q whereKey:@"objectId" notEqualTo:curUser.objectId];
    [q findObjectsInBackgroundWithBlock:block];
}
@end
