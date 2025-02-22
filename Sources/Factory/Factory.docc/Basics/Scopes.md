# Scopes

Not everything wants to be a Singleton. Learn the power of Scopes.

## Overview

If you've used Resolver or some other dependency injection system before then you've probably experienced the benefits and power of scopes.

And if not, the concept is easy to understand: Just how long should an instance of an object live?

You've no doubt stuffed an instance of a class into a variable and created a singleton at some point in your career. This is an example of a scope. A single instance is created and then used and shared by all of the methods and functions in the app.

This is easily done in Factory.

## Singleton

Just specify a singleton factory.

```swift
extension Container {
    var myService: Factory<MyServiceType> { 
        self { MyService() }
            .singleton
    }
}
```
Now whenever someone requests an instance of `myService` they'll get the same instance of the object as everyone else.

> Note: Singletons are global, meaning that they're *not* managed or cached by any specific container. If we create two instances of the above container and resolve `myService` from both, we'll get the same instance from both.

## Unique

If no scope is specified the default scope is unique. A new instance of the service will be instantiated and returned each and every time one is requested from the factory.

## Other Scopes

Other common scopes are `cached` and `shared`. 

Cached items are persisted until the cache is reset, while shared items exist just as long as someone holds a strong reference to them. When the last reference goes away, the weakly held shared reference also goes away.

```swift
extension Container {
    var cachedService: Factory<MyServiceType> { 
        self { MyService() }.cached
    }
    var sharedService: Factory<MyServiceType> { 
        self { MyService() }.shared
    }
}
```

Unlike singletons, cached and shared scopes are managed by the container. If I create an instance of `Container` and use it to resolve `cachedService` three times, I'll get the same instance of the object each time.

But if we create two instances of the above container and resolve `cachedService` from both, we'll get two different instances of the service.

The cache is specific to the container.

## Custom Scopes

You can also add your own special purpose caches to the mix. Try this.

```swift
extension Scope {
    static var session = Cached()
}

extension Container {
    var authenticatedUser: Factory<AuthenticatedUser> { 
        self { AuthenticatedUser() }
            .scope(.session)
    }
    var profileImageCache: Factory<ProfileImageCache> { 
        self { ProfileImageCache() } 
            .scope(.session)
    }
}
```
Once created, a single instance of `AuthenticatedUser` and `ProfileImageCache` will be provided to anyone that needs one... up until the point where the session scope is reset, perhaps by a user logging out.

```swift
func logout() {
    Container.shared.manager.reset(scope: .session)
    ...
}
```
Scopes are powerful tools to have in your arsenal. Use them.

## Graph Scope

There's one additional scope, called `graph`. This scope will reuse any factory instances resolved during a given resolution cycle. This can come in handy when a single class implements multiple protocols. Consider the following...
```swift
class ProtocolConsumer {
    @Injected(\.idProvider) var ids
    @Injected(\.valueProvider) var values
    init() {}
}
```
The `ProtocolConsumer` wants two different protocols. But it doesn't know that a single class provides both services. (Nor should it care.) Take a look at the referenced factories.
```swift
extension Container {
    var consumer: Factory<ProtocolConsumer> { self { ProtocolConsumer() } }
    var idProvider: Factory<IDProviding> { self { commonProviding() } }
    var valueProvider: Factory<ValueProviding> { self { commonProviding() } }
    private var commonProviding: Factory<MyService> { graph { MyService() } }
}
```
Both provider factories reference the same factory. When Factory is asked for an instance of `consumer`, both providers will receive the same instance of `MyService`.

There are a few caveats and considerations for using graph. The first is that anyone who wants to participate in the graph needs to explicitly state as such using the graph scope. Note the scope parameter for `commonProviding`.

The second is that there needs to be a "root" to the graph. 

In the above example, the `consumer` object is the root. Factory is asked for a consumer, which in turn requires two providers. 

If you were to instantiate an instance of `ProtocolConsumer` yourself, each one of ProtocolConsumer's Injected property wrappers would initialize sequentially on the same thread, resulting in two separate and distinct resolution cycles.

See: <doc:Cycle> for more on this.

## Lifecycles

Scope caches for all types except singletons are maintained by the Factory's container.

> Warning: If a container ever goes out of scope, so will all of its registrations and cached objects.

See the "Releasing a Container" discussion in <doc:Containers> for more information.

## Default Scope

As mentioned earlier, the default scope for a new Factory is `unique`; a new instance will be created each and every time the Factory is resolved.

That default can be changed on a per-container basis.
```swift
extension Container: AutoRegistering {
    func autoRegister() {
        manager.defaultScope = .graph
        ...
    }
}
```
Now any Factory registration that doesn't specify a scope of its own will use the `graph` scope by default.

## Reset

As shown above, individual scope caches on a container can be reset (cleared) if needed.
```swift
Container.shared.manager.reset(scope: .cached)
```
Or you can reset the cache for all of the scopes managed by that container.
```swift
Container.shared.manager.reset(options: .scope)
```
As mentioned earlier, singletons are *not* managed by the container. If needed, the singleton scope can be reset directly.
```swift
Scope.singleton.reset()
```
> Important: Resetting a container or scope has no effect whatsoever on anything that's already been resolved by Factory. It only ensures that the *next* time a Factory is asked to resolve a dependency that dependency will be a new instance.

## Topics

### Scope Class Definitions

- ``Scope``
- ``Scope/Cached-swift.class``
- ``Scope/Graph-swift.class``
- ``Scope/Shared-swift.class``
- ``Scope/Singleton-swift.class``
