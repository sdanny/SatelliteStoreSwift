//
//  SatelliteStoreSpec.swift
//  SatelliteStoreSwiftTests
//
//  Created by Daniyar Salakhutdinov on 13.02.2018.
//  Copyright © 2018 Daniyar Salakhutdinov. All rights reserved.
//

import UIKit
import Quick
import Nimble
@testable import SatelliteStoreSwift

class SatelliteStoreSpec: QuickSpec {
    
    fileprivate class FakeRequest: NSObject, SatelliteProductsRequest {
        
        var identifier = ""
        var isStarted = false
        
        func start() {
            isStarted = true
        }
    }
    
    fileprivate class FakeEngine: SatelliteEngineProtocol {
        var request: FakeRequest?
        var transaction: SatelliteTransaction?
        
        var delegate: SatelliteEngineDelegate?
        var canMakePayments = false
        
        func purchase(product: SatelliteProduct) throws {
            
        }
        
        func fetchProduct(identifier: String) -> SatelliteProductsRequest {
            let request = FakeRequest()
            request.identifier = identifier
            self.request = request
            return request
        }
        
        func restoreCompletedTransactions() {
            
        }
        
        func complete(transaction: SatelliteTransaction) {
            self.transaction = transaction
        }
        
    }
    
    fileprivate class FakeTransaction: SatelliteTransaction {
        
        var error: Error?
        var isPurchasedOrRestored: Bool = false
        var productIdentifier: String = ""
    }
    
    fileprivate class FakeProduct: NSObject, SatelliteProduct {
        var price: NSDecimalNumber = 0
        var priceLocale: Locale = Locale(identifier: "Ru_ru")
        var productIdentifier: String = ""
    }
    
    override func spec() {
        super.spec()
        //
        let engine = FakeEngine()
        let transaction = FakeTransaction()
        let product = FakeProduct()
        var store: SatelliteStore!
        // configure
        beforeEach {
            engine.canMakePayments = false
            engine.request = nil
            engine.transaction = nil
            transaction.error = nil
            transaction.isPurchasedOrRestored = false
            transaction.productIdentifier = ""
            product.price = 0
            product.priceLocale = Locale(identifier: "Ru_ru")
            product.productIdentifier = ""
            //
            store = SatelliteStore(engine: engine)
        }
        
        describe("Satellite store") {
            context("when purchasing") {
                it("calls back once") {
                    var calls = 0
                    let identifier = "some_product"
                    store.purchaseProduct(identifier: identifier, completion: { (response) in
                        calls += 1
                    })
                    // set product identifier and call engine delegate method
                    product.productIdentifier = identifier
                    store.productsRequest(engine.request!, didReceive: [product])
                    // update transaction
                    transaction.productIdentifier = identifier
                    transaction.isPurchasedOrRestored = true
                    store.updatedTransactions([transaction])
                    store.updatedTransactions([transaction])
                    expect(calls).to(equal(1))
                }
                it("completes transaction") {
                    let identifier = "some_identifier"
                    store.purchaseProduct(identifier: identifier, completion: { (response) in
                        
                    })
                    // set product identifier and call engine delegate method
                    product.productIdentifier = identifier
                    store.productsRequest(engine.request!, didReceive: [product])
                    //
                    transaction.productIdentifier = identifier
                    transaction.isPurchasedOrRestored = true
                    store.updatedTransactions([transaction])
                    expect(engine.transaction).toNot(beNil())
                    expect(engine.transaction?.productIdentifier).to(equal(transaction.productIdentifier))
                }
            }
            context("when restoring") {
                it("calls back once") {
                    var calls = 0
                    let identifier = "some_product"
                    store.restorePurchases(completion: { (response) in
                        calls += 1
                    })
                    store.restoreCompletedTransactionsFinished(identifiers: [identifier])
                    store.restoreCompletedTransactionsFinished(identifiers: [identifier])
                    expect(calls).to(equal(1))
                }
            }
        }
    }
}
