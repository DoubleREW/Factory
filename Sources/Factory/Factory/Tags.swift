//
//  Tags.swift
//  
//
//  Created by Fausto Ristagno on 02/04/23.
//

import Foundation

public protocol Tag<T> {
    associatedtype T

    var name: String { get }
}

extension Tag {
    var name: String {
        String(reflecting: type(of: self))
    }
}

struct TaggedFactory<G: Tag> : AnyTaggedFactory {
    let tag: G
    let factory: Factory<G.T>
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

extension Factory {
    @discardableResult
    func tag<G: Tag>(_ tag: G, priority: Int = 0, alias: String? = nil) -> Self where G.T == Self.T {
        let taggedFactory = TaggedFactory(tag: tag, factory: self, priority: priority, alias: alias)

        if registration.container.manager.taggedFactories[tag.name] == nil {
            registration.container.manager.taggedFactories[tag.name] = [:]
        }

        registration.container.manager.taggedFactories[tag.name]![self.registration.id] = taggedFactory

        return self
    }
}


extension Container {
    func resolve<G: Tag>(tagged tag: G) -> [G.T] {
        let taggedFactories = self.manager.taggedFactories[tag.name] ?? [:]
        var results: [G.T] = []

        for anyTaggedFactory in taggedFactories.values.sorted(by: { $0.priority < $1.priority }) {
            guard let taggedFactory = anyTaggedFactory as? TaggedFactory<G> else {
                continue
            }

            let instance = taggedFactory.factory.resolve()
            results.append(instance)
        }

        return results
    }

    func resolveAssociative<G: Tag>(tagged tag: G) -> [String: G.T] {
        let taggedFactories = self.manager.taggedFactories[tag.name] ?? [:]
        var results: [String: G.T] = [:]

        for anyTaggedFactory in taggedFactories.values {
            guard let taggedFactory = anyTaggedFactory as? TaggedFactory<G> else {
                continue
            }

            guard let alias = taggedFactory.alias else {
                continue
            }

            let instance = taggedFactory.factory.resolve()
            results[alias] = instance
        }

        return results
    }
}
