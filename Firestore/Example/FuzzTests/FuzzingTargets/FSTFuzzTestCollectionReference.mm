/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>
#include <cstddef>
#include <cstdint>

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestCollectionReference.h"

#import "Firestore/Source/API/FIRFirestore+Internal.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

// Copied from test helpers, but does not work.
FIRFirestore *GetTestFirestore() {
  static FIRFirestore *sharedInstance = nil;
  static dispatch_once_t onceToken;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRFirestore alloc] initWithProjectID:"abc"
                                                    database:"abc"
                                              persistenceKey:@"db123"
                                         credentialsProvider:nil
                                         workerDispatchQueue:nil
                                                 firebaseApp:nil];
  });
#pragma clang diagnostic pop
  return sharedInstance;
}

int FuzzTestCollectionReference(const uint8_t *data, size_t size) {
  @autoreleasepool {
    // This does not work because it requires authenticaion with Firestore.
    FIRFirestore *firestore = GetTestFirestore();

    // Convert bytes to a string.
    NSString *string = [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];

    @try {
      // Create a collection reference from the string.
      FIRCollectionReference *coll = [firestore collectionWithPath:string];
    } @catch (...) {
      // Ignore caught exceptions and assertions.
    }

    @try {
      // Create a document reference from the string.
      FIRDocumentReference *doc = [firestore documentWithPath:string];
    } @catch (...) {
      // Ignore caught exceptions and assertions.
    }
  }

  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
