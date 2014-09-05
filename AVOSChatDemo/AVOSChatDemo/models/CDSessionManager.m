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
//    NSMutableArray *_sessions;
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
//+ (id)allocWithZone:(NSZone *)zone {
//    return [self sharedInstance];
//}

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
    [_session open:[AVUser currentUser].username withPeerIds:nil];

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
            
            AVGroup *group = [_session getGroup:otherid];
            group.delegate = self;
            [group join];
        }
        [_chatRooms addObject:dict];
    }
    [_session watchPeers:peerIds];
    initialized = YES;
}

//- (void)addSession:(AVSession *)session {
//    BOOL hadSession = NO;
//    for (AVSession *s in _sessions) {
//        if ([session isGroupSession]) {
//            if ([s isGroupSession] && [session group].groupId && [[session group].groupId isEqualToString:[s group].groupId]) {
//                hadSession = YES;
//                break;
//            }
//        } else {
//            if (![s isGroupSession] && [[[session getAllPeers] firstObject] isEqual:[[s getAllPeers] firstObject]]) {
//                hadSession = YES;
//                break;
//            }
//        }
//    }
//    if (!hadSession) {
//        NSString *otherId = nil;
//        CDSessionType type = 0;
//        if ([session isGroupSession]) {
//            otherId = [session group].groupId;
//            type = CDSessionTypeGroup;
//        } else {
//            otherId = [[session getAllPeers] firstObject];
//            type = CDSessionTypeNormal;
//        }
//        if (otherId) {
//        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:type], otherId]];
//        [_sessions addObject:session];
//        }
//    }
////    
////    if ([_sessions indexOfObject:session] == NSNotFound) {
////        [_sessions addObject:session];
////    }
//}
//
//- (NSArray *)sessions {
//    return _sessions;
//}


//- (void)sendWithSession:(AVSession *)session message:(NSString *)message {
//    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//    [dict setObject:session.getSelfPeerId forKey:@"dn"];
//    [dict setObject:message forKey:@"msg"];
//    NSError *error = nil;
//    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
//    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    if ([session group]) {
//        [[session group] sendMessage:payload isTransient:NO];
//    } else {
//        [session sendMessage:payload isTransient:NO toPeerIds:session.getAllPeers];
//    }
//    
//    dict = [NSMutableDictionary dictionary];
//    [dict setObject:session.getSelfPeerId forKey:@"fromid"];
//    if ([session group]) {
//        [dict setObject:[session group].groupId forKey:@"toid"];
//    } else {
//        NSArray *names = session.getAllPeers;
//        NSString *name = [names objectAtIndex:0];
//        [dict setObject:name forKey:@"toid"];
//    }
//    [dict setObject:message forKey:@"message"];
//    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
//    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"message\", \"time\") values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
//    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:session userInfo:dict];
//}

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
        [_session watchPeers:@[peerId]];
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
        AVGroup *group = [_session getGroup:groupId];
        group.delegate = self;
        [group join];
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
        [dict setObject:groupId forKey:@"otherid"];
        [_chatRooms addObject:dict];
        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], groupId]];
    }
    return [_session getGroup:groupId];
}
- (AVGroup *)startNewGroup {
    AVGroup *group = [_session getGroup:nil];
    group.delegate = self;
    [group join];
    return group;
}
- (void)sendMessage:(NSString *)message toPeerId:(NSString *)peerId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.getSelfPeerId forKey:@"dn"];
    [dict setObject:message forKey:@"msg"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [_session sendMessage:payload isTransient:NO toPeerIds:@[peerId]];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.getSelfPeerId forKey:@"fromid"];
    [dict setObject:peerId forKey:@"toid"];
    [dict setObject:message forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"message\", \"time\") values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];
    
}
- (void)sendMessage:(NSString *)message toGroup:(NSString *)groupId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.getSelfPeerId forKey:@"dn"];
    [dict setObject:message forKey:@"msg"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [[_session getGroup:groupId] sendMessage:payload isTransient:NO];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.getSelfPeerId forKey:@"fromid"];
    [dict setObject:groupId forKey:@"toid"];
    [dict setObject:message forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"message\", \"time\") values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];

}

- (NSArray *)getMessagesForPeerId:(NSString *)peerId {
    NSString *selfId = [_session getSelfPeerId];
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
- (void)onSessionOpen:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.getSelfPeerId);
}

- (void)onSessionPaused:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.getSelfPeerId);
}

- (void)onSessionResumed:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.getSelfPeerId);
}

- (void)onSessionMessage:(AVSession *)session message:(NSString *)message peerId:(NSString *)peerId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ peerId:%@", session.getSelfPeerId, message, peerId);
    NSError *error;
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    NSString *msg = [jsonDict objectForKey:@"msg"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:peerId forKey:@"fromid"];
    [dict setObject:session.getSelfPeerId forKey:@"toid"];
    [dict setObject:msg forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
    
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
        [self addChatWithPeerId:peerId];
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

- (void)onSessionMessageFailure:(AVSession *)session message:(NSString *)message toPeerIds:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ peerIds:%@", session.getSelfPeerId, message, peerIds);
}

- (void)onSessionMessageSent:(AVSession *)session message:(NSString *)message toPeerIds:(NSArray *)peerIds{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ peerIds:%@", session.getSelfPeerId, message, peerIds);
}

- (void)onSessionStatusOnline:(AVSession *)session peers:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ peerIds:%@", session.getSelfPeerId, peerIds);
}

- (void)onSessionStatusOffline:(AVSession *)session peers:(NSArray *)peerId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ peerIds:%@", session.getSelfPeerId, peerId);
}

- (void)onSessionError:(AVSession *)session withException:(NSException *)exception {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ exception:%@", session.getSelfPeerId, exception);
}

#pragma mark - AVGroupDelegate
- (void)session:(AVSession *)session group:(AVGroup *)group didReceiveGroupMessage:(NSString *)message fromPeerId:(NSString *)peerId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ peerId:%@", group.groupId, message, peerId);
    NSError *error;
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    NSString *msg = [jsonDict objectForKey:@"msg"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:peerId forKey:@"fromid"];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:session userInfo:nil];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:session userInfo:dict];
}

- (void)session:(AVSession *)session group:(AVGroup *)group didReceiveGroupEvent:(AVGroupEvent)event memberIds:(NSArray *)memberIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ event:%d memberIds:%@", group.groupId, event, memberIds);
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
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:session userInfo:nil];
        }
    }
}

- (void)session:(AVSession *)session group:(AVGroup *)group messageSent:(NSString *)message success:(BOOL)success {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ success:%d", group.groupId, message, success);
}
@end
