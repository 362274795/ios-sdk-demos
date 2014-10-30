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
#import "ChatRoom.h"
#import "Utils.h"

@interface CDSessionManager () {
    FMDatabase *_database;
    AVSession *_session;
    NSMutableArray *_chatRooms;
    NSMutableDictionary *_cachedUsers;
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
        _cachedUsers=[[NSMutableDictionary alloc] init];
        
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
    initialized = YES;
}

-(void)openSession{
    [_session openWithPeerId:[User curUserId]];
}

-(void)closeSession{
    [_session close];
}

-(void)cacheMsgs:(NSArray*)msgs callback:(AVArrayResultBlock)callback{
    NSMutableArray* uncacheUserIds=[[NSMutableArray alloc] init];
    for(Msg* msg in msgs){
        NSString* otherId=[msg getOtherId];
        if(msg.roomType==CDMsgRoomTypeSingle){
            if([self lookupUser:otherId]==nil){
                [uncacheUserIds addObject:otherId];
            }
        }
    }
    [UserService findUsers:uncacheUserIds callback:^(NSArray *objects, NSError *error) {
        if(objects){
            [self registerUsers:objects];
            callback(objects,error);
        }else{
            callback(objects,error);
        }
    }];
}

-(void)findConversations:(AVArrayResultBlock)callback{
    FMResultSet *rs = [_database executeQuery:@"select * from messages group by convid order by timestamp desc" ];
    NSArray *msgs=[self getMsgsByResultSet:rs];
    [self cacheMsgs:msgs callback:^(NSArray *objects, NSError *error) {
        if(error){
            callback(objects,error);
        }else{
            [_chatRooms removeAllObjects];
            for(Msg* msg in msgs){
                NSString* otherId=[msg getOtherId];
                ChatRoom* chatRoom=[[ChatRoom alloc] init];
                chatRoom.roomType=msg.roomType;
                if(msg.roomType==CDMsgRoomTypeSingle){
                    User* other=[self lookupUser:otherId];
                    chatRoom.chatUser=other;
                }else{
                    AVGroup *group = [AVGroup getGroupWithGroupId:otherId session:_session];
                    chatRoom.group=group;
                }
                [_chatRooms addObject:chatRoom];
            }
            callback(_chatRooms,error);
        }
    }];
}

- (void)clearData {
    //[_database executeUpdate:@"DROP TABLE IF EXISTS messages"];
    [_chatRooms removeAllObjects];
    [_session close];
    initialized = NO;
}

- (NSArray *)chatRooms {
    return _chatRooms;
}

- (void)watchPeerId:(NSString *)peerId {
    [_session watchPeerIds:@[peerId]];
}

-(void)unwatchPeerId:(NSString*)peerId{
    [_session unwatchPeerIds:@[peerId]];
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
    return [Utils md5:result];
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

+(NSString*)getConvid:(CDMsgRoomType)roomType otherId:(NSString*)otherId groupId:(NSString*)groupId{
    if(roomType==CDMsgRoomTypeSingle){
        NSString* curUserId=[User curUserId];
        return [CDSessionManager convid:curUserId otherId:otherId];
    }else{
        return groupId;
    }
}

-(Msg*)createAndSendMsg:(NSString*)objectId type:(CDMsgType)type content:(NSString*)content toPeerId:(NSString*)toPeerId group:(AVGroup*)group{
    Msg* msg=[[Msg alloc] init];
    msg.toPeerId=toPeerId;
    int64_t currentTime=[[NSDate date] timeIntervalSince1970]*1000;
    msg.timestamp=currentTime;
    //NSLog(@"%@",[[NSDate dateWithTimeIntervalSince1970:msg.timestamp/1000] description]);
    msg.content=content;
    NSString* curUserId=[User curUserId];
    msg.fromPeerId=curUserId;
    msg.status=CDMsgStatusSendStart;
    if(!group){
        msg.toPeerId=toPeerId;
        msg.roomType=CDMsgRoomTypeSingle;
    }else{
        msg.roomType=CDMsgRoomTypeGroup;
    }
    msg.convid=[CDSessionManager getConvid:msg.roomType otherId:msg.toPeerId groupId:group.groupId];
    msg.objectId=objectId;
    msg.type=type;
    return [self sendMsg:group msg:msg];
}

-(Msg*)createAndSendMsg:(CDMsgType)type content:(NSString*)content toPeerId:(NSString*)toPeerId group:(AVGroup*)group{
    return [self createAndSendMsg:[CDSessionManager uuid] type:type content:content toPeerId:toPeerId group:group];
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

- (void)sendMessage:(NSString *)content type:(CDMsgType)type toPeerId:(NSString *)toPeerId group:(AVGroup*)group{
    Msg* msg=[self createAndSendMsg:type content:content toPeerId:toPeerId group:group];
    [self insertMessageToDBAndNotify:msg];
}

- (void)sendMessage:(NSString*)objectId content:(NSString *)content type:(CDMsgType)type toPeerId:(NSString *)toPeerId group:(AVGroup*)group{
    Msg* msg=[self createAndSendMsg:objectId type:type content:content toPeerId:toPeerId group:group];
    [self insertMessageToDBAndNotify:msg];
}


+(NSString*)getFilesPath{
    NSString* appPath=[NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* filesPath=[appPath stringByAppendingString:@"/files/"];
    NSFileManager *fileMan=[NSFileManager defaultManager];
    NSError *error;
    BOOL isDir=YES;
    if([fileMan fileExistsAtPath:filesPath isDirectory:&isDir]==NO){
        [fileMan createDirectoryAtPath:filesPath withIntermediateDirectories:YES attributes:nil error:&error];
        if(error){
            [NSException raise:@"error when create dir" format:@"error"];
        }
    }
    return filesPath;
}

+(NSString*)getPathByObjectId:(NSString*)objectId{
    return [[self getFilesPath] stringByAppendingString:objectId];
}

- (void)sendAttachment:(NSString*)objectId type:(CDMsgType)type toPeerId:(NSString *)toPeerId group:(AVGroup*)group{
    NSString* path=[CDSessionManager getPathByObjectId:objectId];
    User* curUser=[User currentUser];
    double time=[[NSDate date] timeIntervalSince1970];
    NSMutableString *name=[[curUser username] mutableCopy];
    [name appendFormat:@"%f",time];
    AVFile *f=[AVFile fileWithName:name contentsAtPath:path];
    [f saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if(error){
            [Utils alert:[error localizedDescription]];
        }else{
            [self sendMessage:objectId content:f.url type:type toPeerId:toPeerId group:group];
        }
    }];
}

- (void )insertMessageToDBAndNotify:(Msg*)msg{
    [self insertMsgToDB:msg];
    [self postMessageUpdateNotify];
}

-(void)postMessageUpdateNotify{
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:nil];
}

- (NSMutableArray*)getMsgsForConvid:(NSString*)convid{
    FMResultSet * rs=[_database executeQuery:@"select * from messages where convid=? order by timestamp" withArgumentsInArray:@[convid]];
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
    CDMsgType type=[rs intForColumn:TYPE];
    CDMsgStatus status=[rs intForColumn:STATUS];
    
    Msg* msg=[Msg createMsg:objectId fromPeerId:fromid toPeerId:toid timestamp:timestamp content:content type:type status:status roomType:roomType convid:convid];
    return msg;
}

-(NSMutableArray*)getMsgsByResultSet:(FMResultSet*)rs{
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

-(void)sendResponseMsg:(Msg*)msg{
    Msg* resMsg=[[Msg alloc] init];
    resMsg.type=CDMsgTypeResponse;
    resMsg.toPeerId=msg.fromPeerId;
    resMsg.fromPeerId=[User curUserId];
    resMsg.convid=[CDSessionManager convid:msg.fromPeerId otherId:[User curUserId]];
    resMsg.roomType=CDMsgRoomTypeSingle;
    resMsg.status=CDMsgStatusSendStart;
    resMsg.content=[NSString stringWithFormat:@"%lld",msg.timestamp];
    resMsg.objectId=msg.objectId;
    [self sendMsg:nil msg:resMsg];
    NSLog(@"send response msg");
}

-(void)dealReceiveMessage:(AVMessage*)avMsg group:(AVGroup*)group{
    NSLog(@"%s",__PRETTY_FUNCTION__);
    NSLog(@"payload=%@",avMsg.payload);
    Msg* msg=[Msg fromAVMessage:avMsg];
    if(msg.type!=CDMsgTypeResponse){
        if(msg.roomType==CDMsgRoomTypeSingle){
            [self sendResponseMsg:msg];
        }
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if(msg.type==CDMsgTypeImage){
                NSString* path=[CDSessionManager getPathByObjectId:msg.objectId];
                NSFileManager* fileMan=[NSFileManager defaultManager];
                if([fileMan fileExistsAtPath:path]==NO){
                    NSData* data=[[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:msg.content]];
                    NSError* error;
                    [data writeToFile:path options:NSDataWritingAtomic error:&error];
                    if(error==nil){
                    }else{
                        NSLog(@"error when download file");
                        return ;
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self insertMessageToDBAndNotify:msg];
            });
        });
    }else{
        [self updateStatusAndTimestamp:msg];
        [self postMessageUpdateNotify];
    }
}

-(void)updateStatusAndTimestamp:(Msg*)msg{
    NSLog(@"%s",__PRETTY_FUNCTION__);
    [_database executeUpdate:@"update messages set status=?,timestamp=? where objectId=?" withArgumentsInArray:@[@(CDMsgStatusSendReceived),msg.content,msg.objectId]];
}

- (void)session:(AVSession *)session didReceiveMessage:(AVMessage *)message {
    [self dealReceiveMessage:message group:nil];
    
    //[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:session userInfo:nil];
    
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
    NSLog(@"session:%@ message:%@ toPeerId:%@", session.peerId, message.payload, message.toPeerId);
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
    [self dealReceiveMessage:message group:group];
    //[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];

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
    [_cachedUsers setObject:user forKey:user.objectId];
}

-(User *)lookupUser:(NSString*)userId{
    return [_cachedUsers valueForKey:userId];
}

-(NSString*)getPeerId:(User*)user{
    return user.objectId;
}

@end
