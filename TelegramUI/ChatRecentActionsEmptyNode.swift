import Foundation
import Display
import AsyncDisplayKit

private let titleFont = Font.medium(16.0)
private let textFont = Font.regular(15.0)

final class ChatRecentActionsEmptyNode: ASDisplayNode {
    private var theme: PresentationTheme
    
    private let backgroundNode: ASImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var layoutParams: CGSize?
    
    private var title: String = ""
    private var text: String = ""
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        
        super.init()
        
        self.backgroundNode.image = PresentationResourcesChat.chatEmptyItemBackgroundImage(self.theme)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.layoutParams = size
        
        let spacing: CGFloat = 5.0
        let insets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)
        
        let maxTextWidth = size.width - insets.left - insets.right - 18.0 * 2.0
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.title, font: titleFont, textColor: self.theme.chat.serviceMessage.serviceMessagePrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.text, font: textFont, textColor: self.theme.chat.serviceMessage.serviceMessagePrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        let contentSize = CGSize(width: max(titleLayout.size.width, textLayout.size.width) + insets.left + insets.right, height: insets.top + insets.bottom + titleLayout.size.height + spacing + textLayout.size.height)
        let backgroundFrame = CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) / 2.0), y: floor((size.height - contentSize.height) / 2.0)), size: contentSize)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((contentSize.width - titleLayout.size.width) / 2.0), y: backgroundFrame.minY + insets.top), size: titleLayout.size))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((contentSize.width - textLayout.size.width) / 2.0), y: backgroundFrame.minY + insets.top + titleLayout.size.height + spacing), size: textLayout.size))
        
        let _ = titleApply()
        let _ = textApply()
    }
    
    func setup(title: String, text: String) {
        if self.title != title || self.text != text {
            self.title = title
            self.text = text
            if let size = self.layoutParams {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
}