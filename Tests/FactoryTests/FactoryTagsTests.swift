import XCTest
@testable import Factory

struct MyTag1 : Tag {
    typealias T = MyServiceType
}

struct MyTag2 : Tag {
    typealias T = MyServiceType
}

struct MyTag3 : Tag {
    typealias T = ValueProviding
}

extension Tag where Self == MyTag1 {
    static var myTag1: MyTag1 { MyTag1() }
}

extension Tag where Self == MyTag2 {
    static var myTag2: MyTag2 { MyTag2() }
}

extension Tag where Self == MyTag3 {
    static var myTag3: MyTag3 { MyTag3() }
}

extension Container {
    var myTaggedService1: Factory<MyServiceType> {
        self {
            MockServiceN(1)
        }
    }

    var myTaggedService2: Factory<MyServiceType> {
        self {
            MockServiceN(2)
        }
    }

    var myUntaggedService: Factory<MyServiceType> {
        self {
            MockServiceN(3)
        }
    }

    var myTaggedService3: Factory<MyServiceType> {
        self {
            MockServiceN(4)
        }
    }
}

final class FactoryTagsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Container.shared = Container()
    }
    
    func testTags() {
        Container.shared.myTaggedService1.tag(.myTag1)
        Container.shared.myTaggedService2.tag(.myTag1)
        Container.shared.myTaggedService3.tag(.myTag2)

        let services1 = Container.shared.resolve(tagged: .myTag1)
        XCTAssertEqual(services1.count, 2)

        let services2 = Container.shared.resolve(tagged: .myTag2)
        XCTAssertEqual(services2.count, 1)
    }

    func testTagsAssociative() {
        Container.shared.myTaggedService1.tag(.myTag1, alias: "myServiceA.1")
        Container.shared.myTaggedService2.tag(.myTag1, alias: "myServiceA.2")
        Container.shared.myTaggedService3.tag(.myTag2, alias: "myServiceB.1")

        let services1 = Container.shared.resolveAssociative(tagged: .myTag1)
        XCTAssertEqual(services1.count, 2)
        XCTAssertNotNil(services1["myServiceA.1"])
        XCTAssertNotNil(services1["myServiceA.2"])

        let services2 = Container.shared.resolveAssociative(tagged: .myTag2)
        XCTAssertEqual(services2.count, 1)
        XCTAssertNotNil(services2["myServiceB.1"])
    }
}
