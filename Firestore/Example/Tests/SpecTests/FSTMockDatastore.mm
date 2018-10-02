/*
 * Copyright 2017 Google
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

#import "Firestore/Example/Tests/SpecTests/FSTMockDatastore.h"

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"

#import "Firestore/Example/Tests/Remote/FSTWatchChange+Testing.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::SnapshotVersion;

@class GRPCProtoCall;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMockWatchStream

namespace firebase {
namespace firestore {
namespace remote {

using model::TargetId;

class MockWatchStream : public WatchStream {
 public:
  MockWatchStream(AsyncQueue *worker_queue,
                  CredentialsProvider *credentials_provider,
                  FSTSerializerBeta *serializer,
                  GrpcConnection *grpc_connection,
                  id<FSTWatchStreamDelegate> delegate,
                  MockDatastore *datastore)
      : WatchStream{async_queue, credentials_provider, serializer, grpc_connection, delegate},
        datastore_{datastore},
        delegate_{delegate} {
  }

  void Start() override {
    HARD_ASSERT(!open_, "Trying to start already started watch stream");
    open_ = true;
    [self.delegate watchStreamDidOpen];
  }

  void Stop() override {
    active_targets_.clear();
  }

  bool IsStarted() const override {
    return open_;
  }
  bool IsOpen() const override {
    return open_;
  }

  void WatchQuery(FSTQueryData *query) override {
    LOG_DEBUG("WatchQuery: %s: %s", query.targetID, query.query);
    datastore_->IncrementWatchStreamRequestsCount();
    // Snapshot version is ignored on the wire
    FSTQueryData *sentQueryData = [query queryDataByReplacingSnapshotVersion:SnapshotVersion::None()
                                                                 resumeToken:query.resumeToken
                                                              sequenceNumber:query.sequenceNumber];
    active_targets_[query.targetID] = sentQueryData;
  }

  void UnwatchTargetId(model::TargetId target_id) override {
    LOG_DEBUG("UnwatchTargetId: %s", target_id);
    active_targets_.erase(active_targets_.find(target_id));
  }

  void FailStreamWithError(NSError *error) {
    open_ = false;
    [self.delegate watchStreamWasInterruptedWithError:error];
  }

  void WriteWatchChange(FSTWatchChange *change, SnapshotVersion snap) {
    if (![change isKindOfClass:[FSTWatchTargetChange class]]) {
      return;
    }
    FSTWatchTargetChange *targetChange = (FSTWatchTargetChange *)change;
    if (!targetChange.cause) {
      return;
    }

    for (NSNumber *targetID in targetChange.targetIDs) {
      auto found = active_targets_.find(target_id);
      if (found == active_targets_.end()) {
        // Technically removing an unknown target is valid (e.g. it could race with a
        // server-side removal), but we want to pay extra careful attention in tests
        // that we only remove targets we listened to.
        HARD_FAIL("Removing a non-active target");
      }

      active_targets_.erase(found);
    }

    if ([targetChange.targetIDs count] != 0) {
      // If the list of target IDs is not empty, we reset the snapshot version to NONE as
      // done in `FSTSerializerBeta.versionFromListenResponse:`.
      snap = SnapshotVersion::None();
    }

    [self.delegate watchStreamDidChange:change snapshotVersion:snap];
  }

 private:
  bool open_ = false;
  std::map<TargetId, FSTQueryData *> active_targets_;
  MockDatastore *datastore_ = nullptr;
  id<FSTWatchStreamDelegate> delegate_ = nullptr;
};

class MockWriteStream : public WriteStream {
 public:
  MockWriteStream(AsyncQueue *worker_queue,
                  CredentialsProvider *credentials_provider,
                  FSTSerializerBeta *serializer,
                  GrpcConnection *grpc_connection,
                  id<FSTWatchStreamDelegate> delegate,
                  MockDatastore *datastore)
      : WatchStream{async_queue, credentials_provider, serializer, grpc_connection, delegate},
        datastore_{datastore},
        delegate_{delegate} {
  }

  void Start() override {
    HARD_ASSERT(!open_, "Trying to start already started watch stream");
    open_ = true;
    [self.delegate watchStreamDidOpen];
  }

  void Stop() override {
    active_targets_.clear();
  }

  bool IsStarted() const override {
    return open_;
  }
  bool IsOpen() const override {
    return open_;
  }

//- (void)startWithDelegate:(id<FSTWriteStreamDelegate>)delegate {
//  HARD_ASSERT(!self.open, "Trying to start already started write stream");
//  self.open = YES;
//  [self.sentMutations removeAllObjects];
//  self.delegate = delegate;
//  [self notifyStreamOpen];
//}
//
//
//- (void)writeHandshake {
//  self.datastore.writeStreamRequestCount += 1;
//  [self setHandshakeComplete];
//  [self.delegate writeStreamDidCompleteHandshake];
//}
//
//- (void)writeMutations:(NSArray<FSTMutation *> *)mutations {
//  self.datastore.writeStreamRequestCount += 1;
//  [self.sentMutations addObject:mutations];
//}
//
//#pragma mark - Helper methods.
//
///** Injects a write ack as though it had come from the backend in response to a write. */
//- (void)ackWriteWithVersion:(const SnapshotVersion &)commitVersion
//            mutationResults:(NSArray<FSTMutationResult *> *)results {
//  [self.delegate writeStreamDidReceiveResponseWithVersion:commitVersion mutationResults:results];
//}
//
///** Injects a failed write response as though it had come from the backend. */
//- (void)failStreamWithError:(NSError *)error {
//  self.open = NO;
//  [self notifyStreamInterruptedWithError:error];
//}
//
///**
// * Returns the next write that was "sent to the backend", failing if there are no queued sent
// */
//- (NSArray<FSTMutation *> *)nextSentWrite {
//  HARD_ASSERT(self.sentMutations.count > 0,
//              "Writes need to happen before you can call nextSentWrite.");
//  NSArray<FSTMutation *> *result = [self.sentMutations objectAtIndex:0];
//  [self.sentMutations removeObjectAtIndex:0];
//  return result;
//}
//
///**
// * Returns the number of mutations that have been sent to the backend but not retrieved via
// * nextSentWrite yet.
// */
//- (int)sentMutationsCount {
//  return (int)self.sentMutations.count;
//}
 private:
  bool open_ = false;
//@property(nonatomic, strong, readonly) NSMutableArray<NSArray<FSTMutation *> *> *sentMutations;
  MockDatastore *datastore_ = nullptr;
  id<FSTWriteStreamDelegate> delegate_ = nullptr;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#pragma mark - FSTMockDatastore

@interface FSTMockDatastore ()
//@property(nonatomic, strong, nullable) FSTMockWatchStream *watchStream;
//@property(nonatomic, strong, nullable) FSTMockWriteStream *writeStream;

/** Properties implemented in FSTDatastore that are nonpublic. */
@property(nonatomic, strong, readonly) FSTDispatchQueue *workerDispatchQueue;
@property(nonatomic, assign, readonly) CredentialsProvider *credentials;

@end

@implementation FSTMockDatastore

#pragma mark - Overridden FSTDatastore methods.

// - (FSTWatchStream *)createWatchStream {
//   self.watchStream = [[FSTMockWatchStream alloc]
//         initWithDatastore:self
//       workerDispatchQueue:self.workerDispatchQueue
//               credentials:self.credentials
//                serializer:[[FSTSerializerBeta alloc]
//                               initWithDatabaseID:&self.databaseInfo->database_id()]];
//   return self.watchStream;
// }

// - (FSTWriteStream *)createWriteStream {
//   self.writeStream = [[FSTMockWriteStream alloc]
//         initWithDatastore:self
//       workerDispatchQueue:self.workerDispatchQueue
//               credentials:self.credentials
//                serializer:[[FSTSerializerBeta alloc]
//                               initWithDatabaseID:&self.databaseInfo->database_id()]];
//   return self.writeStream;
// }

- (void)authorizeAndStartRPC:(GRPCProtoCall *)rpc completion:(FSTVoidErrorBlock)completion {
  HARD_FAIL("FSTMockDatastore shouldn't be starting any RPCs.");
}

#pragma mark - Method exposed for tests to call.

- (NSArray<FSTMutation *> *)nextSentWrite {
  return @[];
  // return [self.writeStream nextSentWrite];
}

- (int)writesSent {
  return 0;
  // return [self.writeStream sentMutationsCount];
}

- (void)ackWriteWithVersion:(const SnapshotVersion &)commitVersion
            mutationResults:(NSArray<FSTMutationResult *> *)results {
  // [self.writeStream ackWriteWithVersion:commitVersion mutationResults:results];
}

- (void)failWriteWithError:(NSError *_Nullable)error {
  // [self.writeStream failStreamWithError:error];
}

- (void)writeWatchChange:(FSTWatchChange *)change snapshotVersion:(const SnapshotVersion &)snap {
  // [self.watchStream writeWatchChange:change snapshotVersion:snap];
}

- (void)failWatchStreamWithError:(NSError *)error {
  // [self.watchStream failStreamWithError:error];
}

- (NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)activeTargets {
  return @{};
  // return [self.watchStream.activeTargets copy];
}

- (BOOL)isWatchStreamOpen {
  return NO;
  // return self.watchStream.isOpen;
}

@end

NS_ASSUME_NONNULL_END
