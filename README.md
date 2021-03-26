[![](https://img.shields.io/github/tag/radianttap/Alley.svg?label=current)](https://github.com/radianttap/Alley/releases)
![platforms: iOS|tvOS|watchOS|macOS](https://img.shields.io/badge/platform-iOS|tvOS|watchOS|macOS-blue.svg)
[![](https://img.shields.io/github/license/radianttap/Alley.svg)](https://github.com/radianttap/Alley/blob/master/LICENSE)
![](https://img.shields.io/badge/swift-5-223344.svg?logo=swift&labelColor=FA7343&logoColor=white)
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

Thus main feature of Alley is **automatic request retries** for predefined conditions.

## Usage

You would already have some `URLSession` instance to work with. Then instead of this:

```swift
let urlRequest = URLRequest(...)

urlSession.dataTask(with: urlRequest) {
	data, urlResponse, error in
	//...process error, response, data
}

task.resume()
```

with Alley you will do this:

```swift
let urlRequest = URLRequest(...)

urlSession.performNetworkRequest(urlRequest) {
	dataResult in
	//...process dataResult
}
```

That’s the basic change, now let’s see what is this `NetworkResult` in the callback.

### NetworkResult

This is your standard Swift’s Result type, defined like this:

```swift
typealias NetworkResult = Result<Data, NetworkError>
```

In case the request was successful, you would get the `Data` instance returned from the service which you can convert into whatever you expected it to be.

In case of failure, you get an instance of `NetworkError`.

### NetworkError

This is custom Error (implemented by an enum) which – for starters – wraps stuff returned by `URLSessionDataTask`. Thus first few possible options are:

```swift
///	`URLSession` errors are passed-through, handle as appropriate.
case urlError(URLError)

///	URLSession returned an `Error` object which is not `URLError`
case generalError(Swift.Error)
```

Then it handles the least possible scenario to happen: no error returned by `URLSessionDataTask` but also no `URLResponse`.

```swift
case noResponse
```

Next, if the returned `URLResponse` is not `HTTPURLResponse`:

```swift
case invalidResponseType(URLResponse)
```

Now, if it is `HTTPURLResponse` but status code is `400` or higher, this is an error returned by the web service endpoint you are communicating with. Hence return the entire `HTTPURLResponse` and `Data` (if it exists) so caller can figure out what happened.

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

urlSession.perform(urlRequest, allowEmptyData: true) {
	dataResult in
	//...process dataResult
}
```

where you will get empty `Data()` instance as `DataResult.success`.

There’s one more possible `NetworkError` value, which is related to...

## Automatic retries

Default number of retries is `10`.

This value is automatically used for all `perform()` calls but you can adjust it per call by simply supplying appropriate number to `maxRetries` argument:

```swift
let urlRequest = URLRequest(...)

urlSession.perform(urlRequest, maxRetries: 5) {
	dataResult in
	//...process dataResult
}
```

How automatic retries work? 

In case of a `NetworkError` being raised, Alley will check its `shouldRetry` property and – if that’s `true` – it will increment retry counter by 1 and perform `URLSessionDataTask` again. And again. And again...until it reaches `maxRetries` value when it will return `NetworkError.inaccessible` as result.

There is currently no delay between retries, it simply tries again.

You can customize the behavior by changing the implementation of `shouldRetry` property. 
Currently it deals only with `NetworkError.urlError` and returns `true` for several obvious `URLError` instances.

* * *

That’s about it. Alley is intentionally simple to encourage writing as little code as possible, hiding away often-repeated boilerplate.

## License

[MIT License,](https://github.com/radianttap/Alley/blob/v2/LICENSE) like all my open source code.

