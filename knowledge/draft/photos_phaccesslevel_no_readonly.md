# PHAccessLevel Has No `.readOnly` Member

## Fact

`PHAccessLevel` (Photos framework) has exactly two cases:

```swift
public enum PHAccessLevel {
    case addOnly    // can add assets, cannot read existing library
    case readWrite  // full read + write access
}
```

There is **no** `.readOnly` case. Any code using `PHAccessLevel.readOnly` will fail to compile:

```
error: Type 'PHAccessLevel' has no member 'readOnly'
```

## Why This Matters

LLMs (including Gemini and Claude) hallucinate `.readOnly` because it sounds logical. If an AI suggests `PHAccessLevel.readOnly`, reject it immediately — it does not exist.

For read-only access to the photo library, use `.readWrite`. There is no way to request only read permission; iOS/macOS always presents the full read+write permission prompt when using `.readWrite`.

## References

- `Sources/Infrastructure/Image/ImageDataSource.swift` (uses `.readWrite`)
