//
//  FV2AuthPluginMechanism.m
//  FV2AuthPlugin
//
//  Created by Burgin, Thomas (NIH/NIMH) [C] on 5/7/15.
//  Copyright (c) 2015 NIH. All rights reserved.
//

#import "FV2AuthPluginMechanism.h"

@implementation FV2AuthPluginMechanism

+ (OSStatus) runMechanism:(MechanismRecord*)mechanism {
    
    NSLog(@"FV2AuthPlugin:MechanismInvoke:AddUsers *************************************");
    
    OSStatus err;
    const AuthorizationValue *value;
    AuthorizationContextFlags flags;
    CFStringRef username;
    CFStringRef password;
    
    // Open libcsfde.dylib.
    void *libcsfde_handle = dlopen("libcsfde.dylib", RTLD_LOCAL | RTLD_LAZY);
    if (!libcsfde_handle) {
        NSLog(@"FV2AuthPlugin:[!] [%s] Unable to load library: %s\n", __FILE__, dlerror());
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    
    // Open libodfde.dylib.
    void *libodfde_handle = dlopen("libodfde.dylib", RTLD_LOCAL | RTLD_LAZY);
    if (!libodfde_handle) {
        NSLog(@"FV2AuthPlugin:[!] [%s] Unable to load library: %s\n", __FILE__, dlerror());
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    
    // Grab the CSFDEStorePassphrase symbol
    CFStringRef (*CSFDEStorePassphrase)(const char *password) = dlsym(libcsfde_handle, "CSFDEStorePassphrase");
    if (!CSFDEStorePassphrase) {
        NSLog(@"FV2AuthPlugin:[!] [%s] Unable to get symbol: %s\n", __FILE__, dlerror());
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    
    // Grab the ODFDEAddUser symbol
    BOOL (*ODFDEAddUser)(CFStringRef authuser, CFStringRef authpass, CFStringRef username, CFStringRef password) = dlsym(libodfde_handle, "ODFDEAddUser");
    if (!ODFDEAddUser) {
        NSLog(@"FV2AuthPlugin:[!] [%s] Unable to get symbol: %s\n", __FILE__, dlerror());
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    
    // Get the AuthorizationEnvironmentUsername
    err = noErr;
    NSLog(@"FV2AuthPlugin:[+] Attempting to receive kAuthorizationEnvironmentUsername");
    err = mechanism->fPlugin->fCallbacks->GetContextValue(mechanism->fEngine, kAuthorizationEnvironmentUsername, &flags, &value);
    if (err == noErr && (value->length > 0) && (((const char *) value->data)[value->length - 1] == 0)) {
        username = CFStringCreateWithCString(NULL, (const char *) value->data, kCFStringEncodingUTF8);
        NSLog(@"FV2AuthPlugin:[+] kAuthorizationEnvironmentUsername [%@] was used.", username);
    } else {
        NSLog(@"FV2AuthPlugin:[!] kAuthorizationEnvironmentUsername was unreadable.");
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    if ([(__bridge NSString*)username isEqualToString:@"rlcadmin"]) {
        NSLog(@"FV2AuthPlugin:[!] User [rlcadmin] is blocked from FV2AuthPlugin.");
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    
    // Get the kAuthorizationEnvironmentPassword
    err = noErr;
    NSLog(@"FV2AuthPlugin:[+] Attempting to receive kAuthorizationEnvironmentPassword");
    err = mechanism->fPlugin->fCallbacks->GetContextValue(mechanism->fEngine, kAuthorizationEnvironmentPassword, &flags, &value);
    if (err == noErr && (value->length > 0) && (((const char *) value->data)[value->length - 1] == 0)) {
        password = CSFDEStorePassphrase((const char *) value->data);
        NSLog(@"FV2AuthPlugin:[+] kAuthorizationEnvironmentPassword received");
    } else {
        NSLog(@"FV2AuthPlugin:[!] kAuthorizationEnvironmentPassword was unreadable.");
        err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
        return err;
    }
    
    // Try and add the user
    BOOL ret = ODFDEAddUser(username, password, username, password);
    if (ret) {
        NSLog(@"FV2AuthPlugin:[+] Success [%@] added to FV2", (__bridge NSString*)username);
    } else {
        NSLog(@"FV2AuthPlugin:[!] FAIL. User [%@] NOT added to FV2", (__bridge NSString*)username);
    }
    
    NSLog(@"FV2AuthPlugin:[+] Done. Thanks and have a lovely day.");
    err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine, kAuthorizationResultAllow);
    return err;

}

@end
