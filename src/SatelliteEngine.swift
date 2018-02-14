//
//  SatelliteEngine.swift
//  SatelliteStoreSwift
//
//  Created by Daniyar Salakhutdinov on 14.02.2018.
//  Copyright © 2018 Daniyar Salakhutdinov. All rights reserved.
//

import UIKit
import StoreKit

internal class SatelliteEngine: NSObject, SatelliteEngineProtocol, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    weak var delegate: SatelliteEngineDelegate?
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    func purchase(product: SatelliteProduct) throws {
        let payment = SKPayment(product: product as! SKProduct)
        DispatchQueue.main.async {
            SKPaymentQueue.default().add(payment)
        }
    }
    
    func fetchProduct(identifier: String) -> SatelliteProductsRequest {
        let set = Set([identifier])
        let request = SKProductsRequest(productIdentifiers: set)
        request.delegate = self
        return request
    }
    
    func restoreCompletedTransactions() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func complete(transaction: SatelliteTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
    }
    
    // MARK: payment transaction observer
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        delegate?.updatedTransactions(transactions)
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        delegate?.restoreCompletedTransactionsFailed(error: error)
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        delegate?.restoreCompletedTransactionsFinished(identifiers: queue.transactions.filter { $0.transactionState == .restored }.map { $0.productIdentifier })
    }
    
    // MARK: products request
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        delegate?.productsRequest(request, didReceive: response.products)
    }
}

extension SKProduct: SatelliteProduct { }
extension SKProductsRequest: SatelliteProductsRequest { }
extension SKPaymentTransaction: SatelliteTransaction {
    var isPurchasedOrRestored: Bool {
        switch transactionState {
        case .purchased, .restored:
            return true
        default:
            return false
        }
    }
    
    var productIdentifier: String {
        return payment.productIdentifier
    }
}
