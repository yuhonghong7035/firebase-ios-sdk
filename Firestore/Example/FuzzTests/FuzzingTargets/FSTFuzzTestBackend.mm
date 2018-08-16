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
#import <XCTest/XCTest.h>

#include <cstddef>
#include <cstdint>

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestBackend.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "FIRCollectionReference.h"
#import "FIRDocumentReference.h"
#import "FIRDocumentSnapshot.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

// Retrieves a document from the collection with the defined path.
void GetDocumentWithPath(FIRCollectionReference* coll, NSString* path) {
  @try {
    // Block on multiple remote calls.
    NSMutableArray *expectations = [NSMutableArray array];

    // Test 1: Get document with the string path.
    XCTestExpectation *doc_ex = [[XCTestExpectation alloc] initWithDescription:@"document_reference"];
    [expectations addObject:doc_ex];
    FIRDocumentReference *doc = [coll documentWithPath:path];
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      [doc_ex fulfill];
    }];
    [XCTWaiter waitForExpectations:expectations timeout:5 enforceOrder:NO];
  } @catch (...) {
    // Ignore caught exceptions and assertions.
  }
}

// If doc_data is a valid dictionary, creates a document with this data, then
// retrieves and deletes it. The document is created with an auto id.
void DocCreateRetrieveDelete(FIRCollectionReference* coll, NSData* doc_data) {
  NSDictionary *dictionary=[NSJSONSerialization
                            JSONObjectWithData:doc_data
                            options:NSJSONReadingMutableLeaves
                            error:nil];
  if (dictionary == nil) {
    return;
  }

  try {
    // Block on multiple remote calls.
    NSMutableArray *expectations = [NSMutableArray array];
    XCTestExpectation *new_doc_ex = [[XCTestExpectation alloc] initWithDescription:@"create"];
    XCTestExpectation *get_doc_ex = [[XCTestExpectation alloc] initWithDescription:@"retrieve"];
    XCTestExpectation *del_doc_ex = [[XCTestExpectation alloc] initWithDescription:@"delete"];
    [expectations addObject:new_doc_ex];
    [expectations addObject:get_doc_ex];
    [expectations addObject:del_doc_ex];

    // Create a document reference.
    FIRDocumentReference *new_doc = [coll documentWithAutoID];

    // Create document with data.
    [new_doc setData:dictionary completion:^(NSError * _Nullable error) {
      [new_doc_ex fulfill];
    }];

    // Retrieve document.
    [new_doc getDocumentWithSource:FIRFirestoreSourceServer completion:
     ^(FIRDocumentSnapshot *_Nullable snapshot, NSError * _Nullable error) {
      [get_doc_ex fulfill];
    }];

    // Delete document.
    [new_doc deleteDocumentWithCompletion:^(NSError * _Nullable error) {
      [del_doc_ex fulfill];
    }];

    [XCTWaiter waitForExpectations:expectations timeout:5 enforceOrder:NO];
  } catch (...) {
    // Ignore caught exceptions and assertions.
  }
}


int FuzzTestBackend(const uint8_t *data, size_t size) {
  // TODO: this object needs to be properly initialized.
  FIRFirestore *firestore = nil;

  // Fixed collection.
  FIRCollectionReference *coll = [firestore collectionWithPath:@"collection"];

  NSData *bytes = [NSData dataWithBytes:data length:size];
  NSString *string = [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];

  // Test retrieving a document with the fuzzing input as a document path.
  GetDocumentWithPath(coll, string);

  // Uses the fuzzing input as document data, creates, retrieves, then deletes
  // this document.
  DocCreateRetrieveDelete(coll, bytes);

  return 0;
}

}  // namespace fuzzing
  }  // namespace firestore
}  // namespace firebase
