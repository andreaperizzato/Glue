//
//  Rendering+TypeErasure.swift
//  Glue
//
//  Created by Andrea Perizzato on 27/12/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//

/// A type-erased `Renderer`.
private class AnyRenderer<ViewModel>: Renderer {

  private let baseRender: (ViewModel) -> Void
  init<R: Renderer>(_ renderer: R) where R.ViewModel == ViewModel {
    self.baseRender = renderer.render
  }

  func render(viewModel: ViewModel) {
    baseRender(viewModel)
  }
}

/// A type-erased `ViewModelEmitter`.
public class AnyViewModelEmitter<ViewModel>: ViewModelEmitter {

  public let base: Any
  private let baseUnregister: () -> Void
  private let baseRegister: (AnyRenderer<ViewModel>) -> Void

  init<E: ViewModelEmitter>(_ emitter: E) where E.ViewModel == ViewModel {
    self.base = emitter
    self.baseUnregister = emitter.unregister
    self.baseRegister = emitter.register
  }

  public func register<R: Renderer>(renderer: R) where R.ViewModel == ViewModel {
    baseRegister(AnyRenderer(renderer))
  }

  public func unregister() {
    baseUnregister()
  }
}
