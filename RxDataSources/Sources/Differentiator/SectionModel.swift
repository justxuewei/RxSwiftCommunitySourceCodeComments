//
//  SectionModel.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 6/16/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public struct SectionModel<Section, ItemType> {
    public var model: Section
    public var items: [Item]

    // Xavier Marks: init from section
    public init(model: Section, items: [Item]) {
        self.model = model
        self.items = items
    }
}

// MARK: SectionModel conforms to SectionModelType
extension SectionModel
    : SectionModelType {
    public typealias Identity = Section
    public typealias Item = ItemType
    
    public var identity: Section {
        return model
    }
}

// MARK: SectionModel conforms to CustomStringConvertible
extension SectionModel
    : CustomStringConvertible {

    public var description: String {
        return "\(self.model) > \(items)"
    }
}

// MARK: init() of SectionModel
extension SectionModel {
    // Xavier Marks:
    //
    // init from other SectionModel, this is a concrete implementation
    // for conforming to SectionModelType
    public init(original: SectionModel<Section, Item>, items: [Item]) {
        self.model = original.model
        self.items = items
    }
}

// MARK: rewrites `==`
extension SectionModel
    : Equatable where Section: Equatable, ItemType: Equatable {
    
    public static func == (lhs: SectionModel, rhs: SectionModel) -> Bool {
        return lhs.model == rhs.model
            && lhs.items == rhs.items
    }
}
