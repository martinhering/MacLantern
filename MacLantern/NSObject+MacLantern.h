//
//  NSObject+VMFoundation.h
//  Instacast
//
//  Created by Martin Hering on 07.01.13.
//
//

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
