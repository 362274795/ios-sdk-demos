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

-(NSDictionary*)toMessagePayloadDict{
    return @{OBJECT_ID:_objectId,CONTENT:_content,
      STATUS:@(_status),TYPE:@(_type),
             ROOM_TYPE:@(_roomType),CONV_ID:_convid};
}

-(NSDictionary*)toDatabaseDict{
    NSDictionary *dict=[self toMessagePayloadDict];
    [dict setValue:[[NSNumber numberWithLongLong:_timestamp] stringValue] forKey:TIMESTAMP];
    [dict setValue:_fromPeerId forKey:FROM_PEER_ID];
    [dict setValue:_toPeerId forKey:TO_PEER_ID];
    NSString* curUserId=[User curUserId];
    [dict setValue:curUserId forKey:OWNER_ID];
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
    if(_roomType){
        if([curUserId isEqualToString:_fromPeerId]){
            return _toPeerId;
        }else{
            return _fromPeerId;
        }
    }else{
        return _toPeerId;
    }
}

+(Msg*)createMsg:(NSString*) objectId fromPeerId:(NSString*)fromPeerId toPeerId:(NSString*)toPeerId timestamp:(int64_t)timestamp content:(NSString*)content type:(CDMsgType)type status:(CDMsgStatus)status roomType:(CDMsgRoomType)roomType convid:(NSString*)convid{
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
    return [self createMsg:dict[@"objectId"] fromPeerId:avMsg.fromPeerId toPeerId:avMsg.toPeerId timestamp:avMsg.timestamp content:dict[@"content"]
                      type:(int)dict[@"type"]
                      status:(int)dict[@"status"] roomType:(int)dict[@"roomType"] convid:dict[@"convid"]];
}

@end
