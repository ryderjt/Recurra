#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "BasicIcon" asset catalog image resource.
static NSString * const ACImageNameBasicIcon AC_SWIFT_PRIVATE = @"BasicIcon";

/// The "StatusBarIcon" asset catalog image resource.
static NSString * const ACImageNameStatusBarIcon AC_SWIFT_PRIVATE = @"StatusBarIcon";

#undef AC_SWIFT_PRIVATE
