import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpDetailTests: XCTestCase {
  func testDelete() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    }

    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(.destination(.presented(.alert(.confirmButtonTapped)))) {
      $0.destination = nil
    }
    // ❌ A reducer requested dismissal at "SyncUps/SyncUpDetail.swift:92", but
    //    couldn't be dismissed. …
    //
    // ❌ The store received 1 unexpected action after this one: …
    //
    //      Unhandled actions:
    //        • .delegate(.deleteSyncUp)
  }
  
  func testEdit() async {
    // ...
  }
}