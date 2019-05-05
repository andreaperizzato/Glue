//
//  ViewModelEmitterTests.swift
//  GlueTests
//
//  Created by Andrea Perizzato on 15/01/2019.
//  Copyright © 2019 Andrea Perizzato. All rights reserved.
//

import XCTest
import Glue

private struct AppendLetterA: Intent {}
private struct DoNothing: Intent {}
private func reducer(state: inout String, action: Intent) -> [Effect] {
  if action is AppendLetterA {
    state += "A"
  }
  return []
}

class MockRenderer: Renderer {
  var calledExp: XCTestExpectation?

  private(set) var viewModels = [Int]()
  func render(viewModel: Int) {
    dispatchPrecondition(condition: .onQueue(.main))
    viewModels.append(viewModel)
    calledExp?.fulfill()
  }
}

class ViewModelEmitterTests: XCTestCase {

  func test_notifiesOnMainThreadWhenViewModelChanges() {
    // Given
    let store = Store(state: "", reducer: reducer)
    let renderer = MockRenderer()
    // When
    let vmEmitter = store.viewModelEmitter { $0.count }
    let exp = expectation(description: "render")
    exp.expectedFulfillmentCount = 3
    renderer.calledExp = exp
    vmEmitter.register(renderer: renderer)
    store.dispatch(AppendLetterA())
    store.dispatch(DoNothing())
    store.dispatch(AppendLetterA())
    // Then
    wait(for: [exp], timeout: 1)
    XCTAssertEqual(renderer.viewModels, [0, 1, 2]) // length of the message
  }

  func test_stopsNotificationAfterUnregister() {
    // Given
    let store = Store(state: "", reducer: reducer)
    let renderer = MockRenderer()
    // When
    let vmEmitter = store.viewModelEmitter { $0.count }
    let initalRender = expectation(description: "inital render")
    renderer.calledExp = initalRender
    vmEmitter.register(renderer: renderer)
    wait(for: [initalRender], timeout: 1)
    vmEmitter.unregister()
    let unregistered = expectation(description: "unregistered")
    unregistered.isInverted = true
    renderer.calledExp = unregistered
    store.dispatch(AppendLetterA())
    // Then
    wait(for: [unregistered], timeout: 0.5)
    XCTAssertEqual(renderer.viewModels, [0]) // length of the message
  }

}
