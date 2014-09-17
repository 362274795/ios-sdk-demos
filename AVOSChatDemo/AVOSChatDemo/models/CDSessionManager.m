//
//  CDSessionManager.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/29/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDSessionManager.h"
#import "FMDB.h"
#import "CDCommon.h"

@interface CDSessionManager () {
    FMDatabase *_database;
    AVSession *_session;
    NSMutableArray *_chatRooms;
}

@end

static id instance = nil;
static BOOL initialized = NO;

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

- (void)commonInit {
    if (![_database tableExists:@"messages"]) {
        [_database executeUpdate:@"create table \"messages\" (\"fromid\" text, \"toid\" text, \"message\" text, \"time\" integer)"];
    }
    if (![_database tableExists:@"sessions"]) {
        [_database executeUpdate:@"create table \"sessions\" (\"type\" integer, \"otherid\" text)"];
    }
    [_session openWithPeerId:[AVUser currentUser].username];

    FMResultSet *rs = [_database executeQuery:@"select \"type\", \"otherid\" from \"sessions\""];
    NSMutableArray *peerIds = [[NSMutableArray alloc] init];
    while ([rs next]) {
        NSInteger type = [rs intForColumn:@"type"];
        NSString *otherid = [rs stringForColumn:@"otherid"];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:type] forKey:@"type"];
        [dict setObject:otherid forKey:@"otherid"];
        if (type == CDChatRoomTypeSingle) {
            [peerIds addObject:otherid];
        } else if (type == CDChatRoomTypeGroup) {
            [dict setObject:[NSNumber numberWithInteger:type] forKey:@"type"];
            [dict setObject:otherid forKey:@"otherid"];
            
            AVGroup *group = [AVGroup getGroupWithGroupId:otherid session:_session];
            group.delegate = self;
            [group join];
        }
        [_chatRooms addObject:dict];
    }
    [_session watchPeerIds:peerIds];
    initialized = YES;
}

- (void)clearData {
    [_database executeUpdate:@"DROP TABLE IF EXISTS messages"];
    [_database executeUpdate:@"DROP TABLE IF EXISTS sessions"];
    [_chatRooms removeAllObjects];
    [_session close];
    initialized = NO;
}

- (NSArray *)chatRooms {
    return _chatRooms;
}
- (void)addChatWithPeerId:(NSString *)peerId {
    BOOL exist = NO;
    for (NSDictionary *dict in _chatRooms) {
        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
        NSString *otherid = [dict objectForKey:@"otherid"];
        if (type == CDChatRoomTypeSingle && [peerId isEqualToString:otherid]) {
            exist = YES;
            break;
        }
    }
    if (!exist) {
        [_session watchPeerIds:@[peerId]];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeSingle] forKey:@"type"];
        [dict setObject:peerId forKey:@"otherid"];
        [_chatRooms addObject:dict];
        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeSingle], peerId]];
    }
}

- (AVGroup *)joinGroup:(NSString *)groupId {
    BOOL exist = NO;
    for (NSDictionary *dict in _chatRooms) {
        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
        NSString *otherid = [dict objectForKey:@"otherid"];
        if (type == CDChatRoomTypeGroup && [groupId isEqualToString:otherid]) {
            exist = YES;
            break;
        }
    }
    if (!exist) {
        AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
        group.delegate = self;
        [group join];
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
        [dict setObject:groupId forKey:@"otherid"];
        [_chatRooms addObject:dict];
        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], groupId]];
    }
    return [AVGroup getGroupWithGroupId:groupId session:_session];;
}
- (void)startNewGroup:(AVGroupResultBlock)callback {
    [AVGroup createGroupWithSession:_session groupDelegate:self callback:^(AVGroup *group, NSError *error) {
        if (!error) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
            [dict setObject:group.groupId forKey:@"otherid"];
            [_chatRooms addObject:dict];
            [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], group.groupId]];
            if (callback) {
                callback(group, error);
            }
        } else {
            NSLog(@"error:%@", error);
        }
    }];
}

- (void)sendMessage:(NSString *)message toPeerId:(NSString *)peerId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:message forKey:@"msg"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVMessage *messageObject = [AVMessage messageForPeerWithSession:_session toPeerId:peerId payload:payload];
    [_session sendMessage:messageObject];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"fromid"];
    [dict setObject:peerId forKey:@"toid"];
    [dict setObject:message forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"message\", \"time\") values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];
    
}
- (void)sendMessage:(NSString *)message toGroup:(NSString *)groupId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:message forKey:@"msg"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
    AVMessage *messageObject = [AVMessage messageForGroup:group payload:payload];
    [group sendMessage:messageObject];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"fromid"];
    [dict setObject:groupId forKey:@"toid"];
    [dict setObject:message forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"message\", \"time\") values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];

}

- (NSArray *)getMessagesForPeerId:(NSString *)peerId {
    NSString *selfId = _session.peerId;
    FMResultSet *rs = [_database executeQuery:@"select \"fromid\", \"toid\", \"message\", \"time\" from \"messages\" where (\"fromid\"=? and \"toid\"=?) or (\"fromid\"=? and \"toid\"=?)" withArgumentsInArray:@[selfId, peerId, peerId, selfId]];
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next]) {
        NSString *fromid = [rs stringForColumn:@"fromid"];
        NSString *toid = [rs stringForColumn:@"toid"];
        NSString *message = [rs stringForColumn:@"message"];
        double time = [rs doubleForColumn:@"time"];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
        NSDictionary *dict = @{@"fromid":fromid, @"toid":toid, @"message":message, @"time":date};
        [result addObject:dict];
    }
    return result;
}

- (NSArray *)getMessagesForGroup:(NSString *)groupId {
    FMResultSet *rs = [_database executeQuery:@"select \"fromid\", \"toid\", \"message\", \"time\" from \"messages\" where \"toid\"=?" withArgumentsInArray:@[groupId]];
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next]) {
        NSString *fromid = [rs stringForColumn:@"fromid"];
        NSString *toid = [rs stringForColumn:@"toid"];
        NSString *message = [rs stringForColumn:@"message"];
        double time = [rs doubleForColumn:@"time"];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
        NSDictionary *dict = @{@"fromid":fromid, @"toid":toid, @"message":message, @"time":date};
        [result addObject:dict];
    }
    return result;
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

- (void)session:(AVSession *)session didReceiveMessage:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ fromPeerId:%@", session.peerId, message, message.fromPeerId);
    NSError *error;
    NSData *data = [message.payload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    NSString *msg = [jsonDict objectForKey:@"msg"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:message.fromPeerId forKey:@"fromid"];
    [dict setObject:session.peerId forKey:@"toid"];
    [dict setObject:msg forKey:@"message"];
    [dict setObject:@(message.timestamp/1000) forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    
    BOOL exist = NO;
    for (NSDictionary *dict in _chatRooms) {
        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
        NSString *otherid = [dict objectForKey:@"otherid"];
        if (type == CDChatRoomTypeSingle && [message.fromPeerId isEqualToString:otherid]) {
            exist = YES;
            break;
        }
    }
    if (!exist) {
        [self addChatWithPeerId:message.fromPeerId];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:session userInfo:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:session userInfo:dict];}

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
    NSString *msg = [jsonDict objectForKey:@"msg"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:message.fromPeerId forKey:@"fromid"];
    [dict setObject:group.groupId forKey:@"toid"];
    [dict setObject:msg forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    BOOL exist = NO;
    for (NSDictionary *dict in _chatRooms) {
        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
        NSString *otherid = [dict objectForKey:@"otherid"];
        if (type == CDChatRoomTypeGroup && [group.groupId isEqualToString:otherid]) {
            exist = YES;
            break;
        }
    }
    if (!exist) {
        [self joinGroup:group.groupId];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:group.session userInfo:dict];
}

- (void)group:(AVGroup *)group didReceiveEvent:(AVGroupEvent)event peerIds:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ event:%u peerIds:%@", group.groupId, event, peerIds);
    if (event == AVGroupEventSelfJoined) {
        BOOL exist = NO;
        for (NSDictionary *dict in _chatRooms) {
            CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
            NSString *otherid = [dict objectForKey:@"otherid"];
            if (type == CDChatRoomTypeGroup && [group.groupId isEqualToString:otherid]) {
                exist = YES;
                break;
            }
        }
        if (!exist) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
            [dict setObject:group.groupId forKey:@"otherid"];
            [_chatRooms addObject:dict];
            [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], group.groupId]];
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];
        }
    }
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

@end
