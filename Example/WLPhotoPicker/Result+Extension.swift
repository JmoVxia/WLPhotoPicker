//
//  Result+Extension.swift
//  Potato
//
//  Created by Emma on 2020/1/24.
//

extension Swift.Result {
    /// 是否成功
    var isSuccess: Bool { if case .success = self { true } else { false } }
    /// 是否错误
    var isError: Bool { !isSuccess }
    /// 成功case
    var success: Success? {
        if case let .success(item) = self {
            return item
        }
        return nil
    }

    /// 失败case
    var failure: Failure? {
        if case let .failure(item) = self {
            return item
        }
        return nil
    }

    /// 成功case
    @discardableResult func success(_ Callback: (Success) -> Void) -> Self {
        if case let .success(item) = self {
            Callback(item)
        }
        return self
    }

    /// 失败case
    @discardableResult func failure(_ Callback: (Failure) -> Void) -> Self {
        if case let .failure(item) = self {
            Callback(item)
        }
        return self
    }
}
