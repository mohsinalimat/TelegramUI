import Foundation
import AsyncDisplayKit

class AccessoryPanelNode: ASDisplayNode {
    var dismiss: (() -> Void)?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
}