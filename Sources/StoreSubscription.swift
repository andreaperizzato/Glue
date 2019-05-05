//
//  StoreSubscription.swift
//  Glue
//
//  Created by Andrea Perizzato on 11/11/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//
import Dispatch

/// BaseStoreSubscription is an internal type to abstract the Substate of a `StoreSubscription`.
class BaseStoreSubscription<State>: SubscriptionToken {
  func fire(oldState: State?, state: State) {}
}

/// StoreSubscription is an internal type to wrap subscription handler.
class StoreSubscription<State, Substate>: BaseStoreSubscription<State> {
  private let handler: (Substate) -> Void
  private let hasChanged: (Substate?, Substate) -> Bool
  private let selector: (State) -> Substate
  private let queue: DispatchQueue

  init(
    queue: DispatchQueue,
    selector: @escaping (State) -> Substate,
    hasChanged: @escaping (Substate?, Substate) -> Bool,
    handler: @escaping (Substate) -> Void) {

    self.handler = handler
    self.hasChanged = hasChanged
    self.selector = selector
    self.queue = queue
  }

  convenience init(queue: DispatchQueue,
                   selector: @escaping (State) -> Substate,
                   handler: @escaping (Substate) -> Void) {
    self.init(queue: queue, selector: selector, hasChanged: { _, _ in true }, handler: handler)
  }

  override func fire(oldState: State?, state: State) {
    let oldSubstate = oldState.map(selector)
    let substate = selector(state)
    guard hasChanged(oldSubstate, substate) else { return }
    queue.async { self.handler(substate) }
  }
}

extension StoreSubscription where Substate: Equatable {
  convenience init(
    queue: DispatchQueue,
    selector: @escaping (State) -> Substate,
    handler: @escaping (Substate) -> Void) {
    self.init(queue: queue, selector: selector, hasChanged: { $0 != $1 }, handler: handler)
  }
}
