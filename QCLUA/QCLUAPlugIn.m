/*
 Copyright (c) 2013 Boinx Software Ltd.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "QCLUAPlugIn.h"
#import "QCLUAPlugInViewController.h"
#import "QCLUAFormatter.h"

#import "lua+ObjC.h"
#import "lua+QuartzComposer.h"

#ifndef NSAppKitVersionNumber10_7
#define NSAppKitVersionNumber10_7 1138
#endif



static NSString * const QCLUAPlugInInputPrefix = @"in";
static NSString * const QCLUAPlugInOutputPrefix = @"out";
static NSString * const QCLUAPlugInTypePrefix = @"QC_";
static NSString * const QCLUAPlugInMainName = @"main";
static NSString * const QCLUAPlugInTimeName = @"patchtime";

static NSString * const QCLUAPlugInPreviousValue = @"QCLUAPlugInPreviousValue";


@interface QCLUAPlugIn ()

+ (NSBundle *)bundle;

- (BOOL)setupLUA;
- (void)cleanupLUA;

- (void)updateCode;
- (void)updatePorts;

@end



@implementation QCLUAPlugIn

@synthesize inputPorts = _inputPorts;
@synthesize outputPorts = _outputPorts;

@synthesize code = _code;

- (void)setCode:(NSAttributedString *)newCode
{
	if([newCode isKindOfClass:NSString.class])
	{
		newCode = [[[NSAttributedString alloc] initWithString:(NSString *)newCode] autorelease];
	}
	
	if(_code != newCode)
	{
		BOOL update = ![newCode.string isEqualToString:_code.string];
		
		[newCode retain];
	
		id oldCode = _code;
		
		_code = newCode;
		
		[oldCode release];
		
		if(update)
		{
			[self updateCode];
		}
	}
}

@synthesize error = _error;

@synthesize needsInputRead = _needsInputRead;

@synthesize viewController = _viewController;

+ (NSBundle *)bundle
{
	return [NSBundle bundleForClass:self];
}

+ (NSDictionary *)attributes
{
	return @{
		QCPlugInAttributeNameKey: @"LUA script",
		QCPlugInAttributeDescriptionKey: @"LUA script plug-in",
		QCPlugInAttributeCopyrightKey: @"© 1994–2015 Lua.org, PUC-Rio & © 2013-2015 Boinx Software Ltd.",
		QCPlugInAttributeCategoriesKey: @[
			@"Program", // used by JavaScript patch
		],
		QCPlugInAttributeExamplesKey: @[
			@"LUA-AirHockey.qtz",
		],
	};
}

+ (NSDictionary *)attributesForPropertyPortWithKey:(NSString *)key
{
	return nil;
}

+ (NSArray *)plugInKeys
{
	return [NSArray arrayWithObjects:@"code", nil];
}

+ (QCPlugInExecutionMode)executionMode
{
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode)timeMode
{
	return kQCPlugInTimeModeNone;
}

- (id)init
{
	self = [super init];
	if(self != nil)
	{
		self.inputPorts = [NSMutableDictionary dictionary];
		self.outputPorts = [NSMutableDictionary dictionary];
		
		[self setupLUA];
	}
	return self;
}

- (void)finalize
{
	[self cleanupLUA];
	
	self.inputPorts = nil;
	self.outputPorts = nil;
	
	self.code = nil;
	self.error = nil;
	
	self.viewController = nil;

	[super finalize];
}

- (void)dealloc
{
	[self cleanupLUA];
	
	self.inputPorts = nil;
	self.outputPorts = nil;
	
	self.code = nil;
	self.error = nil;
	
	self.viewController = nil;
	
	[super dealloc];
}

- (id)serializedValueForKey:(NSString *)key
{
	if([key isEqualToString:@"code"])
	{
		return self.code.string;
	}
	
	return [super serializedValueForKey:key];
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key
{
	if([key isEqualToString:@"code"] && [serializedValue isKindOfClass:NSString.class])
	{
		self.code = serializedValue;
		return;
	}
	
	[super setSerializedValue:serializedValue forKey:key];
}

- (QCPlugInViewController *)createViewController
{
	QCLUAPlugInViewController *viewController = [[QCLUAPlugInViewController alloc] initWithPlugIn:self viewNibName:@"QCLUAPlugInViewController"];
	self.viewController = viewController;
	
	NSDictionary *qcAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor colorWithDeviceRed:0.1f green:0.6f blue:0.1f alpha:1.0f], NSForegroundColorAttributeName,
		nil
	];
	
	NSDictionary *typeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor colorWithDeviceRed:0.0f green:0.4f blue:0.0f alpha:1.0f], NSForegroundColorAttributeName,
		nil
	];
	
	[self.viewController.formatter.keywordAttributes setObject:qcAttributes forKey:QCLUAPlugInMainName];
	[self.viewController.formatter.keywordAttributes setObject:qcAttributes forKey:QCLUAPlugInTimeName];
	
	[self.viewController.formatter.prefixAttributes setObject:qcAttributes forKey:QCLUAPlugInInputPrefix];
	[self.viewController.formatter.prefixAttributes setObject:qcAttributes forKey:QCLUAPlugInOutputPrefix];
	
	[self.viewController.formatter.prefixAttributes setObject:typeAttributes forKey:QCLUAPlugInTypePrefix];
	
	return viewController; // this method must return a retained object.
}

- (BOOL)setupLUA
{
	// shutdown old LUA interpreter
	if(L)
	{
		[self cleanupLUA];
	}
	
	@try {
		L = luaL_newstate();
		
		{
			// load default libs
			
			lua_gc(L, LUA_GCSTOP, 0);
			luaL_openlibs(L);
			lua_openQCSupport(L);
			lua_gc(L, LUA_GCRESTART, 0);
		}

		{
			// declare base types
		
			lua_declareQCPortTypes(L);
		}

		if(self.code == nil)
		{
			NSBundle *bundle = [[self class] bundle];
		
			NSString *path = [bundle pathForResource:@"Template" ofType:@"lua"];

			NSString *code = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		
			// this will trigger updateCode
			self.code = [[[NSMutableAttributedString alloc] initWithString:code] autorelease];
		}
		else
		{
			[self updateCode];
		}
	}
	@catch (NSException *e)
	{
		NSLog(@"Unable to init lua: %@ %@ %@", [e name], e, [e userInfo]);
		return NO;
	}
	
	return YES;
}

- (void)cleanupLUA
{
	if(L)
	{
		lua_close(L);
		L = NULL;
	}
}

- (void)updateCode
{
	// check if we have a working LUA setup here
	if(!L)
	{
		return;
	}
	
	@try
	{
		// clear old inputs, output and main
		
		lua_pushglobaltable(L);
		lua_pushnil(L);
		while (lua_next(L, 1))
		{
			if(lua_type(L, -2) != LUA_TSTRING)
			{
				lua_pop(L, 1);
				continue;
			}
			
			NSString *variable = [NSString stringWithUTF8String:lua_tostring(L, -2)];
			
			if((variable.length > QCLUAPlugInInputPrefix.length && [variable hasPrefix:QCLUAPlugInInputPrefix])
			|| (variable.length > QCLUAPlugInOutputPrefix.length && [variable hasPrefix:QCLUAPlugInOutputPrefix])
			|| [variable isEqualToString:QCLUAPlugInMainName])
			{
				lua_pushnil(L);
				lua_setglobal(L, variable.UTF8String);
			}
			
			lua_pop(L, 1);
		}
		lua_pop(L, 1);
		
		// compile new code
		
		if(self.code.length > 0)
		{
			if(luaL_dostring(L, self.code.string.UTF8String) == 0)
			{
				self.error = @"";

				self.needsInputRead = YES;
				[self updatePorts];
			}
			else
			{
				NSString *message = [NSString stringWithUTF8String:lua_tostring(L, -1)];
				
				NSArray *components = [message componentsSeparatedByString:@":"];
				
				self.error = [NSString stringWithFormat:@"🔴 Line %@: %@", [components objectAtIndex:1], [components objectAtIndex:2]];
		
				lua_pop(L, 1);
			}
		}
		else
		{
			self.error = @"";
		}
	}
	@catch (NSException *e)
	{
		NSLog(@"Unable to init lua: %@ %@ %@", [e name], e, [e userInfo]);
		return;
	}
}

- (void)updatePorts
{
	// find all the special variables
	
	NSMutableArray *inputVariables = [NSMutableArray array];
	NSMutableArray *outputVariables = [NSMutableArray array];

	lua_pushglobaltable(L);
	lua_pushnil(L);
	while (lua_next(L, 1))
	{
		if(lua_type(L, -2) != LUA_TSTRING)
		{
			lua_pop(L, 1);
			continue;
		}
		
		NSString *variable = [NSString stringWithUTF8String:lua_tostring(L, -2)];

		if(variable.length > QCLUAPlugInInputPrefix.length && [variable hasPrefix:QCLUAPlugInInputPrefix])
		{
			[inputVariables addObject:variable];
		}
		else if(variable.length > QCLUAPlugInOutputPrefix.length && [variable hasPrefix:QCLUAPlugInOutputPrefix])
		{
			[outputVariables addObject:variable];
		}

		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	// sort the variables
	
	[inputVariables sortUsingSelector:@selector(compare:)];
	[outputVariables sortUsingSelector:@selector(compare:)];

	// update input ports
	
	NSMutableArray *previousInputPortKeys = [[self.inputPorts.allKeys mutableCopy] autorelease];
	for(NSString *variable in inputVariables)
	{
		lua_getglobal(L, variable.UTF8String);
		NSString *portType = lua_QCPortType(L, -1);
		lua_pop(L, 1);
		
		if(portType == nil)
		{
			NSLog(@"unhandled type for input: %@", variable);
			
			if(self.error.length == 0)
			{
				self.error = [NSString stringWithFormat:@"⭕ Unable to detect input type for: %@", variable];
			}
			continue;
		}
		
		NSString *portKey = [variable substringFromIndex:QCLUAPlugInInputPrefix.length];

		NSDictionary *inputPort = [self.inputPorts objectForKey:portKey];
		if(inputPort)
		{
			NSString *inputPortType = [inputPort objectForKey:QCPortAttributeTypeKey];
			if(![portType isEqualToString:inputPortType])
			{
				inputPort = [NSDictionary dictionaryWithObjectsAndKeys:
					portKey, QCPortAttributeNameKey,
					portType, QCPortAttributeTypeKey,
					nil
				];
				[self.inputPorts setObject:inputPort forKey:portKey];
					
				[self removeInputPortForKey:portKey];
				[self addInputPortWithType:portType forKey:portKey withAttributes:nil];
			}
		
			[previousInputPortKeys removeObject:portKey];
		}
		else
		{
			inputPort = [NSDictionary dictionaryWithObjectsAndKeys:
				portKey, QCPortAttributeNameKey,
				portType, QCPortAttributeTypeKey,
				nil
			];
				
			[self.inputPorts setObject:inputPort forKey:portKey];
				
			[self addInputPortWithType:portType forKey:portKey withAttributes:nil];
		}
	}
	
	for(NSString *key in previousInputPortKeys)
	{
		[self.inputPorts removeObjectForKey:key];
		[self removeInputPortForKey:key];
	}
	
	// update output ports
	
	NSMutableArray *previousOutputPortKeys = [[self.outputPorts.allKeys mutableCopy] autorelease];
	for(NSString *variable in outputVariables)
	{
		lua_getglobal(L, variable.UTF8String);
		NSString *portType = lua_QCPortType(L, -1);
		lua_pop(L, 1);
		
		if(portType == nil)
		{
			NSLog(@"unhandled type for output: %@", variable);
			
			if(self.error.length == 0)
			{
				self.error = [NSString stringWithFormat:@"⭕ Unable to detect output type for: %@", variable];
			}

			continue;
		}
		
		NSString *portKey = [variable substringFromIndex:QCLUAPlugInOutputPrefix.length];
		
		NSDictionary *outputPort = [self.outputPorts objectForKey:portKey];
		if(outputPort)
		{
			NSString *outputPortType = [outputPort objectForKey:QCPortAttributeTypeKey];
			if(![portType isEqualToString:outputPortType])
			{
				outputPort = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					portKey, QCPortAttributeNameKey,
					portType, QCPortAttributeTypeKey,
					nil
				];
				[self.outputPorts setObject:outputPort forKey:portKey];
				
				[self removeOutputPortForKey:portKey];
				[self addOutputPortWithType:portType forKey:portKey withAttributes:nil];
			}
			
			[previousOutputPortKeys removeObject:portKey];
		}
		else
		{
			outputPort = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				portKey, QCPortAttributeNameKey,
				portType, QCPortAttributeTypeKey,
				nil
			];
			
			[self.outputPorts setObject:outputPort forKey:portKey];
			
			[self addOutputPortWithType:portType forKey:portKey withAttributes:nil];
		}
	}

	for(NSString *key in previousOutputPortKeys)
	{
		[self.outputPorts removeObjectForKey:key];
		[self removeOutputPortForKey:key];
	}
}

@end

@implementation QCLUAPlugIn (Execution)

- (BOOL)startExecution:(id<QCPlugInContext>)context
{
	if(!L)
	{
		return NO;
	}
	
	self.needsInputRead = YES;
	
	for(NSString *key in self.outputPorts)
	{
		NSMutableDictionary *outputPort = [self.outputPorts objectForKey:key];
		
		[outputPort removeObjectForKey:QCLUAPlugInPreviousValue];
	}
	
	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context
{
}

- (BOOL)execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary *)arguments
{
	// set global variables
	
	lua_pushnumber(L, time);
	lua_setglobal(L, QCLUAPlugInTimeName.UTF8String);
	
	// read inputs
	
	for(NSString *key in self.inputPorts)
	{
		if(![self didValueForInputKeyChange:key] && self.needsInputRead == NO)
		{
			continue;
		}
		
		id value = [self valueForInputKey:key];

		if(lua_pushNSObject(L, value))
		{
			NSString *variable = [NSString stringWithFormat:@"in%@", key];
			
			lua_setglobal(L, variable.UTF8String);
		}
	}

	self.needsInputRead = NO;

	// execute
	
	lua_getglobal(L, QCLUAPlugInMainName.UTF8String);
	if(!lua_pcall(L, 0, 0, 0))
	{
		//NSLog(@"executed");
	}
	else
	{
		if(self.error.length == 0)
		{
			NSString *message = [NSString stringWithUTF8String:lua_tostring(L, -1)];
			
			NSArray *components = [message componentsSeparatedByString:@":"];
			
			self.error = [NSString stringWithFormat:@"❌ Line %@: %@", [components objectAtIndex:1], [components objectAtIndex:2]];
		}
		
		[context logMessage:@"%@ lua error in main(). %s", context, lua_tostring(L, -1)];
		
		lua_pop(L, 1);
	}
	
	// write outputs
	
	for(NSString *key in self.outputPorts)
	{
		NSString *variable = [NSString stringWithFormat:@"out%@", key];
		
		lua_getglobal(L, [variable UTF8String]);
		id value = lua_toNSObject(L, lua_gettop(L));
		lua_pop(L, 1);
		
		if (NSAppKitVersionNumber < NSAppKitVersionNumber10_7)  // only on 10.7 and above we can provide an array as structure output
		{
			if ([value isKindOfClass:[NSArray class]])
			{
				Class QCStructureClass = NSClassFromString(@"QCStructure");
				value = [[[QCStructureClass alloc] initWithArray:value] autorelease];
				value = [value dictionaryRepresentation];
			}
		}
		
		if(value)
		{
			@try
			{
				// todo: check for value
				
				NSMutableDictionary *outputPort = [self.outputPorts objectForKey:key];
				
				id previousValue = [outputPort objectForKey:QCLUAPlugInPreviousValue];
				
				if(![previousValue isEqual:value])
				{
					[self setValue:value forOutputKey:key];
					
					[outputPort setObject:value forKey:QCLUAPlugInPreviousValue];
			
					//NSLog(@"Set output %@ to (%@) %@ previous (%@) %@", key, [value class], value, [previousValue class], previousValue);
				}
				else
				{
					//NSLog(@"Output unchanged %@ is (%@) %@", key, [value class], value);
				}
			}
			@catch (NSException *exception)
			{
				//NSLog(@"Unable to set %@ to (%@) %@", key, [value class], value);
			}
		}
		else
		{
			//NSLog(@"No value for %@", key);
		}
		
	}

	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context
{
}

- (void)stopExecution:(id <QCPlugInContext>)context
{
}

@end
