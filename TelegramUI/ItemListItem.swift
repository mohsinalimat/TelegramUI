import Display

protocol ItemListItem {
    var sectionId: ItemListSectionId { get }
    var isAlwaysPlain: Bool { get }
}

extension ItemListItem {
    var isAlwaysPlain: Bool {
        return false
    }
}

enum ItemListNeighbor {
    case none
    case otherSection
    case sameSection(alwaysPlain: Bool)
}

struct ItemListNeighbors {
    let top: ItemListNeighbor
    let bottom: ItemListNeighbor
}

func itemListNeighbors(item: ItemListItem, topItem: ItemListItem?, bottomItem: ItemListItem?) -> ItemListNeighbors {
    let topNeighbor: ItemListNeighbor
    if let topItem = topItem {
        if topItem.sectionId != item.sectionId {
            topNeighbor = .otherSection
        } else {
            topNeighbor = .sameSection(alwaysPlain: topItem.isAlwaysPlain)
        }
    } else {
        topNeighbor = .none
    }
    
    let bottomNeighbor: ItemListNeighbor
    if let bottomItem = bottomItem {
        if bottomItem.sectionId != item.sectionId {
            bottomNeighbor = .otherSection
        } else {
            bottomNeighbor = .sameSection(alwaysPlain: bottomItem.isAlwaysPlain)
        }
    } else {
        bottomNeighbor = .none
    }

    return ItemListNeighbors(top: topNeighbor, bottom: bottomNeighbor)
}

func itemListNeighborsPlainInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
        case .otherSection:
            insets.top += 22.0
        case .none, .sameSection:
            break
    }
    switch neighbors.bottom {
        case .none:
            insets.bottom += 22.0
        case .otherSection, .sameSection:
            break
    }
    return insets
}

func itemListNeighborsGroupedInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    let topInset: CGFloat
    switch neighbors.top {
        case .none:
            topInset = UIScreenPixel + 35.0
        case .sameSection:
            topInset = 0.0
        case .otherSection:
            topInset = UIScreenPixel + 35.0
    }
    let bottomInset: CGFloat
    switch neighbors.bottom {
        case .sameSection, .otherSection:
            bottomInset = 0.0
        case .none:
            bottomInset = UIScreenPixel + 35.0
    }
    return UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0)
}