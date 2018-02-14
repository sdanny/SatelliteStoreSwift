//
//  SatelliteStore.swift
//  BabyPhone
//
//  Created by Daniyar Salakhutdinov on 29.08.17.
//  Copyright © 2017 Codeness. All rights reserved.
//

import UIKit
import StoreKit

enum Response<Value> {
    case success(Value)
    case failure(Error)
}

struct Payment {
    let amount: Decimal
    let currency: String
}

protocol SatelliteProduct: NSObjectProtocol {
    
    var price: Decimal { get }
    var priceLocale: Locale { get }
    var productIdentifier: String { get }
}

protocol SatelliteStoreProtocol {
    var isOpenForBusiness: Bool { get }
    
    func getProduct(identifier: String, completion: @escaping (Response<SKProduct>) -> Void)
    func purchaseProduct(identifier: String, completion: @escaping (Response<Payment>) -> Void)
    func restorePurchases(completion: @escaping (Response<[String]>) -> Void)
}

open class SatelliteStore: NSObject, SatelliteStoreProtocol, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    static var shoppingCenter = SatelliteStore()
    
    fileprivate struct Purchase: Equatable {
        let product: SKProduct
        let completion: (Response<Payment>) -> Void
    }
    
    fileprivate struct Fetch {
        let productIdentifier: String
        let request: SKProductsRequest
        let completion: (Response<SKProduct>) -> Void
        
        init(productIdentifier: String, completion: @escaping (Response<SKProduct>) -> Void) {
            self.productIdentifier = productIdentifier
            self.completion = completion
            let set = Set([productIdentifier])
            self.request = SKProductsRequest(productIdentifiers: set)
        }
    }
    
    fileprivate var purchases = [Purchase]()
    fileprivate var fetches = [Fetch]()
    fileprivate let lock = NSLock()
    fileprivate var restoreCompletion: ((Response<[String]>) -> Void)?
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    var isOpenForBusiness: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    func purchaseProduct(identifier: String, completion: @escaping (Response<Payment>) -> Void) {
        getProduct(identifier: identifier) { response in
            switch response {
            case .success(let product):
                self.purchaseProduct(product, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    fileprivate func purchaseProduct(_ product: SKProduct, completion: @escaping (Response<Payment>) -> Void) {
        // check already have this product to be purchased
        let purchase = Purchase(product: product, completion: completion)
        guard !purchases.contains(purchase) else { return }
        // append
        purchases.append(purchase)
        // start payment
        let payment = SKPayment(product: product)
        DispatchQueue.main.async {
            SKPaymentQueue.default().add(payment)
        }
    }
    
    func restorePurchases(completion: @escaping (Response<[String]>) -> Void) {
        self.restoreCompletion = completion
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func getProduct(identifier: String, completion: @escaping (Response<SKProduct>) -> Void) {
        // synchronize
        lock.lock()
        defer { lock.unlock() }
        // start
        let fetch = Fetch(productIdentifier: identifier, completion: completion)
        fetch.request.delegate = self
        fetches.append(fetch)
        fetch.request.start()
    }
    
    // MARK: payment transaction observing
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // synchronize
        lock.lock()
        defer { lock.unlock() }
        // complete transactions if needed
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored, .failed:
                completeTransaction(transaction, error: transaction.error)
            default:
                break
            }
        }
    }
    
    fileprivate func completeTransaction(_ transaction: SKPaymentTransaction, error: Error?) {
        // finish one
        SKPaymentQueue.default().finishTransaction(transaction)
        // find model with product identifier
        let productIdentifier = transaction.payment.productIdentifier
        let items = purchases
        for index in 0..<items.count {
            let item = items[index]
            guard item.product.productIdentifier == productIdentifier else { continue }
            // run completion
            if let error = error {
                item.completion(.failure(error))
            } else {
                let currencyCode: String = item.product.priceLocale.currencyCode ?? ""
                let payment = Payment(amount: item.product.price as Decimal, currency: currencyCode)
                item.completion(.success(payment))
            }
            // remove model
            purchases.remove(at: index)
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        restoreCompletion?(.failure(error))
        restoreCompletion = nil
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        // get restored product identifiers
        var identifiers = [String]()
        for transaction in queue.transactions {
            guard transaction.transactionState == .restored else { continue }
            identifiers.append(transaction.payment.productIdentifier)
        }
        // run completion
        restoreCompletion?(.success(identifiers))
        restoreCompletion = nil
    }
    
    // MARK: products request delegate
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // synchronize
        lock.lock()
        defer { lock.unlock() }
        // iterate through a copy
        let items = fetches
        for index in 0..<items.count {
            let fetch = items[index]
            // find the request
            guard fetch.request == request else { continue }
            // run completion
            let result: Response<SKProduct>
            if let product = response.products.first {
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
