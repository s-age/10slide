# UseCases/Requests Layer

New directory: `Sources/UseCases/Requests/`

---

## `Sources/UseCases/Requests/UseCaseRequest.swift` (new)

**Protocol** — base contract for all request types:
```swift
protocol UseCaseRequest: Sendable {
    func validate() throws
}
```

## `Sources/UseCases/Requests/ValidationError.swift` (new)

```swift
import Foundation

enum ValidationError: Error, Sendable {
    case emptyName
    case noIdentifiers
    case invalidIndex
    case noSlides
}
```

---

## Slideshow Requests

### `Sources/UseCases/Requests/CreateSlideshowRequest.swift` (new)

```swift
import Foundation

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let localIdentifiers: [String]
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
```

### `Sources/UseCases/Requests/UpdateSlideshowRequest.swift` (new)

```swift
import Foundation

struct UpdateSlideshowRequest: UseCaseRequest {
    let id: UUID
    let name: String
    let localIdentifiers: [String]

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
```

### `Sources/UseCases/Requests/DeleteSlideshowRequest.swift` (new)

```swift
import Foundation

struct DeleteSlideshowRequest: UseCaseRequest {
    let id: UUID

    func validate() throws {}
}
```

### `Sources/UseCases/Requests/FetchSlideshowRequest.swift` (new)

```swift
import Foundation

struct FetchSlideshowRequest: UseCaseRequest {
    let id: UUID

    func validate() throws {}
}
```

### `Sources/UseCases/Requests/FetchSlideshowsRequest.swift` (new)

```swift
struct FetchSlideshowsRequest: UseCaseRequest {
    func validate() throws {}
}
```

---

## Image Requests

### `Sources/UseCases/Requests/FetchLibraryRequest.swift` (new)

```swift
struct FetchLibraryRequest: UseCaseRequest {
    func validate() throws {}
}
```

### `Sources/UseCases/Requests/LoadSlideImageRequest.swift` (new)

```swift
struct LoadSlideImageRequest: UseCaseRequest {
    let localIdentifier: String

    func validate() throws {}
}
```

### `Sources/UseCases/Requests/LoadThumbnailRequest.swift` (new)

```swift
struct LoadThumbnailRequest: UseCaseRequest {
    let localIdentifier: String

    func validate() throws {}
}
```

### `Sources/UseCases/Requests/SetDirectoryRequest.swift` (new)

```swift
import Foundation

struct SetDirectoryRequest: UseCaseRequest {
    let url: URL

    func validate() throws {}
}
```

### `Sources/UseCases/Requests/AddDroppedFilesRequest.swift` (new)

```swift
import Foundation

struct AddDroppedFilesRequest: UseCaseRequest {
    let urls: [URL]
    let existingIdentifiers: [String]

    func validate() throws {}
}
```

---

## Config Requests

### `Sources/UseCases/Requests/LoadConfigRequest.swift` (new)

```swift
struct LoadConfigRequest: UseCaseRequest {
    func validate() throws {}
}
```

### `Sources/UseCases/Requests/SaveConfigRequest.swift` (new)

```swift
struct SaveConfigRequest: UseCaseRequest {
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {}
}
```

---

## Playback Requests

### `Sources/UseCases/Requests/AdvanceSlideRequest.swift` (new)

```swift
struct AdvanceSlideRequest: UseCaseRequest {
    let totalSlides: Int
    let currentIndex: Int
    let loop: Bool

    func validate() throws {
        guard totalSlides > 0 else { throw ValidationError.noSlides }
        guard currentIndex >= 0, currentIndex < totalSlides else {
            throw ValidationError.invalidIndex
        }
    }
}
```

### `Sources/UseCases/Requests/PreviousSlideRequest.swift` (new)

```swift
struct PreviousSlideRequest: UseCaseRequest {
    let totalSlides: Int
    let currentIndex: Int
    let loop: Bool

    func validate() throws {
        guard totalSlides > 0 else { throw ValidationError.noSlides }
        guard currentIndex >= 0, currentIndex < totalSlides else {
            throw ValidationError.invalidIndex
        }
    }
}
```

### `Sources/UseCases/Requests/UpdateSlideshowConfigRequest.swift` (new)

```swift
import Foundation

struct UpdateSlideshowConfigRequest: UseCaseRequest {
    let slideshowID: UUID
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {}
}
```
