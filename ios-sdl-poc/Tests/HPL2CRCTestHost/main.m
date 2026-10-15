#import <UIKit/UIKit.h>

@interface HPL2CRCTestHostDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation HPL2CRCTestHostDelegate
- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    (void)application;
    (void)launchOptions;
    return YES;
}
@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([HPL2CRCTestHostDelegate class]));
    }
}
