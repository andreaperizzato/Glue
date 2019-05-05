//
//  StoreTests.swift
//  GlueTests
//
//  Created by Andrea Perizzato on 24/12/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//

import XCTest
import Glue
import Dispatch

private struct NonEquatableState {
  var count: Int = 0
}
private struct EquatableState: Equatable {
  var count: Int = 0
}

private struct Increment: Intent {}
private struct Noop: Intent {}

private protocol Incrementable {
  mutating func increment()
}
private func reducer<S: Incrementable>(state: inout S, action: Intent) -> [Effect] {
  switch action {
  case is Increment:
    state.increment()
    return []
  default:
    return []
  }
}
extension NonEquatableState: Incrementable {
  mutating func increment() { count += 1 }
}
extension EquatableState: Incrementable {
  mutating func increment() { count += 1 }
}
extension Int: Incrementable {
  mutating func increment() { self += 1 }
}

class StoreTests: XCTestCase {

  // MARK: - Dispatch
  func test_dispatch_CallReducerOnBackgroundQueue() {
    // Given
    let reducerCalled = expectation(description: "reducer called")
    var isMainThread: Bool?
    let store = Store(state: 0) { _, _ in
      isMainThread = Thread.isMainThread
      reducerCalled.fulfill()
      return []
    }
    // When
    store.dispatch(Increment())
    // Then
    wait(for: [reducerCalled], timeout: 1)
    XCTAssertFalse(isMainThread!)
  }

  func test_dispatch_UpdateState() {
    // Given
    let store = Store(state: 0, reducer: reducer)
    // When
    store.dispatch(Increment(), sync: true)
    // Then
    XCTAssertEqual(store.state, 1)
  }

  // MARK: - Subscribe
  func test_subscribe_NotifiesCurrentState() {
    // Given
    let store = Store(state: NonEquatableState(), reducer: reducer)
    // When
    let notified = expectation(description: "notified")
    var notifiedState: NonEquatableState?
    _ = store.subscribe { state in
      notifiedState = state
      notified.fulfill()
    }
    // Then
    wait(for: [notified], timeout: 1)
    XCTAssertEqual(notifiedState?.count, store.state.count)
  }

  func test_subscribe_nonEquatableState_AlwaysNotifiesAfterEveryIntent() {
    // Given
    let store = Store(state: NonEquatableState(), reducer: reducer)
    // When
    let notified = expectation(description: "notified")
    notified.expectedFulfillmentCount = 4
    var notifiedStates = [NonEquatableState]()
    let token = store.subscribe { state in
      notifiedStates.append(state)
      notified.fulfill()
    }
    store.dispatch(Increment(), sync: true)
    store.dispatch(Noop(), sync: true)
    store.dispatch(Increment(), sync: true)
    // Then
    wait(for: [notified], timeout: 1)
    XCTAssertEqual(notifiedStates.count, 4) // initial + 3 actions
    XCTAssertEqual(notifiedStates.map({ $0.count }), [0, 1, 1, 2])
    _ = token // keep the subscription alive
  }

  func test_subscribe_equatableState_NotifiesOnlyWhenStateChanges() {
    // Given
    let store = Store(state: EquatableState(), reducer: reducer)
    // When
    let notified = expectation(description: "notified")
    notified.expectedFulfillmentCount = 3
    var notifiedStates = [EquatableState]()
    let token = store.subscribe { state in
      notifiedStates.append(state)
      notified.fulfill()
    }
    store.dispatch(Increment(), sync: true)
    store.dispatch(Noop(), sync: true)
    store.dispatch(Increment(), sync: true)
    // Then
    wait(for: [notified], timeout: 1)
    XCTAssertEqual(notifiedStates.count, 3)
    XCTAssertEqual(notifiedStates.map({ $0.count }), [0, 1, 2])
    _ = token // keep the subscription alive
  }

  func test_subscribe_nonEquatableSubstate_AlwaysNotifiesAfterEveryIntent() {
    // Given
    let store = Store(state: NonEquatableState(), reducer: reducer)
    // When
    let notified = expectation(description: "notified")
    notified.expectedFulfillmentCount = 4
    // Select a `Void` which is not equatable.
    let token = store.subscribe(selector: { _ in () }, handler: { _ in
      notified.fulfill()
    })
    store.dispatch(Increment(), sync: true)
    store.dispatch(Noop(), sync: true)
    store.dispatch(Increment(), sync: true)
    // Then
    wait(for: [notified], timeout: 1)
    _ = token // keep the subscription alive
  }

  func test_subscribe_equatableSubstate_NotifiesOnlyWhenSubstateChanges() {
    // Given
    let store = Store(state: EquatableState(), reducer: reducer)
    // When
    // The `count` substate is an `Int` which is equatable.
    let countExp = expectation(description: "notified count")
    countExp.expectedFulfillmentCount = 3
    var notifiedCount = [Int]()
    let countToken = store.subscribe(selector: { $0.count }, handler: { state in
      notifiedCount.append(state)
      countExp.fulfill()
    })
    // Select a `Void` which is not equatable.
    let otherExp = expectation(description: "notified other")
    otherExp.expectedFulfillmentCount = 4 // initial + 3 actions.
    let otherToken = store.subscribe(selector: { _ in () }, handler: { _ in
      otherExp.fulfill()
    })
    store.dispatch(Increment(), sync: true)
    store.dispatch(Noop(), sync: true)
    store.dispatch(Increment(), sync: true)
    // Then
    wait(for: [countExp, otherExp], timeout: 1)
    XCTAssertEqual(notifiedCount, [0, 1, 2])
    _ = otherToken // keep the subscription alive
    _ = countToken
  }

  func test_subscribe_NotifiedOfSpecifiedQueue() {
    // Given
    let store = Store(state: NonEquatableState(), reducer: reducer)
    let queue = DispatchQueue(label: "test-queue")
    // When
    let notified = expectation(description: "notified")
    let token = store.subscribe(on: queue, handler: { _ in
      dispatchPrecondition(condition: .onQueue(queue))
      notified.fulfill()
    })
    // Then
    wait(for: [notified], timeout: 1)
    _ = token // keep the subscription alive
  }

  // MARK: - Effects
  enum TestEffect: Effect {
    case first, second
  }
  class Handler: EffectHandler {
    private(set) var effects = [Effect]()
    func handle(effect: Effect, dispatch: @escaping DispatchFunction) {
      effects.append(effect)
    }
  }
  func test_effectHandlers() {
    // Given
    let handler = Handler()
    let effects = [TestEffect.first, .second]
    let store = Store(state: EquatableState()) { _, _ in effects }
    // When
    store.add(effectHandler: handler)
    store.dispatch(Increment(), sync: true)
    // Then
    XCTAssertEqual(handler.effects as? [TestEffect], effects)
  }
}
