/*
 Copyright (c) 2013 Boinx Software Ltd.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#pragma once

#import <Foundation/Foundation.h>

#import "lua.h"

// pushing

BOOL lua_pushNSNumber(lua_State *L, NSNumber *number);
BOOL lua_pushNSString(lua_State *L, NSString *string);

BOOL lua_pushNSArray(lua_State *L, NSArray *array);
BOOL lua_pushNSDictionary(lua_State *L, NSDictionary *dictionary);

BOOL lua_pushNSObject(lua_State *L, id object);

// reading

NSNumber *lua_toNSNumber(lua_State *L, int idx);
NSString *lua_toNSString(lua_State *L, int idx);

NSArray *lua_toNSArray(lua_State *L, int idx);
NSDictionary *lua_toNSDictionary(lua_State *L, int idx);

id lua_toNSObject(lua_State *L, int idx);

// stack dump

NSString *lua_stackToNSString(lua_State *L);
