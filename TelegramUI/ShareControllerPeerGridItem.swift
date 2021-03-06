import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ShareControllerInteraction {
    var foundPeers: [Peer] = []
    var selectedPeerIds = Set<PeerId>()
    var selectedPeers: [Peer] = []
    let togglePeer: (Peer, Bool) -> Void
    
    init(togglePeer: @escaping (Peer, Bool) -> Void) {
        self.togglePeer = togglePeer
    }
}

final class ShareControllerGridSection: GridSection {
    let height: CGFloat = 33.0
    
    private let title: String
    private let theme: PresentationTheme
    
    var hashValue: Int {
        return 1
    }
    
    init(title: String, theme: PresentationTheme) {
        self.title = title
        self.theme = theme
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? ShareControllerGridSection {
            return self.title == to.title
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return ShareControllerGridSectionNode(title: self.title, theme: self.theme)
    }
}

private let sectionTitleFont = Font.medium(12.0)

final class ShareControllerGridSectionNode: ASDisplayNode {
    let backgroundNode: ASDisplayNode
    let titleNode: ASTextNode
    
    init(title: String, theme: PresentationTheme) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.chatList.sectionHeaderFillColor
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.attributedText = NSAttributedString(string: title.uppercased(), font: sectionTitleFont, textColor: theme.list.sectionHeaderTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: bounds.size.width, height: 27.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 7.0), size: titleSize)
    }
}

final class ShareControllerPeerGridItem: GridItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: Peer
    let chatPeer: Peer?
    let controllerInteraction: ShareControllerInteraction
    let search: Bool
    
    let section: GridSection?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, peer: Peer, chatPeer: Peer?, controllerInteraction: ShareControllerInteraction, sectionTitle: String? = nil, search: Bool = false) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.chatPeer = chatPeer
        self.controllerInteraction = controllerInteraction
        self.search = search
        
        if let sectionTitle = sectionTitle {
            self.section = ShareControllerGridSection(title: sectionTitle, theme: self.theme)
        } else {
            self.section = nil
        }
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = ShareControllerPeerGridItemNode()
        node.controllerInteraction = self.controllerInteraction
        node.setup(account: self.account, theme: self.theme, strings: self.strings, peer: self.peer, chatPeer: self.chatPeer, search: self.search)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ShareControllerPeerGridItemNode else {
            assertionFailure()
            return
        }
        node.controllerInteraction = self.controllerInteraction
        node.setup(account: self.account, theme: self.theme, strings: self.strings, peer: self.peer, chatPeer: self.chatPeer, search: self.search)
    }
}

final class ShareControllerPeerGridItemNode: GridItemNode {
    private var currentState: (Account, Peer, Peer?, Bool)?
    private let peerNode: SelectablePeerNode
    
    var controllerInteraction: ShareControllerInteraction?
    
    override init() {
        self.peerNode = SelectablePeerNode()
        
        super.init()
        
        self.peerNode.toggleSelection = { [weak self] in
            if let strongSelf = self {
                if let (_, peer, chatPeer, search) = strongSelf.currentState {
                    let mainPeer = chatPeer ?? peer
                    strongSelf.controllerInteraction?.togglePeer(mainPeer, search)
                }
            }
        }
        self.addSubnode(self.peerNode)
    }
    
    func setup(account: Account, theme: PresentationTheme, strings: PresentationStrings, peer: Peer, chatPeer: Peer?, search: Bool) {
        if self.currentState == nil || self.currentState!.0 !== account || !arePeersEqual(self.currentState!.1, peer) {
            let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: theme.chatList.secretTitleColor, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.checkContentColor)
            self.peerNode.theme = itemTheme
            self.peerNode.setup(account: account, strings: strings, peer: peer, chatPeer: chatPeer)
            self.currentState = (account, peer, chatPeer, search)
            self.setNeedsLayout()
        }
        self.updateSelection(animated: false)
    }
    
    func updateSelection(animated: Bool) {
        var selected = false
        if let controllerInteraction = self.controllerInteraction, let (_, peer, chatPeer, _) = self.currentState {
            let mainPeer = chatPeer ?? peer
            selected = controllerInteraction.selectedPeerIds.contains(mainPeer.id)
        }
        
        self.peerNode.updateSelection(selected: selected, animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.peerNode.frame = bounds
    }
}
