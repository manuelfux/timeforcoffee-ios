//
//  SKTMessage.h
//  SupportKit
//
//  Copyright (c) 2015 Radialpoint. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  @abstract Notification that is fired when a message fails to upload.
 */
extern NSString* const SKTMessageUploadFailedNotification;

/**
 *  @abstract Notification that is fired when a message uploads successfully.
 */
extern NSString* const SKTMessageUploadCompletedNotification;

/**
 *  @discussion Upload status of an SKTMessage.
 *
 *  @see SKTMessage
 */
typedef NS_ENUM(NSInteger, SKTMessageUploadStatus) {
    /**
     *  A user message that has not yet finished uploading.
     */
    SKTMessageUploadStatusUnsent,
    /**
     *  A user message that failed to upload.
     */
    SKTMessageUploadStatusFailed,
    /**
     *  A user message that was successfully uploaded.
     */
    SKTMessageUploadStatusSent,
    /**
     *  A message that did not originate from the current user.
     */
    SKTMessageUploadStatusNotUserMessage
};

@interface SKTMessage : NSObject

/**
 *  @abstract Create a message with the given text. The message will be owned by the current user.
 */
-(instancetype)initWithText:(NSString*)text;

/**
 *  @abstract The text content of the message.
 */
@property(readonly) NSString* text;

/**
 *  @abstract The name of the author. This property may be nil if no name could be determined.
 */
@property(readonly) NSString* name;

/**
 *  @abstract The url for the author's avatar image.
 */
@property(readonly) NSString* avatarUrl;

/**
 *  @abstract The date and time the message was sent.
 */
@property(readonly) NSDate *date;

/**
 *  @abstract Returns YES if the message was generated by a Whisper.
 */
@property(readonly) BOOL isWhisper;

/**
 *  @abstract Returns YES if the message originated from the user, or NO if the message comes from the app team.
 */
@property(readonly) BOOL isFromCurrentUser;

/**
 *  @abstract The upload status of the message.
 *
 *  @see SKTMessageStatus
 */
@property(readonly) SKTMessageUploadStatus uploadStatus;

@end
