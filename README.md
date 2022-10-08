# ApiCenter
10行代码搞定一个极简版本的Swift组件方案

## 组件化方案与路由方案

组件化跟路由解决的主要问题还是有一些区别的。

组件化方案：处理的对象是模块（包含多个页面、服务等），主要是解决本地代码模块化后的跨模块调用场景（模块调用模块）（无解析过程）

路由方案：处理的对象单个页面或者单个服务，主要是解决远端、本地的单个业务调用（有解析过程，可能跨业务线）

组件化方案跟路由方案并不冲突，很多情况下是配合使用的：

1. 一个app只有一个固定的组件化方案，可以没有路由方案，也可以有多个路由方案
   1. app组件化要求一定要有组件化方案，但对路由并没有要求
   2. 组件化方案建议是固定的，路由方案可按需替换，甚至可以没有路由方案（这样的话，远端下发得手动处理）
2. 组件化方案跨业务调用是直观清晰明确（有具体类型）的，路由可能是基于 Map 的，调用起来不一定清晰明确（Map 内容很难直接知道是什么类型）
3. 组件化方案应该越简单越好，可公开的部分最好不要有实现，一定要稳定
4. 组件化方案与路由方案应该是相互独立的，组件化方案固定，路由方案可变且不能影响组件化方案（部分路由方案可直接被用于组件化方案，但会存在一些问题）

我们这次要做的就是搞一个极简版本的组件化方案，不包含任何路由方案的那种，但业务方在具体使用中又能使用任一路由方案。


## Protocol 方案

注意：不是 Protocol-Class 方案，是 Protocol 方案（无 class 注册流程）

要求：
1. 不依赖任何语言特性，任一语言均可实现
2. Protocol 与 IMP 分离，公开 Protocol，IMP 私有到具体业务库里，调用方只需关心 Protocol，无需关心 IMP
3. Protocol 方法出入参有明确类型，无硬编码

实现：
1. Map 存储：Protocol（key）、IMP（value），根据 Protocol 取 IMP
2. Map 提供注册、移除、查看等功能
3. IMP 自己实现 cache 等功能，与 Protocol 无关

```swift
public protocol ApiCenterProtocol {
    func registerApi<T>(type: T.Type, impBuilder: @escaping () -> T)
    func removeApi<T>(api: T.Type)
    func api<T>(type: T.Type) throws -> T?
    func isRegisteredApi<T>(api: T.Type) -> Bool
    func allRegisteredApi() -> [String]
    func removeAll()
}

public class ApiCenter: ApiCenterProtocol {
    public static let shared = ApiCenter()
    private lazy var registerMap: [String: () -> Any] = [:]

    public func registerApi<T>(type: T.Type, impBuilder: @escaping () -> T) {
        let name = "\(T.self)"
        assert(registerMap[name] == nil, "协议：\(name) 已经注册")
        registerMap[name] = impBuilder
    }

    public func removeApi<T>(api: T.Type) {
        registerMap["\(T.self)"] = nil
    }

    public func api<T>(type: T.Type) -> T? {
        registerMap["\(T.self)"]?() as? T
    }

    public func isRegisteredApi<T>(api: T.Type) -> Bool {
        registerMap["\(T.self)"] != nil
    }

    public func allRegisteredApi() -> [String] {
        registerMap.keys.sorted(by: <)
    }

    public func removeAll() {
        registerMap.removeAll()
    }
}
```

## 说明

1. 业务库需要拆分成两个库：API（纯 Protocol）、IMP（完整业务代码+API的具体实现，也就是说必须依赖 API 库）
2. API 库公开给其它模块调用，IMP库不公开
3. API 只能依赖一个库：对应的 IMP 库（版本依赖应该使用 >= ,即：有个最小依赖版本）。其它业务库只能依赖 API 库，不得依赖 IMP 库。
4. IMP 库有版本更新，必须同步更新对外更新 API 库版本（即使没有 Protocol 无 任何变化），对外功能的更新说明以 Protocol 为准。主要是为了规避 API、IMP 版本不一致导致功能异常的问题，同时保持对外只有1个窗口
5. API、IMP 如果有公用的类型，必须放在 API 库里，同时 IMP 必须依赖 API库并实现
6. IMP 库如果需要调用其它 API 的方法，则需要依赖 ApiCenter 库

依赖关系如图：

![依赖图](https://files.catbox.moe/1umobj.jpeg)

## 如何使用

注意：以下使用 ModuleA、ModuleB、ModuleC 代表 App 中不同业务模块

1. 为业务库 ModuleA 添加 API 库：ModuleAApi，内容：ModuleAApiProtocol。注意：ModuleAApi 不得依赖任何其它库
   
    ```swift
    /// 协议内方法是 ModuleA 对外提供的能力，包含方法、属性等
    protocol ModuleAApiProtocol {
        func descriptionA()
    }
    ```

2. 业务库 ModuleA 依赖对应的 API 库：ModuleAApi，并实现相应方法

    ```swift
    /// 实现  ModuleAApiProtocol 协议内所有能力，可以设计成单例模式
    struct ModuleAApi: ModuleAApiProtocol {
        // 不同方法内部可以采用不同的实现方案（走不同的路由方案，或者直接实现）

        func descriptionA() {
            // 方法内部可以使用路由方案，或者直接处理
            print("我是 ModuleA Api 的 description 方法")
        }
    }
    ```

3. 注册到 ApiCenter(不管在哪个位置注册，注册代码是一致的)
   1. 方法一：在 App 壳工程依赖库： ModuleA、ModuleAApi、ApiCenter，并在合适的位置实现注册
   2. 方法二：App 将生命周期同步给业务库，在业务库中合适的位置实现注册（推荐）

    ```swift
    /// 注册
    ApiCenter.shared.registerApi(type: ModuleAApiProtocol.self) {
        // 可以直接返回一个单例
        ModuleAApi()
    }
    ```

4. ModuleB、ModuleC 重复上述 1-3 的步骤
   
    ```swift
    /// 库：ModuleBApi
    protocol ModuleBApiProtocol {
        func descriptionB()
    }

    /// 库：ModuleB
    struct ModuleBApi: ModuleBApiProtocol {
        func descriptionB() {
            print("我是 ModuleB Api 的 description 方法")
        }
    }

    /// 库：ModuleCApi
    protocol ModuleCApiProtocol {
        func descriptionC()
    }

    /// 库：ModuleC
    struct ModuleCApi: ModuleCApiProtocol {
        func descriptionC() {
            print("我是 ModuleC Api 的 description 方法")
        }
    }


    // 注册到 ApiCenter
    ApiCenter.shared.registerApi(type: ModuleBApiProtocol.self) {
        ModuleBApi()
    }
    ApiCenter.shared.registerApi(type: ModuleCApiProtocol.self) {
        ModuleCApi()
    }
    ```

5. 在某个业务仓库中通过 ApiCenter 获取其它API库的 IMP 来实现调用
   
    ```swift
    /// 库：ModuleA
    ApiCenter.shared.api(type: ModuleBApiProtocol.self)?.descriptionB()
    ApiCenter.shared.api(type: ModuleCApiProtocol.self)?.descriptionC()


    /// 库：ModuleB
    ApiCenter.shared.api(type: ModuleAApiProtocol.self)?.descriptionA()
    ApiCenter.shared.api(type: ModuleCApiProtocol.self)?.descriptionC()


    /// 库：ModuleC
    ApiCenter.shared.api(type: ModuleAApiProtocol.self)?.descriptionA()
    ApiCenter.shared.api(type: ModuleBApiProtocol.self)?.descriptionB()
    ```

6. ModuleA 功能迭代更新升级版本：从 1.0.0 到 2.0.0 
   1. ModuleA 库中修改 ModuleA.podspec 升级版本

        ```
        // 升级前
        s.name = "ModuleA"
        s.version = "1.0.0"

        // 升级前
        s.name = "ModuleA"
        s.version = "2.0.0"
        ```

   2. ModuleAApiProtocol 中修改 ModuleAApi.podspec 依赖的 ModuleA 版本以及自身版本，并添加升级内容说明

        ```
        // 升级前
        s.name = "ModuleAApi"
        s.version = "1.0.0"
        s.dependency "ModuleA", ">= 1.0.0"

        // 升级前
        s.name = "ModuleAApi"
        s.version = "2.0.0"
        s.dependency "ModuleA", ">= 2.0.0"
        ```


## 其它用途

ApiCenter 可以作为组件库方案，同时也可以做其它用途

1. 数据共享，公共数据抽取一个 Protocol，然后注册一个单例对象作为 IMP，那么整个 App 共享的同一份数据。好处：
   1. 无需关心具体实现
   2. 实现方可变更方法具体实现，但不会影响现有逻辑
2. 极简版：[Swinject](https://github.com/Swinject/Swinject)

    ```swift
    protocol Animal {
        var name: String? { get }
    }

    class Cat: Animal {
        let name: String?

        init(name: String?) {
            self.name = name
        }
    }

    protocol Person {
        func play()
    }

    class PetOwner: Person {
        let pet: Animal

        init(pet: Animal) {
            self.pet = pet
        }

        func play() {
            let name = pet.name ?? "someone"
            print("I'm playing with \(name).")
        }
    }

    let container = ApiCenter()
    container.registerApi(type: Animal.self) { Cat(name: "Mimi") }
    container.registerApi(type: Person.self) {
        PetOwner(pet: container.api(type: Animal.self)!)
    }
    container.api(type: Person.self)?.play()
    ```

## 其它说明

如何减少依赖冲突

- cocoapods 没有提供 dependency_override 方法，无法强制使用某个版本
- 模块之间的依赖只能是 API，podspec 中最好不要写死版本，统一用 >=，如果都用 >=，就可以变相在 Podfile 中强制使用某个版本了 。
- 接口的变化最好有一个过渡期，旧接口暂时不删除，标记废弃
