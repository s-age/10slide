---
type: discovery
context: Setting the macOS window title bar from SwiftUI without NavigationStack
keywords: [macOS, navigationTitle, window title, WindowGroup, SwiftUI]
---

## What

On macOS, `.navigationTitle()` applied to the root view inside a `WindowGroup` sets
the window's title bar text — even without a `NavigationStack` or
`NavigationSplitView` parent. Setting `""` effectively hides the title text while
keeping the title bar chrome visible.

## Do

- Use `.navigationTitle()` on each root view branch to control the window title:
  ```swift
  // In ContentView inside WindowGroup:
  SlideshowPlayerView(...)
      .navigationTitle(slideshow.name)   // → title bar shows slideshow name

  HomeView(...)
      .navigationTitle("")               // → title bar shows nothing
  ```
- Apply the modifier to each branch of an `if`/`else` in the root view to
  conditionally control the title based on app state.

## Don't

- Don't reach for `NSViewRepresentable` + `nsView.window?.title` to set the window
  title — `.navigationTitle()` is the idiomatic SwiftUI approach and works correctly
  on macOS 26.
- Don't assume `NavigationStack` or `NavigationSplitView` is required for
  `.navigationTitle()` to affect the window title bar on macOS.
