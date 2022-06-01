import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct LoginState: Equatable {
  public var alert: AlertState<LoginAction>?
  public var email = ""
  public var isFormValid = false
  public var isLoginRequestInFlight = false
  public var password = ""
  public var twoFactor: TwoFactorState?

  public init() {}
}

public enum LoginAction: Equatable {
  case alertDismissed
  case emailChanged(String)
  case passwordChanged(String)
  case loginButtonTapped
  case loginResponse(TaskResult<AuthenticationResponse>)
  case twoFactor(TwoFactorAction)
  case twoFactorDismissed
}

public struct LoginEnvironment: Sendable {
  public var authenticationClient: AuthenticationClient

  public init(
    authenticationClient: AuthenticationClient
  ) {
    self.authenticationClient = authenticationClient
  }
}

public let loginReducer = Reducer<LoginState, LoginAction, LoginEnvironment>.combine(
  twoFactorReducer
    .optional()
    .pullback(
      state: \.twoFactor,
      action: /LoginAction.twoFactor,
      environment: {
        TwoFactorEnvironment(
          authenticationClient: $0.authenticationClient
        )
      }
    ),

  .init {
    state, action, environment in
    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case let .emailChanged(email):
      state.email = email
      state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
      return .none

    case let .loginResponse(.success(response)):
      state.isLoginRequestInFlight = false
      if response.twoFactorRequired {
        state.twoFactor = TwoFactorState(token: response.token)
      }
      return .none

    case let .loginResponse(.failure(error)):
      state.alert = .init(title: TextState(error.localizedDescription))
      state.isLoginRequestInFlight = false
      return .none

    case let .passwordChanged(password):
      state.password = password
      state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
      return .none

    case .loginButtonTapped:
      state.isLoginRequestInFlight = true
      return .task { @MainActor [email = state.email, password = state.password] in
        .loginResponse(
          await .init {
            try await environment.authenticationClient.login(
              .init(email: email, password: password)
            )
          }
        )
      }

    case .twoFactor:
      return .none

    case .twoFactorDismissed:
      state.twoFactor = nil
      return .cancel(id: TwoFactorTearDownToken.self)
    }
  }
)
