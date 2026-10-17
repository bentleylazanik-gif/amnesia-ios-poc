#ifndef HPL2_GAME_DATA_IMPORT_OVERLAY_H
#define HPL2_GAME_DATA_IMPORT_OVERLAY_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Small UIKit bridge over the SDL Metal view. Imports a selected game-data
// folder into Documents/AmnesiaData and reports an honest shallow inventory;
// it does not initialize HPL2 or replace the separate mesh preview.
@interface HPL2GameDataImportOverlay : NSObject

- (nullable instancetype)initWithView:(UIView *)view;
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END

#endif
