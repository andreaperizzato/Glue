//
//  Effect.swift
//  Glue
//
//  Created by Andrea Perizzato on 11/11/2018.
//  Copyright © 2018 Andrea Perizzato. All rights reserved.
//

/// Effect is a side-effect that is handled by an effect handler.
/// Effect are meant to describe interactions with the asynchronous real world,
/// e.g. network requests, database storage, etc.
public protocol Effect {}

/// EffectHandler is something handling effects and that can
/// dispatch intents if needed.
public protocol EffectHandler {

  /// Handles an effect and dispatches one or more intents when completed.
  /// - Parameters:
  ///   - effect: effect to be handled
  ///   - dispatch: dispatch function
  func handle(effect: Effect, dispatch: @escaping DispatchFunction)
}
