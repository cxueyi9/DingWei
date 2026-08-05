#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== 存储工具 ==========
static NSUserDefaults *defaults() { return [NSUserDefaults standardUserDefaults]; }
static BOOL isEnabled() { return [defaults() boolForKey:@"enabled"]; }
static void setEnabled(BOOL on) {
    [defaults() setBool:on forKey:@"enabled"];
    [defaults() synchronize];
}
static CLLocationCoordinate2D currentCoordinate() {
    double lat = [defaults() doubleForKey:@"latitude"];
    double lon = [defaults() doubleForKey:@"longitude"];
    if (lat == 0 && lon == 0) { lat = 37.3349; lon = -122.0093; }
    return CLLocationCoordinate2DMake(lat, lon);
}
static void setCoordinate(CLLocationCoordinate2D coord) {
    [defaults() setDouble:coord.latitude forKey:@"latitude"];
    [defaults() setDouble:coord.longitude forKey:@"longitude"];
    [defaults() synchronize];
}
static void saveFavorites(NSArray *list) {
    [defaults() setObject:list forKey:@"favorites"];
    [defaults() synchronize];
}
static NSArray *loadFavorites() { return [defaults() objectForKey:@"favorites"] ?: @[]; }

// ========== 获取当前活跃 UIWindowScene ==========
static UIWindowScene * activeWindowScene(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

// ========== 设置界面控制器 ==========
@interface LFSettingsVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) void (^dismissBlock)(void);
@property (nonatomic, strong) UITextField *latField, *lonField;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UITableView *favoritesTable;
@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) UIView *contentView;
@end

@implementation LFSettingsVC
// ... 与之前完全相同，此处省略以节省篇幅，可直接复用上一版本的实现 ...
// 注意：需要在 close 方法里调用 dismissBlock，同时关闭设置窗口
@end

// ========== 悬浮按钮窗口 ==========
@interface FloatWindow : UIWindow
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, assign) BOOL isEditing;
@end

@implementation FloatWindow

- (instancetype)initWithFrame:(CGRect)frame scene:(UIWindowScene *)scene {
    if (self = [super initWithWindowScene:scene]) {
        self.frame = frame;
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [UIViewController new];
        self.rootViewController.view.backgroundColor = [UIColor clearColor];
        
        // 按钮视图
        UIView *btnView = [[UIView alloc] initWithFrame:self.bounds];
        btnView.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        btnView.layer.cornerRadius = frame.size.width / 2;
        btnView.clipsToBounds = YES;
        btnView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.rootViewController.view addSubview:btnView];
        
        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, frame.size.width, 30)];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.font = [UIFont boldSystemFontOfSize:20];
        _badgeLabel.text = @"📍";
        [btnView addSubview:_badgeLabel];
        
        // 拖拽手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btnView addGestureRecognizer:pan];
        // 长按手势
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.8;
        [btnView addGestureRecognizer:longPress];
        
        self.hidden = NO;
    }
    return self;
}

// 如果未使用 initWithWindowScene，兼容旧方式
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindowScene *scene = activeWindowScene();
    if (scene) {
        return [self initWithFrame:frame scene:scene];
    }
    // 无 scene 时用传统初始化
    if (self = [super initWithFrame:frame]) {
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor clearColor];
        // 同样添加视图...
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (self.isEditing) return;
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn];
    CGRect newFrame = self.frame;
    newFrame.origin.x += translation.x;
    newFrame.origin.y += translation.y;
    
    CGFloat margin = 10;
    newFrame.origin.x = MAX(margin, MIN(newFrame.origin.x, [UIScreen mainScreen].bounds.size.width - newFrame.size.width - margin));
    newFrame.origin.y = MAX(margin + 20, MIN(newFrame.origin.y, [UIScreen mainScreen].bounds.size.height - newFrame.size.height - margin - 20));
    
    self.frame = newFrame;
    [pan setTranslation:CGPointZero inView:btn];
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGPoint(self.frame.origin) forKey:@"floatPos"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan) {
        [self showSettingsPanel];
    }
}

static UIWindow *settingsWindow = nil;

- (void)showSettingsPanel {
    if (self.isEditing || settingsWindow) return;
    self.isEditing = YES;
    
    LFSettingsVC *vc = [[LFSettingsVC alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.dismissBlock = ^{
        weakSelf.isEditing = NO;
        settingsWindow.hidden = YES;
        settingsWindow = nil;
    };
    
    UIWindowScene *scene = activeWindowScene();
    UIWindow *window;
    if (scene) {
        window = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    window.frame = [UIScreen mainScreen].bounds;
    window.windowLevel = UIWindowLevelAlert + 2;
    window.backgroundColor = [UIColor clearColor];
    window.rootViewController = vc;
    window.hidden = NO;
    settingsWindow = window;
}

@end

// ========== 创建悬浮按钮 ==========
static FloatWindow *floatWindow = nil;

static void createFloatButton() {
    if (floatWindow) return;
    
    CGPoint origin = CGPointMake([UIScreen mainScreen].bounds.size.width - 70, 100);
    NSString *posStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"floatPos"];
    if (posStr) {
        CGPoint saved = CGPointFromString(posStr);
        if (!CGPointEqualToPoint(saved, CGPointZero)) origin = saved;
    }
    
    CGRect btnFrame = CGRectMake(origin.x, origin.y, 50, 50);
    UIWindowScene *scene = activeWindowScene();
    if (scene) {
        floatWindow = [[FloatWindow alloc] initWithFrame:btnFrame scene:scene];
    } else {
        floatWindow = [[FloatWindow alloc] initWithFrame:btnFrame];
    }
}

// ========== Hook 替换 ==========
static CLLocationCoordinate2D (*orig_coordinate)(id self, SEL _cmd);
static CLLocationCoordinate2D replaced_coordinate(id self, SEL _cmd) {
    if (isEnabled()) {
        return currentCoordinate();
    }
    return orig_coordinate(self, _cmd);
}

// ========== 初始化入口 ==========
__attribute__((constructor)) static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            createFloatButton();
        });
    });
    
    Method origMethod = class_getInstanceMethod([CLLocation class], @selector(coordinate));
    if (origMethod) {
        IMP imp = method_getImplementation(origMethod);
        orig_coordinate = (CLLocationCoordinate2D (*)(id, SEL))imp;
        method_setImplementation(origMethod, (IMP)replaced_coordinate);
        NSLog(@"[locationfaker] Hook installed.");
    } else {
        NSLog(@"[locationfaker] Failed to hook coordinate.");
    }
}