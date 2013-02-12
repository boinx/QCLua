/*
 Copyright (c) 2013 Boinx Software Ltd.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "lua+QuartzComposer.h"

void lua_declareQCPortTypes(lua_State *L)
{
	lua_pushnumber(L, 0.0);
	lua_setglobal(L, "QC_INDEX");
	
	lua_pushnumber(L, -0.0); // all negative numbers are handled as a number
	lua_setglobal(L, "QC_NUMBER");
	
	lua_pushboolean(L, 0);
	lua_setglobal(L, "QC_BOOLEAN");
	
	lua_pushstring(L, "");
	lua_setglobal(L, "QC_STRING");
	
	lua_createtable(L, 0, 0);
	lua_setglobal(L, "QC_STRUCT");
}

NSString *lua_QCPortType(lua_State *L, int idx)
{
	int type = lua_type(L, idx);
	
	switch(type)
	{
		case LUA_TBOOLEAN :
			return QCPortTypeBoolean;
		
		case LUA_TNUMBER :
		{
			// lua does not distinguish between integer and real numbers, so we use the sign as indicator
			lua_Number number = lua_tonumber(L, idx);
			if(signbit(number))
			{
				return QCPortTypeNumber;
			}
			else
			{
				return QCPortTypeIndex;
			}
		}
		
		case LUA_TSTRING :
			return QCPortTypeString;
		
		case LUA_TTABLE :
			return QCPortTypeStructure;
		
		default:
			return nil;
	}
}

int lua_openQCSupport(lua_State *L)
{
	NSDictionary* systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	
	NSString* productVersion = [systemVersion objectForKey:@"ProductVersion"];
	
	lua_pushstring(L, productVersion.UTF8String);
	lua_setglobal(L, "qcsystemversion");
	
	return 0;
}
