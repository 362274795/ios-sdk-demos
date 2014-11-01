//
//  Msg.h
//  AVOSChatDemo
//
//  Created by lzw on 14/10/25.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVOSCloud/AVOSCloud.h>

typedef enum : NSUInteger {
    CDMsgRoomTypeSingle = 0,
    CDMsgRoomTypeGroup=1,
} CDMsgRoomType;

typedef enum : NSUInteger{
    CDMsgTypeText=0,
    CDMsgTypeResponse=1,
    CDMsgTypeImage=2,
    CDMsgTypeAudio=3,
    CDMsgTypeLocation=4,
}CDMsgType;

typedef enum : NSUInteger{
    CDMsgStatusSendStart=0,
    CDMsgStatusSendSucceed=1,
    CDMsgStatusSendReceived=2,
    CDMsgStatusSendFailed=3,
}CDMsgStatus;

#define OWNER_ID @"ownerId"
#define FROM_PEER_ID @"fromPeerId"
#define TO_PEER_ID @"toPeerId"
#define CONV_ID @"convid"
#define TYPE @"type"
#define CONTENT @"content"
#define TIMESTAMP @"timestamp"
#define OBJECT_ID @"objectId"
#define ROOM_TYPE @"roomType"
#define STATUS @"status"

@interface Msg : NSObject{
}
@property NSString* fromPeerId;
@property NSString* toPeerId;
@property int64_t timestamp;

@property NSString* content;
@property NSString* objectId;
@property NSString* convid;

@property CDMsgRoomType roomType;
@property CDMsgStatus status;
@property CDMsgType type;

+(Msg*)createMsg:(NSString*) objectId fromPeerId:(NSString*)fromPeerId toPeerId:(NSString*)toPeerId timestamp:(int64_t)timestamp content:(NSString*)content type:(CDMsgType)type status:(CDMsgStatus)status roomType:(CDMsgRoomType)roomType convid:(NSString*)convid;
+(Msg*)fromAVMessage:(AVMessage *)avMsg;
-(NSString *)toMessagePayload;
-(NSString*)getOtherId;
-(NSDictionary*)toDatabaseDict;
-(NSDate*)getTimestampDate;
-(NSString*)getStatusDesc;
-(BOOL)fromMe;

@end
