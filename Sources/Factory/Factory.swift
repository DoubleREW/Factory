//
// Factory.swift
//
// GitHub Repo and Documentation: https://github.com/hmlongco/Factory
//
// Copyright ©2022 Michael Long. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation

/// Factory manages the dependency injection process for a given object or service.
public struct Factory<T> {
    /// Initializes a Factory with a factory closure that returns a new instance of the desired type.
    public init(factory: @escaping () -> T) {
        self.factory = factory
    }
    /// Initializes with factory closure that returns a new instance of the desired type. The scope defines the lifetime of that instance.
    public init(scope: SharedContainer.Scope, factory: @escaping () -> T) {
        self.factory = factory
        self.scope = scope
    }
    /// Returns an instance of the desired object type. This may be a new instances or one that was created previously and then cached,
    /// depending on whether or not a scope was specified when the factory was created.
    public func callAsFunction() -> T {
        let id = Int(bitPattern: ObjectIdentifier(T.self))
        if let instance: T = scope?.cached(id) {
            SharedContainer.Decorator.cached?(instance)
            return instance
        } else {
            let instance = SharedContainer.Registrations.registered(id) ?? factory()
            scope?.cache(id: id, instance: instance)
            SharedContainer.Decorator.created?(instance)
            return instance
        }
    }
    /// Registers a new factory that will be used to create and return an instance of the desired object type.
    ///
    /// This registration overrides the orginal factory and its result will be returned on all new object resolutions. Registering a new
    /// factory also clears the previous instance from the associated scope.
    ///
    /// All registrations are stored in SharedContainer.Registrations.
    public func register(factory: @escaping () -> T) {
        let id = Int(bitPattern: ObjectIdentifier(T.self))
        SharedContainer.Registrations.register(id: id, factory: factory)
        scope?.reset(id)
    }
    /// Deletes any registered factory override and resets this Factory to use the factory closure specified during initialization. Also
    /// resets the scope so that a new instance of the original type will be returned on the next resolution.
    public func reset() {
        let id = Int(bitPattern: ObjectIdentifier(T.self))
        SharedContainer.Registrations.reset(id)
        scope?.reset(id)
    }
    private var factory: () -> T
    private var scope: SharedContainer.Scope?
}

/// Empty convenience class for user dependencies.
public class Container: SharedContainer {

}

/// Base class for all containers.
open class SharedContainer {

    public class Registrations {
        /// Pushes the current set of registration overrides onto a stack. Useful when testing when you want to push the current set of registions,
        /// add your own, test, then pop the stack to restore the world to its original state.
        public static func push() {
            defer { lock.unlock() }
            lock.lock()
            stack.append(registrations)
        }
        /// Pops a previously pushed registration stack. Does nothing if stack is empty.
        public static func pop() {
            defer { lock.unlock() }
            lock.lock()
            if let registrations = stack.popLast() {
                self.registrations = registrations
            }
        }
        /// Resets and deletes all registered factory overrides.
        public static func reset() {
            defer { lock.unlock() }
            lock.lock()
            registrations = [:]
        }

        /// Internal function used by Factory
        fileprivate static func register<T>(id: Int, factory: @escaping () -> T) {
            defer { lock.unlock() }
            lock.lock()
            registrations[id] = factory
        }
        /// Internal function used by Factory
        fileprivate static func registered<T>(_ id: Int) -> T? {
            defer { lock.unlock() }
            lock.lock()
            if let registration = registrations[id] {
                let result = registration()
                if let optional = result as? T? {
                    return optional
                }
                return result as? T
            }
            return nil
        }
        /// Internal function used by Factory
        fileprivate static func reset(_ id: Int) {
            defer { lock.unlock() }
            lock.lock()
            registrations.removeValue(forKey: id)
        }

        private static var registrations: [Int:() -> Any] = [:]
        private static var stack: [[Int:() -> Any]] = []
        private static var lock = NSRecursiveLock()
    }

    /// Defines the base implementation of a scope.
    public class Scope {
        private init() {}
        fileprivate func cached<T>(_ id: Int) -> T? {
            fatalError()
        }
        fileprivate func cache(id: Int, instance: Any) {
            fatalError()
        }
        fileprivate func reset(_ id: Int) {}
        public func reset() {}
    }

    /// Defines decorator functions that will be called when a factory is resolved.
    public struct Decorator {
        /// Decorator function that will be called when a factory is resolved and the instance is retrieved from a scope cache. Useful for logging.
        public static var cached: ((_ dependency: Any) -> Void)?
        /// Decorator function that will be called when a factory is resolved and a new instance is created. Useful for logging.
        public static var created: ((_ dependency: Any) -> Void)?
    }
}

extension SharedContainer.Scope {

    /// Instance of the cached scope. The same instance will be returned by the factory until the cache is reset.
    public static let cached = Cached()
    /// Instance of the shared (weak) scope. The same instance will be returned by the factory as long as someone maintains a strong reference.
    public static let shared = Shared()
    /// Instance of the singleton scope. Once created, one and only once instance of the object will be created and returned by the factory.
    public static let singleton = Cached()

    /// Defines the cached scope. The same instance will be returned by the factory until the cache is reset.
    public final class Cached: SharedContainer.Scope {
        public override init() {}
        /// Resets the cache. Anything using this cache will return a new instance after the cache is reset.
        public override func reset() {
            defer { lock.unlock() }
            lock.lock()
            cache = [:]
        }
        fileprivate override func cached<T>(_ id: Int) -> T? {
            defer { lock.unlock() }
            lock.lock()
            return cache[id] as? T
        }
        fileprivate override func cache(id: Int, instance: Any) {
            defer { lock.unlock() }
            lock.lock()
            cache[id] = instance
        }
        fileprivate override func reset(_ id: Int) {
            defer { lock.unlock() }
            lock.lock()
            cache.removeValue(forKey: id)
        }
        private var cache = [Int:Any](minimumCapacity: 32)
        private var lock = NSRecursiveLock()
    }

    /// Defines the shared (weak) scope. The same instance will be returned by the factory as long as someone maintains a strong reference.
    public final class Shared: SharedContainer.Scope {
        public override init() {}
        /// Resets the cache. Anything using this cache will return a new instance after the cache is reset.
        public override func reset() {
            defer { lock.unlock() }
            lock.lock()
            cache = [:]
        }
        fileprivate override func cached<T>(_ id: Int) -> T? {
            defer { lock.unlock() }
            lock.lock()
            return cache[id]?.instance as? T
        }
        fileprivate override func cache(id: Int, instance: Any) {
            defer { lock.unlock() }
            lock.lock()
            cache[id] = WeakBox(instance: instance as AnyObject)
        }
        fileprivate override func reset(_ id: Int) {
            defer { lock.unlock() }
            lock.lock()
            cache.removeValue(forKey: id)
        }
        private struct WeakBox {
            weak var instance: AnyObject?
        }
        private var cache = [Int:WeakBox](minimumCapacity: 32)
        private var lock = NSRecursiveLock()
    }

}

/// Convenience property wrappeer takes a factory and creates an instance of the desired type.
@propertyWrapper public struct Injected<T> {
    private var factory:  Factory<T>
    private var dependency: T
    public init(_ factory: Factory<T>) {
        self.dependency = factory()
        self.factory = factory
    }
    public var wrappedValue: T {
        get { return dependency }
        mutating set { dependency = newValue }
    }
    public var projectedValue: Factory<T> {
        get { return factory }
    }
}

/// Convenience property wrappeer takes a factory and creates an instance of the desired type the first time the wrapped value is requested.
@propertyWrapper public struct LazyInjected<T> {
    private var factory:  Factory<T>
    private var dependency: T!
    public init(_ factory: Factory<T>) {
        self.factory = factory
    }
    public var wrappedValue: T {
        mutating get {
            if dependency == nil {
                dependency = factory()
            }
            return dependency
        }
        mutating set {
            dependency = newValue
        }
    }
    public var projectedValue: Factory<T> {
        get { return factory }
    }
}
