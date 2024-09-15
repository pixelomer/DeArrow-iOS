#import <Foundation/Foundation.h>
#import "PXLDeArrowBranding.h"

@interface PXLDeArrow : NSObject {
    NSMutableDictionary<NSString *, PXLDeArrowBranding *> *_cache;
}
+ (PXLDeArrow *)sharedInstance;
- (PXLDeArrowBranding *)cachedBrandingForVideoID:(NSString *)videoID;
- (void)fetchBrandingForVideoID:(NSString *)videoID
    completion:(void(^)(PXLDeArrowBranding *, NSError *))completion;
@end