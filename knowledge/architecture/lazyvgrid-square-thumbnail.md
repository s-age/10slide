---
type: gotcha
context: Displaying square thumbnail images inside a LazyVGrid cell
keywords: [LazyVGrid, thumbnail, square, aspectRatio, scaledToFill, scaledToFit, hit-testing, layout]
---

## What

Two common approaches break square thumbnails in `LazyVGrid`:

1. `scaledToFill()` — clips visually but the image's layout size still extends beyond the `ZStack` frame, corrupting hit-testing for overlaid buttons.
2. `.aspectRatio(1, contentMode: .fill)` alone — `LazyVGrid` proposes an infinite height, so `.fill` cannot determine a fixed ratio and the cell does not become square.

## Do

Fix width first with `frame(maxWidth: .infinity)`, then lock the height to match with `aspectRatio(1, contentMode: .fit)`. Use `scaledToFit()` so the image never overflows its frame.

```swift
ZStack {
    Color.gray.opacity(0.15)           // letterbox background
    if let nsImage = image {
        Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()             // stays within frame
    }
}
.frame(maxWidth: .infinity)            // pin width to column width
.aspectRatio(1, contentMode: .fit)     // height = width → square
.clipShape(RoundedRectangle(cornerRadius: 6))
```

The background colour fills the letterbox margins for images that don't fill the square.

## Don't

- Don't use `scaledToFill()` in grid cells that have overlaid interactive elements — layout overflow breaks hit-testing.
- Don't rely on `.aspectRatio(1, contentMode: .fill)` without first establishing a finite width.
