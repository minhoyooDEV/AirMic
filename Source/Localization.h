#import <Foundation/Foundation.h>

// Stable keys keep translations independent of wording changes.
// NSBundle selects the user's preferred supported language, then English.
#define L(key) NSLocalizedString((key), nil)
