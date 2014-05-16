//
//  XCDFormInputAccessoryView.m
//
//  Created by Cédric Luthi on 2012-11-10
//  Copyright (c) 2012 Cédric Luthi. All rights reserved.
//

#import "XCDFormInputAccessoryView.h"

static NSArray * EditableTextInputsInView(UIView *view)
{
	NSMutableArray *textInputs = [NSMutableArray new];
	for (UIView *subview in view.subviews)
	{
		BOOL isEnabledTextField = [subview isKindOfClass:[UITextField class]] && [(UITextField *)subview isEnabled];
		BOOL isEditableTextView = [subview isKindOfClass:[UITextView class]] && [(UITextView *)subview isEditable];
		if (isEnabledTextField || isEditableTextView)
			[textInputs addObject:subview];
		else
			[textInputs addObjectsFromArray:EditableTextInputsInView(subview)];
	}
	return textInputs;
}

@interface XCDFormInputAccessoryView ()

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *previousBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *nextBarButtonItem;

@end

@implementation XCDFormInputAccessoryView

- (id) initWithFrame:(CGRect)frame
{
	return [self initWithResponders:nil];
}

- (id) initWithResponders:(NSArray *)responders
{
	if (!(self = [super initWithFrame:CGRectZero]))
		return nil;
	
	_responders = responders;
	
	self.toolbar = [[UIToolbar alloc] init];
	self.toolbar.barStyle = UIBarStyleDefault;
	self.toolbar.translucent = YES;
	self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIImage *previousImage = [UIImage imageNamed:@"XCDFormInputAccessoryView.bundle/button-arrow-left"];
	UIImage *nextImage = [UIImage imageNamed:@"XCDFormInputAccessoryView.bundle/button-arrow-right"];
	self.previousBarButtonItem = [[UIBarButtonItem alloc] initWithImage:previousImage style:UIBarButtonItemStylePlain target:self action:@selector(previous:)];
	self.nextBarButtonItem = [[UIBarButtonItem alloc] initWithImage:nextImage style:UIBarButtonItemStylePlain target:self action:@selector(next:)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	space.width = 20;
	self.toolbar.items = @[self.previousBarButtonItem, space, self.nextBarButtonItem, flexSpace];
	self.hasDoneButton = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
	
	[self addSubview:self.toolbar];
	
	self.frame = self.toolbar.frame = (CGRect){CGPointZero, [self.toolbar sizeThatFits:CGSizeZero]};
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputDidBeginEditing:) name:UITextFieldTextDidBeginEditingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputDidBeginEditing:) name:UITextViewTextDidBeginEditingNotification object:nil];
	
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) updateSegmentedControl
{
	NSArray *responders = self.responders;
	if ([responders count] == 0)
		return;
	
	self.previousBarButtonItem.enabled = ![responders.firstObject isFirstResponder];
	self.nextBarButtonItem.enabled = ![responders.lastObject isFirstResponder];
}

- (void) willMoveToWindow:(UIWindow *)window
{
	if (!window)
		return;
	
	[self updateSegmentedControl];
}

- (void) textInputDidBeginEditing:(NSNotification *)notification
{
	[self updateSegmentedControl];
}

- (NSArray *) responders
{
	if (_responders)
		return _responders;
	
	NSArray *textInputs = EditableTextInputsInView([[UIApplication sharedApplication] keyWindow]);
	return [textInputs sortedArrayUsingComparator:^NSComparisonResult(UIView *textInput1, UIView *textInput2) {
		UIView *commonAncestorView = textInput1.superview;
		while (commonAncestorView && ![textInput2 isDescendantOfView:commonAncestorView])
			commonAncestorView = commonAncestorView.superview;
		
		CGRect frame1 = [textInput1 convertRect:textInput1.bounds toView:commonAncestorView];
		CGRect frame2 = [textInput2 convertRect:textInput2.bounds toView:commonAncestorView];
		
		NSComparisonResult result = [@(CGRectGetMinY(frame1)) compare:@(CGRectGetMinY(frame2))];
		if (result == NSOrderedSame) {
			result = [@(CGRectGetMinX(frame1)) compare:@(CGRectGetMinX(frame2))];
		}
		
		return result;
	}];
}

- (void)setHasDoneButton:(BOOL)hasDoneButton
{
	[self setHasDoneButton:hasDoneButton animated:NO];
}

- (void)setHasDoneButton:(BOOL)hasDoneButton animated:(BOOL)animated
{
	if (_hasDoneButton == hasDoneButton)
		return;
	
	[self willChangeValueForKey:@"hasDoneButton"];
	_hasDoneButton = hasDoneButton;
	[self didChangeValueForKey:@"hasDoneButton"];
	
	NSArray *items;
	if (hasDoneButton) {
		UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
		items = [self.toolbar.items arrayByAddingObject:done];
	} else {
		items = [self.toolbar.items subarrayWithRange:NSMakeRange(0, 2)];
	}
	
	[self.toolbar setItems:items animated:animated];
}

#pragma mark - Actions

- (void)previous:(id)sender
{
	NSArray *firstResponders = [self.responders filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIResponder *responder, NSDictionary *bindings) {
		return [responder isFirstResponder];
	}]];
	UIResponder *firstResponder = [firstResponders lastObject];
	NSInteger firstResponderIndex = [self.responders indexOfObject:firstResponder];
	NSInteger adjacentResponderIndex = firstResponderIndex != NSNotFound ? firstResponderIndex - 1 : NSNotFound;
	UIResponder *adjacentResponder = nil;
	if (adjacentResponderIndex >= 0 && adjacentResponderIndex < (NSInteger)[self.responders count])
		adjacentResponder = [self.responders objectAtIndex:adjacentResponderIndex];
	
	[adjacentResponder becomeFirstResponder];
}

- (void)next:(id)sender
{
	NSArray *firstResponders = [self.responders filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIResponder *responder, NSDictionary *bindings) {
		return [responder isFirstResponder];
	}]];
	UIResponder *firstResponder = [firstResponders lastObject];
	NSInteger firstResponderIndex = [self.responders indexOfObject:firstResponder];
	NSInteger adjacentResponderIndex = firstResponderIndex != NSNotFound ? firstResponderIndex + 1 : NSNotFound;
	UIResponder *adjacentResponder = nil;
	if (adjacentResponderIndex >= 0 && adjacentResponderIndex < (NSInteger)[self.responders count])
		adjacentResponder = [self.responders objectAtIndex:adjacentResponderIndex];
	
	[adjacentResponder becomeFirstResponder];
}

- (void) done
{
	[[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

@end
