#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#import <ubidding_flutter/UBiddingFlutterPlugin.h>

// Example-only evidence capture. Never dismiss views, alter interactions or read
// advertising/web content. Bounded class/geometry metadata is returned on demand.
static NSDictionary *UBExampleRect(CGRect rect) {
  return @{
    @"x" : @(rect.origin.x),
    @"y" : @(rect.origin.y),
    @"width" : @(rect.size.width),
    @"height" : @(rect.size.height)
  };
}
static void UBExampleViews(UIView *view, UIWindow *window, NSUInteger depth, NSMutableArray *out) {
  if (!view || depth > 12 || out.count >= 200) return;
  [out addObject:@{
    @"class" : NSStringFromClass(view.class),
    @"depth" : @(depth),
    @"rectInWindow" : UBExampleRect([view convertRect:view.bounds toView:window]),
    @"hidden" : @(view.hidden),
    @"alpha" : @(view.alpha),
    @"interactionEnabled" : @(view.userInteractionEnabled)
  }];
  for (UIView *child in view.subviews) UBExampleViews(child, window, depth + 1, out);
}
static void UBExampleControllers(UIViewController *controller, NSMutableArray *out,
                                 NSUInteger depth) {
  if (!controller || depth > 12 || out.count >= 50) return;
  [out addObject:@{
    @"class" : NSStringFromClass(controller.class),
    @"beingPresented" : @(controller.isBeingPresented),
    @"beingDismissed" : @(controller.isBeingDismissed),
    @"transitionActive" : @(controller.transitionCoordinator != nil),
    @"transitionInteractive" : @(controller.transitionCoordinator.isInteractive),
    @"viewInWindow" : @(controller.viewIfLoaded.window != nil)
  }];
  for (UIViewController *child in controller.childViewControllers)
    UBExampleControllers(child, out, depth + 1);
  UBExampleControllers(controller.presentedViewController, out, depth + 1);
}
static NSDictionary *UBExamplePresentationSnapshot(void) {
  NSMutableArray *scenes = [NSMutableArray array];
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if (![scene isKindOfClass:UIWindowScene.class]) continue;
    NSMutableArray *windows = [NSMutableArray array];
    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      NSMutableArray *views = [NSMutableArray array], *controllers = [NSMutableArray array];
      UBExampleViews(window, window, 0, views);
      UBExampleControllers(window.rootViewController, controllers, 0);
      NSMutableArray *hits = [NSMutableArray array];
      for (NSNumber *fraction in @[ @0.25, @0.5, @0.75 ]) {
        CGPoint point = CGPointMake(CGRectGetWidth(window.bounds) * fraction.doubleValue,
                                    CGRectGetHeight(window.bounds) * 0.5);
        UIView *hit = [window hitTest:point withEvent:nil];
        [hits addObject:@{
          @"x" : @(point.x),
          @"y" : @(point.y),
          @"class" : hit ? NSStringFromClass(hit.class) : @"nil"
        }];
      }
      [windows addObject:@{
        @"class" : NSStringFromClass(window.class),
        @"key" : @(window.isKeyWindow),
        @"hidden" : @(window.hidden),
        @"alpha" : @(window.alpha),
        @"level" : @(window.windowLevel),
        @"frame" : UBExampleRect(window.frame),
        @"controllers" : controllers,
        @"views" : views,
        @"hitTests" : hits
      }];
    }
    [scenes addObject:@{@"activationState" : @(scene.activationState), @"windows" : windows}];
  }
  return @{
    @"timestamp" : @((int64_t)(NSDate.date.timeIntervalSince1970 * 1000)),
    @"systemVersion" : UIDevice.currentDevice.systemVersion,
    @"mainThread" : @(NSThread.isMainThread),
    @"scenes" : scenes
  };
}

@interface AppDelegate ()
@property(nonatomic, strong) FlutterMethodChannel *presentationDiagnostics;
@end

// Runtime-visible host UIView class resolved by bottomTemplate, never plugin-owned branding.
@interface UBExampleSplashBottomView : UILabel
@end
@implementation UBExampleSplashBottomView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.text = @"UBidding · 开发者自定义底部";
    self.textAlignment = NSTextAlignmentCenter;
    self.backgroundColor = UIColor.whiteColor;
    self.textColor = UIColor.darkGrayColor;
  }
  return self;
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)didInitializeImplicitFlutterEngine:(NSObject<FlutterImplicitEngineBridge> *)engineBridge {
  [GeneratedPluginRegistrant registerWithRegistry:engineBridge.pluginRegistry];
  NSObject<FlutterPluginRegistrar> *diagnostics =
      [engineBridge.pluginRegistry registrarForPlugin:@"UBiddingExampleDiagnostics"];
  self.presentationDiagnostics =
      [FlutterMethodChannel methodChannelWithName:@"ubidding_example/diagnostics"
                                  binaryMessenger:diagnostics.messenger];
  [self.presentationDiagnostics
      setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        if ([call.method isEqual:@"presentationSnapshot"])
          result(UBExamplePresentationSnapshot());
        else
          result(FlutterMethodNotImplemented);
      }];
  UBiddingFlutterPlugin *plugin =
      [engineBridge.pluginRegistry valuePublishedByPlugin:@"UBiddingFlutterPlugin"];
  [plugin
      registerSplashBottomViewFactory:^UIView *(UIViewController *presenter, NSString *requestId,
                                                NSString *slotId, CGSize windowSize) {
        UILabel *bottom = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, windowSize.width, 80)];
        bottom.text = @"UBidding · 开发者自定义底部";
        bottom.textAlignment = NSTextAlignmentCenter;
        bottom.backgroundColor = UIColor.whiteColor;
        bottom.textColor = UIColor.darkGrayColor;
        return bottom;
      }
                       withIdentifier:@"example_bottom"];
}

@end
