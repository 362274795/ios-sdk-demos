//
//  Msg.m
//  AVOSChatDemo
//
//  Created by lzw on 14/10/25.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "Msg.h"
#import "User.h"


@implementation Msg

@synthesize fromPeerId;
@synthesize toPeerId;
@synthesize timestamp;

@synthesize content;
@synthesize convid;
@synthesize objectId;

@synthesize type;
@synthesize roomType;
@synthesize status;

-(NSDictionary*)toMessagePayloadDict{
    if(convid==nil || content==nil || objectId==nil){
        [NSException raise:@"null pointer exception" format:nil];
    }
    return @{OBJECT_ID:objectId,CONTENT:content,
      STATUS:@(status),TYPE:@(type),
             ROOM_TYPE:@(roomType),CONV_ID:convid};
}

-(NSDictionary*)toDatabaseDict{
    NSMutableDictionary *dict=[[self toMessagePayloadDict] mutableCopy];
    [dict setValue:[[NSNumber numberWithLongLong:timestamp] stringValue] forKey:TIMESTAMP];
    [dict setValue:fromPeerId forKey:FROM_PEER_ID];
    [dict setValue:toPeerId forKey:TO_PEER_ID];
    NSString* curUserId=[User curUserId];
    [dict setValue:curUserId forKey:OWNER_ID];
    if(curUserId==nil || fromPeerId==nil){
        [NSException raise:@"fromPeerId or curUserId is null" format:nil];
    }
    return dict;
}

-(NSString *)toMessagePayload{
    NSDictionary* dict=[self toMessagePayloadDict];
    NSError* error=nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return payload;
}

-(NSString*)getOtherId{
    NSString* curUserId=[User curUserId];
    if(roomType==CDMsgRoomTypeSingle){
        if([curUserId isEqualToString:fromPeerId]){
            return toPeerId;
        }else{
            return fromPeerId;
        }
    }else{
        return convid; // groupId
    }
}


+(Msg*)createMsg:(NSString*) objectId fromPeerId:(NSString*)fromPeerId toPeerId:(NSString*)toPeerId timestamp:(int64_t)timestamp content:(NSString*)content type:(CDMsgType)type status:(CDMsgStatus)status roomType:(CDMsgRoomType)roomType convid:(NSString*)convid{
    if(fromPeerId==nil || convid==nil || objectId==nil){
        [NSException raise:@"null pointer exception" format:nil];
    }
    if(roomType==CDMsgRoomTypeSingle && toPeerId==nil){
        [NSException raise:@"null pointer exception" format:nil];
    }
    
    //NSLog(@"%d %d %d",status,roomType,type);
    
    Msg* msg=[[Msg alloc] init];
    msg.timestamp=timestamp;
    msg.fromPeerId=fromPeerId;
    msg.toPeerId=toPeerId;
    msg.objectId=objectId;
    msg.content=content;
    msg.status=status;
    msg.type=type;
    msg.roomType=roomType;
    msg.convid=convid;
    return msg;
}

+(Msg*)fromAVMessage:(AVMessage *)avMsg{
    NSString *payload=[avMsg payload];
    NSData *data=[payload dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error=nil;
    NSDictionary *dict=[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if(error){
        [NSException raise:@"json deserialize error" format:nil];
    }
    int typeValue=[dict[@"type"] intValue];
    int statusValue=[dict[@"status"] intValue];
    int roomTypeValue=[dict[@"roomType"] intValue];
    return [self createMsg:dict[@"objectId"] fromPeerId:avMsg.fromPeerId toPeerId:avMsg.toPeerId timestamp:avMsg.timestamp content:dict[@"content"]
                      type:(CDMsgType)typeValue
                      status:(CDMsgStatus)statusValue roomType:roomTypeValue convid:dict[@"convid"]];
}

-(NSDate*)getTimestampDate{
    return [NSDate dateWithTimeIntervalSince1970:timestamp/1000];
}

-(NSString*)getStatusDesc{
    switch (status) {
        case CDMsgStatusSendStart:
            return @"发送中";
        case CDMsgStatusSendFailed:
            return @"发送失败";
        case CDMsgStatusSendReceived:
            return @"";
        case CDMsgStatusSendSucceed:
            return @"已发送";
    }
    [NSException raise:@"invalid status" format:nil];
}

-(BOOL)fromMe{
    User* curUser=[User currentUser];
    assert(curUser!=nil);
    return [fromPeerId isEqualToString:curUser.objectId];
}

@end
