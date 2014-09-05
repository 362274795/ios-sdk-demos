//
//  CDSessionManager.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/29/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDCommon.h"

typedef enum : NSUInteger {
    CDChatRoomTypeSingle = 1,
    CDChatRoomTypeGroup,
} CDChatRoomType;

@interface CDSessionManager : NSObject <AVSessionDelegate, AVSignatureDelegate, AVGroupDelegate>
+ (instancetype)sharedInstance;
//- (void)startSession;
//- (void)addSession:(AVSession *)session;
//- (NSArray *)sessions;
- (NSArray *)chatRooms;
- (void)addChatWithPeerId:(NSString *)peerId;
- (AVGroup *)joinGroup:(NSString *)groupId;
- (AVGroup *)startNewGroup;
- (void)sendMessage:(NSString *)message toPeerId:(NSString *)peerId;
- (void)sendMessage:(NSString *)message toGroup:(NSString *)groupId;
- (NSArray *)getMessagesForPeerId:(NSString *)peerId;
- (NSArray *)getMessagesForGroup:(NSString *)groupId;
- (void)clearData;
@end
