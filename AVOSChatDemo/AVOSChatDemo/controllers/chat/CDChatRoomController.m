//
//  CDChatRoomController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatRoomController.h"
#import "CDSessionManager.h"
#import "CDChatDetailController.h"
#import "QBImagePickerController.h"
#import "UIImage+Resize.h"
#import "Utils.h"

@interface CDChatRoomController () <JSMessagesViewDelegate, JSMessagesViewDataSource, QBImagePickerControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate> {
    NSMutableDictionary *_loadedData;
    CDSessionManager* sessionManager;
}
@property (nonatomic, strong) NSArray *messages;
@end

@implementation CDChatRoomController

- (instancetype)init {
    if ((self = [super init])) {
        self.hidesBottomBarWhenPushed = YES;
        _loadedData = [[NSMutableDictionary alloc] init];
        sessionManager=[CDSessionManager sharedInstance];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.type == CDMsgRoomTypeGroup) {
        NSString *title = @"group";
        if (self.group.groupId) {
            title = [NSString stringWithFormat:@"group:%@", self.group.groupId];
        }
        self.title = title;
    } else {
        self.title = self.chatUser.username;
        [sessionManager watchPeerId:self.chatUser.objectId];
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showDetail:)];
    self.delegate = self;
    self.dataSource = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdated:) name:NOTIFICATION_MESSAGE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionUpdated:) name:NOTIFICATION_SESSION_UPDATED object:nil];
    [self messageUpdated:nil];
//    [AVAnalytics event:@"likebutton" attributes:@{@"source":@{@"view": @"week"}, @"do":@"unfollow"}];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(self.type==CDMsgRoomTypeSingle){
        [sessionManager unwatchPeerId:self.chatUser.objectId];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showDetail:(id)sender {
    CDChatDetailController *controller = [[CDChatDetailController alloc] init];
    controller.type = self.type;
    if (self.type == CDMsgRoomTypeSingle) {
        controller.otherId = self.chatUser.objectId;
    } else if (self.type == CDMsgRoomTypeGroup) {
        controller.otherId = self.group.groupId;
    }
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

#pragma mark - Messages view delegate
- (void)sendPressed:(UIButton *)sender withText:(NSString *)text {
    [sessionManager sendMessage:text type:CDMsgTypeText
                       toPeerId:self.chatUser.objectId group:self.group];
    [self finishSend];
}

- (void)sendAttachment:(NSString *)objectId{
    [sessionManager sendAttachment:objectId type:CDMsgTypeImage toPeerId:self.chatUser.objectId group:self.group];
    [self finishSend];
}

- (void)cameraPressed:(id)sender{
    [self.inputToolBarView.textView resignFirstResponder];
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍照",@"相册", nil];
    [actionSheet showInView:self.view];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    Msg* msg=[self.messages objectAtIndex:indexPath.row];
    NSString *fromPeerId=msg.fromPeerId;
    return (![fromPeerId isEqualToString:[User curUserId]]) ? JSBubbleMessageTypeIncoming : JSBubbleMessageTypeOutgoing;
}

- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return JSBubbleMessageStyleFlat;
}

- (JSBubbleMediaType)messageMediaTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    Msg* msg=[self.messages objectAtIndex:indexPath.row];
    CDMsgType type = msg.type;
    if (type ==CDMsgTypeText) {
        return JSBubbleMediaTypeText;
    } else if (type==CDMsgTypeImage) {
        return JSBubbleMediaTypeImage;
    }
    return JSBubbleMediaTypeText;

//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//        return JSBubbleMediaTypeText;
//    }else if ([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//        return JSBubbleMediaTypeImage;
//    }
//    
//    return -1;
}

- (UIButton *)sendButton
{
    return [UIButton defaultSendButton];
}

- (JSMessagesViewTimestampPolicy)timestampPolicy
{
    /*
     JSMessagesViewTimestampPolicyAll = 0,
     JSMessagesViewTimestampPolicyAlternating,
     JSMessagesViewTimestampPolicyEveryThree,
     JSMessagesViewTimestampPolicyEveryFive,
     JSMessagesViewTimestampPolicyCustom
     */
    return JSMessagesViewTimestampPolicyCustom;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy
{
    /*
     JSMessagesViewAvatarPolicyIncomingOnly = 0,
     JSMessagesViewAvatarPolicyBoth,
     JSMessagesViewAvatarPolicyNone
     */
    return JSMessagesViewAvatarPolicyNone;
}

- (JSAvatarStyle)avatarStyle
{
    /*
     JSAvatarStyleCircle = 0,
     JSAvatarStyleSquare,
     JSAvatarStyleNone
     */
    return JSAvatarStyleNone;
}

- (JSInputBarStyle)inputBarStyle
{
    /*
     JSInputBarStyleDefault,
     JSInputBarStyleFlat
     
     */
    return JSInputBarStyleFlat;
}

//  Optional delegate method
//  Required if using `JSMessagesViewTimestampPolicyCustom`
//
- (BOOL)hasTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row==0){
        return YES;
    }else{
        Msg* msg=[self.messages objectAtIndex:indexPath.row];
        Msg* lastMsg=[self.messages objectAtIndex:indexPath.row-1];
        int interval=[[msg getTimestampDate] timeIntervalSinceDate:[lastMsg getTimestampDate]];
        if(interval>60*5){
            return YES;
        }else{
            return NO;
        }
    }
}

- (BOOL)hasNameForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.type == CDMsgRoomTypeGroup) {
        return YES;
    }
    return NO;
}

#pragma mark - Messages view data source
- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"];
//    }
    Msg* msg=[self.messages objectAtIndex:indexPath.row];
    return msg.content;
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    Msg* msg=[self.messages objectAtIndex:indexPath.row];
    return [msg getTimestampDate];
}

- (NSString *)nameForRowAtIndexPath:(NSIndexPath *)indexPath {
    Msg *msg=[self.messages objectAtIndex:indexPath.row];
    User* user=[sessionManager lookupUser:msg.fromPeerId];
    return user.username;
}

- (UIImage *)avatarImageForIncomingMessage {
    return [UIImage imageNamed:@"demo-avatar-jobs"];
}

- (SEL)avatarImageForIncomingMessageAction {
    return @selector(onInComingAvatarImageClick);
}

- (void)onInComingAvatarImageClick {
    NSLog(@"__%s__",__func__);
}

- (SEL)avatarImageForOutgoingMessageAction {
    return @selector(onOutgoingAvatarImageClick);
}

- (void)onOutgoingAvatarImageClick {
    NSLog(@"__%s__",__func__);
}

- (UIImage *)avatarImageForOutgoingMessage
{
    return [UIImage imageNamed:@"demo-avatar-woz"];
}

- (id)dataForRowAtIndexPath:(NSIndexPath *)indexPath{
    Msg *msg=[self.messages objectAtIndex:indexPath.row];
    if(msg.type==CDMsgTypeText){
        //return nil;
    }
    UIImage* image = [_loadedData objectForKey:msg.objectId];
    if (image) {
        return image;
    } else {
        NSString* path=[CDSessionManager getPathByObjectId:msg.objectId];
        NSFileManager* fileMan=[NSFileManager defaultManager];
        NSLog(@"path=%@",path);
        if([fileMan fileExistsAtPath:path]){
            NSData* data=[fileMan contentsAtPath:path];
            UIImage* image=[UIImage imageWithData:data];
            [_loadedData setObject:image forKey:msg.objectId];
        }else{
            //[Utils alert:@"image file does not exist"];
            NSLog(@"does not exists image file");
        }
        return image;
    }
}

- (void)messageUpdated:(NSNotification *)notification {
    NSString* convid=[CDSessionManager getConvid:self.type otherId:self.chatUser.objectId groupId:self.group.groupId];
    NSArray *messages  = [sessionManager getMsgsForConvid:convid];
    self.messages = messages;
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)sessionUpdated:(NSNotification *)notification {
    if (self.type == CDMsgRoomTypeGroup) {
        NSString *title = @"group";
        if (self.group.groupId) {
            title = [NSString stringWithFormat:@"group:%@", self.group.groupId];
        }
        self.title = title;
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
        {
            @try {
                UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
                imagePickerController.delegate = self;
                imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
                [self presentViewController:imagePickerController animated:YES completion:^{
                    
                }];
            }
            @catch (NSException *exception) {
                
            }
            @finally {
                
            }
        }
            break;
        case 1:
        {
            QBImagePickerController *imagePickerController = [[QBImagePickerController alloc] init];
            imagePickerController.delegate = self;
            imagePickerController.allowsMultipleSelection = NO;
            //            imagePickerController.minimumNumberOfSelection = 3;
            
            //                [self.navigationController pushViewController:imagePickerController animated:YES];
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:imagePickerController];
            [self presentViewController:navigationController animated:YES completion:^{
                
            }];

        }
            break;
        default:
            break;
    }
}

- (void)dismissImagePickerController
{
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:NULL];
    } else {
        [self.navigationController popToViewController:self animated:YES];
    }
}

#pragma mark - QBImagePickerControllerDelegate

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAsset:(ALAsset *)asset
{
    NSLog(@"*** qb_imagePickerController:didSelectAsset:");
    NSLog(@"%@", asset);
    ALAssetRepresentation *representation = [asset defaultRepresentation];
    Byte *buffer = (Byte*)malloc((unsigned long)representation.size);
    
    // add error checking here
    NSUInteger buffered = [representation getBytes:buffer fromOffset:0.0 length:(NSUInteger)representation.size error:nil];
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
    if (data) {
        [self sendImage:data];
    }
    [self dismissImagePickerController];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets
{
    NSLog(@"*** qb_imagePickerController:didSelectAssets:");
    NSLog(@"%@", assets);
    
    [self dismissImagePickerController];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    NSLog(@"*** qb_imagePickerControllerDidCancel:");
    
    [self dismissImagePickerController];
}

-(void)sendImage:(NSData*)imageData{
    NSString* objectId=[CDSessionManager uuid];
    NSString* path=[CDSessionManager getPathByObjectId:objectId];
    NSError* error;
    [imageData writeToFile:path options:NSDataWritingAtomic error:&error];
    NSLog(@" save path=%@",path);
    if(error==nil){
        [self sendAttachment:objectId];
    }else{
        [Utils alert:@"write image to file error"];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!image) {
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    if (image) {
        UIImage *scaledImage = [image resizedImageToFitInSize:CGSizeMake(1080, 1920) scaleIfSmaller:NO];
        NSData *imageData = UIImageJPEGRepresentation(scaledImage, 0.6);
        [self sendImage:imageData];
    }
   [self dismissImagePickerController];
}
@end
