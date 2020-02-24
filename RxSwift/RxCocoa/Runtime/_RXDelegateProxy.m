//
//  _RXDelegateProxy.m
//  RxCocoa
//
//  Created by Krunoslav Zaher on 7/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#import "include/_RXDelegateProxy.h"
#import "include/_RX.h"
#import "include/_RXObjCRuntime.h"

@interface _RXDelegateProxy () {
    id __weak __forwardToDelegate;
}

@property (nonatomic, strong) id strongForwardDelegate;

@end

static NSMutableDictionary *voidSelectorsPerClass = nil;

@implementation _RXDelegateProxy

// Marked by Xavier:
//
// Add all methods that the type is void in this protocol and protocols that
// this protocol adopted into a NSSet named selectors.
+(NSSet*)collectVoidSelectorsForProtocol:(Protocol *)protocol {
    NSMutableSet *selectors = [NSMutableSet set];

    unsigned int protocolMethodCount = 0;
    // Marked by Xavier: Those copied to `pMethods` are optional and instance methods
    struct objc_method_description *pMethods = protocol_copyMethodDescriptionList(protocol, NO, YES, &protocolMethodCount);

    for (unsigned int i = 0; i < protocolMethodCount; ++i) {
        struct objc_method_description method = pMethods[i];
        // Marked by Xavier: if the type of method is void, then it will be added into selectors
        if (RX_is_method_with_description_void(method)) {
            [selectors addObject:SEL_VALUE(method.name)];
        }
    }
            
    free(pMethods);

    unsigned int numberOfBaseProtocols = 0;
    Protocol * __unsafe_unretained * pSubprotocols = protocol_copyProtocolList(protocol, &numberOfBaseProtocols);

    // Marked by Xavier:
    //
    // Recursive call collectVoidSelectorsForProtocol to collect all methods that the type
    // is void in the protocols this class adopts.
    // `unionSet` means there is no duplicated methods in selectors.
    for (unsigned int i = 0; i < numberOfBaseProtocols; ++i) {
        [selectors unionSet:[self collectVoidSelectorsForProtocol:pSubprotocols[i]]];
    }
    
    free(pSubprotocols);

    return selectors;
}

/**
 * Marked by Xavier:
 *
 * Method `initialize` searches all optional methods that the type of return value
 * is void existed in protocols of its class and superclasses and adds them into
 * `voidSelectorsPerClass`, a static variable in _RXDelegateProxy.
 */
+(void)initialize {
    @synchronized (_RXDelegateProxy.class) {
        // Marked by Xavier: initialize voidSelectorsPerClass and voidSelectors
        if (voidSelectorsPerClass == nil) {
            voidSelectorsPerClass = [[NSMutableDictionary alloc] init];
        }

        NSMutableSet *voidSelectors = [NSMutableSet set];

#define CLASS_HIERARCHY_MAX_DEPTH 100

        NSInteger  classHierarchyDepth = 0;
        Class      targetClass         = NULL;

        // Marked by Xavier: Search super class until the deep reaches to 100.
        for (classHierarchyDepth = 0, targetClass = self;
             classHierarchyDepth < CLASS_HIERARCHY_MAX_DEPTH && targetClass != nil;
             ++classHierarchyDepth, targetClass = class_getSuperclass(targetClass)
        ) {
            unsigned int count;
            // Marked by Xavier:
            //
            // class_copyProtocolList returns an array of pointers of type of Protocol*. Any
            // protocols adopted by superclasses and other protocols are not included.
            Protocol *__unsafe_unretained *pProtocols = class_copyProtocolList(targetClass, &count);
            
            for (unsigned int i = 0; i < count; i++) {
                NSSet *selectorsForProtocol = [self collectVoidSelectorsForProtocol:pProtocols[i]];
                [voidSelectors unionSet:selectorsForProtocol];
            }
            
            free(pProtocols);
        }

        if (classHierarchyDepth == CLASS_HIERARCHY_MAX_DEPTH) {
            NSLog(@"Detected weird class hierarchy with depth over %d. Starting with this class -> %@", CLASS_HIERARCHY_MAX_DEPTH, self);
#if DEBUG
            abort();
#endif
        }

        // Marked by Xavier: save all void selectors into voidSelectorsPerClass by class
        voidSelectorsPerClass[CLASS_VALUE(self)] = voidSelectors;
    }
}

-(id)_forwardToDelegate {
    return __forwardToDelegate;
}

-(void)_setForwardToDelegate:(id __nullable)forwardToDelegate retainDelegate:(BOOL)retainDelegate {
    __forwardToDelegate = forwardToDelegate;
    if (retainDelegate) {
        self.strongForwardDelegate = forwardToDelegate;
    }
    else {
        self.strongForwardDelegate = nil;
    }
}

-(BOOL)hasWiredImplementationForSelector:(SEL)selector {
    return [super respondsToSelector:selector];
}

// Marked by Xavier: detect whether the type of method corresponding to the
// selector is void
-(BOOL)voidDelegateMethodsContain:(SEL)selector {
    @synchronized(_RXDelegateProxy.class) {
        // Marked by Xavier: about what is voidSelectors please see also initialize()
        NSSet *voidSelectors = voidSelectorsPerClass[CLASS_VALUE(self.class)];
        NSAssert(voidSelectors != nil, @"Set of allowed methods not initialized");
        return [voidSelectors containsObject:SEL_VALUE(selector)];
    }
}

/**
 * Marked by Xavier:
 *
 * The key component of proxy in RxSwift: Message Forwarding
 */
-(void)forwardInvocation:(NSInvocation *)anInvocation {
    BOOL isVoid = RX_is_method_signature_void(anInvocation.methodSignature);
    NSArray *arguments = nil;

    // Marked by Xavier: if return type is void,
    if (isVoid) {
        arguments = RX_extract_arguments(anInvocation);
        [self _sentMessage:anInvocation.selector withArguments:arguments];
    }

    // Marked by Xavier: if `_forwardToDelegate` could respond to the selector, then the invocation
    // will be forwarded to `_forwardToDelegate`
    if (self._forwardToDelegate && [self._forwardToDelegate respondsToSelector:anInvocation.selector]) {
        [anInvocation invokeWithTarget:self._forwardToDelegate];
    }

    if (isVoid) {
        [self _methodInvoked:anInvocation.selector withArguments:arguments];
    }
}

// abstract method
-(void)_sentMessage:(SEL)selector withArguments:(NSArray *)arguments {

}

// abstract method
-(void)_methodInvoked:(SEL)selector withArguments:(NSArray *)arguments {

}

-(void)dealloc {
}

@end
