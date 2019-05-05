//
//  Rendering.swift
//  Glue
//
//  Created by Andrea Perizzato on 27/12/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//

/// Renderer is a class that can render a `ViewModel`.
public protocol Renderer: AnyObject {
  /// ViewModel is the model driving the view.
  associatedtype ViewModel

  /// Updates the UI to match the given model.
  ///
  /// - Parameter viewModel: model representing the view.
  func render(viewModel: ViewModel)
}

/// ViewModelEmitter is a class `Renderer`s can register themselves to.
public protocol ViewModelEmitter: AnyObject {
  /// ViewModel is the model driving the view.
  associatedtype ViewModel

  /// Register a renderer to be notified when the view model changes.
  /// Only one rendered can be registered at any time.
  func register<R: Renderer>(renderer: R) where R.ViewModel == ViewModel

  /// Unregister the current renderer, if any.
  func unregister()
}
