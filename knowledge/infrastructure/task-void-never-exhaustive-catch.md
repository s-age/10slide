---
type: gotcha
context: Task<Void, Never> bodies containing try inside a do-catch
keywords: [Task, Void, Never, do-catch, exhaustive catch, CancellationError, Swift concurrency, type mismatch]
---

## What

`Task<Void, Never>` requires a non-throwing closure. A pattern-match-only catch (`catch is CancellationError { return }`) is not exhaustive — Swift infers the closure as throwing and promotes the Task type to `Task<Void, Error>`, causing a type mismatch at the assignment site.

```swift
// NG — closure becomes throwing; type mismatch with Task<Void, Never>
hideFilmstripTask = Task {
    do { try await Task.sleep(for: duration) } catch is CancellationError { return }
}
```

## Do

Add a fallback `catch` clause to make the do-catch exhaustive:

```swift
hideFilmstripTask = Task {
    do {
        try await Task.sleep(for: duration)
    } catch is CancellationError {
        return
    } catch {
        return  // satisfies exhaustiveness requirement
    }
}
```

Or collapse to a bare `catch { return }` when distinguishing error types is unnecessary.

## Don't

Use a pattern-only catch as the sole catch clause inside a `Task<Void, Never>` body — it compiles fine in throwing contexts but silently changes the Task's error type in non-throwing ones.
