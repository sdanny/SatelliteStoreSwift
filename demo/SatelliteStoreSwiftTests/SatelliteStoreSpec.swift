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
            
        }
        
    }
    
    override func spec() {
        super.spec()
        // define dependencies
        let engine = FakeEngine()
        // configure
        beforeEach {
            engine.canMakePayments = false
        }
        
        describe("Satellite store") {
            
        }
    }
}
