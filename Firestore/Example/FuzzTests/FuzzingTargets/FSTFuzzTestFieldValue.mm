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

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestFieldValue.h"

#import "Firestore/Source/API/FSTUserDataConverter.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

using firebase::firestore::model::DatabaseId;

// Tries to interpret the 'data' bytes as different object types and returns all
// possible created types.
NSArray *FieldValueInterpreter(const uint8_t* data, size_t size) {
  NSMutableArray *vals = [[NSMutableArray alloc] init];

  // Convert to NSData.
  NSData *bytes = [NSData dataWithBytes:data length:size];

  // Try casting to an NSDictionary.
  NSDictionary *dict =
  [NSJSONSerialization JSONObjectWithData:bytes options:NSJSONReadingMutableLeaves error:nil];
  if (dict != nil) {
    [vals addObject:dict];
  }

  // Try casting to an array.
  NSArray *arr = [NSKeyedUnarchiver unarchiveObjectWithData:bytes];
  if (arr != nil && [arr count] > 0) {
    [vals addObject:arr];
  }

  // Cast as a string.
  NSString *str = [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];

  if (str != nil && [str length] > 0) {
    [vals addObject:str];
  }

  // Cast as an integer -> use hash value of the data.
  [vals addObject:@([bytes hash])];

  return vals;
}

int FuzzTestFieldValue(const uint8_t* data, size_t size) {
  @autoreleasepool {
    // Create a simple no-op converter to parse field values.
    DatabaseId database_id{"project", DatabaseId::kDefault};
    FSTUserDataConverter *converter = [[FSTUserDataConverter alloc]
                                       initWithDatabaseID:&database_id
                                       preConverter:^id _Nullable(id _Nullable input) {
                                         return input;
                                       }];

    // Interpret the input in multiple ways.
    NSArray *vals = FieldValueInterpreter(data, size);
    if (vals == nil) {
      return 0;
    }

    // Try parsing each of the returned values.
    for (id val in vals) {
      @try {
        [converter parsedQueryValue:val];
      } @catch (...) {
        // Ignore caught exceptions and assertions.
      }

      if ([val isKindOfClass:[NSDictionary class]]) {
        @try {
          [converter parsedSetData:val];
        } @catch (...) {
          // Ignore caught exceptions and assertions.
        }

        @try {
          [converter parsedMergeData:val fieldMask:nil];
        } @catch (...) {
          // Ignore caught exceptions and assertions.
        }

        @try {
          [converter parsedUpdateData:val];
        } @catch (...) {
          // Ignore caught exceptions and assertions.
        }
      }
    }
  }
  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
