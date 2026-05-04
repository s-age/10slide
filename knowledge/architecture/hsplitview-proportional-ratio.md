---
type: gotcha
context: Using HSplitView and expecting pane widths to stay proportional as the window grows
keywords: [HSplitView, layout, proportional, GeometryReader, idealWidth, maxWidth, split-view]
---

## What

`HSplitView` distributes extra space **equally** across panes when the window grows. Setting `idealWidth` only affects the initial layout; as the window enlarges the split collapses toward 50/50 regardless of ideal values.

## Do

Wrap in `GeometryReader` and set `maxWidth` to the desired fraction of the total width. Because `geometry.size.width` updates on every resize, the ratio is preserved across all window sizes.

```swift
GeometryReader { geometry in
    HSplitView {
        LeftPane()
            .frame(
                minWidth: 200,
                idealWidth: geometry.size.width * 0.3,
                maxWidth: geometry.size.width * 0.3
            )
        RightPane()
            .frame(minWidth: 400)
    }
}
```

The user can still drag the divider, but the left pane is capped at 30 % of the window width.

## Don't

- Don't rely on `idealWidth` alone to maintain proportional splits after window resize.
- Don't use this approach when the user needs to freely drag the divider rightward past the cap — a custom `HStack` + drag gesture is required instead.
