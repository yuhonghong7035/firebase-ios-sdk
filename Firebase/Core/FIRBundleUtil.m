// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Private/FIRBundleUtil.h"
#import "Private/FIRLogger.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

@implementation FIRBundleUtil

+ (NSArray<NSString *> *)appExtensionSuffixes {
  return @[ @"TodayExtension", @"NotificationServiceExtension", @"NotificationContentExtension" ];
}

+ (NSArray *)relevantBundles {
  return @[ [NSBundle mainBundle], [NSBundle bundleForClass:[self class]] ];
}

+ (NSString *)optionsDictionaryPathWithResourceName:(NSString *)resourceName
                                        andFileType:(NSString *)fileType
                                          inBundles:(NSArray *)bundles {
  // Loop through all bundles to find the config dict.
  for (NSBundle *bundle in bundles) {
    NSString *path = [bundle pathForResource:resourceName ofType:fileType];
    // Use the first one we find.
    if (path) {
      return path;
    }
  }
  return nil;
}

+ (NSArray *)relevantURLSchemes {
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (NSBundle *bundle in [[self class] relevantBundles]) {
    NSArray *urlTypes = [bundle objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    for (NSDictionary *urlType in urlTypes) {
      [result addObjectsFromArray:urlType[@"CFBundleURLSchemes"]];
    }
  }
  return result;
}

+ (BOOL)hasBundleIdentifier:(NSString *)bundleIdentifier inBundles:(NSArray *)bundles {
  for (NSBundle *bundle in bundles) {
    if ([bundle.bundleIdentifier isEqualToString:bundleIdentifier]) {
      return YES;
    } else if ([GULAppEnvironmentUtil isAppExtension]) {
      // If it's an App Extension, the bundleID should be the expected bundleID + a pre-determined
      // suffix based on the extension type. Compare against known types and log that support may
      // not be available for all SDKs in the extension.
      // TODO: We should use the Core configuration process and allow SDKs to specify which
      //       extensions they explicitly support. This way errors could be thrown or logged if an
      //       SDK was accessed inside an extension it doesn't support.
      for (NSString *extensionSuffix in [self appExtensionSuffixes]) {
        NSString *bundleWithSuffix =
            [NSString stringWithFormat:@"%@.%@", bundleIdentifier, extensionSuffix];
        if ([bundleIdentifier isEqualToString:bundleWithSuffix]) {
          FIRLogWarning(kFIRLoggerCore, @"I-COR000035",
                        @"Not all Firebase SDKs support running in an App Extension - please "
                        @"ensure all functionalities are tested and report any issues.");
          return YES;
        }
      }
    }
  }

  return NO;
}

@end
