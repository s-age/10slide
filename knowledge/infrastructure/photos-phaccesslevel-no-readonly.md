---
type: gotcha
context: when requesting Photos library access level
keywords: [Photos, PHAccessLevel, readOnly, readWrite, addOnly, hallucination]
---

## What

`PHAccessLevel` has exactly two cases: `.addOnly` and `.readWrite`. There is no `.readOnly` case.
Code using `PHAccessLevel.readOnly` fails to compile:

```
error: Type 'PHAccessLevel' has no member 'readOnly'
```

LLMs (including Claude and Gemini) frequently hallucinate `.readOnly` because the name sounds
logical. To read the photo library, `.readWrite` is the only option; macOS/iOS always presents
the full read+write permission prompt.

See `Sources/Infrastructure/Image/ImageDataSource.swift` (uses `.readWrite`).

## Do

Use `.readWrite` for any operation that needs to read photos:

```swift
let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
```

## Don't

- Don't use `PHAccessLevel.readOnly` — it does not exist and will not compile.
- Don't assume an AI-suggested `PHAccessLevel` case is valid without checking the SDK docs.
