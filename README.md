[![](https://img.shields.io/github/tag/radianttap/Alley.svg?label=current)](https://github.com/radianttap/Alley/releases)
![platforms: iOS|tvOS|watchOS|macOS](https://img.shields.io/badge/platform-iOS|tvOS|watchOS|macOS-blue.svg)
[![](https://img.shields.io/github/license/radianttap/Alley.svg)](https://github.com/radianttap/Alley/blob/master/LICENSE)
![](https://img.shields.io/badge/swift-5.5-223344.svg?logo=swift&labelColor=FA7343&logoColor=white)
[![SwiftPM ready](https://img.shields.io/badge/SwiftPM-ready-FA7343.svg?style=flat)](https://swift.org/package-manager/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-AD4709.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods compatible](https://img.shields.io/badge/CocoaPods-compatible-fb0006.svg)](https://cocoapods.org)

# Alley

Essential `URLSessionDataTask` micro-wrapper for communication with HTTP(S) web services. This is built as framework but it’s so small that I encourage you to simply copy the Alley folder into your project directly.

## Why

In most cases where you need to fetch something from the internet, you:

1. Want to get the data at the URL you are targeting, no matter what
2. In case when it’s simply not possible, display some useful error to the end-customer *and* display / log what error actually happened so you can troubleshoot and debug

Second point is nice to have. First one is vastly more important since that data is the reason you are doing this at all.

> Thus main feature of Alley is **automatic request retries** for predefined conditions.

## Integration

### Manually 

Just drag `Alley` folder into your project.

If you prefer to use dependency managers, see below. 
Releases are tagged with [Semantic Versioning](https://semver.org) in mind.

### Swift Package Manager 

Ready, just add this repo URL as Package. 

- Version 2.x supports old school stuff with completion handlers.
- Version 3.x is pure `async`/`await`.

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Alley into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'Alley', 	:git => 'https://github.com/radianttap/Alley.git'
```

### Setting up with Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Alley into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "radianttap/Alley"
```


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

///	URLSession returned an `Error` object which is not `URLError`
case generalError(Swift.Error)
```

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

There’s one more possible `NetworkError` value, which is related to...

## Automatic retries

Default number of retries is `10`.

This value is automatically used for all networking calls but you can adjust it per call by simply supplying appropriate number to `maxRetries` argument:

```swift
let urlRequest = URLRequest(...)

let data = try await urlSession.alleyData(for: urlRequest, maxRetries: 5)
```

How automatic retries work? 

In case of a `NetworkError` being raised, _Alley_ will check its `shouldRetry` property and – if that’s `true` – it will increment retry counter by 1 and perform `URLSessionDataTask` again. And again. And again...until it reaches `maxRetries` value when it will return `NetworkError.inaccessible` as result.

Each retry is delayed by half a second (see `NetworkError.defaultRetryDelay`).

You can customize the behavior by changing the implementation of `shouldRetry` property. 

* * *

That’s about it. _Alley_ is intentionally simple to encourage writing as little code as possible, hiding away often-repeated boilerplate.

## License

[MIT License,](https://github.com/radianttap/Alley/blob/v2/LICENSE) like all my open source code.

## Give back

If you found this code useful, please consider [buying me a coffee](https://www.buymeacoffee.com/radianttap) or two. ☕️😋
