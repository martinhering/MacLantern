/*
 * Copyright (C) 2017 Martin Hering
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor,
 * Boston, MA  02110-1301, USA.
 */

#import <Foundation/Foundation.h>

@interface NSObject (MacLantern)
- (void) coalescedPerformSelector:(SEL)sel;
- (void) coalescedPerformSelector:(SEL)sel afterDelay:(NSTimeInterval)delay;
- (void) coalescedPerformSelector:(SEL)sel object:(id)object afterDelay:(NSTimeInterval)delay;

#pragma mark -
- (void)setAssociatedObject:(id)value forKey:(NSString *)key;
- (void)setAssociatedObjectCopy:(id)value forKey:(NSString*)key;
- (id)associatedObjectForKey:(NSString *)key;
- (NSMutableDictionary *)associatedObjects;

#pragma mark -
- (NSArray*) arrayFromMethodList;
+ (NSArray*) arrayFromMethodList;
+ (BOOL) implementsSelector:(SEL)selector;
+ (BOOL) implementsClassSelector:(SEL)selector;
+ (void)swizzleSelector:(SEL)oldSel withSelector:(SEL)newSel;

#pragma mark -
- (NSString*) perform:(void (^)(id sender))block afterDelay:(NSTimeInterval)delay;
- (void) cancelPerformBlockWithIdentifier:(NSString*)identifier;
- (void) cancelPerformBlocks;

#pragma mark -
typedef void(^VMObservationBlock)(id obj, NSDictionary *change);

- (NSString *)addObserverForKeyPath:(NSString *)keyPath task:(VMObservationBlock)task;
- (void)addObserverForKeyPath:(NSString *)keyPath identifier:(NSString *)identifier task:(VMObservationBlock)task;
- (void)removeObserverForKeyPath:(NSString *)inKeyPath identifier:(NSString *)token;

- (void)addTaskObserver:(id)observer forKeyPath:(NSString *)keyPath task:(VMObservationBlock)task;
- (void)removeTaskObserver:(id)observer forKeyPath:(NSString *)keyPath;

- (void)addTaskObserver:(id)observer forKeyPathes:(NSArray<NSString*> *)keyPathes task:(VMObservationBlock)task;
- (void)removeTaskObserver:(id)observer forKeyPathes:(NSArray<NSString*> *)keyPathes;

- (void)removeAllBlockObservers;

#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
-(void) propagateValue:(id)value forBinding:(NSString*)binding;
@end
#endif
