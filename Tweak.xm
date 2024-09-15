#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "PXLDeArrow.h"
//#import "CTBlockDescription.h"
#import "YouTube.h"

#define NSLog(args...) NSLog(@"[DeArrow] " args)

static BOOL enableDeArrowThumbs = YES;

static NSURL *DeArrowThumbForVideoID(NSString *videoID) {
	return [NSURL URLWithString:[NSString stringWithFormat:
		@"https://dearrow-thumb.ajay.app/api/v1/getThumbnail?videoID=%@",
		videoID]];
}

static NSString *VideoIDFromYouTubeThumb(NSURL *url) {
	NSString *path = [url path];
	if ([path hasPrefix:@"/vi/"]) {
		NSArray *comps = [path componentsSeparatedByString:@"/"];
		if (comps.count >= 3) {
			NSString *videoID = comps[2];
			if ([videoID length] == 11) {
				return videoID;
			}
		}
	}
	return nil;
}

static NSString *VideoIDForUIImage(UIImage *image) {
	return objc_getAssociatedObject(image, (const void *)VideoIDForUIImage);
}

static void SetVideoIDForUIImage(UIImage *image, NSString *videoID) {
	objc_setAssociatedObject(image, (const void *)VideoIDForUIImage,
		videoID, OBJC_ASSOCIATION_RETAIN);
}

static __kindof id Find(NSArray *haystack, BOOL(^conditionBlock)(id object)) {
	id match = nil;
	for (id needle in haystack) {
		if (conditionBlock(needle)) {
			if (match != nil) {
				return nil;
			}
			match = needle;
		}
	}
	return match;
}

static NSArray<UIView *> *GetAllSubviews(UIView *view) {
	NSMutableArray *array = [view.subviews mutableCopy];
	for (UIView *subview in view.subviews) {
		[array addObjectsFromArray:GetAllSubviews(subview)];
	}
	return [array copy];
}

%hook UIImage

%new
- (NSString *)DeArrow_videoID {
	return VideoIDForUIImage(self);
}

%end

%hook ELMImageDownloader

- (id)downloadImageWithURL:(NSURL *)url targetSize:(CGSize)size
	callbackQueue:(id)queue downloadProgress:(id)progress
	completion:(void(^)(id imageContainer, NSError *error, id arg3, id arg4))completion
{
	// Check if this is a YouTube thumbnail URL
	NSString *videoID = VideoIDFromYouTubeThumb(url);
	if (videoID == nil) {
		return %orig;
	}

	// Fetch branding data for this video ID from DeArrow
	[[PXLDeArrow sharedInstance] fetchBrandingForVideoID:videoID
	completion:^(PXLDeArrowBranding *branding, NSError *error) {
		// "Hook" the completion handler.
		// Insert the video ID into the returned UIImage object.
		void(^orig)(UIImage *, NSError *, id, id) = completion;
		void(^hook)(UIImage *, NSError *, id, id) =
			^(UIImage *image, NSError *error, id arg3, id arg4) {
				if (image != nil) {
					SetVideoIDForUIImage(image, videoID);
				}
				orig(image, error, arg3, arg4);
			};
		
		// If DeArrow doesn't have a thumbnail, fetch the YouTube thumbnail
		if (!enableDeArrowThumbs || !branding.hasThumbnail) {
			%orig(url, size, queue, progress, hook);
			return;
		}

		// If DeArrow does have a thumbnail, fetch that
		NSURL *thumbURL = DeArrowThumbForVideoID(videoID);
		%orig(thumbURL, size, queue, progress, hook);
	}];

	//FIXME: Don't return null
	return nil;
}

- (UIImage *)cachedImageWithURL:(NSURL *)url {
	// Check if this is a YouTube thumbnail URL
	NSString *videoID = VideoIDFromYouTubeThumb(url);
	if (!enableDeArrowThumbs || videoID == nil) {
		return %orig;
	}

	// Get the DeArrow thumbnail URL and check if that is cached
	NSURL *dearrowThumbURL = DeArrowThumbForVideoID(videoID);
	UIImage *dearrowThumb = [self cachedImageWithURL:dearrowThumbURL];
	if (dearrowThumb != nil) {
		// It is cached, insert the video ID and return it
		SetVideoIDForUIImage(dearrowThumb, videoID);
		return dearrowThumb;
	}

	// Check if the YouTube thumbnail and check if that is cached
	UIImage *youtubeThumb = %orig;
	if (youtubeThumb != nil) {
		// It is cached, insert the video ID and return it
		SetVideoIDForUIImage(youtubeThumb, videoID);
		return youtubeThumb;
	}

	// The cache is empty
	return nil;
}

%end

// Copy paste of ELMTextNode hook
%hook YTFormattedStringLabel
%property (nonatomic, strong) NSNumber *DeArrow_userOverride;
%property (nonatomic, assign) BOOL DeArrow_override;
%property (nonatomic, strong) NSString *DeArrow_overrideTitle;
%property (nonatomic, strong) NSAttributedString *DeArrow_originalTitle;
%property (nonatomic, strong) UITapGestureRecognizer *DeArrow_tapGesture;

//FIXME: not called early enough
%new
- (void)DeArrow_discover {
	if ([self.accessibilityIdentifier isEqualToString:@"id.playlist.video.title.label"]) {
		UIView *subtitleView = nil;
		for (UIView *subview in self.superview.subviews) {
			if ([subview isKindOfClass:%c(YTSubtitleView)]) {
				subtitleView = subview;
				break;
			}
		}
		if (subtitleView != nil) {
			CGRect subtitleFrame = subtitleView.frame;
			CGRect titleFrame = self.frame;
			titleFrame.size.width = subtitleFrame.size.width;
			titleFrame.size.height = 40;
			self.frame = titleFrame;
			subtitleFrame.origin.y = titleFrame.origin.y + 40;
			subtitleView.frame = subtitleFrame;
		}
	}
	else if ([self.accessibilityIdentifier
		isEqualToString:@"id.upload_metadata_editor_title_field"])
	{
		if (self._viewControllerForAncestor == nil) {
			return;
		}
		UIViewController *watchViewController = self._viewControllerForAncestor
			.parentViewController.parentViewController.parentViewController;
		if (watchViewController != nil) {
			NSString *videoID = MSHookIvar<NSString *>(watchViewController, "_videoID");
			if (videoID != nil) {

			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"DeArrow"
				message:[NSString stringWithFormat:@"videoID: %@", videoID]
				preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"OK"
				style:UIAlertActionStyleCancel handler:nil];
			[alert addAction:cancelAction];
			[[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alert
				animated:YES completion:nil];
				PXLDeArrowBranding *branding = [[PXLDeArrow sharedInstance]
					cachedBrandingForVideoID:videoID];
				if (branding.title != nil) {
					NSString *newTitle = [NSString stringWithFormat:@"🧿 %@", branding.title];
					[self DeArrow_setupOverride];
					self.DeArrow_overrideTitle = newTitle;
					self.attributedText = nil;
				}
			}
		}
	}
}

- (void)didMoveToWindow {
	%orig;
	[self DeArrow_discover];
}

- (void)layoutSubviews {
	%orig;
	[self DeArrow_discover];
}

// When overrides are enabled, setting attributedText to null
// triggers a title update.
- (void)setAttributedText:(NSAttributedString *)arg1 {
	// Don't do anything if this text node isn't used by the tweak
	if (!self.DeArrow_override) {
		[self DeArrow_discover];
		%orig;
		return;
	}

	// Make sure the original title is always available
	if (arg1 != nil) {
		self.DeArrow_originalTitle = arg1;
	}
	else if (self.DeArrow_originalTitle == nil) {
		self.DeArrow_originalTitle = self.attributedText;
	}

	// Figure out what the new text will be
	NSString *text = nil;
	if (self.DeArrow_userOverride != nil) {
		// The user wants to override the text node value, probably
		// by tapping on the video title
		text = self.DeArrow_userOverride.boolValue ?
			self.DeArrow_overrideTitle :
			[self.DeArrow_originalTitle string];
	}
	if (text == nil) {
		if (self.DeArrow_overrideTitle != nil) {
			text = self.DeArrow_overrideTitle;
		}
		else {
			text = [self.DeArrow_originalTitle string];
		}
	}

	// Use attributes of the original title
	NSDictionary *attr;
	if (self.DeArrow_originalTitle.length > 0) {
		attr = [self.DeArrow_originalTitle attributesAtIndex:0
			effectiveRange:nil];
	}
	else {
		attr = @{};
	}

	if (text == nil) {
		%orig;
		return;
	}
	NSAttributedString *overrideText = [[NSAttributedString alloc]
		initWithString:text attributes:attr];
	%orig(overrideText);
}

%new
- (void)DeArrow_handleLabelPress {
	// Pressing the video title creates a user override
	if (self.DeArrow_userOverride == nil) {
		self.DeArrow_userOverride = @NO;
	}
	else {
		self.DeArrow_userOverride = @(!self.DeArrow_userOverride.boolValue);
	}
	self.attributedText = nil;
}

%new
- (void)DeArrow_setupOverride {
	self.DeArrow_override = YES;
	self.adjustsFontSizeToFitWidth = YES;
	self.minimumScaleFactor = 0.5;
	self.attributedText = nil;

	if (self.DeArrow_tapGesture == nil) {
		self.userInteractionEnabled = YES;
		self.DeArrow_tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
			action:@selector(DeArrow_handleLabelPress)];
		[self addGestureRecognizer:self.DeArrow_tapGesture];
	}
}

%end

%hook ELMTextNode
%property (nonatomic, strong) NSNumber *DeArrow_userOverride;
%property (nonatomic, assign) BOOL DeArrow_override;
%property (nonatomic, strong) NSString *DeArrow_overrideTitle;
%property (nonatomic, strong) NSAttributedString *DeArrow_originalTitle;

// When overrides are enabled, setting attributedText to null
// triggers a title update.
- (void)setAttributedText:(NSAttributedString *)arg1 {
	// Don't do anything if this text node isn't used by the tweak
	if (!self.DeArrow_override) {
		%orig;
		return;
	}

	// Make sure the original title is always available
	if (arg1 != nil) {
		self.DeArrow_originalTitle = arg1;
	}
	else if (self.DeArrow_originalTitle == nil) {
		self.DeArrow_originalTitle = self.attributedText;
	}

	// Figure out what the new text will be
	NSString *text = nil;
	if (self.DeArrow_userOverride != nil) {
		// The user wants to override the text node value, probably
		// by tapping on the video title
		text = self.DeArrow_userOverride.boolValue ?
			self.DeArrow_overrideTitle :
			[self.DeArrow_originalTitle string];
	}
	if (text == nil) {
		if (self.DeArrow_overrideTitle != nil) {
			text = self.DeArrow_overrideTitle;
		}
		else {
			text = [self.DeArrow_originalTitle string];
		}
	}

	// Use attributes of the original title
	NSDictionary *attr;
	if (self.DeArrow_originalTitle.length > 0) {
		attr = [self.DeArrow_originalTitle attributesAtIndex:0
			effectiveRange:nil] ?: @{};
	}
	else {
		attr = @{};
	}
	if (text == nil) {
		%orig;
		return;
	}
	NSAttributedString *overrideText = [[NSAttributedString alloc]
		initWithString:text attributes:attr];
	%orig(overrideText);
}

%new
- (void)DeArrow_handleLabelPress {
	// Pressing the video title creates a user override
	if (self.DeArrow_userOverride == nil) {
		self.DeArrow_userOverride = @NO;
	}
	else {
		self.DeArrow_userOverride = @(!self.DeArrow_userOverride.boolValue);
	}
	self.attributedText = nil;
}

%new
- (void)DeArrow_setupOverride {
	self.DeArrow_override = YES;
	self.attributedText = nil;
}

%end

%hook ELMImageNode
%property (nonatomic, strong) ELMTextNode *DeArrow_titleNode;

- (void)imageNode:(id)node didLoadImage:(UIImage *)image {
	if (image != nil) {
		ELMTextNode *titleNode = self.DeArrow_titleNode;
		if (titleNode != nil) {
			NSString *videoID = VideoIDForUIImage(image);
			PXLDeArrowBranding *branding = [[PXLDeArrow sharedInstance]
				cachedBrandingForVideoID:videoID];
			if (branding.title == nil) {
				titleNode.DeArrow_overrideTitle = nil;
			}
			else {
				titleNode.DeArrow_overrideTitle =
					[NSString stringWithFormat:@"🧿 %@", branding.title];
			}
			titleNode.attributedText = nil;
		}
	}
	%orig;
}

%end

%hook YTThumbnailController
%property (nonatomic, strong) NSString *DeArrow_videoID;

//FIXME: DeArrow cannot be loaded using this initializer
- (YTThumbnailController *)initWithImageView:(YTImageView *)imageView
	URLs:(NSDictionary *)URLs imageService:(id)imageService
{
	NSString *thumbVideoID = nil;
	for (NSValue *key in URLs) {
		NSURL *url = URLs[key];
		NSString *videoID = VideoIDFromYouTubeThumb(url);
		if (videoID != nil) {
			thumbVideoID = videoID;
		}
	}
	self.DeArrow_videoID = thumbVideoID;
	return %orig;
}

%end

%hook YTImageView

- (void)setImage:(UIImage *)image animated:(BOOL)animated {
	YTThumbnailController *controller = self.delegate;
	NSString *videoID;
	if ([controller isKindOfClass:%c(YTThumbnailController)] &&
		(videoID = controller.DeArrow_videoID) != nil)
	{
		UIView *container = self.superview.superview;
		YTFormattedStringLabel *label = nil;
		for (UIView *subview in container.subviews) {
			if ([subview.accessibilityIdentifier isEqualToString:@"id.playlist.video.title.label"]) {
				label = (id)subview;
				break;
			}
		}
		if (label != nil) {
			[label DeArrow_setupOverride];
			label.DeArrow_overrideTitle = @"🧿 ...";
			label.attributedText = nil;
			[[PXLDeArrow sharedInstance] fetchBrandingForVideoID:videoID completion:
				^(PXLDeArrowBranding *branding, NSError *error){
					if (branding.title == nil) {
						label.DeArrow_overrideTitle = nil;
						label.attributedText = nil;
					}
					else {
						NSString *newTitle = [NSString stringWithFormat:@"🧿 %@", branding.title];
						label.DeArrow_overrideTitle = newTitle;
						label.attributedText = nil;
					}
				}];
		}
	}
	%orig;
}

%end

%hook _ASDisplayView
%property (nonatomic, assign) BOOL DeArrow_isVideoView;
%property (nonatomic, strong) ELMTextNode *DeArrow_titleNode;
%property (nonatomic, strong) _ASDisplayView *DeArrow_titleView;

- (void)layoutSubviews {
	if ([self.accessibilityIdentifier isEqualToString:@"eml.overflow_button"]) {
		//NSArray *videoContainerIDs = @[ @"eml.cvr", @"eml.vwc" ];
		_ASDisplayView *videoContainer = (id)self.superview;
		NSArray<UIView *> *__block allSubviews = GetAllSubviews(self.superview);
		_ASDisplayView *__block titleView = nil, *__block timestampView = nil,
			*__block metadataView = nil, *__block thumbnailView = nil;
		BOOL(^findViews)() = ^BOOL() {
			timestampView = Find(allSubviews, ^BOOL(UIView *subview){
				return [subview.accessibilityIdentifier isEqualToString:@"eml.timestamp"];
			});
			thumbnailView = (id)timestampView.superview;
			if (![thumbnailView isKindOfClass:%c(_ASDisplayView)]) {
				return NO;
			}
			metadataView = Find(allSubviews, ^BOOL(UIView *subview){
				return [subview.accessibilityIdentifier isEqualToString:@"eml.metadata"];
			});
			titleView = (id)metadataView.subviews[0];
			if (![titleView isKindOfClass:%c(_ASDisplayView)]) {
				return NO;
			}
			return YES;
		};

		if (!findViews()) {
			videoContainer = (id)self.superview.superview;
			allSubviews = GetAllSubviews(self.superview.superview);
		}
		if (!findViews()) {
			return;
		}
		if (![videoContainer isKindOfClass:%c(_ASDisplayView)]) {
			return;
		}
		if (timestampView.keepalive_node.yogaChildren.count == 2) {
			// This is a playlist view
			return;
		}
		videoContainer.DeArrow_isVideoView = YES;

		// Configure nodes
		ELMImageNode *imageNode = (id)thumbnailView.keepalive_node.yogaChildren[0];
		ELMTextNode *titleNode = (id)titleView.keepalive_node.yogaChildren[0];
		titleNode.DeArrow_overrideTitle = @"🧿 ...";
		[titleNode DeArrow_setupOverride];
		imageNode.DeArrow_titleNode = titleNode;
		videoContainer.DeArrow_titleNode = titleNode;
		videoContainer.DeArrow_titleView = titleView;
	}
	%orig;
}

%new
- (BOOL)DeArrow_handleTap:(CGPoint)point {
	if (self.DeArrow_isVideoView) {
		_ASDisplayView *titleView = self.DeArrow_titleView;
		CGRect converted = [titleView convertRect:titleView.frame toView:self];
		if (CGRectContainsPoint(converted, point)) {
			[self.DeArrow_titleNode DeArrow_handleLabelPress];
			return YES;
		}
	}
	return NO;
}

%end

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
	UITapGestureRecognizer *gesture = MSHookIvar<id>(self, "_tapRecognizer");
	_ASDisplayView *view = (id)gesture.view;
	if ([view isKindOfClass:%c(_ASDisplayView)]) {
		CGPoint point = [gesture locationInView:view];
		if ([view DeArrow_handleTap:point]) {
			return;
		}
	}
	%orig;
}

%end