/*
 Copyright (c) 2013 Boinx Software Ltd.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "lua+ObjC.h"

static BOOL NSStringIntegerRepresentaion(NSString *string, NSInteger *integer)
{
	if(string.length == 0)
	{
		return NO;
	}
	
	unichar c = [string characterAtIndex:0];
	if(c != '-' && !(c >= '0' && c <= '9'))
	{
		return NO;
	}
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	
	NSInteger i;
	if(![scanner scanInteger:&i] || ![scanner isAtEnd])
	{
		return NO;
	}
	
	if(integer)
	{
		*integer = i;
	}

	return YES;
}



BOOL lua_pushNSNumber(lua_State *L, NSNumber *number)
{
	if(CFGetTypeID((CFNumberRef)number) == CFBooleanGetTypeID())
	{
		lua_pushboolean(L, number.boolValue);
	}
	else
	{
		lua_pushnumber(L, number.doubleValue);
	}
	return YES;
}

BOOL lua_pushNSString(lua_State *L, NSString *string)
{
	lua_pushstring(L, string.UTF8String);
	
	return YES;
}

BOOL lua_pushNSArray(lua_State *L, NSArray *array)
{
	lua_createtable(L, (int)array.count, 0);
	
	NSUInteger index = 1; // lua iterates from 1
	for(id value in array)
	{		
		lua_pushinteger(L, index);
		lua_pushNSObject(L, value);
		lua_settable(L, -3);
		
		index++;
	}
	
	return YES;
}

BOOL lua_pushNSDictionary(lua_State *L, NSDictionary *dictionary)
{
	lua_createtable(L, (int)dictionary.count, 0);
	
	for(id key in dictionary)
	{
		id value = [dictionary objectForKey:key];
		
		if([key isKindOfClass:[NSString class]])
		{
			NSString *string = (NSString *)key;
			
			NSInteger integer = 0;
			if(NSStringIntegerRepresentaion(string, &integer))
			{
				if(integer >= 0)
				{
					integer += 1; // lua iterates from 1
				}
				lua_pushnumber(L, (double)integer);
			}
			else
			{
				lua_pushstring(L, string.UTF8String);
			}
			lua_pushNSObject(L, value);
			lua_settable(L, -3);
		}
		else if([key isKindOfClass:[NSNumber class]])
		{
			NSNumber *number = (NSNumber *)key;

			lua_pushnumber(L, number.doubleValue + 1.0); // lua iterates from 1
			lua_pushNSObject(L, value);
			lua_settable(L, -3);
		}
	}

	return YES;
}

BOOL lua_pushNSObject(lua_State *L, id object)
{
	if(object == nil)
	{
		lua_pushnil(L);
		return YES;
	}
	
	if(object == [NSNull null])
	{
		lua_pushnil(L);
		return YES;
	}
	
	if([object isKindOfClass:[NSNumber class]])
	{
		return lua_pushNSNumber(L, (NSNumber *)object);
	}
	
	if([object isKindOfClass:[NSString class]])
	{
		return lua_pushNSString(L, (NSString *)object);
	}
	
	if([object isKindOfClass:[NSArray class]])
	{
		return lua_pushNSArray(L, (NSArray *)object);
	}
	
	if([object isKindOfClass:[NSDictionary class]])
	{
		return lua_pushNSDictionary(L, (NSDictionary *)object);
	}
	
	return NO;
}




NSNumber *lua_toNSNumber(lua_State *L, int idx)
{
	return [NSNumber numberWithDouble:lua_tonumber(L, idx)];
}

NSString *lua_toNSString(lua_State *L, int idx)
{
	return [NSString stringWithUTF8String:lua_tostring(L, idx)];
}

NSArray *lua_toNSArray(lua_State *L, int idx)
{
	NSMutableArray *array = [NSMutableArray array];
	
	const size_t length = lua_rawlen(L, idx);
	
	for(size_t index = 1; index <= length; ++index)
	{
		lua_rawgeti(L, idx, (int)index);
		
		id object = lua_toNSObject(L, lua_gettop(L));
		
		if(object == nil)
		{
			object = [NSNull null];
		}
		
		[array addObject:object];
		
		lua_pop(L, 1);
	}
	
	return array;
}

NSDictionary *lua_toNSDictionary(lua_State *L, int idx)
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	
	lua_pushnil(L);
	while(lua_next(L, idx))
	{
		id key = lua_toNSObject(L, lua_gettop(L) - 1);
		id object = lua_toNSObject(L, lua_gettop(L));
		
		if(object == nil)
		{
			object = [NSNull null];
		}
		
		if([key isKindOfClass:[NSNumber class]] || [key isKindOfClass:[NSString class]])
		{
			[dictionary setObject:object forKey:key];
		}
		
		lua_pop(L, 1);
	}

	return dictionary;
}

id lua_toNSObject(lua_State *L, int idx) {
	int type = lua_type(L, idx);
	
	if(type == LUA_TNIL)
	{
		return [NSNull null];
	}
	
	// bools are a special case, also NSNumer in ObjC
	if(type == LUA_TBOOLEAN)
	{
		return [NSNumber numberWithBool:lua_toboolean(L, idx)];
	}

	if(type == LUA_TNUMBER)
	{
		return lua_toNSNumber(L, idx);
	}
	
	if(type == LUA_TSTRING)
	{
		return lua_toNSString(L, idx);
	}
	
	if(type == LUA_TTABLE)
	{
		// when numeric indices are present an NSArray is generated
		if(lua_rawlen(L, idx) > 0)
		{
			return lua_toNSArray(L, idx);
		}
		else
		{
			return lua_toNSDictionary(L, idx);
		}
	}

	return nil;
}


NSString *lua_stackToNSString(lua_State *L)
{
	const int count = lua_gettop(L);

	NSMutableString *result = [NSMutableString stringWithFormat:@"LUA %p Stack Size: %d", L, count];
	
	for(int index = 1; index <= count; ++index)
	{
		int type = lua_type(L, index);
		
		switch(type)
		{
			case LUA_TBOOLEAN :
				[result appendFormat:@"\n%@", lua_toboolean(L, index) ? @"true" : @"false"];
				break;
				
			case LUA_TNUMBER :
				[result appendFormat:@"\n%f", lua_tonumber(L, index)];
				break;
				
			case LUA_TSTRING :
				[result appendFormat:@"\n\"%s\"", lua_tostring(L, index)];
				break;
				
			default:
				[result appendFormat:@"\n<%s>", lua_typename(L, index)];
				break;
		}
	}
	
	return result;
}
