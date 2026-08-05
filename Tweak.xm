#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP orig_coordinate = NULL;   // 使用 IMP 类型

// ----- 存储工具 -----
static NSUserDefaults *defaults() { return [NSUserDefaults standardUserDefaults]; }

static void saveFavorites(NSArray *list) {
    [defaults() setObject:list forKey:@"favorites"];
    [defaults() synchronize];
}
static NSArray *loadFavorites() { return [defaults() objectForKey:@"favorites"] ?: @[]; }
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

// ----- 设置界面控制器 -----
@interface LocationFakerSettingsVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITextField *latField, *lonField;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UITableView *favoritesTable;
@property (nonatomic, strong) NSMutableArray *favorites;
@end

@implementation LocationFakerSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    self.view.layer.cornerRadius = 20;
    self.view.clipsToBounds = YES;
    CGFloat w = 320, h = 480;
    self.preferredContentSize = CGSizeMake(w, h);
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, w-40, 30)];
    title.text = @"📍 位置模拟";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:22];
    title.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:title];
    
    // 启用开关
    UILabel *enableLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, 100, 30)];
    enableLabel.text = @"启用";
    enableLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:enableLabel];
    _enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(w-70, 60, 50, 30)];
    _enabledSwitch.on = isEnabled();
    [_enabledSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_enabledSwitch];
    
    // 坐标输入
    CLLocationCoordinate2D cur = currentCoordinate();
    _latField = [[UITextField alloc] initWithFrame:CGRectMake(20, 110, (w-50)/2, 35)];
    _latField.placeholder = @"纬度";
    _latField.text = [NSString stringWithFormat:@"%.6f", cur.latitude];
    _latField.borderStyle = UITextBorderStyleRoundedRect;
    _latField.keyboardType = UIKeyboardTypeDecimalPad;
    _latField.textColor = [UIColor whiteColor];
    _latField.backgroundColor = [UIColor darkGrayColor];
    [self.view addSubview:_latField];
    
    _lonField = [[UITextField alloc] initWithFrame:CGRectMake(30+(w-50)/2, 110, (w-50)/2, 35)];
    _lonField.placeholder = @"经度";
    _lonField.text = [NSString stringWithFormat:@"%.6f", cur.longitude];
    _lonField.borderStyle = UITextBorderStyleRoundedRect;
    _lonField.keyboardType = UIKeyboardTypeDecimalPad;
    _lonField.textColor = [UIColor whiteColor];
    _lonField.backgroundColor = [UIColor darkGrayColor];
    [self.view addSubview:_lonField];
    
    // 按钮
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(20, 160, (w-50)/2, 35);
    [applyBtn setTitle:@"应用坐标" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.backgroundColor = [UIColor systemBlueColor];
    applyBtn.layer.cornerRadius = 8;
    [applyBtn addTarget:self action:@selector(applyCoords) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:applyBtn];
    
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(30+(w-50)/2, 160, (w-50)/2, 35);
    [saveBtn setTitle:@"收藏当前" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.backgroundColor = [UIColor systemGreenColor];
    saveBtn.layer.cornerRadius = 8;
    [saveBtn addTarget:self action:@selector(saveFavorite) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveBtn];
    
    // 收藏列表
    UILabel *favLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 210, 200, 20)];
    favLabel.text = @"⭐ 收藏坐标";
    favLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:favLabel];
    
    _favoritesTable = [[UITableView alloc] initWithFrame:CGRectMake(20, 235, w-40, h-270) style:UITableViewStylePlain];
    _favoritesTable.backgroundColor = [UIColor clearColor];
    _favoritesTable.separatorColor = [UIColor grayColor];
    _favoritesTable.delegate = self;
    _favoritesTable.dataSource = self;
    _favoritesTable.rowHeight = 44;
    [self.view addSubview:_favoritesTable];
    
    _favorites = [loadFavorites() mutableCopy];
    [_favoritesTable reloadData];
    
    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w-50, 10, 40, 40);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
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

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dismissKeyboard { [self.view endEditing:YES]; }

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

// ----- 悬浮按钮管理 -----
@interface UIApplication (LocationFaker)
- (void)lf_showSettings;
- (void)lf_handlePan:(UIPanGestureRecognizer *)gesture;
@end

@implementation UIApplication (LocationFaker)
- (void)lf_showSettings {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (root.presentedViewController) {
        [root dismissViewControllerAnimated:NO completion:nil];
    }
    LocationFakerSettingsVC *vc = [[LocationFakerSettingsVC alloc] init];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [root presentViewController:vc animated:YES completion:nil];
}

- (void)lf_handlePan:(UIPanGestureRecognizer *)gesture {
    UIButton *btn = (UIButton *)gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
        [gesture setTranslation:CGPointZero inView:btn.superview];
    }
}
@end

static void createFloatButton() {
    if (objc_getAssociatedObject([UIApplication sharedApplication], "lf_floatButton")) return;
    
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor clearColor];
    window.userInteractionEnabled = YES;
    window.hidden = NO;
    window.rootViewController = [UIViewController new];
    window.rootViewController.view.backgroundColor = [UIColor clearColor];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 60, 60);
    [btn setTitle:@"📍" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:36];
    btn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.7];
    btn.layer.cornerRadius = 30;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.5;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 4;
    btn.userInteractionEnabled = YES;
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[UIApplication sharedApplication] action:@selector(lf_showSettings)];
    longPress.minimumPressDuration = 0.8;
    [btn addGestureRecognizer:longPress];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[UIApplication sharedApplication] action:@selector(lf_handlePan:)];
    [btn addGestureRecognizer:pan];
    
    [window.rootViewController.view addSubview:btn];
    
    // 保存引用
    objc_setAssociatedObject([UIApplication sharedApplication], "lf_floatButton", btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject([UIApplication sharedApplication], "lf_floatWindow", window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 默认位置右上角
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    (void)screenH; // 消除未使用警告
    btn.center = CGPointMake(screenW - 50, 100);
}

// ----- Hook 替换 -----
static CLLocationCoordinate2D replaced_coordinate(id self, SEL _cmd) {
    if (isEnabled()) {
        return currentCoordinate();
    }
    // 调用原方法
    CLLocationCoordinate2D (*orig)(id, SEL) = (void *)orig_coordinate;
    return orig(self, _cmd);
}

// ----- 初始化入口 -----
__attribute__((constructor)) static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            createFloatButton();
        });
    });
    
    Method origMethod = class_getInstanceMethod([CLLocation class], @selector(coordinate));
    if (origMethod) {
        orig_coordinate = method_getImplementation(origMethod);
        method_setImplementation(origMethod, (IMP)replaced_coordinate);
        NSLog(@"[locationfaker] Hook installed.");
    } else {
        NSLog(@"[locationfaker] Failed to hook coordinate.");
    }
}