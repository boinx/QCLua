/*
 Copyright (c) 2013 Boinx Software Ltd.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "QCLUAPlugInViewController.h"

#import "NoodleLineNumberView.h"

#import "QCLUAFormatter.h"


@implementation QCLUAPlugInViewController

@synthesize scrollView = _scrollView;
@synthesize textView = _textView;
@synthesize lineNumberView = _lineNumberView;

@synthesize errorView = _errorView;

@synthesize formatter = _formatter;

- (id)initWithPlugIn:(QCPlugIn *)plugIn viewNibName:(NSString *)name
{
	self = [super initWithPlugIn:plugIn viewNibName:name];
	if(self != nil)
	{
		self.formatter = [[[QCLUAFormatter alloc] init] autorelease];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextStorageDidProcessEditingNotification object:self.textView.textStorage];
	
	// prevent retain cycle
	self.scrollView.hasVerticalRuler = NO;
	self.scrollView.verticalRulerView = nil;
	
	self.scrollView = nil;
	self.textView = nil;
	self.lineNumberView = nil;
	
	self.errorView = nil;
	
	[super dealloc];
}

- (void)loadView
{
	[super loadView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textStorageDidProcessEditing:) name:NSTextStorageDidProcessEditingNotification object:self.textView.textStorage];

	if(self.scrollView && !self.lineNumberView)
	{
		self.lineNumberView = [[[NoodleLineNumberView alloc] initWithScrollView:self.scrollView] autorelease];
		self.scrollView.verticalRulerView = self.lineNumberView;
		self.scrollView.hasHorizontalRuler = NO;
		self.scrollView.hasVerticalRuler = YES;
		self.scrollView.rulersVisible = YES;
	}
}

#pragma mark - NSTextViewDelegate

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSTextStorage *textStorage = notification.object;

	[self.formatter formatString:textStorage];
}

@end
