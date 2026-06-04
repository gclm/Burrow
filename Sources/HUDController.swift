//
//  HUDController.swift
//  Burrow
//
//  Hosts the menu-bar HUD (PopupView) so it can NEVER run off the bottom
//  of the screen, without a width-stealing scrollbar:
//
//    * The popover is capped to the visible screen height
//      (preferredContentSize), so however tall the content gets, the
//      dropdown stops at the screen edge.
//    * The content lives in a scroll view with FORCED overlay scrollers
//      (`scrollerStyle = .overlay`, auto-hiding). Overlay scrollers float
//      over the content and take no layout width — even when the system
//      "Show scroll bars" preference is set to "Always" (which is what
//      pushed the content left before). When the content fits, nothing
//      scrolls and no scroller shows at all.
//

import AppKit
import SwiftUI

final class HUDController: NSViewController {
    private let hosting: NSHostingView<PopupView>

    init(root: PopupView) {
        self.hosting = NSHostingView(rootView: root)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var maxHeight: CGFloat {
        max(360, (NSScreen.main?.visibleFrame.height ?? 800) - 28)
    }

    override func loadView() {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.automaticallyAdjustsContentInsets = false

        hosting.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = hosting
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            hosting.widthAnchor.constraint(equalToConstant: 334),
        ])
        self.view = scroll
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        var contentH = hosting.intrinsicContentSize.height
        if contentH <= 0 { contentH = hosting.fittingSize.height }
        let target = NSSize(width: 334, height: min(max(contentH, 1), maxHeight))
        if abs(preferredContentSize.height - target.height) > 0.5 || preferredContentSize.width != target.width {
            preferredContentSize = target
        }
    }
}
