#import <UIKit/UIKit.h>

@interface ELMImageDownloader : NSObject

- (id)downloadImageWithURL:(NSURL *)url targetSize:(CGSize)size
	callbackQueue:(id)queue downloadProgress:(id)progress
	completion:(void(^)(UIImage *image, NSError *error, id arg3, id arg4))completion;
- (UIImage *)cachedImageWithURL:(NSURL *)url;

@end

@interface _ASCollectionViewCell : UICollectionViewCell
@end

@interface ASDisplayNode : NSObject
- (ASDisplayNode *)yogaParent;
- (NSArray<ASDisplayNode *> *)yogaChildren;
- (UIView *)view;
@end

@interface ASControlNode : ASDisplayNode
@end

@interface ASTextNode : ASControlNode
@property (copy) NSAttributedString *attributedText;
@end

@interface ELMTextNode : ASTextNode
@property (nonatomic, strong) NSNumber *DeArrow_userOverride;
@property (nonatomic, assign) BOOL DeArrow_override;
@property (nonatomic, strong) NSString *DeArrow_overrideTitle;
@property (nonatomic, strong) NSAttributedString *DeArrow_originalTitle;
- (void)DeArrow_handleLabelPress;
- (void)DeArrow_setupOverride;
@end

@interface _ASDisplayView : UIView
@property (nonatomic, assign) BOOL DeArrow_isVideoView;
@property (nonatomic, strong) ELMTextNode *DeArrow_titleNode;
@property (nonatomic, strong) _ASDisplayView *DeArrow_titleView;
- (ASDisplayNode *)keepalive_node;
- (BOOL)DeArrow_handleTap:(CGPoint)point;
@end

@interface ELMContainerNode : ASDisplayNode
@end

@interface ASImageNode : ASControlNode
@property (strong) UIImage *image;
@end

@interface ASNetworkImageNode : ASImageNode
- (void)_setImage:(UIImage *)image;
@end

@interface ELMImageNode : ASNetworkImageNode
@property (nonatomic, strong) ELMTextNode *DeArrow_titleNode;
- (void)imageNode:(id)node didLoadImage:(UIImage *)image;
@end

@interface NIAttributedLabel : UILabel
@end

@interface YTFormattedStringLabel : NIAttributedLabel
@property (nonatomic, strong) NSNumber *DeArrow_userOverride;
@property (nonatomic, assign) BOOL DeArrow_override;
@property (nonatomic, strong) NSString *DeArrow_overrideTitle;
@property (nonatomic, strong) NSAttributedString *DeArrow_originalTitle;
@property (nonatomic, strong) UITapGestureRecognizer *DeArrow_tapGesture;
@property (nonatomic, strong) NSString *DeArrow_debug;
- (void)DeArrow_handleLabelPress;
- (void)DeArrow_discover;
- (void)DeArrow_setupOverride;
@end

@interface YTImageView : UIView
- (id)delegate;
@end

@interface UIView(Private)
- (UIViewController *)_viewControllerForAncestor;
@end

@interface YTThumbnailController : NSObject
@property (nonatomic, strong) NSString *DeArrow_videoID;
@end

@interface YTVideoThumbnailView : UIView
@end

@interface YTPriorityThumbnailController : YTThumbnailController
@end

@interface YTIVideoDetails : NSObject
@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, copy) NSString *title;
@end