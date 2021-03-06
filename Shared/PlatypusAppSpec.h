/*
    Platypus - program for creating Mac OS X application wrappers around scripts
    Copyright (C) 2003-2011 Sveinbjorn Thordarson <sveinbjornt@gmail.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

// PlatypusAppSpec is a wrapper class around an NSDictionary containing
// all the information / specifications for creating a Platypus application.

#import <Cocoa/Cocoa.h>
#import "CommonDefs.h"

#define MAX_APPSPEC_PROPERTIES	128 // whatever...

@interface PlatypusAppSpec : NSObject 
{
	NSMutableDictionary		*properties;
	NSString				*error;
}
-(PlatypusAppSpec *)initWithDefaults;
-(PlatypusAppSpec *)initWithDictionary: (NSDictionary *)dict;
-(PlatypusAppSpec *)initFromFile: (NSString *)filePath;
+(PlatypusAppSpec *)profileWithDefaults;
+(PlatypusAppSpec *)profileWithDictionary: (NSDictionary *)dict;
+(PlatypusAppSpec *)profileFromFile: (NSString *)filePath;
-(void)setDefaults;
-(BOOL)create;
-(BOOL)verify;
-(void)dump: (NSString *)filePath;
-(NSString *)commandString;
-(void)setProperty: (id)property forKey: (NSString *)theKey;
-(id)propertyForKey: (NSString *)theKey;
-(NSDictionary *)properties;
-(void)addProperties: (NSDictionary *)dict;
-(NSString *)error;
@end
