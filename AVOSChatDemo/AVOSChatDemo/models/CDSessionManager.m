//  CDSessionManager.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/29/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDSessionManager.h"
#import "FMDB.h"
#import "CDCommon.h"
#import "Msg.h"

@interface CDSessionManager () {
    FMDatabase *_database;
    AVSession *_session;
    NSMutableArray *_chatRooms;
    NSDictionary *_cachedUsers;
}

@end

#define MESSAGES @"messages"

static id instance = nil;
static BOOL initialized = NO;
static NSString *messagesTableSQL=@"create table if not exists messages (id integer primary key, objectId varchar(63) unique,ownerId varchar(255),fromPeerId varchar(255), convid varchar(255),toPeerId varchar(255),content varchar(1023),status integer,type integer,roomType integer,timestamp varchar(63))";

@implementation CDSessionManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    if (!initialized) {
        [instance commonInit];
    }
    return instance;
}

- (NSString *)databasePath {
    static NSString *databasePath = nil;
    if (!databasePath) {
        NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        databasePath = [cacheDirectory stringByAppendingPathComponent:@"chat.db"];
    }
    return databasePath;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    if ((self = [super init])) {
        _chatRooms = [[NSMutableArray alloc] init];
        _cachedUsers=[[NSDictionary alloc] init];
        
        AVSession *session = [[AVSession alloc] init];
        session.sessionDelegate = self;
        session.signatureDelegate = self;
        _session = session;

        NSLog(@"database path:%@", [self databasePath]);
        _database = [FMDatabase databaseWithPath:[self databasePath]];
        [_database open];
        [self commonInit];
    }
    return self;
}

//if type is image ,message is attment.objectId

- (void)commonInit {
    if (![_database tableExists:@"messages"]) {
        [_database executeUpdate:messagesTableSQL];
    }
    [_session openWithPeerId:[AVUser currentUser].username];

    FMResultSet *rs = [_database executeQuery:@"select * from messages group by convid order by time desc" ];
    NSArray *msgs=[self getMsgsByResultSet:rs];
    NSMutableArray *peerIds = [[NSMutableArray alloc] init];
    for(Msg* msg in msgs){
        NSString* otherId=[msg getOtherId];
        if(msg.roomType==CDMsgRoomTypeSingle){
            [peerIds addObject:otherId];
        }else{
            AVGroup *group = [AVGroup getGroupWithGroupId:otherId session:_session];
            group.delegate = self;
            [group join];
        }
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:msg.roomType] forKey:@"roomType"];
        [dict setObject:otherId forKey:@"otherid"];
        [_chatRooms addObject:dict];
    }
    [_session watchPeerIds:peerIds];
    initialized = YES;
}

- (void)clearData {
    [_database executeUpdate:@"DROP TABLE IF EXISTS messages"];
    [_chatRooms removeAllObjects];
    [_session close];
    initialized = NO;
}

- (NSArray *)chatRooms {
    return _chatRooms;
}

- (void)addChatWithPeerId:(NSString *)peerId {
    [_session watchPeerIds:@[peerId]];
}

- (AVGroup *)joinGroup:(NSString *)groupId {
    AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
    group.delegate = self;
    [group join];
    return [AVGroup getGroupWithGroupId:groupId session:_session];;
}

- (void)startNewGroup:(AVGroupResultBlock)callback {
    [AVGroup createGroupWithSession:_session groupDelegate:self callback:^(AVGroup *group, NSError *error) {
        if (!error) {
            if (callback) {
                callback(group, error);
            }
        } else {
            NSLog(@"error:%@", error);
        }
    }];
}

-(Msg*)insertMsgToDB:(Msg*)msg{
    NSDictionary *dict=[msg toDatabaseDict];
    [_database executeUpdate:@"insert into messages (objectId,ownerId , fromPeerId, toPeerId, content,convid,status,type,roomType,timestamp) values (:objectId,:ownerId,:fromPeerId,:toPeerId,:content,:convid,:status,:type,:roomType,:timestamp)" withParameterDictionary:dict];
    return msg;
}

+(NSString*)convid:(NSString*)myId otherId:(NSString*)otherId{
    NSArray *arr=@[myId,otherId];
    NSArray *sortedArr=[arr sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableString* result= [[NSMutableString alloc] init];
    for(int i=0;i<sortedArr.count;i++){
        if(i!=0){
            [result appendString:@":"];
        }
        [result appendString:[sortedArr objectAtIndex:i]];
    }
    return result;
}

+(NSString*)uuid{
    NSString *chars=@"abcdefghijklmnopgrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    assert(chars.length==62);
    int len=chars.length;
    NSMutableString* result=[[NSMutableString alloc] init];
    for(int i=0;i<24;i++){
        int p=arc4random_uniform(len);
        NSRange range=NSMakeRange(p, 1);
        [result appendString:[chars substringWithRange:range]];
    }
    return result;
}

-(Msg*)createAndSendMsg:(NSString*)toPeerId type:(CDMsgType)type content:(NSString*)content group:(AVGroup*)group{
    Msg* msg=[[Msg alloc] init];
    msg.toPeerId=toPeerId;
    int64_t currentTime=(int64_t)CACurrentMediaTime()*1000;
    msg.timestamp=currentTime;
    msg.content=content;
    NSString* curUserId=[User curUserId];
    msg.fromPeerId=curUserId;
    msg.status=CDMsgStatusSendStart;
    if(!group){
        msg.toPeerId=toPeerId;
        msg.roomType=CDMsgRoomTypeSingle;
        msg.convid=[CDSessionManager convid:curUserId otherId:toPeerId];
    }else{
        msg.roomType=CDMsgRoomTypeGroup;
        msg.toPeerId=group.groupId;
        msg.convid=group.groupId;
    }
    msg.objectId=[CDSessionManager uuid];
    msg.type=type;
    return [self sendMsg:group msg:msg];
}

-(AVSession*)getSession{
    return _session;
}

-(Msg*)sendMsg:(AVGroup*)group msg:(Msg*)msg{
    if(!group){
        AVMessage *avMsg=[AVMessage messageForPeerWithSession:_session toPeerId:msg.toPeerId payload:[msg toMessagePayload]];
        [_session sendMessage:avMsg];
    }else{
        AVMessage *avMsg=[AVMessage messageForGroup:group payload:[msg toMessagePayload]];
        [group sendMessage:avMsg];
    }
    return msg;
}

- (void)sendMessage:(NSString *)message toPeerId:(NSString *)peerId group:(AVGroup*)group{

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:@"text" forKey:@"type"];
    [dict setObject:message forKey:@"message"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVMessage *messageObject = [AVMessage messageForPeerWithSession:_session toPeerId:peerId payload:payload];
    [_session sendMessage:messageObject];
    
    NSString* type=@"text";
    [self insertMessageToDBAndNotify:peerId type:type message:message];
}


- (void)sendAttachment:(AVFile *)object type:(NSString*)type toPeerId:(NSString *)peerId {
//    AVFile *file = [object objectForKey:type];
    
    NSDictionary *dict=[self createMsgDict:_session.peerId type:type message:object.objectId];
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVMessage *messageObject = [AVMessage messageForPeerWithSession:_session toPeerId:peerId payload:payload];
    [_session sendMessage:messageObject];
    //    [_session sendMessage:payload isTransient:NO toPeerIds:@[peerId]];
    [self insertMessageToDBAndNotify:peerId type:type message:object.objectId];
}

- (void )insertMessageToDBAndNotify:(NSString *)targetId type:(NSString *)type message:(NSString *)message {
    NSDictionary *msgDict=[self insertSendMessageToDB:targetId type:type message:	message];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:msgDict];
}

- (void)sendMessage:(NSString *)message toGroup:(NSString *)groupId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:@"text" forKey:@"type"];
    [dict setObject:message forKey:@"message"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
    AVMessage *messageObject = [AVMessage messageForGroup:group payload:payload];
    [group sendMessage:messageObject];

    [self insertMessageToDBAndNotify:groupId type:@"text" message:message];
}

- (NSDictionary*)createMsgDict:(NSString*)dn type:(NSString*)type message:(NSString*)message{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:dn forKey:@"dn"];
    [dict setObject:type forKey:@"type"];
    [dict setObject:message forKey:@"message"];
    return dict;
}

- (void)sendAttachment:(AVFile *)object type:(NSString*)type toGroup:(NSString *)groupId {
    NSDictionary *dict=[self createMsgDict:_session.peerId type:type message:object.objectId];
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
    AVMessage *messageObject = [AVMessage messageForGroup:group payload:payload];
    [group sendMessage:messageObject];
    
    [self insertMessageToDBAndNotify:groupId type:type message:object.objectId];

}

- (NSArray *)getMessagesForPeerId:(NSString *)peerId {
    NSString *selfId = _session.peerId;
    FMResultSet *rs = [_database executeQuery:@"select * from messages where (fromid=? and toid=?) or (fromid=? and toid=?)" withArgumentsInArray:@[selfId, peerId, peerId, selfId]];
    return [self getMsgsByResultSet:rs];
}

-(Msg* )getMsgByResultSet:(FMResultSet*)rs{
    NSString *fromid = [rs stringForColumn:FROM_PEER_ID];
    NSString *toid = [rs stringForColumn:TO_PEER_ID];
    NSString *convid=[rs stringForColumn:CONV_ID];
    NSString *objectId=[rs stringForColumn:OBJECT_ID];
    NSString* timestampText = [rs stringForColumn:TIMESTAMP];
    int64_t timestamp=[timestampText longLongValue];
    NSString* content=[rs stringForColumn:CONTENT];
    CDMsgRoomType roomType=[rs intForColumn:ROOM_TYPE];
    int type=[rs intForColumn:TYPE];
    int status=[rs intForColumn:STATUS];
    
    Msg* msg=[Msg createMsg:objectId fromPeerId:fromid toPeerId:toid timestamp:timestamp content:content type:type status:status roomType:roomType convid:convid];
    return msg;
}

-(NSArray*)getMsgsByResultSet:(FMResultSet*)rs{
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next]) {
        Msg *msg=[self getMsgByResultSet :rs];
        [result addObject:msg];
    }
    return result;
}

- (NSArray *)getMessagesForGroup:(NSString *)groupId {
    FMResultSet *rs = [_database executeQuery:@"select fromid, toid, type, message,  time from messages where toid=?" withArgumentsInArray:@[groupId]];
    return [self getMsgsByResultSet:rs];
}

- (void)getHistoryMessagesForPeerId:(NSString *)peerId callback:(AVArrayResultBlock)callback {
    AVHistoryMessageQuery *query = [AVHistoryMessageQuery queryWithFirstPeerId:_session.peerId secondPeerId:peerId];
    [query findInBackgroundWithCallback:^(NSArray *objects, NSError *error) {
        callback(objects, error);
    }];
}

- (void)getHistoryMessagesForGroup:(NSString *)groupId callback:(AVArrayResultBlock)callback {
    AVHistoryMessageQuery *query = [AVHistoryMessageQuery queryWithGroupId:groupId];
    [query findInBackgroundWithCallback:^(NSArray *objects, NSError *error) {
        callback(objects, error);
    }];
}
#pragma mark - AVSessionDelegate
- (void)sessionOpened:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.peerId);
}

- (void)sessionPaused:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.peerId);
}

- (void)sessionResumed:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.peerId);
}

-(void)dealReceiveMessage:(AVMessage*)avMsg group:(AVGroup*)group{
    
}

- (void)session:(AVSession *)session didReceiveMessage:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ fromPeerId:%@", session.peerId, message, message.fromPeerId);
    NSError *error;
    NSData *data = [message.payload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    NSString *type = [jsonDict objectForKey:@"type"];
    NSString *msg = [jsonDict objectForKey:@"message"];
    NSDictionary *dict=[self insertMessageToDB:message.fromPeerId toId:session.peerId type:type timestamp:@(message.timestamp/1000) message:msg];
    
    BOOL exist = [self existsInChatRooms:CDMsgRoomTypeSingle targetId:message.fromPeerId];
    if (!exist) {
        [self addChatWithPeerId:message.fromPeerId];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:session userInfo:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:session userInfo:dict];
    //    NSError *error;
    //    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    //    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    //
    //    if (error == nil) {
    //        KAMessage *chatMessage = nil;
    //        if ([jsonDict objectForKey:@"st"]) {
    //            NSString *displayName = [jsonDict objectForKey:@"dn"];
    //            NSString *status = [jsonDict objectForKey:@"st"];
    //            if ([status isEqualToString:@"on"]) {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:@"上线了" fromMe:YES];
    //            } else {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:@"下线了" fromMe:YES];
    //            }
    //            chatMessage.isStatus = YES;
    //        } else {
    //            NSString *displayName = [jsonDict objectForKey:@"dn"];
    //            NSString *message = [jsonDict objectForKey:@"msg"];
    //            if ([displayName isEqualToString:MY_NAME]) {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:message fromMe:YES];
    //            } else {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:message fromMe:NO];
    //            }
    //        }
    //
    //        if (chatMessage) {
    //            [_messages addObject:chatMessage];
    //            //            [self.tableView beginUpdates];
    //            [self.tableView reloadData];
    //            //            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    //            [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
    //            //            [self.tableView endUpdates];
    //        }
    //    }
}

- (void)session:(AVSession *)session messageSendFailed:(AVMessage *)message error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ toPeerId:%@ error:%@", session.peerId, message, message.toPeerId, error);
}

- (void)session:(AVSession *)session messageSendFinished:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ toPeerId:%@", session.peerId, message, message.toPeerId);
}

- (void)session:(AVSession *)session didReceiveStatus:(AVPeerStatus)status peerIds:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ peerIds:%@ status:%@", session.peerId, peerIds, status==AVPeerStatusOffline?@"offline":@"online");
}

- (void)sessionFailed:(AVSession *)session error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ error:%@", session.peerId, error);
}

#pragma mark - AVGroupDelegate
- (void)group:(AVGroup *)group didReceiveMessage:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ fromPeerId:%@", group.groupId, message, message.fromPeerId);
    NSError *error;
    NSData *data = [message.payload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    
    NSString *type = [jsonDict objectForKey:@"type"];
    NSString *msg = [jsonDict objectForKey:@"message"];
    NSDictionary *dict=[self insertMessageToDB:message.fromPeerId toId:group.groupId type:type timestamp:@(message.timestamp/1000) message:msg];
    
    BOOL exist = [self existsInChatRooms:CDMsgRoomTypeGroup targetId:group.groupId];
    if (!exist) {
        [self joinGroup:group.groupId];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:group.session userInfo:dict];
}

- (void)group:(AVGroup *)group didReceiveEvent:(AVGroupEvent)event peerIds:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ event:%u peerIds:%@", group.groupId, event, peerIds);
}

- (void)group:(AVGroup *)group messageSendFinished:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@", group.groupId, message.payload);

}

- (void)group:(AVGroup *)group messageSendFailed:(AVMessage *)message error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ error:%@", group.groupId, message.payload, error);

}

- (void)session:(AVSession *)session group:(AVGroup *)group messageSent:(NSString *)message success:(BOOL)success {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ success:%d", group.groupId, message, success);
}

#pragma end of interface

- (void)registerUsers:(NSArray*)users{
    for(int i=0;i<users.count;i++){
        [self registerUser:[users objectAtIndex:i]];
    }
}

-(void) registerUser:(User*)user{
    [_cachedUsers setValue:user forKey:user.objectId];
}

-(User *)lookupUser:(NSString*)userId{
    return [_cachedUsers valueForKey:userId];
}

@end
