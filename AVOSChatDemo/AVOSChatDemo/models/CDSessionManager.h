//
//  CDSessionManager.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/29/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDCommon.h"
#import "Msg.h"

@interface CDSessionManager : NSObject <AVSessionDelegate, AVSignatureDelegate, AVGroupDelegate>
+ (instancetype)sharedInstance;
//- (void)startSession;
//- (void)addSession:(AVSession *)session;
//- (NSArray *)sessions;
- (NSArray *)chatRooms;
- (void)watchPeerId:(NSString *)peerId;
-(void)unwatchPeerId:(NSString*)peerId;

- (AVGroup *)joinGroup:(NSString *)groupId;
- (void)startNewGroup:(AVGroupResultBlock)callback;
- (void)sendMessage:(NSString *)content type:(CDMsgType)type toPeerId:(NSString *)toPeerId group:(AVGroup*)group;
- (void)sendAttachment:(NSString*)objectId type:(CDMsgType)type toPeerId:(NSString *)toPeerId group:(AVGroup*)group;

- (NSArray*)getMsgsForConvid:(NSString*)convid;
- (void)getHistoryMessagesForPeerId:(NSString *)peerId callback:(AVArrayResultBlock)callback;
- (void)getHistoryMessagesForGroup:(NSString *)groupId callback:(AVArrayResultBlock)callback;
- (void)clearData;

+(NSString*)getConvid:(CDMsgRoomType)roomType otherId:(NSString*)otherId groupId:(NSString*)groupId;
+(NSString*)convid:(NSString*)myId otherId:(NSString*)otherId;
+(NSString*)getPathByObjectId:(NSString*)objectId;
+(NSString*)uuid;

- (void)registerUsers:(NSArray*)users;
- (void)registerUser:(User*)user;
- (User *)lookupUser:(NSString*)userId;

-(void)openSession;
-(void)closeSession;

-(void)findConversations:(AVArrayResultBlock)callback;
@end
