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

// ========== 获取当前活跃的 UIWindowScene ==========
static UIWindowScene * activeWindowScene(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    // fallback：取第一个 UIWindowScene
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

// ========== 设置界面控制器（浮层卡片） ==========
@interface LFSettingsVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) void (^dismissBlock)(void);
@property (nonatomic, strong) UITextField *latField, *lonField;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UITableView *favoritesTable;
@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) UIView *contentView;   // 卡片容器
@end

@implementation LFSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4]; // 半透明背景

    // 居中卡片
    CGFloat cardW = 300;
    CGFloat cardH = 460;
    _contentView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - cardW)/2,
                                                             (self.view.bounds.size.height - cardH)/2,
                                                             cardW, cardH)];
    _contentView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    _contentView.layer.cornerRadius = 20;
    _contentView.clipsToBounds = YES;
    [self.view addSubview:_contentView];

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, cardW-40, 30)];
    title.text = @"📍 位置模拟";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:22];
    title.textAlignment = NSTextAlignmentCenter;
    [_contentView addSubview:title];

    // 启用开关
    UILabel *enableLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 65, 80, 30)];
    enableLabel.text = @"启用";
    enableLabel.textColor = [UIColor whiteColor];
    [_contentView addSubview:enableLabel];
    _enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cardW-70, 65, 50, 30)];
    _enabledSwitch.on = isEnabled();
    [_enabledSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [_contentView addSubview:_enabledSwitch];

    // 经纬度输入
    CLLocationCoordinate2D cur = currentCoordinate();
    _latField = [[UITextField alloc] initWithFrame:CGRectMake(20, 110, (cardW-60)/2, 36)];
    _latField.placeholder = @"纬度";
    _latField.text = [NSString stringWithFormat:@"%.6f", cur.latitude];
    _latField.borderStyle = UITextBorderStyleRoundedRect;
    _latField.keyboardType = UIKeyboardTypeDecimalPad;
    _latField.textColor = [UIColor whiteColor];
    _latField.backgroundColor = [UIColor darkGrayColor];
    [_contentView addSubview:_latField];

    _lonField = [[UITextField alloc] initWithFrame:CGRectMake(40+(cardW-60)/2, 110, (cardW-60)/2, 36)];
    _lonField.placeholder = @"经度";
    _lonField.text = [NSString stringWithFormat:@"%.6f", cur.longitude];
    _lonField.borderStyle = UITextBorderStyleRoundedRect;
    _lonField.keyboardType = UIKeyboardTypeDecimalPad;
    _lonField.textColor = [UIColor whiteColor];
    _lonField.backgroundColor = [UIColor darkGrayColor];
    [_contentView addSubview:_lonField];

    // 应用 & 收藏按钮
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(20, 160, (cardW-60)/2, 36);
    [applyBtn setTitle:@"应用坐标" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.backgroundColor = [UIColor systemBlueColor];
    applyBtn.layer.cornerRadius = 8;
    [applyBtn addTarget:self action:@selector(applyCoords) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:applyBtn];

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(40+(cardW-60)/2, 160, (cardW-60)/2, 36);
    [saveBtn setTitle:@"收藏当前" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.backgroundColor = [UIColor systemGreenColor];
    saveBtn.layer.cornerRadius = 8;
    [saveBtn addTarget:self action:@selector(saveFavorite) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:saveBtn];

    // 收藏列表
    UILabel *favLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 210, 200, 20)];
    favLabel.text = @"⭐ 收藏坐标";
    favLabel.textColor = [UIColor whiteColor];
    [_contentView addSubview:favLabel];

    _favoritesTable = [[UITableView alloc] initWithFrame:CGRectMake(20, 240, cardW-40, cardH-270) style:UITableViewStylePlain];
    _favoritesTable.backgroundColor = [UIColor clearColor];
    _favoritesTable.separatorColor = [UIColor grayColor];
    _favoritesTable.delegate = self;
    _favoritesTable.dataSource = self;
    _favoritesTable.rowHeight = 44;
    [_contentView addSubview:_favoritesTable];

    _favorites = [loadFavorites() mutableCopy];
    [_favoritesTable reloadData];

    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(cardW-45, 10, 40, 40);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:closeBtn];

    // 点击背景关闭
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.view];
    if (!CGRectContainsPoint(_contentView.frame, point)) {
        [self close];
    }
}

- (void)switchChanged:(UISwitch *)sender { setEnabled(sender.on); }

- (void)applyCoords {
    double lat = [_latField.text doubleValue];
    double lon = [_lonField.text doubleValue];
    if (lat != 0 || lon != 0) {
        setCoordinate(CLLocationCoordinate2DMake(lat, lon));
        [self.view endEditing:YES];
    } else {
        [self showAlert:@"无效坐标" msg:@"请输入有效的数字"];
    }
}

- (void)saveFavorite {
    double lat = [_latField.text doubleValue];
    double lon = [_lonField.text doubleValue];
    if (lat == 0 && lon == 0) {
        [self showAlert:@"无效坐标" msg:@"请先输入有效坐标"];
        return;
    }
    NSString *name = [NSString stringWithFormat:@"%.6f, %.6f", lat, lon];
    NSDictionary *item = @{@"name": name, @"lat": @(lat), @"lon": @(lon)};
    [_favorites addObject:item];
    saveFavorites(_favorites);
    [_favoritesTable reloadData];
}

- (void)showAlert:(NSString *)title msg:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)close {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:NO completion:^{
        if (self.dismissBlock) self.dismissBlock();
    }];
}

#pragma mark - TableView
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _favorites.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    NSDictionary *item = _favorites[indexPath.row];
    cell.textLabel.text = item[@"name"];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = _favorites[indexPath.row];
    double lat = [item[@"lat"] doubleValue];
    double lon = [item[@"lon"] doubleValue];
    setCoordinate(CLLocationCoordinate2DMake(lat, lon));
    _latField.text = [NSString stringWithFormat:@"%.6f", lat];
    _lonField.text = [NSString stringWithFormat:@"%.6f", lon];
    if (!_enabledSwitch.on) { _enabledSwitch.on = YES; setEnabled(YES); }
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_favorites removeObjectAtIndex:indexPath.row];
        saveFavorites(_favorites);
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end

// ========== 悬浮按钮视图 ==========
@interface FloatView : UIView
@property (nonatomic, weak) UILabel *badgeLabel;
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, weak) UIWindowScene *scene; // 关联的 scene
@end

@implementation FloatView

- (instancetype)initWithFrame:(CGRect)frame scene:(UIWindowScene *)scene {
    if (self = [super initWithFrame:frame]) {
        _scene = scene;
        self.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        self.layer.cornerRadius = frame.size.width / 2;
        self.clipsToBounds = YES;
        
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, frame.size.width, 30)];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.textColor = [UIColor whiteColor];
        badge.font = [UIFont boldSystemFontOfSize:20];
        badge.text = @"📍";
        [self addSubview:badge];
        _badgeLabel = badge;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.8;
        [self addGestureRecognizer:longPress];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (self.isEditing) return;
    CGPoint translation = [pan translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    CGFloat half = self.bounds.size.width / 2, margin = 10;
    newCenter.x = MAX(half + margin, MIN(newCenter.x, self.superview.bounds.size.width - half - margin));
    newCenter.y = MAX(half + margin + 20, MIN(newCenter.y, self.superview.bounds.size.height - half - margin - 20));
    self.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.superview];
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
    
    UIWindowScene *scene = self.scene ?: activeWindowScene();
    UIWindow *window;
    if (scene) {
        window = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    window.windowLevel = UIWindowLevelAlert + 2; // 比悬浮按钮更高
    window.backgroundColor = [UIColor clearColor];
    window.rootViewController = vc;
    window.hidden = NO;
    settingsWindow = window;
}

@end

// ========== 悬浮窗口管理 ==========
static UIWindow *overlayWindow = nil;
static FloatView *floatView = nil;

static void createFloatButton() {
    if (floatView) return;
    
    UIWindowScene *scene = activeWindowScene();
    UIWindow *window;
    if (scene) {
        window = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    window.frame = CGRectMake(0, 0, 60, 60);
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor clearColor];
    window.userInteractionEnabled = YES;
    window.hidden = NO;
    window.rootViewController = [UIViewController new];
    window.rootViewController.view.backgroundColor = [UIColor clearColor];
    
    // 恢复上次保存的位置
    CGPoint origin = CGPointMake([UIScreen mainScreen].bounds.size.width - 70, 100);
    NSString *posStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"floatPos"];
    if (posStr) {
        CGPoint saved = CGPointFromString(posStr);
        if (!CGPointEqualToPoint(saved, CGPointZero)) origin = saved;
    }
    FloatView *fv = [[FloatView alloc] initWithFrame:CGRectMake(origin.x, origin.y, 50, 50) scene:scene];
    [window.rootViewController.view addSubview:fv];
    floatView = fv;
    overlayWindow = window;
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