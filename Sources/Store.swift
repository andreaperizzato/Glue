//
//  Store.swift
//  Glue
//
//  Created by Andrea Perizzato on 11/11/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//
import Dispatch
import Foundation

/// DispatchFunction is a function intents can be dispatched with.
public typealias DispatchFunction = (Intent) -> Void

/// Reducer is a function that updates the state given an intent and returns a list of effects.
public typealias Reducer<State> = (inout State, Intent) -> [Effect]

/// Glueper holding a weak reference to an object.
private struct WeakBox<T: AnyObject> {
  weak var value: T?
}

/// Store holds the state it allows mutations only
/// by dispatching intents.
/// It also allows third party to subscribe to state updates.
public class Store<State> {
  /// Read-only state.
  public private(set) var state: State {
    didSet { notify(oldState: oldValue, newState: state) }
  }
  private var weakSubscribers = [WeakBox<BaseStoreSubscription<State>>]()
  private let queue = createDispatchQueue()
  private var effectHandlers = [EffectHandler]()
  private let reducer: Reducer<State>

  private static func createDispatchQueue() -> DispatchQueue {
    let name = String(describing: State.self).lowercased() + ".state-queue"
    return DispatchQueue(label: name)
  }

  /// Create a new store with an initial state.
  public init(state: State, reducer: @escaping Reducer<State>) {
    self.state = state
    self.reducer = reducer
  }
}

// MARK: - Executors
extension Store {
  /// Add a new effect handler which will get all effects
  /// that are returned by the reducer.
  public func add(effectHandler: EffectHandler) {
    effectHandlers.append(effectHandler)
  }
}

// MARK: - Dispatch
extension Store {
  /// Dispatching intents is the only way to update the state.
  /// - Effects returned by the reducer will be passed to all handlers.
  /// - All subscribers will receive an update when the state changes.
  public func dispatch(_ intent: Intent, sync: Bool = false) {
    let block = { [weak self] in
      guard let self = self else { return }
      let effects = self.reducer(&self.state, intent)
      effects.forEach(self.handle)
    }
    if sync {
      queue.sync(execute: block)
    } else {
      queue.async(execute: block)
    }
  }

  private func handle(effect: Effect) {
    let dispatch = { self.dispatch($0, sync: false) }
    effectHandlers.forEach { handler in handler.handle(effect: effect, dispatch: dispatch) }
  }
}

// MARK: - Subscription
extension Store {

  ///
  /// Subscribe to state updates applying the given selector to the state.
  /// - The handler will be immediatelly called with the current state.
  /// - The lifetime of the subscription matches that of the return
  /// subscription token.
  ///
  /// - Parameters:
  ///   - queue: queue where the handler will be called. Defaults to the main queue
  ///   - selector: state selector
  ///   - handler: function that will be called every time the state is updated
  /// - Returns: token to keep the subscription alive.
  public func subscribe<Substate>(on queue: DispatchQueue = DispatchQueue.main,
                                  selector: @escaping (State) -> Substate,
                                  handler: @escaping (Substate) -> Void) -> SubscriptionToken {
    let sub = StoreSubscription(queue: queue, selector: selector, handler: handler)
    sub.fire(oldState: nil, state: state)
    weakSubscribers.append(WeakBox(value: sub))
    return sub
  }

  ///
  /// Subscribe to state updated of the entire state.
  ///
  /// - Parameters:
  ///   - queue: queue where the handler will be called. Defaults to the main queue
  ///   - handler: function that will be called every time the state is updated
  /// - Returns: token to keep the subscription alive.
  public func subscribe(
    on queue: DispatchQueue = DispatchQueue.main,
    handler: @escaping (State) -> Void) -> SubscriptionToken {
    return subscribe(on: queue, selector: { $0 }, handler: handler)
  }

  ///
  /// Subscribe to state changes applying the given selector to the state.
  /// - The handler will be called only when the `Substate` changes according to
  ///   its `Equatable` implementation.
  /// - The handler will be immediatelly called with the current state.
  /// - The lifetime of the subscription matches that of the return
  /// subscription token.
  ///
  /// - Parameters:
  ///   - queue: queue where the handler will be called. Defaults to the main queue
  ///   - selector: state selector
  ///   - handler: function that will be called every time the state is updated
  /// - Returns: token to keep the subscription alive.
  public func subscribe<Substate: Equatable>(
    on queue: DispatchQueue = DispatchQueue.main,
    selector: @escaping (State) -> Substate,
    handler: @escaping (Substate) -> Void) -> SubscriptionToken {

    let sub = StoreSubscription(queue: queue, selector: selector, handler: handler)
    sub.fire(oldState: nil, state: state)
    weakSubscribers.append(WeakBox(value: sub))
    return sub
  }

  private func notify(oldState: State?, newState: State) {
    weakSubscribers
      .forEach { sub in sub.value?.fire(oldState: oldState, state: newState) }
  }
}

extension Store where State: Equatable {

  ///
  /// Subscribe to state updated of the entire state.
  /// - The handler will be called only when the `State` changes according to
  ///   its `Equatable` implementation.
  /// - The handler will be immediatelly called with the current state.
  /// - The lifetime of the subscription matches that of the return
  /// subscription token.
  ///
  /// - Parameters:
  ///   - queue: queue where the handler will be called. Defaults to the main queue
  ///   - handler: function that will be called every time the state is updated
  /// - Returns: token to keep the subscription alive.
  public func subscribe(on queue: DispatchQueue = DispatchQueue.main,
                        handler: @escaping (State) -> Void) -> SubscriptionToken {
    let sub = StoreSubscription(queue: queue, selector: { $0 }, handler: handler)
    sub.fire(oldState: nil, state: state)
    weakSubscribers.append(WeakBox(value: sub))
    return sub
  }
}

/// SubscriptionToken is used to keep a subscription alive.
/// Once release, the subscription is released.
public protocol SubscriptionToken {}
