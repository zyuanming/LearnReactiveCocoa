import UIKit

struct SearchCellItem {
    let title: String
    let textBeingSearched: String
}

extension SearchCellItem: TextPresentable {
    var text: NSAttributedString {
        
        let attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedStringKey.foregroundColor: UIColor.gray])
        
        let range = (title as NSString).range(of: textBeingSearched)
        attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.blue, range: range)
        
        return attributedString
    }
}
