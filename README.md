# Glue

## Introduction

`Glue` is a simple implementation of unidirectional data flow architecture in Swift.

It follows the idea of functional core - imperative shell, discussed by Gary Bernhardt in his great talk [Boundaries](https://www.destroyallsoftware.com/talks/boundaries).

`Glue` is very simple to understand and use as it defines clear patterns, in a very similar way to Redux.

### Core principles

There are three key components:
- `Store`s contain the `State` and expose a read-only view of it. The state can only be modified by dispatching `Intent`s 
- `Intent`s describe ways of updating the state, e.g. update the value of the counter. State mutations are performed by pure functions, called `Reducers`.
- `Effect`s describe side-effects such as a network request, database operation or pushing/popping the navigation stack. Effects are handled by `EffectHandler`s.

`Store`s, `Reducer`s and `Intent`s are all part of the so-called functional core where all the logic is implemented using pure functions which are very easy and fast to test. Side effects are by definition non-pure and they are part of the imperative shell.

## Simple Example

Let's build a very simple application to increment and decrement a counter from 0 and that every time a multiple of 5 is reached, it plays a sound.

First of all we need to define the state:

```swift
struct AppState {
  var value = 0
}
```

Followed by all the possible mutations of the state:

```swift
enum AppIntent: Intent {
  case increment
  case decrement
}
```

The only side effect we have is playing a sound:

```swift
enum AppEffect: Effect {
  case playSound
}
```

Now we can implement the logic of the application:

```swift
func reducer(state: inout AppState, intent: Intent) -> [Effect] {
  switch intent {
  case .increment:
    state.value += 1
    if state.value % 5 == 0 {
      return [AppEffect.playSound]      
    }
    return []
  case .decrement where state.value > 0:
    state.value -= 1
    return []
  default:
    return []
  }
}
```

Not let's assume we are building an iOS app and want to play the sound. We can create an `EffectHandler` to handle the `AppEffect.playSound` effect:

```swift
class SoundEffectHandler: EffectHandler {
  
  private let player: AVAudioPlayer = ...

  func handle(effect: Effect, dispatch: @escaping DispatchFunc) {
    guard effect = AppEffect.playSound else { return }
    player.play()
  }
}
```

The last step is to setup the store and add all the effect handlers:

```swift
let store = Store(state: AppState(), reducer: reducer)
store.add(effectHandler: SoundEffectHandler())
return store
```
