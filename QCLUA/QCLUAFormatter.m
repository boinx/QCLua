/*
 Copyright (c) 2013 Boinx Software Ltd.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "QCLUAFormatter.h"


@implementation QCLUAFormatter

@synthesize keywordAttributes = _keywordAttributes;
@synthesize prefixAttributes  = _prefixAttributes;

@synthesize defaultAttributes = _defaultAttributes;
@synthesize stringAttributes  = _stringAttributes;
@synthesize commentAttributes = _commentAttributes;


- (id)init
{
	self = [super init];
	if(self != nil)
	{
		self.defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"Monaco" size:10.0], NSFontAttributeName,
			[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:1.0f], NSForegroundColorAttributeName,
			nil
		];
		
		self.stringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSColor colorWithDeviceRed:0.8f green:0.0f blue:0.0f alpha:1.0f], NSForegroundColorAttributeName,
			nil
		];

		self.commentAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSColor colorWithDeviceRed:0.7f green:0.7f blue:0.7f alpha:1.0f], NSForegroundColorAttributeName,
			nil
		];

		self.keywordAttributes = [NSMutableDictionary dictionary];
		self.prefixAttributes = [NSMutableDictionary dictionary];
		
		// LUA keywords
		{
			NSColor *LUAAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSColor colorWithDeviceRed:0.2f green:0.2f blue:0.7f alpha:1.0f], NSForegroundColorAttributeName,
				nil
			];
		
			[self.keywordAttributes setObject:LUAAttributes forKey:@"and"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"break"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"do"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"else"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"elseif"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"end"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"false"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"for"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"function"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"goto"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"if"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"in"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"local"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"nil"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"not"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"or"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"repeat"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"return"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"then"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"true"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"until"];
			[self.keywordAttributes setObject:LUAAttributes forKey:@"while"];
		}
	}
	return self;
}

- (void)dealloc
{
	self.defaultAttributes = nil;
	self.stringAttributes = nil;
	self.commentAttributes = nil;

    self.keywordAttributes = nil;
	self.prefixAttributes = nil;
	
	[super dealloc];
}

- (NSAttributedString *)formattedStringFromString:(NSString *)string
{
	NSMutableAttributedString *attributedString = [[[NSMutableAttributedString alloc] initWithString:string] autorelease];

	[self formatString:attributedString];
	
	return attributedString;
}

- (void)formatString:(NSMutableAttributedString *)attributedString
{
	[attributedString setAttributes:self.defaultAttributes range:NSMakeRange(0, attributedString.length)];

	@try
	{
		NSScanner *scanner = [NSScanner scannerWithString:attributedString.string];
		scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@" \r\n\t;:,.=+-~/*(){}[]"];

		while(!scanner.isAtEnd)
		{
			NSString *word = nil;
			if([scanner scanUpToCharactersFromSet:scanner.charactersToBeSkipped intoString:&word])
			{
				NSRange range = NSMakeRange(scanner.scanLocation - word.length, word.length);
			
				// Check for keyword
				{
					NSDictionary *attributes = [self.keywordAttributes objectForKey:word];
					if(attributes)
					{
						[attributedString addAttributes:attributes range:range];
						continue;
					}
				}
			
				// check for prefix
				for(NSString *prefix in self.prefixAttributes)
				{
					if([word hasPrefix:prefix])
					{
						NSDictionary *attributes = [self.prefixAttributes objectForKey:prefix];
						[attributedString addAttributes:attributes range:range];
						break;
					}
				}	
			}
		}
		
		NSCharacterSet *quoteCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\"'"];
		scanner.scanLocation = 0;
		scanner.charactersToBeSkipped = nil;
		while(!scanner.isAtEnd)
		{
			[scanner scanUpToCharactersFromSet:quoteCharacterSet intoString:nil];
			if(scanner.isAtEnd)
			{
				break;
			}
		
			NSRange range;
			range.location = scanner.scanLocation;
			range.length = 1;
		
			NSString *quoteString = [scanner.string substringWithRange:NSMakeRange(scanner.scanLocation, 1)];
			
			scanner.scanLocation += 1;
		
			while(!scanner.isAtEnd)
			{
				[scanner scanUpToString:quoteString intoString:nil];
				if(scanner.isAtEnd)
				{
					break;
				}
			
				// text string was escaped here
				if([scanner.string characterAtIndex:scanner.scanLocation - 1] == '\\')
				{
					scanner.scanLocation += 1;
					continue;
				}
			
				scanner.scanLocation += 1;
				range.length = scanner.scanLocation - range.location;
				break;
			}
		
			for(NSString *attribute in self.stringAttributes)
			{
				[attributedString removeAttribute:attribute range:range];
			}
			[attributedString addAttributes:self.stringAttributes range:range];
		}
	
		NSCharacterSet *newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
		scanner.scanLocation = 0;
		scanner.charactersToBeSkipped = nil;
		while(!scanner.isAtEnd)
		{
			NSRange range;
		
			if(scanner.scanLocation == 0 && [scanner.string hasPrefix:@"--"]) {
				range.location = 0;
			} else {
				[scanner scanUpToString:@"--" intoString:nil];
				range.location = scanner.scanLocation;
			}
			
			if(scanner.isAtEnd)
			{
				break;
			}
		
			[scanner scanUpToCharactersFromSet:newlineCharacterSet intoString:nil];
			range.length = scanner.scanLocation - range.location;
		
			scanner.scanLocation -= 1;
		
			// no removeAttributes:range:
			for(NSString *attribute in self.commentAttributes)
			{
				[attributedString removeAttribute:attribute range:range];
			}
			[attributedString addAttributes:self.commentAttributes range:range];
		}
	}
	@catch(...)
	{
		
	}
}

@end
