//
//  Rendering+Store.swift
//  Glue
//
//  Created by Andrea Perizzato on 27/12/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//

/// StoreViewModelEmitter is a ViewModelEmitter subscribed to Store.
private class StoreViewModelEmitter<State, ViewModel: Equatable>: ViewModelEmitter {

  private let store: Store<State>
  private let transform: (State) -> ViewModel
  private var subscriptionToken: Any?

  init(store: Store<State>, transform: @escaping ((State) -> ViewModel)) {
    self.store = store
    self.transform = transform
  }

  func register<R: Renderer>(renderer: R) where R.ViewModel == ViewModel {
    subscriptionToken = store.subscribe(on: .main, selector: transform) { viewModel in
      renderer.render(viewModel: viewModel)
    }
  }

  func unregister() {
    subscriptionToken = nil
  }
}

extension Store {

  /// Creates a `ViewModelEmitter` applying the given transformation to the state.
  /// The renderer will always be called on the main thread.
  ///
  /// - Parameter transform: state to viewModel transformation
  /// - Returns: view model emitter
  public func viewModelEmitter<ViewModel: Equatable>(
    transform: @escaping ((State) -> ViewModel)) -> AnyViewModelEmitter<ViewModel> {

    let emitter = StoreViewModelEmitter(store: self, transform: transform)
    return AnyViewModelEmitter(emitter)
  }
}
