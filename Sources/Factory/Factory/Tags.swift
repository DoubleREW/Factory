//
//  Tags.swift
//  
//
//  Created by Fausto Ristagno on 02/04/23.
//

import Foundation

public protocol Tag<S> {
    associatedtype S

    var name: String { get }
}

extension Tag {
    var name: String {
        String(reflecting: type(of: self))
    }
}

struct TaggedFactory<C: SharedContainer, T: Tag> : AnyTaggedFactory {
    let tag: T
    let factoryKeyPath: KeyPath<C, Factory<T.S>>
    let priority: Int
    let alias: String?

    var tagName: String {
        return tag.name
    }
}

protocol AnyTaggedFactory {
    var tagName: String { get }
    var priority: Int { get }
    var alias: String? { get }
}

// FactoryModifying tagging

extension SharedContainer {
    fileprivate func _tag<C: SharedContainer, T: Tag>(_ keyPath: KeyPath<C, Factory<T.S>>, as tag: T, priority: Int = 0, alias: String? = nil) {
        let taggedFactory = TaggedFactory(
            tag: tag,
            factoryKeyPath: keyPath,
            priority: priority,
            alias: alias)

        if manager.taggedFactories[tag.name] == nil {
            manager.taggedFactories[tag.name] = [:]
        }

        manager.taggedFactories[tag.name]![C.shared[keyPath: keyPath].registration.id] = taggedFactory
    }

    func tag<C: SharedContainer, T: Tag>(_ keyPath: KeyPath<C, Factory<T.S>>, as tag: T, priority: Int = 0, alias: String? = nil) {
        _tag(keyPath, as: tag, priority: priority, alias: alias)
    }

    func resolve<T: Tag>(tagged tag: T) -> [T.S] {
        let taggedFactories = manager.taggedFactories[tag.name] ?? [:]
        var results: [T.S] = []

        for anyTaggedFactory in taggedFactories.values.sorted(by: { $0.priority < $1.priority }) {
            guard let taggedFactory = anyTaggedFactory as? TaggedFactory<Self, T> else {
                continue
            }

            let instance = self[keyPath: taggedFactory.factoryKeyPath].resolve()
            results.append(instance)
        }

        return results
    }

    func resolveAssociative<T: Tag>(tagged tag: T) -> [String: T.S] {
        let taggedFactories = self.manager.taggedFactories[tag.name] ?? [:]
        var results: [String: T.S] = [:]

        for anyTaggedFactory in taggedFactories.values {
            guard let taggedFactory = anyTaggedFactory as? TaggedFactory<Self, T> else {
                continue
            }

            guard let alias = taggedFactory.alias else {
                continue
            }

            let instance = self[keyPath: taggedFactory.factoryKeyPath].resolve()
            results[alias] = instance
        }

        return results
    }
}

extension Container {
    func tag<T: Tag>(_ keyPath: KeyPath<Container, Factory<T.S>>, as tag: T, priority: Int = 0, alias: String? = nil) {
        _tag(keyPath, as: tag, priority: priority, alias: alias)
    }
}
