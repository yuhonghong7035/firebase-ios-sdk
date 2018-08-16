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

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestFIRQuery.h"

#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

using firebase::firestore::model::ResourcePath;

int FuzzTestFIRQuery(const uint8_t *data, size_t size) {
  // Do not process empty inputs.
  if (size == 0) {
    return 0;
  }

  @autoreleasepool {
    try {
      // Convert to a string view.
      absl::string_view str_view{reinterpret_cast<char const*>(data), size};
      if (str_view.find("//") != std::string::npos) {
        return 0;
      }

      // Convert to NSString.
      NSString *str = [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];

      // Create main FIRQuery object.
      ResourcePath rp = ResourcePath::FromString(str_view);
      FSTQuery *fstQuery = [FSTQuery queryWithPath:rp];
      FIRQuery *firQuery = [FIRQuery referenceWithQuery:fstQuery firestore:nil];

      // Create other FIRQuery objects.
      [firQuery queryWhereField:str isEqualTo:str];
      [firQuery queryOrderedByField:str];
    } catch (...) {
      // Ignore caught exceptions and errors.
    }
  }
  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
