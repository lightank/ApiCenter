//
//  ApiCenter.swift
//
//  Created by huanyu on 2022/10/4. see: https://github.com/lightank/ApiCenter
//

import Foundation

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
