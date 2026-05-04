---
type: gotcha
context: Injecting an @Observable ViewModel into a SwiftUI View via init
keywords: [Observable, State, Bindable, ViewModel, DI, injection, SwiftUI, anti-pattern]
---

## What

Using `@State(initialValue:)` for an externally injected `@Observable` ViewModel is a SwiftUI anti-pattern. `@State` signals *ownership*: SwiftUI stores the value internally on first render and silently discards every subsequent value the parent passes. If the DI container ever vends a new VM instance, the view keeps the stale one.

```swift
// BAD — ignores any new instance after first render
@State private var viewModel: MyViewModel
init(viewModel: MyViewModel) {
    self._viewModel = State(initialValue: viewModel)  // NG
}
```

`@Observable` tracks property access in `body` automatically — `@State` is not required for observation to work.

## Do

Use `let` for read-only access or `@Bindable` when two-way binding (`$vm.prop`) is needed.

```swift
// Read-only
let viewModel: MyViewModel
init(viewModel: MyViewModel) { self.viewModel = viewModel }

// Two-way binding required
@Bindable var viewModel: MyViewModel
init(viewModel: MyViewModel) { self.viewModel = viewModel }
```

| VM source | Binding needed? | Storage |
|-----------|----------------|---------|
| View creates inline | — | `@State private var vm = MyVM()` |
| Injected via init | No | `let vm: MyVM` |
| Injected via init | Yes (`$vm.prop`) | `@Bindable var vm: MyVM` |

`LibraryPickerView` uses `@Bindable` because it binds `$createViewModel.slideshowName` in a `TextField`. Most others (`ContentView`, `HomeView`, `SlideshowLibraryPanel`, `SlideshowPlayerView`) use `let`.

## Don't

- Don't use `State(initialValue:)` for injected `@Observable` objects.
- Don't add `@State` to an `@Observable` VM just to make observation work — it is automatic.
