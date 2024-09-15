#import "PXLDeArrowBranding.h"

@implementation PXLDeArrowBranding

- (NSString *)description {
    return [NSString stringWithFormat:@"<PXLDeArrowBranding:%p "
        @"title=\"%@\" hasThumbnail=%@>", self, self.title,
        self.hasThumbnail ? @"true" : @"false"];
}

@end