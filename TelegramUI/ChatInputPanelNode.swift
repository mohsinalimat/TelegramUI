import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

class ChatInputPanelNode: ASDisplayNode {
    var account: Account?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 0.0
    }
}