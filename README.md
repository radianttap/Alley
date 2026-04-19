[![](https://img.shields.io/github/tag/radianttap/Alley.svg?label=current)](https://github.com/radianttap/Alley/releases)
[![](https://img.shields.io/github/license/radianttap/Alley.svg)](https://github.com/radianttap/Alley/blob/master/LICENSE)
![](https://img.shields.io/badge/swift-6.0-223344.svg?logo=swift&labelColor=FA7343&logoColor=white)
\
![platforms: iOS|tvOS|watchOS|macOS|visionOS](https://img.shields.io/badge/platform-iOS_15_·_tvOS_15_·_watchOS_10_·_macOS_12_·_visionOS_1-blue.svg)

# Alley

Essential `URLSessionDataTask` micro-wrapper for communication with HTTP(S) web services. 

## Why

In most cases where you need to fetch something from the internet, you:

1. Want to get the data at the URL you are targeting, no matter what
2. In case when it’s simply not possible, display some useful error to the end-customer *and* display / log what error actually happened so you can troubleshoot and debug

Second point is nice to have. First one is vastly more important since that data is the reason you are doing this at all.

> Thus main feature of Alley is **automatic request retries** for predefined conditions.

## Integration

Just drag `Alley` folder into your project.

Or just add this repo’s URL through Swift Package Manager.

- Version 2.x supports old school stuff with completion handlers.
- Version 3.x is pure `async`/`await`.
- Version 4.x runs in Swift 6 language mode with strict concurrency. Adds exponential backoff with jitter, `Retry-After` support, 429 retries, an idempotency guard, `Task` cancellation propagation, `Sendable` conformance on `NetworkError`, download/upload/streaming variants, per-request `URLSessionTaskDelegate`, and OSLog logging.

## Usage

You would already have some `URLSession` instance to work with. Then instead of this:

```swift
let urlRequest = URLRequest(...)

do {
	let data = try await urlSession.data(for: urlRequest)
} catch let err {
	//...process error
}
```

with _Alley_ you will do this:

```swift
let urlRequest = URLRequest(...)

do {
	let data = try await urlSession.alleyData(for: urlRequest)
} catch let err {
	//...process NetworkError
}
```

In case the request was successful, you would get the `Data` instance returned from the service which you can convert into whatever you expected it to be.

In case of failure you will get an instance of `NetworkError`.

### NetworkError

This is custom Error (implemented by an enum) which – for starters – wraps stuff returned by `URLSessionDataTask`. Thus first few possible options are:

```swift
///	`URLSession` errors are passed-through, handle as appropriate.
case urlError(URLError)

///	URLSession returned an `Error` object which is not `URLError`.
///	Constrained to `Sendable` so the whole enum can cross actor boundaries.
case generalError(any Error & Sendable)
```

If you need to wrap a non-`Sendable` error, convert it to a value type (or a `Sendable` wrapper) before constructing `.generalError`.

Next, if the returned `URLResponse` is not `HTTPURLResponse`:

```swift
case invalidResponseType(URLResponse)
```

Now, if it is `HTTPURLResponse` but status code is `400` or higher, this is an error returned by the web service endpoint you are communicating with. Hence you get the entire `HTTPURLResponse` and `Data` (if it exists) so caller can figure out what happened.

```swift
case endpointError(HTTPURLResponse, Data?)
```

In the calling object, you can use these values and try to build instances of strongly-typed custom errors related to the given specific web service.

If status code is in `2xx` range, you may have a case of missing response body. 

```swift
case noResponseData(HTTPURLResponse)
```

This may or may not be an error. If you perform `PUT` or `DELETE` or even `POST` requests, your service may not return any data as valid response (just `200 OK` or whatever). In that case, prevent this error by calling perform like this:

```swift
let urlRequest = URLRequest(...)

let data = try await urlSession.alleyData(for: urlRequest, allowEmptyData: true)
```

where you will get empty `Data()`.

There are two more possible `NetworkError` values. `.inaccessible` is covered in the next section. The other is:

```swift
///	The surrounding `Task` was cancelled before the request completed.
case cancelled
```

If the enclosing `Task` is cancelled – by the caller, by structured concurrency, or during the backoff sleep – Alley stops retrying immediately and throws `.cancelled`. `URLError.cancelled` (which `URLSession` throws on task cancellation) is mapped to the same case, so you don't need to special-case it. Use this to skip error UI when the user simply navigated away.

## Automatic retries

Default number of retries is `10`.

This value is automatically used for all networking calls but you can adjust it per call by simply supplying appropriate number to `maxRetries` argument:

```swift
let urlRequest = URLRequest(...)

let data = try await urlSession.alleyData(for: urlRequest, maxRetries: 5)
```

How automatic retries work?

In case of a `NetworkError` being raised, _Alley_ will check its `shouldRetry` property and – if `true` – it will increment retry counter by 1 and perform `URLSessionDataTask` again. And again. And again...until it reaches `maxRetries` value when it will return `NetworkError.inaccessible` as result.

The retryable set covers the usual transient conditions: `URLError.timedOut`, `.cannotFindHost`, `.cannotConnectToHost`, `.networkConnectionLost`, `.dnsLookupFailed`, `.notConnectedToInternet`, and HTTP `408`, `429`, `444`, `503`, `504`, `599`.

### Backoff and jitter

`retryInterval` (default `0.5` seconds) is the **base delay** for exponential backoff. The actual wait before the Nth retry is a random value in `[0, min(30s, base × 2^(N-1))]` – full jitter, capped at 30 seconds. Jitter is important: without it, many clients retrying at the same moment synchronize into a thundering herd against a recovering server.

```swift
let urlRequest = URLRequest(...)

let data = try await urlSession.alleyData(for: urlRequest, retryInterval: 0.3)
```

Pass `0` to retry immediately with no delay.

### Retry-After

If the server returns a `Retry-After` response header (per RFC 7231 – common on `429` and `503`), Alley honors it: the header value (either an integer number of seconds or an HTTP-date) replaces the computed backoff for that attempt. This prevents hammering a server that has explicitly told you how long to wait.

### Idempotency guard

By default, Alley **does not retry non-idempotent HTTP methods** (`POST`, `PATCH`, etc.). Replaying a `POST` after `networkConnectionLost` is a silent footgun: the original request may have reached the server and only the response was lost, which would cause a retry to double-submit.

Only `GET`, `HEAD`, `OPTIONS`, `TRACE`, `PUT`, and `DELETE` (RFC 7231 §4.2.2) are retried automatically. If you know a specific `POST` is safe to replay – for example, because your server supports an `Idempotency-Key` header – opt in per call:

```swift
let urlRequest = URLRequest(...) // POST with Idempotency-Key set

let data = try await urlSession.alleyData(for: urlRequest, retryNonIdempotent: true)
```

### Customizing

You can customize the behavior by changing the implementation of `shouldRetry` property (in this case I recommend to manually copy Alley folder into your project).

## Download, upload, and streaming

`alleyData` is the workhorse. The rest of the entry points reuse the same retry engine for other transport shapes.

### `alleyDownload(for:)`

Downloads the response body to a temporary file and returns `(URL, HTTPURLResponse)`. Use this when the response is large enough that buffering into memory is wasteful — video, PDFs, backups. Each retry starts a fresh download (resume data from a failed attempt is not reused).

```swift
let (fileURL, response) = try await urlSession.alleyDownload(for: urlRequest)
try FileManager.default.moveItem(at: fileURL, to: destination)
```

### `alleyUpload(for:from:)`

Uploads a `Data` body and returns the response `Data`. Because uploads are almost always non-idempotent, the idempotency guard is in force by default — opt in with `retryNonIdempotent: true` when your server deduplicates.

```swift
let response = try await urlSession.alleyUpload(for: urlRequest, from: bodyData)
```

### `alleyBytes(for:)`

Wraps `URLSession.bytes(for:)` for streaming responses (SSE, NDJSON, long poll, progressive audio/video). **Does not retry** — an `AsyncBytes` stream isn't safe to replay once iteration has started. On an HTTP error status, Alley consumes the small error body and surfaces it through `.endpointError` so you see why the server rejected the stream.

```swift
let (bytes, response) = try await urlSession.alleyBytes(for: urlRequest)
for try await line in bytes.lines {
    // process one event per line
}
```

## Metrics, auth, and progress: `URLSessionTaskDelegate`

Every Alley call accepts an optional `URLSessionTaskDelegate`, which `URLSession` attaches for the duration of each task. Use it to gather `URLSessionTaskMetrics`, handle per-task authentication challenges, or observe upload/download progress — without having to switch to a custom `URLSession` configuration.

```swift
let data = try await urlSession.alleyData(for: urlRequest, delegate: myTelemetryDelegate)
```

The same delegate is reused across retry attempts, so telemetry callbacks fire once per attempt and can be correlated by `URLSessionTask.taskIdentifier`.

## Logging

Alley emits retry decisions via `OSLog` under the subsystem `Alley`, category `retries`:

- `.debug` on each scheduled retry (attempt number, delay, URL, error reason)
- `.debug` when a request is refused due to the idempotency guard
- `.error` when retries are exhausted

These messages are off by default. Enable them for troubleshooting with:

```
log config --mode level:debug --subsystem Alley
```

or filter by subsystem `Alley` in Console.app. No API surface is added; callers who want structured telemetry per attempt should use the `delegate:` parameter with `URLSessionTaskMetrics`.

* * *

That’s about it. _Alley_ is intentionally simple to encourage writing as little code as possible, hiding away often-repeated boilerplate.

## License

[MIT License,](https://github.com/radianttap/Alley/blob/v2/LICENSE) like all my open source code.

## Give back

If you found this code useful, please consider [buying me a coffee](https://www.buymeacoffee.com/radianttap) or two. ☕️😋
