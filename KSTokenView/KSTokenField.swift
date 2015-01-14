//
//  KSTokenField.swift
//  KSTokenView
//
//  Created by Khawar Shahzad on 01/01/2015.
//  Copyright (c) 2015 Khawar Shahzad. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit

enum KSTokenFieldState {
   case Opened
   case Closed
}

@objc protocol KSTokenFieldDelegate : UITextFieldDelegate {
   func tokenFieldShouldChangeHeight(height: CGFloat)
   optional func tokenFieldDidSelectToken(token: KSToken)
   optional func tokenFieldDidBeginEditing(tokenField: KSTokenField)
   optional func tokenFieldDidEndEditing(tokenField: KSTokenField)
}


class KSTokenField: UITextField {
   
   // MARK: - Private Properties
   private var _cursorColor: UIColor = UIColor.grayColor() {
      willSet {
         tintColor = newValue
      }
   }
   private var _setupCompleted: Bool = false
   private var _selfFrame: CGRect?
   private var _caretPoint: CGPoint?
   private var _placeholderValue: String?
   private var _placeholderLabel: UILabel?
   private var _state: KSTokenFieldState = .Opened
   private var _minWidthForInput: CGFloat?
   private var _seperatorText: String?
   private var _font: UIFont?
   private var _paddingX: CGFloat?
   private var _paddingY: CGFloat?
   private var _marginX: CGFloat?
   private var _marginY: CGFloat?
   private var _removesTokensOnEndEditing = true
   private var _scrollView = UIScrollView(frame: .zeroRect)
   private var _scrollPoint = CGPoint.zeroPoint
   private var _descriptionText: String = "selections" {
      didSet {
         _updateText()
      }
   }
   
   // MARK: - Public Properties
   
   /// default is grayColor()
   var promptTextColor: UIColor = UIColor.grayColor()
   
   /// default is grayColor()
   var placeHolderColor: UIColor = UIColor.grayColor()
   
   /// default is 120.0. After maximum limit is reached, tokens starts scrolling vertically
   var maximumHeight: CGFloat = 120.0
   
   /// default is nil
   override var placeholder: String? {
      get {
         return _placeholderValue
      }
      set {
         super.placeholder = newValue
         if (newValue == nil) {
            return
         }
         _placeholderValue = newValue
      }
   }
   
   weak var parentView: KSTokenView? {
      willSet (tokenView) {
         if (tokenView != nil) {
            _cursorColor = tokenView!.cursorColor
            _paddingX = tokenView!.paddingX
            _paddingY = tokenView!.paddingY
            _marginX = tokenView!.marginX
            _marginY = tokenView!.marginY
            _font = tokenView!.font
            _minWidthForInput = tokenView!.minWidthForInput
            _seperatorText = tokenView!.seperatorText
            _removesTokensOnEndEditing = tokenView!.removesTokensOnEndEditing
            _descriptionText = tokenView!.descriptionText
            _setPromptText(tokenView!.promptText)
            if (_setupCompleted) {
               updateLayout()
            }
            
         }
      }
   }
   
   weak var tokenFieldDelegate: KSTokenFieldDelegate? {
      didSet {
         delegate  = tokenFieldDelegate
      }
   }
   
   /// returns Array of tokens
   var tokens = [KSToken]()
   
   /// returns selected KSToken object
   var selectedToken: KSToken?
   
   // MARK: - Constructors
   required init(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
      _setupTokenField()
   }
   
   override init(frame: CGRect) {
      super.init(frame: frame)
      _setupTokenField()
   }
   
   
   // MARK: - Methods
   
   // MARK: - Setup
   private func _setupTokenField() {
      text = ""
      autocorrectionType = UITextAutocorrectionType.No
      autocapitalizationType = UITextAutocapitalizationType.None
      contentVerticalAlignment = UIControlContentVerticalAlignment.Top
      returnKeyType = UIReturnKeyType.Done
      text = KSTextEmpty
      backgroundColor = UIColor.whiteColor()
      clipsToBounds = true
      _state = .Closed
      
      _scrollView.frame.size = CGSize(width: frame.width, height: frame.height)
      _scrollView.backgroundColor = UIColor.clearColor()
      _scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "scrollViewDidTap"))
      _scrollView.delegate = self
      addSubview(_scrollView)
      
      addTarget(self, action: "tokenFieldTextDidChange:", forControlEvents: UIControlEvents.EditingChanged)
   }
   
   
   override func drawRect(rect: CGRect) {
      _selfFrame = rect
      _setupCompleted = true
      _updateText()
   }
   
   // MARK: - Add Token
   /**
   Create and add new token
   
   :param: title String value
   
   :returns: KSToken object
   */
   func addTokenWithTitle(title: String) -> KSToken? {
      return addTokenWithTitle(title, tokenObject: nil)
   }
   
   /**
   Create and add new token with custom object
   
   :param: title       String value
   :param: tokenObject Any custom object
   
   :returns: KSToken object
   */
   func addTokenWithTitle(title: String, tokenObject: AnyObject?) -> KSToken? {
      var token = KSToken(title: title, object: tokenObject)
      return addToken(token)
   }
   
   /**
   Add new token
   
   :param: token KSToken object
   
   :returns: KSToken object
   */
   func addToken(token: KSToken) -> KSToken? {
      if (countElements(token.title) == 0) {
         NSException(name: "", reason: "Title is not valid String", userInfo: nil);
      }
      
      if (!contains(tokens, token)) {
         token.addTarget(self, action: "tokenTouchDown:", forControlEvents: UIControlEvents.TouchDown)
         token.addTarget(self, action: "tokenTouchUpInside:", forControlEvents: UIControlEvents.TouchUpInside)
         tokens.append(token)
         _insertToken(token)
      }
      
      return token
   }
   
   private func _insertToken(token: KSToken, shouldLayout: Bool = true) {
      _scrollView.addSubview(token)
      token.setNeedsDisplay()
      if shouldLayout == true {
         updateLayout()
      }
   }
   
   //MARK: - Delete Token
   /*
   **************************** Delete Token ****************************
   */
   
   /**
   Deletes a token from view
   
   :param: token KSToken object
   */
   func deleteToken(token: KSToken) {
      removeToken(token)
   }
   
   /**
   Deletes a token from view, if any token is found for custom object
   
   :param: object Custom object
   */
   func deleteTokenWithObject(object: AnyObject?) {
      if object == nil {return}
      for token in tokens {
         if (token.object!.isEqual(object)) {
            removeToken(token)
            break
         }
      }
   }
   
   /**
   Deletes all tokens from view
   */
   func forceDeleteAllTokens() {
      tokens.removeAll(keepCapacity: false)
      for token in tokens {
         removeToken(token, removingAll: true)
      }
      updateLayout()
   }
   
   /**
   Deletes token from view
   
   :param: token       KSToken object
   :param: removingAll A boolean to describe if removingAll tokens
   */
   func removeToken(token: KSToken, removingAll: Bool = false) {
      if token.isEqual(selectedToken) {
         deselectSelectedToken()
      }
      token.removeFromSuperview()
      
      let index = find(tokens, token)
      if (index != nil) {
         tokens.removeAtIndex(index!)
      }
      if (!removingAll) {
         updateLayout()
      }
   }
   
   
   //MARK: - Layout
   /*
   **************************** Layout ****************************
   */
   
   /**
   Untokenzies the layout
   */
   func untokenize() {
      if (!_removesTokensOnEndEditing) {
         return
      }
      _state = .Closed
      for subview in _scrollView.subviews {
         if subview is KSToken {
            subview.removeFromSuperview()
         }
      }
      updateLayout()
   }
   
   
   func tokenize() {
      _state = .Opened
      for token: KSToken in tokens {
         _insertToken(token, shouldLayout: false)
      }
      updateLayout()
   }
   
   
   func updateLayout() {
      if (parentView == nil) {
         return
      }
      _caretPoint = _layoutTokens()
      deselectSelectedToken()
      _updateText()
      
      if _caretPoint != .zeroPoint {
         let tokensMaxY = _caretPoint!.y
         
         if (frame.size.height != tokensMaxY) {
            tokenFieldDelegate?.tokenFieldShouldChangeHeight(tokensMaxY)
         }
      }
   }
   
   /**
   Layout tokens and returns position
   
   :returns: CGPoint maximum position values
   */
   private func _layoutTokens() -> CGPoint {
      if (_selfFrame == nil) {
         return .zeroPoint
      }
      if (_state == .Closed) {
         return CGPoint(x: _marginX!, y: _selfFrame!.size.height)
      }
      
      var lineNumber = 1
      let leftMargin = _leftViewRect().width
      let rightMargin = _rightViewRect().width
      let lineHeight = _font!.lineHeight + _paddingY!;
      let tokenHeight = lineHeight;
      
      var tokenPosition = CGPoint.zeroPoint
      tokenPosition.x = leftMargin + (_marginX!*2)
      tokenPosition.y = _marginY!
      
      for token: KSToken in tokens {
         let width = KSUtils.getRect(token.title, width: bounds.size.width, font: _font!).size.width + ceil(_paddingX!*2+1)
         let tokenWidth = min(width, token.maxWidth)
         
         if ((token.superview) != nil) {
            if (tokenPosition.x + tokenWidth + _marginX! > bounds.size.width - rightMargin) {
               lineNumber++;
               tokenPosition.x = leftMargin + _marginX!
               tokenPosition.y += (tokenHeight + _marginY!);
            }
            
            token.frame = CGRect(x: tokenPosition.x, y: tokenPosition.y, width: tokenWidth, height: tokenHeight)
            tokenPosition.x += tokenWidth + _marginX!;
         }
      }
      
      if ((bounds.size.width) - (tokenPosition.x + _marginX!) < _minWidthForInput!) {
         lineNumber++;
         tokenPosition.x = leftMargin + _marginX!
         tokenPosition.y += (tokenHeight + _marginY!);
      }
      
      var positionY = (lineNumber == 1 && tokens.count == 0) ? _selfFrame!.size.height: (tokenPosition.y + tokenHeight + _marginY!)
      _scrollView.contentSize = CGSize(width: _scrollView.frame.width, height: positionY)
      if (positionY > maximumHeight) {
         positionY = maximumHeight
      }
      
      _scrollView.frame.size = CGSize(width: _scrollView.frame.width, height: positionY)
      scrollViewScrollToBottom()
      
      return CGPoint(x: tokenPosition.x, y: positionY)
   }
   
   func scrollViewScrollToBottom() {
      let bottomOffset = CGPoint(x: 0, y: _scrollView.contentSize.height - _scrollView.bounds.height)
      _scrollView.setContentOffset(bottomOffset, animated: true)
   }
   
   //MARK: - Text Rect
   /*
   **************************** Text Rect ****************************
   */
   
   private func _textRectWithBounds(bounds: CGRect) -> CGRect {
      if (!_setupCompleted) {return .zeroRect}
      if (tokens.count == 0 || _caretPoint == nil) {
         return CGRect(x: _leftViewRect().width + _marginX!, y: (bounds.size.height - font.lineHeight)*0.5, width: bounds.size.width-5, height: bounds.size.height)
      }
      
      if (tokens.count != 0 && _state == .Closed) {
         return CGRect(x: _leftViewRect().maxX + _marginX!, y: (_caretPoint!.y - font.lineHeight - (_marginY!)), width: (frame.size.width - _caretPoint!.x - _marginX!), height: bounds.size.height)
      }
      return CGRect(x: _caretPoint!.x, y: (_caretPoint!.y - font.lineHeight - (_marginY!)), width: (frame.size.width - _caretPoint!.x - _marginX!), height: bounds.size.height)
   }
   
   override func leftViewRectForBounds(bounds: CGRect) -> CGRect {
      return CGRect(x: _marginX!, y: (_selfFrame != nil) ? (_selfFrame!.height - _leftViewRect().height)*0.5: (bounds.height - _leftViewRect().height)*0.5, width: _leftViewRect().width, height: _leftViewRect().height)
   }
   
   override func textRectForBounds(bounds: CGRect) -> CGRect {
      return _textRectWithBounds(bounds)
   }
   
   override func editingRectForBounds(bounds: CGRect) -> CGRect {
      return _textRectWithBounds(bounds)
   }
   
   override func placeholderRectForBounds(bounds: CGRect) -> CGRect {
      return _textRectWithBounds(bounds)
   }
   
   private func _leftViewRect () -> CGRect {
      if (leftViewMode == .Never ||
         (leftViewMode == .UnlessEditing && editing) ||
         (leftViewMode == .WhileEditing && !editing)) {
            return .zeroRect
      }
      
      return leftView!.bounds
   }
   
   private func _rightViewRect() -> CGRect {
      if (rightViewMode == .Never ||
         rightViewMode == .UnlessEditing && editing ||
         rightViewMode == .WhileEditing && !editing) {
            return .zeroRect
      }
      return rightView!.bounds
   }
   
   private func _setPromptText(text: String?) {
      if (text != nil) {
         var label = leftView
         if !(label is UILabel) {
            label = UILabel(frame: .zeroRect) as UILabel
            label?.frame.origin.x += _marginX!
            (label as UILabel).textColor = promptTextColor
            leftViewMode = .Always
         }
         
         (label as UILabel).text = text
         (label as UILabel).font = font
         (label as UILabel).sizeToFit()
         leftView = label
         
      } else {
         leftView = nil
      }
   }
   
   
   //MARK: - Placeholder
   /*
   **************************** Placeholder ****************************
   */
   
   private func _updateText() {
      if (!_setupCompleted) {return}
      _initPlaceholderLabel()
      
      switch(_state) {
      case .Opened:
         text = KSTextEmpty
         break
         
      case .Closed:
         if tokens.count == 0 {
            text = KSTextEmpty
            
         } else {
            var title = KSTextEmpty
            for token: KSToken in tokens {
               title += "\(token.title)\(_seperatorText!)"
            }
            
            if (countElements(title) > 0) {
               title = title.substringWithRange(Range<String.Index>(start: advance(title.startIndex, 0), end: advance(title.endIndex, -countElements(_seperatorText!))))
            }
            
            var width = KSUtils.widthOfString(title, font: font)
            if width + _leftViewRect().width > bounds.width {
               text = "\(tokens.count) \(_descriptionText)"
            } else {
               text = title
            }
         }
         break
      }
      _updatePlaceHolderVisibility()
   }
   
   private func _updatePlaceHolderVisibility() {
      if tokens.count == 0 && (text == KSTextEmpty || text.isEmpty) {
         _placeholderLabel?.text = _placeholderValue!
         _placeholderLabel?.hidden = false
         
      } else {
         _placeholderLabel?.hidden = true
      }
   }
   
   private func _initPlaceholderLabel() {
      let xPos = _leftViewRect().size.width+_marginX!
      if (_placeholderLabel == nil) {
         _placeholderLabel = UILabel(frame: CGRect(x: xPos, y: 0, width: _selfFrame!.width - xPos, height: 30))
         _placeholderLabel?.textColor = placeHolderColor
         addSubview(_placeholderLabel!)
      } else {
         _placeholderLabel?.frame.origin.x = xPos
      }
   }
   
   
   //MARK: - Token Gestures
   //__________________________________________________________________________________
   //
   func isSelectedToken(token: KSToken) -> Bool {
      if token.isEqual(selectedToken) {
         return true
      }
      return false
   }
   
   
   func deselectSelectedToken() {
      selectedToken?.selected = false
      selectedToken = nil
   }
   
   func selectToken(token: KSToken) {
      if (token.sticky) {
         return
      }
      for token: KSToken in tokens {
         if isSelectedToken(token) {
            deselectSelectedToken()
            break
         }
      }
      
      token.selected = true
      selectedToken = token
      tokenFieldDelegate?.tokenFieldDidSelectToken?(token)
   }
   
   func tokenTouchDown(token: KSToken) {
      if (selectedToken != nil) {
         selectedToken?.selected = false
         selectedToken = nil
      }
   }
   
   func tokenTouchUpInside(token: KSToken) {
      selectToken(token)
   }
   
   override func beginTrackingWithTouch(touch: UITouch, withEvent event: UIEvent) -> Bool {
      if (touch.view == self) {
         deselectSelectedToken()
      }
      return super.beginTrackingWithTouch(touch, withEvent: event)
   }
   
   func tokenFieldTextDidChange(textField: UITextField) {
      _updatePlaceHolderVisibility()
   }
   
   // MARK: - Other Methods
   
   func paddingX() -> CGFloat? {
      return _paddingX
   }
   
   func tokenFont() -> UIFont? {
      return _font
   }
   
   func objects() -> NSArray {
      var objects = NSMutableArray()
      for object: AnyObject in tokens {
         objects.addObject(object)
      }
      return objects
   }
   
   override func becomeFirstResponder() -> Bool {
      tokenFieldDelegate?.tokenFieldDidBeginEditing?(self)
      return super.becomeFirstResponder()
   }
   
   override func resignFirstResponder() -> Bool {
      tokenFieldDelegate?.tokenFieldDidEndEditing?(self)
      return super.resignFirstResponder()
   }
   
   func scrollViewDidTap() {
      becomeFirstResponder()
   }
}


//MARK: - UIScrollViewDelegate
//__________________________________________________________________________________
//
extension KSTokenField : UIScrollViewDelegate {
   func scrollViewWillBeginDragging(scrollView: UIScrollView) {
      _scrollPoint = scrollView.contentOffset
   }
   
   func scrollViewDidScroll(aScrollView: UIScrollView) {
      text = KSTextEmpty
      updateCaretVisiblity(aScrollView)
   }
   
   func updateCaretVisiblity(aScrollView: UIScrollView) {
      let scrollViewHeight = aScrollView.frame.size.height;
      let scrollContentSizeHeight = aScrollView.contentSize.height;
      let scrollOffset = aScrollView.contentOffset.y;
      
      if (scrollOffset + scrollViewHeight < scrollContentSizeHeight - 10) {
         hideCaret()
         
      } else if (scrollOffset + scrollViewHeight >= scrollContentSizeHeight - 10) {
         showCaret()
      }
   }
   
   func hideCaret() {
      tintColor = UIColor.clearColor()
   }
   
   func showCaret() {
      tintColor = _cursorColor
   }
}
