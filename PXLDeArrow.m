#import "PXLDeArrow.h"

/*
+ (void)sendAsynchronousRequest:(NSURLRequest *)request 
                          queue:(NSOperationQueue *)queue 
              completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))handler
*/

@implementation PXLDeArrow

#define kPXLDeArrowErrorDomain @"com.pixelomer.de-arrow/Error"
#define MAKE_ERROR(_code, msg) ([NSError errorWithDomain:kPXLDeArrowErrorDomain \
    code:(_code) userInfo:@{ NSLocalizedDescriptionKey: (msg) }])

- (PXLDeArrowBranding *)cachedBrandingForVideoID:(NSString *)videoID {
    return _cache[videoID];
}

+ (PXLDeArrow *)sharedInstance {
    static PXLDeArrow *instance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [PXLDeArrow new];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _cache = [NSMutableDictionary new];
    }
    return self;
}

- (void)fetchBrandingForVideoID:(NSString *)videoID
    completion:(void(^)(PXLDeArrowBranding *, NSError *))completion
{
    PXLDeArrowBranding *cachedBranding = [self cachedBrandingForVideoID:videoID];
    if (cachedBranding != nil) {
        completion(cachedBranding, nil);
        return;
    }
    NSString *urlStr = [NSString stringWithFormat:
        @"https://sponsor.ajay.app/api/branding?videoID=%@", videoID];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
        queue:[NSOperationQueue mainQueue]
        completionHandler:
    ^(NSURLResponse *_response, NSData *data, NSError *connectionError){
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)_response;
        if (response == nil || data == nil) {
            completion(nil, connectionError);
            return;
        }
        if (response.statusCode == 404) {
            completion(nil, nil);
            return;
        }
        if (response.statusCode != 200) {
            completion(nil, MAKE_ERROR(response.statusCode, @"HTTP request failed"));
            return;
        }
        NSError *jsonError = nil;
        NSDictionary<NSString *, NSArray<NSDictionary *> *> *root =
            [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            completion(nil, jsonError);
            return;
        }
        if (![root isKindOfClass:[NSDictionary class]]) {
            completion(nil, MAKE_ERROR(-1, @"Invalid root JSON object"));
            return;
        }
        PXLDeArrowBranding *branding = [PXLDeArrowBranding new];
        branding.videoID = videoID;
        NSArray<NSDictionary *> *thumbnails = root[@"thumbnails"];
        if ([thumbnails isKindOfClass:[NSArray class]] && thumbnails.count > 0) {
            branding.hasThumbnail = YES;
        }
        NSArray<NSDictionary *> *titles = root[@"titles"];
        if ([titles isKindOfClass:[NSArray class]] && titles.count > 0) {
            NSDictionary *titleData = titles[0];
            if ([titleData isKindOfClass:[NSDictionary class]]) {
                NSString *title = titleData[@"title"];
                if ([title isKindOfClass:[NSString class]]) {
                    branding.title = title;
                }
            }
        }
        _cache[videoID] = branding;
        completion(branding, nil);
    }];
}

@end