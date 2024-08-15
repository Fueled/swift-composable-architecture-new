import Combine

extension Effect {
  /// Creates an effect from a Combine publisher.
  ///
  /// - Parameter createPublisher: The closure to execute when the effect is performed.
  /// - Returns: An effect wrapping a Combine publisher.
  public static func publisher(_ createPublisher: () -> some Publisher<Action, Never>) -> Self {
    Self(operation: .publisher(createPublisher()))
  }
}

public struct _EffectPublisher<Action>: Publisher {
  public typealias Output = Action
  public typealias Failure = Never

  let effect: Effect<Action>

  public init(_ effect: Effect<Action>) {
    self.effect = effect
  }

  public func receive(subscriber: some Combine.Subscriber<Action, Failure>) {
    publisher.subscribe(subscriber)
  }

  private var publisher: AnyPublisher<Action, Failure> {
    switch effect.operation {
    case .none:
      return Empty().eraseToAnyPublisher()
    case let .sync(operation):
      return withEscapedDependencies { dependencies in
        AnyPublisher.create { subscriber in
          let continuation = Send<Action>.Continuation { action in
            dependencies.yield {
              subscriber.send(action)
            }
          }
          continuation.onTermination = { _ in
            subscriber.send(completion: .finished)
          }
          operation(continuation)
          return AnyCancellable {
            continuation.finish()
          }
        }
      }
    case let .run(priority, operation):
      return .create { subscriber in
        let task = Task(priority: priority) { @MainActor in
          defer { subscriber.send(completion: .finished) }
          await operation(Send { subscriber.send($0) })
        }
        return AnyCancellable {
          task.cancel()
        }
      }
    }
  }
}
