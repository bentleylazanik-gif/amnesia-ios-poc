#import "HPL2GameDataImportOverlay.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface HPL2GameDataImportOverlay () <UIDocumentPickerDelegate>
@property (nonatomic, weak) UIView *containerView;
@property (nonatomic, strong) UIButton *importButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic) BOOL importInProgress;
@end

@implementation HPL2GameDataImportOverlay

- (nullable instancetype)initWithView:(UIView *)view
{
    self = [super init];
    if (self == nil || view == nil) {
        return nil;
    }

    self.containerView = view;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(16.0, 18.0, 210.0, 46.0);
    button.autoresizingMask = UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleBottomMargin;
    button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    button.layer.cornerRadius = 8.0;
    [button setTitle:@"Import Game Data" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.accessibilityIdentifier = @"game-data-import-button";
    [button addTarget:self action:@selector(importButtonPressed)
     forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:button];
    self.importButton = button;

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 68.0, 350.0, 56.0)];
    status.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleBottomMargin;
    status.numberOfLines = 2;
    status.font = [UIFont systemFontOfSize:12.0];
    status.textColor = [UIColor whiteColor];
    status.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.58];
    status.text = @"Game data not imported. Metal mesh preview remains a separate diagnostic.";
    status.accessibilityIdentifier = @"game-data-import-status";
    status.isAccessibilityElement = YES;
    [view addSubview:status];
    self.statusLabel = status;

    UIActivityIndicatorView *indicator =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    indicator.frame = CGRectMake(190.0, 20.0, 42.0, 42.0);
    indicator.autoresizingMask = UIViewAutoresizingFlexibleRightMargin |
                                  UIViewAutoresizingFlexibleBottomMargin;
    indicator.hidesWhenStopped = YES;
    [view addSubview:indicator];
    self.activityIndicator = indicator;
    return self;
}

- (UIViewController *)presentingViewController
{
    UIViewController *controller = self.containerView.window.rootViewController;
    while (controller.presentedViewController != nil) {
        controller = controller.presentedViewController;
    }
    return controller;
}

- (void)importButtonPressed
{
    if (self.importInProgress) {
        return;
    }
    UIViewController *controller = [self presentingViewController];
    if (controller == nil) {
        self.statusLabel.text = @"Import unavailable: could not find the iOS view controller.";
        return;
    }

    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder]
                                                                   asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [controller presentViewController:picker animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    (void)controller;
    self.statusLabel.text = @"Import cancelled. Existing imported files were left unchanged.";
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
 didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    (void)controller;
    NSURL *sourceURL = urls.firstObject;
    if (sourceURL == nil) {
        self.statusLabel.text = @"Import failed: Files returned no folder.";
        return;
    }

    self.importInProgress = YES;
    self.importButton.enabled = NO;
    self.statusLabel.text = @"Copying selected game-data folder…";
    [self.activityIndicator startAnimating];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        __block NSError *importError = nil;
        const BOOL hasSecurityScope = [sourceURL startAccessingSecurityScopedResource];
        NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                  inDomains:NSUserDomainMask].firstObject;
        NSURL *destinationRoot = [documentsURL URLByAppendingPathComponent:@"AmnesiaData"
                                                               isDirectory:YES];
        if (documentsURL == nil ||
            ![fileManager createDirectoryAtURL:destinationRoot
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&importError]) {
            if (importError == nil) {
                importError = [NSError errorWithDomain:@"HPL2GameDataImport"
                                                   code:1
                                               userInfo:@{NSLocalizedDescriptionKey:
                                                              @"Could not resolve the app Documents folder."}];
            }
        }

        __block NSURL *copiedFolderURL = nil;
        if (importError == nil) {
            NSString *folderName = sourceURL.lastPathComponent;
            if (folderName.length == 0 || [folderName isEqualToString:@"/"]) {
                folderName = @"ImportedGameData";
            }
            NSURL *baseDestination = [destinationRoot URLByAppendingPathComponent:folderName
                                                                      isDirectory:YES];
            NSURL *destination = baseDestination;
            NSUInteger suffix = 2;
            while ([fileManager fileExistsAtPath:destination.path]) {
                NSString *candidateName = [NSString stringWithFormat:@"%@-%lu", folderName,
                                                                    (unsigned long)suffix++];
                destination = [destinationRoot URLByAppendingPathComponent:candidateName
                                                               isDirectory:YES];
            }

            NSFileCoordinator *coordinator =
                [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            NSError *coordinationError = nil;
            [coordinator coordinateReadingItemAtURL:sourceURL
                                            options:0
                                              error:&coordinationError
                                         byAccessor:^(NSURL *coordinatedURL) {
                NSError *copyError = nil;
                if ([fileManager copyItemAtURL:coordinatedURL
                                         toURL:destination
                                         error:&copyError]) {
                    copiedFolderURL = destination;
                } else {
                    importError = copyError;
                    [fileManager removeItemAtURL:destination error:nil];
                }
            }];
            if (importError == nil && coordinationError != nil) {
                importError = coordinationError;
            }
            if (copiedFolderURL == nil && importError == nil) {
                importError = coordinationError ?: [NSError errorWithDomain:@"HPL2GameDataImport"
                                                                          code:2
                                                                      userInfo:@{NSLocalizedDescriptionKey:
                                                                                     @"The file provider did not supply the selected folder."}];
            }
        }
        if (hasSecurityScope) {
            [sourceURL stopAccessingSecurityScopedResource];
        }

        NSString *summary = nil;
        if (importError == nil && copiedFolderURL != nil) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.statusLabel.text = @"Copy complete. Checking required game files…";
            });
            __block BOOL foundMainInit = NO;
            __block NSUInteger meshCount = 0;
            __block NSUInteger materialCount = 0;
            NSDirectoryEnumerator<NSURL *> *enumerator =
                [fileManager enumeratorAtURL:copiedFolderURL
                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                errorHandler:^BOOL(NSURL *url, NSError *error) {
                (void)url;
                (void)error;
                return YES;
            }];
            for (NSURL *fileURL in enumerator) {
                NSNumber *isDirectory = nil;
                if (![fileURL getResourceValue:&isDirectory
                                        forKey:NSURLIsDirectoryKey
                                         error:nil] || isDirectory.boolValue) {
                    continue;
                }
                NSString *folderPath = copiedFolderURL.path;
                NSString *filePath = fileURL.path;
                if (filePath.length <= folderPath.length ||
                    ![filePath hasPrefix:[folderPath stringByAppendingString:@"/"]]) {
                    continue;
                }
                NSString *relativePath = [filePath substringFromIndex:folderPath.length + 1];
                if ([relativePath caseInsensitiveCompare:@"config/main_init.cfg"] == NSOrderedSame) {
                    foundMainInit = YES;
                }
                NSString *extension = fileURL.pathExtension.lowercaseString;
                if ([extension isEqualToString:@"msh"]) ++meshCount;
                if ([extension isEqualToString:@"mat"]) ++materialCount;
            }
            summary = [NSString stringWithFormat:
                @"Imported folder. config/main_init.cfg: %@; MSH meshes: %lu; MAT materials: %lu. Engine startup is not implemented.",
                foundMainInit ? @"found" : @"missing",
                (unsigned long)meshCount, (unsigned long)materialCount];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.importInProgress = NO;
            self.importButton.enabled = YES;
            [self.activityIndicator stopAnimating];
            if (importError != nil) {
                self.statusLabel.text = [NSString stringWithFormat:@"Import failed: %@",
                                                                   importError.localizedDescription];
            } else {
                self.statusLabel.text = summary;
            }
        });
    });
}

- (void)shutdown
{
    [self.importButton removeFromSuperview];
    [self.statusLabel removeFromSuperview];
    [self.activityIndicator removeFromSuperview];
    self.importButton = nil;
    self.statusLabel = nil;
    self.activityIndicator = nil;
    self.containerView = nil;
}

@end
