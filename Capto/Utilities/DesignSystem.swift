//
//  DesignSystem.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Centralized design system constants to replace magic numbers throughout the app.
enum DesignSystem {
    enum Spacing {
        static let section: CGFloat = 24
        static let bubble: CGFloat = 18
        static let timestamp: CGFloat = 6
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 24
        static let bottomPadding: CGFloat = 120
        static let composerVertical: CGFloat = 16
        static let composerHorizontal: CGFloat = 22
        static let composerTextFieldVertical: CGFloat = 14
        static let composerTextFieldHorizontal: CGFloat = 18
    }
    
    enum CornerRadius {
        static let bubble: CGFloat = 32
        static let composer: CGFloat = 40
        static let composerTextField: CGFloat = 26
        static let button: CGFloat = 26
        static let dateHeader: CGFloat = 28
        static let searchBar: CGFloat = 24
        static let errorBanner: CGFloat = 12
        static let toast: CGFloat = 28
    }
    
    enum Bubble {
        static let widthMultiplier: CGFloat = 0.82
        static let minWidth: CGFloat = 280
        static let maxWidth: CGFloat = 520
        static let paddingVertical: CGFloat = 18
        static let paddingHorizontal: CGFloat = 22
    }
    
    enum ScrollTiming {
        static let viewLayoutDelay: TimeInterval = 0.3
        static let keyboardSyncDelay: TimeInterval = 0.2
        static let focusDelay: TimeInterval = 0.1
        static let timestampAutoHide: TimeInterval = 3.5
        static let searchFocusDelay: TimeInterval = 0.15
        static let copyToastDuration: TimeInterval = 1.5
        static let reFocusDelay: TimeInterval = 0.05
        static let defaultFocusDelay: TimeInterval = 0.02
    }
    
    enum Shadow {
        static let bubbleRadius: CGFloat = 20
        static let bubbleRadiusSecondary: CGFloat = 40
        static let bubbleY: CGFloat = 6
        static let bubbleYSecondary: CGFloat = 12
        static let composerRadius: CGFloat = 24
        static let composerRadiusSecondary: CGFloat = 48
        static let composerY: CGFloat = 8
        static let composerYSecondary: CGFloat = 16
        static let dateHeaderRadius: CGFloat = 8
        static let dateHeaderY: CGFloat = 3
        static let searchBarRadius: CGFloat = 10
        static let searchBarY: CGFloat = 3
        static let toastRadius: CGFloat = 20
        static let toastRadiusSecondary: CGFloat = 40
        static let toastY: CGFloat = 6
        static let toastYSecondary: CGFloat = 12
    }
    
    enum Animation {
        static let timestampDuration: TimeInterval = 0.2
        static let scrollDuration: TimeInterval = 0.3
        static let springResponse: TimeInterval = 0.3
        static let springDamping: CGFloat = 0.7
    }
}

