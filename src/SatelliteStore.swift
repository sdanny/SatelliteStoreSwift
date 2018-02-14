//
//  SatelliteStore.swift
//  BabyPhone
//
//  Created by Daniyar Salakhutdinov on 29.08.17.
//  Copyright © 2017 Codeness. All rights reserved.
//

import UIKit

public enum Response<Value> {
    case success(Value)
    case failure(Error)
}

struct Payment {
    let amount: Decimal
    let currency: String
}

// MARK: - StoreKit taming
protocol SatelliteProduct: NSObjectProtocol {
    
    var price: NSDecimalNumber { get }
    var priceLocale: Locale { get }
    var productIdentifier: String { get }
}

protocol SatelliteProductsRequest: NSObjectProtocol {
    func start()
}

protocol SatelliteTransaction {
    var error: Error? { get }
    var isPurchasedOrRestored: Bool { get }
    var productIdentifier: String { get }
}

// MARK: - store engine
protocol SatelliteEngineDelegate: class {
    
    func productsRequest(_ request: SatelliteProductsRequest, didReceive response: [SatelliteProduct])
    func restoreCompletedTransactionsFailed(error: Error)
    func restoreCompletedTransactionsFinished(identifiers: [String])
    func updatedTransactions(_ transactions: [SatelliteTransaction])
}

protocol SatelliteEngineProtocol: class {
    
    var delegate: SatelliteEngineDelegate? { get set }
    var canMakePayments: Bool { get }
    
    func purchase(product: SatelliteProduct) throws
    func fetchProduct(identifier: String) -> SatelliteProductsRequest
    func restoreCompletedTransactions()
    func complete(transaction: SatelliteTransaction)
}

// MARK: - store class
protocol SatelliteStoreProtocol {
    var isOpenForBusiness: Bool { get }
    
    func getProduct(identifier: String, completion: @escaping (Response<SatelliteProduct>) -> Void)
    func purchaseProduct(identifier: String, completion: @escaping (Response<Payment>) -> Void)
    func restorePurchases(completion: @escaping (Response<[String]>) -> Void)
}

open class SatelliteStore: SatelliteStoreProtocol, SatelliteEngineDelegate {
    
    static var shoppingCenter = SatelliteStore(engine: SatelliteEngine())
    
    fileprivate struct Purchase: Equatable {
        let product: SatelliteProduct
        let completion: (Response<Payment>) -> Void
    }
    
    fileprivate struct Fetch {
        let request: SatelliteProductsRequest
        let completion: (Response<SatelliteProduct>) -> Void
    }
    
    fileprivate let engine: SatelliteEngineProtocol
    
    fileprivate var purchases = [Purchase]()
    fileprivate var fetches = [Fetch]()
    fileprivate let lock = NSLock()
    fileprivate var restoreCompletion: ((Response<[String]>) -> Void)?
    
    init(engine: SatelliteEngineProtocol) {
        self.engine = engine
        engine.delegate = self
    }
    
    var isOpenForBusiness: Bool {
        return engine.canMakePayments
    }
    
    func purchaseProduct(identifier: String, completion: @escaping (Response<Payment>) -> Void) {
        getProduct(identifier: identifier) { response in
            switch response {
            case .success(let product):
                // since product is returned by the engine pass it implicitly
                try! self.purchaseProduct(product, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    fileprivate func purchaseProduct(_ product: SatelliteProduct, completion: @escaping (Response<Payment>) -> Void) throws {
        // check already have this product to be purchased
        let purchase = Purchase(product: product, completion: completion)
        guard !purchases.contains(purchase) else { return }
        // append
        purchases.append(purchase)
        // call engine
        try engine.purchase(product: product)
    }
    
    func restorePurchases(completion: @escaping (Response<[String]>) -> Void) {
        self.restoreCompletion = completion
        engine.restoreCompletedTransactions()
    }
    
    func getProduct(identifier: String, completion: @escaping (Response<SatelliteProduct>) -> Void) {
        // synchronize
        lock.lock()
        defer { lock.unlock() }
        // start
        let request = engine.fetchProduct(identifier: identifier)
        let fetch = Fetch(request: request, completion: completion)
        fetches.append(fetch)
        request.start()
    }
    
    // MARK: payment transaction observing
    func updatedTransactions(_ transactions: [SatelliteTransaction]) {
        // synchronize
        lock.lock()
        defer { lock.unlock() }
        //
        for transaction in transactions {
            guard transaction.isPurchasedOrRestored || transaction.error != nil else { continue }
            // finish transaction
            engine.complete(transaction: transaction)
            // find purchase model
            let items = purchases
            for index in 0..<items.count {
                let item = items[index]
                guard item.product.productIdentifier == transaction.productIdentifier else { continue }
                // run completion
                if let error = transaction.error {
                    item.completion(.failure(error))
                } else { // purchased or restored
                    let currencyCode: String = item.product.priceLocale.currencyCode ?? ""
                    let payment = Payment(amount: item.product.price as Decimal, currency: currencyCode)
                    item.completion(.success(payment))
                }
                // remove model
                purchases.remove(at: index)
            }
        }
    }
    
    // MARK: satellite engine delegate
    func restoreCompletedTransactionsFailed(error: Error) {
        // run completion
        restoreCompletion?(.failure(error))
        restoreCompletion = nil
    }
    
    func restoreCompletedTransactionsFinished(identifiers: [String]) {
        // run completion
        restoreCompletion?(.success(identifiers))
        restoreCompletion = nil
    }
    
    func productsRequest(_ request: SatelliteProductsRequest, didReceive response: [SatelliteProduct]) {
        // synchronize
        lock.lock()
        defer { lock.unlock() }
        // iterate through a copy
        let items = fetches
        for index in 0..<items.count {
            let fetch = items[index]
            // find the request
            guard fetch.request.isEqual(request) else { continue }
            // run completion
            let result: Response<SatelliteProduct>
            if let product = response.first {
                result = .success(product)
            } else {
                let error = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "No product found"])
                result = .failure(error)
            }
            fetch.completion(result)
            // remove fetch
            fetches.remove(at: index)
        }
    }
    
}

fileprivate func == (lhs: SatelliteStore.Purchase, rhs: SatelliteStore.Purchase) -> Bool {
    return lhs.product.productIdentifier == rhs.product.productIdentifier
}
