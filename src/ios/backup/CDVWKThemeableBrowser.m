/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVWKThemeableBrowser.h"

#if __has_include("CDVWKProcessPoolFactory.h")
#import "CDVWKProcessPoolFactory.h"
#endif

#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVUserAgentUtil.h>

#define    kThemeableBrowserTargetSelf @"_self"
#define    kThemeableBrowserTargetSystem @"_system"
#define    kThemeableBrowserTargetBlank @"_blank"

#define    kThemeableBrowserToolbarBarPositionBottom @"bottom"
#define    kThemeableBrowserToolbarBarPositionTop @"top"

#define    kThemeableBrowserAlignLeft @"left"
#define    kThemeableBrowserAlignRight @"right"

#define    kThemeableBrowserPropEvent @"event"
#define    kThemeableBrowserPropLabel @"label"
#define    kThemeableBrowserPropColor @"color"
#define    kThemeableBrowserPropHeight @"height"
#define    kThemeableBrowserPropImage @"image"
#define    kThemeableBrowserPropWwwImage @"wwwImage"
#define    kThemeableBrowserPropImagePressed @"imagePressed"
#define    kThemeableBrowserPropWwwImagePressed @"wwwImagePressed"
#define    kThemeableBrowserPropWwwImageDensity @"wwwImageDensity"
#define    kThemeableBrowserPropProgressBgColor @"progressBgColor"
#define    kThemeableBrowserPropProgressColor @"progressColor"
#define    kThemeableBrowserPropShowProgress @"showProgress"
#define    kThemeableBrowserPropStaticText @"staticText"
#define    kThemeableBrowserPropShowPageTitle @"showPageTitle"
#define    kThemeableBrowserPropAlign @"align"
#define    kThemeableBrowserPropTitle @"title"
#define    kThemeableBrowserPropCancel @"cancel"
#define    kThemeableBrowserPropItems @"items"
#define    kThemeableBrowserPropSize @"fontSize"

#define    kThemeableBrowserEmitError @"ThemeableBrowserError"
#define    kThemeableBrowserEmitWarning @"ThemeableBrowserWarning"
#define    kThemeableBrowserEmitCodeCritical @"critical"
#define    kThemeableBrowserEmitCodeLoadFail @"loadfail"
#define    kThemeableBrowserEmitCodeUnexpected @"unexpected"
#define    kThemeableBrowserEmitCodeUndefined @"undefined"

#define    IAB_BRIDGE_NAME @"cordova_iab"
#define    IAB_BRIDGE_EXTRA_API @"extra_api"

#define    TOOLBAR_HEIGHT 44.0
#define    STATUSBAR_HEIGHT 20.0
#define    LOCATIONBAR_HEIGHT 21.0
#define    FOOTER_HEIGHT ((TOOLBAR_HEIGHT) + (LOCATIONBAR_HEIGHT))

#define iPhoneX (SCREEN_HEIGHT >= 812)

#pragma mark CDVWKThemeableBrowser

@interface CDVWKThemeableBrowser () {
    NSInteger _previousStatusBarStyle;
}
@end

@implementation CDVWKThemeableBrowser

static CDVWKThemeableBrowser* instance = nil;


+ (id) getInstance{
    return instance;
}

- (void)pluginInitialize
{
    instance = self;
    _previousStatusBarStyle = -1;
    _callbackIdPattern = nil;
    _beforeload = @"";
    _waitForBeforeload = NO;
}

- (id)settingForKey:(NSString*)key
{
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

- (void)onReset
{
    [self close:nil];
}

- (void)close:(CDVInvokedUrlCommand*)command
{
    if (self.themeBrowserViewController == nil) {
        NSLog(@"IAB.close() called but it was already closed.");
        return;
    }
    
    // Things are cleaned up in browserExit.
    [self.themeBrowserViewController close];
}

- (BOOL) isSystemUrl:(NSURL*)url
{
    if ([[url host] isEqualToString:@"itunes.apple.com"]) {
        return YES;
    }
    
    return NO;
}

- (void)reload:(CDVInvokedUrlCommand*)command
{
    if (self.themeBrowserViewController) {
        [self.themeBrowserViewController reload];
    }
    
}
- (void)open:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult;
    
    NSString* url = [command argumentAtIndex:0];
    NSString* target = [command argumentAtIndex:1 withDefault:kThemeableBrowserTargetSelf];
    NSString* options = [command argumentAtIndex:2 withDefault:@"" andClass:[NSString class]];
    
    self.callbackId = command.callbackId;
    
    if (url != nil) {
#ifdef __CORDOVA_4_0_0
        NSURL* baseUrl = [self.webViewEngine URL];
#else
        NSURL* baseUrl = [self.webView.request URL];
#endif
        NSURL* absoluteUrl = [[NSURL URLWithString:url relativeToURL:baseUrl] absoluteURL];
        
        if ([self isSystemUrl:absoluteUrl]) {
            target = kThemeableBrowserTargetSystem;
        }
        
        if ([target isEqualToString:kThemeableBrowserTargetSelf]) {
            [self openInCordovaWebView:absoluteUrl withOptions:options];
        } else if ([target isEqualToString:kThemeableBrowserTargetSystem]) {
            [self openInSystem:absoluteUrl];
        } else { // _blank or anything else
            [self openInInAppBrowser:absoluteUrl withOptions:options];
        }
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"incorrect number of arguments"];
    }
    
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)openInInAppBrowser:(NSURL*)url withOptions:(NSString*)options
{
    CDVWKThemeableBrowserOptions* browserOptions = [CDVWKThemeableBrowserOptions parseOptions:options];
    
    WKWebsiteDataStore* dataStore = [WKWebsiteDataStore defaultDataStore];
    if (browserOptions.cleardata) {
        
        NSDate* dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        [dataStore removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] modifiedSince:dateFrom completionHandler:^{
            NSLog(@"Removed all WKWebView data");
            self.themeBrowserViewController.webView.configuration.processPool = [[WKProcessPool alloc] init]; // create new process pool to flush all data
        }];
    }
    
    if (browserOptions.clearcache) {
        bool isAtLeastiOS11 = false;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
        if (@available(iOS 11.0, *)) {
            isAtLeastiOS11 = true;
        }
#endif
            
        if(isAtLeastiOS11){
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
            // Deletes all cookies
            WKHTTPCookieStore* cookieStore = dataStore.httpCookieStore;
            [cookieStore getAllCookies:^(NSArray* cookies) {
                NSHTTPCookie* cookie;
                for(cookie in cookies){
                    [cookieStore deleteCookie:cookie completionHandler:nil];
                }
            }];
#endif
        }else{
            // https://stackoverflow.com/a/31803708/777265
            // Only deletes domain cookies (not session cookies)
            [dataStore fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
             completionHandler:^(NSArray<WKWebsiteDataRecord *> * __nonnull records) {
                 for (WKWebsiteDataRecord *record  in records){
                     NSSet<NSString*>* dataTypes = record.dataTypes;
                     if([dataTypes containsObject:WKWebsiteDataTypeCookies]){
                         [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:record.dataTypes
                               forDataRecords:@[record]
                               completionHandler:^{}];
                     }
                 }
             }];
        }
    }
    
    if (browserOptions.clearsessioncache) {
        bool isAtLeastiOS11 = false;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
        if (@available(iOS 11.0, *)) {
            isAtLeastiOS11 = true;
        }
#endif
        if (isAtLeastiOS11) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
            // Deletes session cookies
            WKHTTPCookieStore* cookieStore = dataStore.httpCookieStore;
            [cookieStore getAllCookies:^(NSArray* cookies) {
                NSHTTPCookie* cookie;
                for(cookie in cookies){
                    if(cookie.sessionOnly){
                        [cookieStore deleteCookie:cookie completionHandler:nil];
                    }
                }
            }];
#endif
        }else{
            NSLog(@"clearsessioncache not available below iOS 11.0");
        }
    }

    if (self.themeBrowserViewController == nil) {
        NSString* userAgent = [CDVUserAgentUtil originalUserAgent];
        NSString* overrideUserAgent = [self settingForKey:@"OverrideUserAgent"];
        NSString* appendUserAgent = [self settingForKey:@"AppendUserAgent"];
        if(overrideUserAgent){
            userAgent = overrideUserAgent;
        }
        if(appendUserAgent){
            userAgent = [userAgent stringByAppendingString: appendUserAgent];
        }
        userAgent = [userAgent stringByAppendingString: @" app/iproud"];
        
        self.themeBrowserViewController = [[CDVWKThemeableBrowserViewController alloc] initWithUserAgent:userAgent prevUserAgent:[self.commandDelegate userAgent] browserOptions: browserOptions];
        self.themeBrowserViewController.navigationDelegate = self;
        
        if ([self.viewController conformsToProtocol:@protocol(CDVScreenOrientationDelegate)]) {
            self.themeBrowserViewController.orientationDelegate = (UIViewController <CDVScreenOrientationDelegate>*)self.viewController;
        }
    }
    
    [self.themeBrowserViewController showLocationBar:browserOptions.location];
    [self.themeBrowserViewController showToolBar:browserOptions.toolbar :browserOptions.toolbarposition];
    if (browserOptions.closebuttoncaption != nil || browserOptions.closebuttoncolor != nil) {
        int closeButtonIndex = browserOptions.lefttoright ? (browserOptions.hidenavigationbuttons ? 1 : 4) : 0;
        [self.themeBrowserViewController setCloseButtonTitle:browserOptions.closebuttoncaption :browserOptions.closebuttoncolor :closeButtonIndex];
    }
    // Set Presentation Style
    UIModalPresentationStyle presentationStyle = UIModalPresentationFullScreen; // default
    if (browserOptions.presentationstyle != nil) {
        if ([[browserOptions.presentationstyle lowercaseString] isEqualToString:@"pagesheet"]) {
            presentationStyle = UIModalPresentationPageSheet;
        } else if ([[browserOptions.presentationstyle lowercaseString] isEqualToString:@"formsheet"]) {
            presentationStyle = UIModalPresentationFormSheet;
        }
    }
    self.themeBrowserViewController.modalPresentationStyle = presentationStyle;
    
    // Set Transition Style
    UIModalTransitionStyle transitionStyle = UIModalTransitionStyleCoverVertical; // default
    if (browserOptions.transitionstyle != nil) {
        if ([[browserOptions.transitionstyle lowercaseString] isEqualToString:@"fliphorizontal"]) {
            transitionStyle = UIModalTransitionStyleFlipHorizontal;
        } else if ([[browserOptions.transitionstyle lowercaseString] isEqualToString:@"crossdissolve"]) {
            transitionStyle = UIModalTransitionStyleCrossDissolve;
        }
    }
    self.themeBrowserViewController.modalTransitionStyle = transitionStyle;
    
    //prevent webView from bouncing
    if (browserOptions.disallowoverscroll) {
        if ([self.themeBrowserViewController.webView respondsToSelector:@selector(scrollView)]) {
            ((UIScrollView*)[self.themeBrowserViewController.webView scrollView]).bounces = NO;
        } else {
            for (id subview in self.themeBrowserViewController.webView.subviews) {
                if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
                    ((UIScrollView*)subview).bounces = NO;
                }
            }
        }
    }
    
    // use of beforeload event
    if([browserOptions.beforeload isKindOfClass:[NSString class]]){
        _beforeload = browserOptions.beforeload;
    }else{
        _beforeload = @"yes";
    }
    _waitForBeforeload = ![_beforeload isEqualToString:@""];
    
    [self.themeBrowserViewController navigateTo:url];
    if (!browserOptions.hidden) {
        [self show:nil withNoAnimate:browserOptions.hidden];
    }
}

- (void)show:(CDVInvokedUrlCommand*)command{
    [self show:command withNoAnimate:NO];
}

- (void)show:(CDVInvokedUrlCommand*)command withNoAnimate:(BOOL)noAnimate
{
    BOOL initHidden = NO;
    if(command == nil && noAnimate == YES){
        initHidden = YES;
    }
    
    if (self.themeBrowserViewController == nil) {
        NSLog(@"Tried to show IAB after it was closed.");
        return;
    }
    if (_previousStatusBarStyle != -1) {
        NSLog(@"Tried to show IAB while already shown");
        return;
    }
    
    if(!initHidden){
        _previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    }
    
    __block CDVWKThemeableBrowserNavigationController* nav = [[CDVWKThemeableBrowserNavigationController alloc]
                                                        initWithRootViewController:self.themeBrowserViewController];
    nav.orientationDelegate = self.themeBrowserViewController;
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = self.themeBrowserViewController.modalPresentationStyle;
    
    __weak CDVWKThemeableBrowser* weakSelf = self;
    
    // Run later to avoid the "took a long time" log message.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.themeBrowserViewController != nil) {
            float osVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf->tmpWindow) {
                CGRect frame = [[UIScreen mainScreen] bounds];
                if(initHidden && osVersion < 11){
                   frame.origin.x = -10000;
                }
                strongSelf->tmpWindow = [[UIWindow alloc] initWithFrame:frame];
            }
            UIViewController *tmpController = [[UIViewController alloc] init];

            [strongSelf->tmpWindow setRootViewController:tmpController];
            [strongSelf->tmpWindow setWindowLevel:UIWindowLevelNormal];

            if(!initHidden || osVersion < 11){
                [self->tmpWindow makeKeyAndVisible];
            }
            [tmpController presentViewController:nav animated:!noAnimate completion:nil];
        }
    });
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
    // Set tmpWindow to hidden to make main webview responsive to touch again
    // https://stackoverflow.com/questions/4544489/how-to-remove-a-uiwindow
    self->tmpWindow.hidden = YES;

    if (self.themeBrowserViewController == nil) {
        NSLog(@"Tried to hide IAB after it was closed.");
        return;
        
        
    }
    if (_previousStatusBarStyle == -1) {
        NSLog(@"Tried to hide IAB while already hidden");
        return;
    }
    
    _previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    
    // Run later to avoid the "took a long time" log message.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.themeBrowserViewController != nil) {
            _previousStatusBarStyle = -1;
            [self.themeBrowserViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

- (void)openInCordovaWebView:(NSURL*)url withOptions:(NSString*)options
{
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
#ifdef __CORDOVA_4_0_0
    // the webview engine itself will filter for this according to <allow-navigation> policy
    // in config.xml for cordova-ios-4.0
    [self.webViewEngine loadRequest:request];
#else
    if ([self.commandDelegate URLIsWhitelisted:url]) {
        [self.webView loadRequest:request];
    } else { // this assumes the InAppBrowser can be excepted from the white-list
        [self openInInAppBrowser:url withOptions:options];
    }
#endif
}

- (void)openInSystem:(NSURL*)url
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)loadAfterBeforeload:(CDVInvokedUrlCommand*)command
{
    NSString* urlStr = [command argumentAtIndex:0];

    if ([_beforeload isEqualToString:@""]) {
        NSLog(@"unexpected loadAfterBeforeload called without feature beforeload=get|post");
    }
    if (self.themeBrowserViewController == nil) {
        NSLog(@"Tried to invoke loadAfterBeforeload on IAB after it was closed.");
        return;
    }
    if (urlStr == nil) {
        NSLog(@"loadAfterBeforeload called with nil argument, ignoring.");
        return;
    }

    NSURL* url = [NSURL URLWithString:urlStr];
    //_beforeload = @"";
    _waitForBeforeload = NO;
    [self.themeBrowserViewController navigateTo:url];
}

// This is a helper method for the inject{Script|Style}{Code|File} API calls, which
// provides a consistent method for injecting JavaScript code into the document.
//
// If a wrapper string is supplied, then the source string will be JSON-encoded (adding
// quotes) and wrapped using string formatting. (The wrapper string should have a single
// '%@' marker).
//
// If no wrapper is supplied, then the source string is executed directly.

- (void)injectDeferredObject:(NSString*)source withWrapper:(NSString*)jsWrapper
{
    // Ensure a message handler bridge is created to communicate with the CDVWKThemeableBrowserViewController
    [self evaluateJavaScript: [NSString stringWithFormat:@"(function(w){if(!w._cdvMessageHandler) {w._cdvMessageHandler = function(id,d){w.webkit.messageHandlers.%@.postMessage({d:d, id:id});}}})(window)", IAB_BRIDGE_NAME]];
    if (jsWrapper != nil) {
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:@[source] options:0 error:nil];
        NSString* sourceArrayString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if (sourceArrayString) {
            NSString* sourceString = [sourceArrayString substringWithRange:NSMakeRange(1, [sourceArrayString length] - 2)];
            NSString* jsToInject = [NSString stringWithFormat:jsWrapper, sourceString];
            [self evaluateJavaScript:jsToInject];
        }
    } else {
        [self evaluateJavaScript:source];
    }
}


//Synchronus helper for javascript evaluation
- (void)evaluateJavaScript:(NSString *)script {
    __block NSString* _script = script;
    [self.themeBrowserViewController.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error == nil) {
            if (result != nil) {
                NSLog(@"%@", result);
            }
        } else {
            NSLog(@"evaluateJavaScript error : %@ : %@", error.localizedDescription, _script);
        }
    }];
}

- (void)injectScriptCode:(CDVInvokedUrlCommand*)command
{
    NSString* jsWrapper = nil;
    
    if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
        jsWrapper = [NSString stringWithFormat:@"_cdvMessageHandler('%@',JSON.stringify([eval(%%@)]));", command.callbackId];
    }
    [self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (void)injectScriptFile:(CDVInvokedUrlCommand*)command
{
    NSString* jsWrapper;
    
    if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
        jsWrapper = [NSString stringWithFormat:@"(function(d) { var c = d.createElement('script'); c.src = %%@; c.onload = function() { _cdvMessageHandler('%@'); }; d.body.appendChild(c); })(document)", command.callbackId];
    } else {
        jsWrapper = @"(function(d) { var c = d.createElement('script'); c.src = %@; d.body.appendChild(c); })(document)";
    }
    [self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (void)injectStyleCode:(CDVInvokedUrlCommand*)command
{
    NSString* jsWrapper;
    
    if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
        jsWrapper = [NSString stringWithFormat:@"(function(d) { var c = d.createElement('style'); c.innerHTML = %%@; c.onload = function() { _cdvMessageHandler('%@'); }; d.body.appendChild(c); })(document)", command.callbackId];
    } else {
        jsWrapper = @"(function(d) { var c = d.createElement('style'); c.innerHTML = %@; d.body.appendChild(c); })(document)";
    }
    [self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (void)injectStyleFile:(CDVInvokedUrlCommand*)command
{
    NSString* jsWrapper;
    
    if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
        jsWrapper = [NSString stringWithFormat:@"(function(d) { var c = d.createElement('link'); c.rel='stylesheet'; c.type='text/css'; c.href = %%@; c.onload = function() { _cdvMessageHandler('%@'); }; d.body.appendChild(c); })(document)", command.callbackId];
    } else {
        jsWrapper = @"(function(d) { var c = d.createElement('link'); c.rel='stylesheet', c.type='text/css'; c.href = %@; d.body.appendChild(c); })(document)";
    }
    [self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (BOOL)isValidCallbackId:(NSString *)callbackId
{
    NSError *err = nil;
    // Initialize on first use
    if (self.callbackIdPattern == nil) {
        self.callbackIdPattern = [NSRegularExpression regularExpressionWithPattern:@"^InAppBrowser[0-9]{1,10}$" options:0 error:&err];
        if (err != nil) {
            // Couldn't initialize Regex; No is safer than Yes.
            return NO;
        }
    }
    if ([self.callbackIdPattern firstMatchInString:callbackId options:0 range:NSMakeRange(0, [callbackId length])]) {
        return YES;
    }
    return NO;
}

/**
 * The message handler bridge provided for the InAppBrowser is capable of executing any oustanding callback belonging
 * to the InAppBrowser plugin. Care has been taken that other callbacks cannot be triggered, and that no
 * other code execution is possible.
 */
- (void)webView:(WKWebView *)theWebView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURL* url = navigationAction.request.URL;
    NSURL* mainDocumentURL = navigationAction.request.mainDocumentURL;
    BOOL isTopLevelNavigation = [url isEqual:mainDocumentURL];
    BOOL shouldStart = YES;
    BOOL useBeforeLoad = NO;
    NSString* httpMethod = navigationAction.request.HTTPMethod;
    NSString* errorMessage = nil;
    
    if([_beforeload isEqualToString:@"post"]){
        //TODO handle POST requests by preserving POST data then remove this condition
        errorMessage = @"beforeload doesn't yet support POST requests";
    }
    else if(isTopLevelNavigation && (
           [_beforeload isEqualToString:@"yes"]
       || ([_beforeload isEqualToString:@"get"] && [httpMethod isEqualToString:@"GET"])
    // TODO comment in when POST requests are handled
    // || ([_beforeload isEqualToString:@"post"] && [httpMethod isEqualToString:@"POST"])
    )){
        useBeforeLoad = YES;
    }

    // When beforeload, on first URL change, initiate JS callback. Only after the beforeload event, continue.
    if (_waitForBeforeload && useBeforeLoad) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"type":@"beforeload", @"url":[url absoluteString]}];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if(errorMessage != nil){
        NSLog(@"%@", errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsDictionary:@{@"type":@"loaderror", @"url":[url absoluteString], @"code": @"-1", @"message": errorMessage}];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
    
    //if is an app store link, let the system handle it, otherwise it fails to load it
    if ([[ url scheme] isEqualToString:@"itms-appss"] || [[ url scheme] isEqualToString:@"itms-apps"]) {
        [theWebView stopLoading];
        [self openInSystem:url];
        shouldStart = NO;
    }
    else if ((self.callbackId != nil) && isTopLevelNavigation) {
        // Send a loadstart event for each top-level navigation (includes redirects).
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"type":@"loadstart", @"url":[url absoluteString]}];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }

    if (useBeforeLoad) {
        _waitForBeforeload = YES;
    }
    
    if(shouldStart){
        // Fix GH-417 & GH-424: Handle non-default target attribute
        // Based on https://stackoverflow.com/a/25713070/777265
        if (!navigationAction.targetFrame){
            [theWebView loadRequest:navigationAction.request];
            decisionHandler(WKNavigationActionPolicyCancel);
        }else{
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    }else{
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

#pragma mark WKScriptMessageHandler delegate
- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    
    CDVPluginResult* pluginResult = nil;
    
    if([message.body isKindOfClass:[NSDictionary class]]){
        NSDictionary* messageContent = (NSDictionary*) message.body;
        NSString* scriptCallbackId = messageContent[@"id"];
        
        if([messageContent objectForKey:@"d"]){
            NSString* scriptResult = messageContent[@"d"];
            NSError* __autoreleasing error = nil;
            NSData* decodedResult = [NSJSONSerialization JSONObjectWithData:[scriptResult dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
            if ((error == nil) && [decodedResult isKindOfClass:[NSArray class]]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:(NSArray*)decodedResult];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION];
            }
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:scriptCallbackId];
    }else if(self.callbackId != nil){
        // Send a message event
        NSString* messageContent = (NSString*) message.body;
        NSError* __autoreleasing error = nil;
        NSData* decodedResult = [NSJSONSerialization JSONObjectWithData:[messageContent dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
        if (error == nil) {
            NSMutableDictionary* dResult = [NSMutableDictionary new];
            [dResult setValue:@"message" forKey:@"type"];
            [dResult setObject:decodedResult forKey:@"data"];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dResult];
            [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        }
    }
}

- (void)apiContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    if([message.body isKindOfClass:[NSDictionary class]]){
        NSDictionary* messageContent = (NSDictionary*) message.body;
        NSString* method = messageContent[@"method"];
        NSDictionary* params = nil;
        if([messageContent objectForKey:@"params"]){
            params = messageContent[@"params"];
        } else {
            
        }
        
        if([method isEqualToString:@"setWebViewFullscreen"]) {
            BOOL fullscreen = [self NSCFBooleanConvertToBool: params[@"fullscreen"]];
            [self.themeBrowserViewController setWebViewFullscreen: fullscreen];
        } else if ([method isEqualToString:@"setStatusBarStyle"]) {
            NSString* style = params[@"style"];
            [self.themeBrowserViewController setStatusBarStyle: style];
        } else if ([method isEqualToString:@"setTitle"]){
            NSString* title = params[@"title"];
            [self.themeBrowserViewController setTitle: title];
        } else if([method isEqualToString:@"close"]) {
            [self.themeBrowserViewController close];
        }
        
    }
    
}

- (BOOL) NSCFBooleanConvertToBool: (NSNumber*) value {
    return [value boolValue];
}

- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

- (void)didStartProvisionalNavigation:(WKWebView*)theWebView
{
    NSLog(@"didStartProvisionalNavigation");
//    self.themeBrowserViewController.currentURL = theWebView.URL;
}

- (void)didFinishNavigation:(WKWebView*)theWebView
{
    if (self.callbackId != nil) {
        NSString* url = [theWebView.URL absoluteString];
        if(url == nil){
            if(self.themeBrowserViewController.currentURL != nil){
                url = [self.themeBrowserViewController.currentURL absoluteString];
            }else{
                url = @"";
            }
        }
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"type":@"loadstop", @"url":url}];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
}

- (void)webView:(WKWebView*)theWebView didFailNavigation:(NSError*)error
{
    if (self.callbackId != nil) {
        NSString* url = [theWebView.URL absoluteString];
        if(url == nil){
            if(self.themeBrowserViewController.currentURL != nil){
                url = [self.themeBrowserViewController.currentURL absoluteString];
            }else{
                url = @"";
            }
        }
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsDictionary:@{@"type":@"loaderror", @"url":url, @"code": [NSNumber numberWithInteger:error.code], @"message": error.localizedDescription}];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
}

- (void)browserExit
{
    if (self.callbackId != nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"type":@"exit"}];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        self.callbackId = nil;
    }
    
    [self.themeBrowserViewController.configuration.userContentController removeScriptMessageHandlerForName:IAB_BRIDGE_NAME];
    [self.themeBrowserViewController.configuration.userContentController removeScriptMessageHandlerForName:IAB_BRIDGE_EXTRA_API];

    self.themeBrowserViewController.configuration = nil;
    
    [self.themeBrowserViewController.webView stopLoading];
    [self.themeBrowserViewController.webView removeFromSuperview];
    [self.themeBrowserViewController.webView setUIDelegate:nil];
    [self.themeBrowserViewController.webView setNavigationDelegate:nil];
    self.themeBrowserViewController.webView = nil;
    
    // Set navigationDelegate to nil to ensure no callbacks are received from it.
    self.themeBrowserViewController.navigationDelegate = nil;
    self.themeBrowserViewController = nil;

    // Set tmpWindow to hidden to make main webview responsive to touch again
    // Based on https://stackoverflow.com/questions/4544489/how-to-remove-a-uiwindow
    self->tmpWindow.hidden = YES;
    
    if (IsAtLeastiOSVersion(@"7.0")) {
        if (_previousStatusBarStyle != -1) {
            [[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle];
            
        }
    }
    
    _previousStatusBarStyle = -1; // this value was reset before reapplying it. caused statusbar to stay black on ios7
}


- (void)emitEvent:(NSDictionary*)event
{
    if (self.callbackId != nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:event];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
}

- (void)emitError:(NSString*)code withMessage:(NSString*)message
{
    NSDictionary *event = @{
        @"type": kThemeableBrowserEmitError,
        @"code": code,
        @"message": message
    };

    [self emitEvent:event];
}

- (void)emitWarning:(NSString*)code withMessage:(NSString*)message
{
    NSDictionary *event = @{
       @"type": kThemeableBrowserEmitWarning,
       @"code": code,
       @"message": message
    };

    [self emitEvent:event];
}

@end //CDVWKThemeableBrowser

#pragma mark CDVWKThemeableBrowserViewController


@implementation CDVWKThemeableBrowserViewController
{
    NSUInteger loadingCount;
    NSUInteger maxLoadCount;
    
    /**
     *  当前加载的url -- 判断url是否重定向
     */
    NSURL *currentURL;
    
    /**
     *  当前加载的title -- title isChange
     */
    NSString *currentTitle;
    
    BOOL interactive;
}
@synthesize currentURL;
@synthesize currentTitle; //add current title 2018-12-17

BOOL viewRenderedAtLeastOnce = FALSE;
BOOL isExiting = FALSE;
BOOL isDismiss = NO;


- (id)initWithUserAgent:(NSString*)userAgent prevUserAgent:(NSString*)prevUserAgent browserOptions: (CDVWKThemeableBrowserOptions*) browserOptions
{
    self = [super init];
    if (self != nil) {
        _userAgent = userAgent;
        _prevUserAgent = prevUserAgent;
        _browserOptions = browserOptions;
        self.webViewUIDelegate = [[CDVWKThemeableBrowserUIDelegate alloc] initWithTitle:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
        [self.webViewUIDelegate setViewController:self];
        
        [self createViews];
    }
    
    return self;
}

-(void)dealloc {
    //NSLog(@"dealloc");
     [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}


- (void)createViews
{
    // We create the views in code for primarily for ease of upgrades and not requiring an external .xib to be included
    
    CGRect webViewBounds = self.view.bounds;
    BOOL toolbarIsAtBottom = ![_browserOptions.toolbarposition isEqualToString:kThemeableBrowserToolbarBarPositionTop];
    NSDictionary* toolbarProps = _browserOptions.toolbar;
    CGFloat toolbarHeight = [self getFloatFromDict:toolbarProps withKey:kThemeableBrowserPropHeight withDefault:TOOLBAR_HEIGHT];
    if (!_browserOptions.fullscreen) {
         webViewBounds.size.height -= toolbarHeight;
     }
    
    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = userContentController;
#if __has_include("CDVWKProcessPoolFactory.h")
    configuration.processPool = [[CDVWKProcessPoolFactory sharedFactory] sharedProcessPool];
#endif
    [configuration.userContentController addScriptMessageHandler:self name:IAB_BRIDGE_NAME];
    [configuration.userContentController addScriptMessageHandler:self name:IAB_BRIDGE_EXTRA_API];
    
    //WKWebView options
    configuration.allowsInlineMediaPlayback = _browserOptions.allowinlinemediaplayback;
    if (IsAtLeastiOSVersion(@"10.0")) {
        configuration.ignoresViewportScaleLimits = _browserOptions.enableviewportscale;
        if(_browserOptions.mediaplaybackrequiresuseraction == YES){
            configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
        }else{
            configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
        }
    }else{ // iOS 9
        configuration.mediaPlaybackRequiresUserAction = _browserOptions.mediaplaybackrequiresuseraction;
    }
    
    self.webView = [[WKWebView alloc] initWithFrame:webViewBounds configuration:configuration];
    self.webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    
    [self.view addSubview:self.webView];
    [self.view sendSubviewToBack:self.webView];
    
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self.webViewUIDelegate;
    self.webView.backgroundColor = [UIColor whiteColor];
    
    self.webView.clearsContextBeforeDrawing = YES;
    self.webView.clipsToBounds = YES;
    self.webView.contentMode = UIViewContentModeScaleToFill;
    self.webView.multipleTouchEnabled = YES;
    self.webView.opaque = YES;
    self.webView.userInteractionEnabled = YES;
    self.automaticallyAdjustsScrollViewInsets = YES ;
    [self.webView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    self.webView.allowsLinkPreview = NO;
    self.webView.allowsBackForwardNavigationGestures = YES;
    
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    
    self.backButton = [self createButton:_browserOptions.backButton action:@selector(goBack:) withDescription:@"back button"];
    self.closeButton = [self createButton:_browserOptions.closeButton action:@selector(close) withDescription:@"close button"];
    self.menuButton = [self createButton:_browserOptions.menu action:@selector(goMenu:) withDescription:@"menu button"];
    
    // Arramge toolbar buttons with respect to user configuration.
    CGFloat leftWidth = 0;
    CGFloat rightWidth = 0;
    
    // Both left and right side buttons will be ordered from outside to inside.
    NSMutableArray* leftButtons = [NSMutableArray new];
    NSMutableArray* rightButtons = [NSMutableArray new];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
   if (@available(iOS 11.0, *)) {
       [self.webView.scrollView setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
   }
#endif
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.alpha = 1.000;
    self.spinner.autoresizesSubviews = YES;
    self.spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin);
    self.spinner.clearsContextBeforeDrawing = NO;
    self.spinner.clipsToBounds = NO;
    self.spinner.contentMode = UIViewContentModeScaleToFill;
    self.spinner.frame = CGRectMake(CGRectGetMidX(self.webView.frame), CGRectGetMidY(self.webView.frame), 20.0, 20.0);
    self.spinner.hidden = NO;
    self.spinner.hidesWhenStopped = YES;
    self.spinner.multipleTouchEnabled = NO;
    self.spinner.opaque = NO;
    self.spinner.userInteractionEnabled = NO;
    [self.spinner stopAnimating];
    
    float toolbarY = toolbarIsAtBottom ? self.view.bounds.size.height - TOOLBAR_HEIGHT : 0.0;
    CGRect toolbarFrame = CGRectMake(0.0, toolbarY, self.view.bounds.size.width, TOOLBAR_HEIGHT);
    
    self.toolbar = [[UIView alloc] initWithFrame:toolbarFrame];
    self.toolbar.alpha = 1.000;
    self.toolbar.autoresizesSubviews = YES;
    self.toolbar.autoresizingMask = toolbarIsAtBottom ? (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin) : UIViewAutoresizingFlexibleWidth;
    //self.toolbar.barStyle = UIBarStyleBlackOpaque;
    self.toolbar.clearsContextBeforeDrawing = NO;
    self.toolbar.clipsToBounds = NO;
    self.toolbar.contentMode = UIViewContentModeScaleToFill;
    self.toolbar.hidden = NO;
    self.toolbar.multipleTouchEnabled = NO;
    self.toolbar.opaque = NO;
    self.toolbar.userInteractionEnabled = YES;
    
//    UIColor *toolbal_bg = [CDVWKThemeableBrowserViewController colorFromRGBA:[self getStringFromDict:toolbarProps withKey:kThemeableBrowserPropColor withDefault:@"#ffffffff"]];
    
    self.toolbar.backgroundColor = [UIColor clearColor];

    // self.toolbar.backgroundColor = toolbal_bg;
    if (toolbarProps[kThemeableBrowserPropImage] || toolbarProps[kThemeableBrowserPropWwwImage]) {
        UIImage *image = [self getImage:toolbarProps[kThemeableBrowserPropImage]
                                altPath:toolbarProps[kThemeableBrowserPropWwwImage]
                             altDensity:[toolbarProps[kThemeableBrowserPropWwwImageDensity] doubleValue]];
        
        if (image) {
            self.toolbar.backgroundColor = [UIColor colorWithPatternImage:image];
        } else {
            [self.navigationDelegate emitError:kThemeableBrowserEmitCodeLoadFail
                                   withMessage:[NSString stringWithFormat:@"Image for toolbar, %@, failed to load.",
                                                toolbarProps[kThemeableBrowserPropImage]
                                                ? toolbarProps[kThemeableBrowserPropImage] : toolbarProps[kThemeableBrowserPropWwwImage]]];
        }
    }
    
    
    if (self.closeButton) {
        self.closeButton.enabled = YES;
        CGFloat width = [self getWidthFromButton:self.closeButton];
        
        if ([kThemeableBrowserAlignRight isEqualToString:_browserOptions.closeButton[kThemeableBrowserPropAlign]]) {
            [rightButtons addObject:self.closeButton];
            rightWidth += width;
        } else {
            [leftButtons addObject:self.closeButton];
            leftWidth += width;
        }
    }
    
    if (self.backButton && ![kThemeableBrowserAlignRight isEqualToString:_browserOptions.backButton[kThemeableBrowserPropAlign]]) {
          CGFloat width = [self getWidthFromButton:self.backButton];
          [leftButtons addObject:self.backButton];
          leftWidth += width;
      }
    if (self.backButton && [kThemeableBrowserAlignRight isEqualToString:_browserOptions.backButton[kThemeableBrowserPropAlign]]) {
        CGFloat width = [self getWidthFromButton:self.backButton];
        [rightButtons addObject:self.backButton];
        rightWidth += width;
    }
    
    if (self.menuButton) {
        CGFloat width = [self getWidthFromButton:self.menuButton];
        
        if ([kThemeableBrowserAlignRight isEqualToString:_browserOptions.menu[kThemeableBrowserPropAlign]]) {
            [rightButtons addObject:self.menuButton];
            rightWidth += width;
        } else {
            [leftButtons addObject:self.menuButton];
            leftWidth += width;
        }
    }
    
    self.rightButtons = rightButtons;
    self.leftButtons = leftButtons;

    for (UIButton* button in self.leftButtons) {
        [self.toolbar addSubview:button];
    }

    for (UIButton* button in self.rightButtons) {
        [self.toolbar addSubview:button];
    }

    [self layoutButtons];
    

    self.titleOffset = fmaxf(leftWidth, rightWidth);
    // The correct positioning of title is not that important right now, since
    // rePositionViews will take care of it a bit later.
    self.titleLabel = nil;
    
    if (_browserOptions.title) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 10, toolbarHeight)];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.numberOfLines = 1;
        self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        UIColor *textColor = [CDVWKThemeableBrowserViewController colorFromRGBA:[self getStringFromDict:_browserOptions.title withKey:kThemeableBrowserPropColor withDefault:@"#000000ff"]];
        self.titleLabel.textColor = textColor;
        
        if (_browserOptions.title[kThemeableBrowserPropStaticText]) {
            self.titleLabel.text = _browserOptions.title[kThemeableBrowserPropStaticText];
        }
        if (_browserOptions.title[kThemeableBrowserPropSize]) {
            CGFloat textSize = [self getFloatFromDict:_browserOptions.title withKey:kThemeableBrowserPropSize withDefault:19.0];
            self.titleLabel.font = [UIFont boldSystemFontOfSize:textSize];
        }
        [self.toolbar addSubview:self.titleLabel];
    }
    
    self.progressView = [[UIProgressView   alloc] initWithFrame:CGRectMake(0.0, toolbarY+ toolbarHeight+[self getStatusBarOffset], self.view.bounds.size.width, 20.0)];
      self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
      self.progressView.progressViewStyle=UIProgressViewStyleDefault;
      self.progressView.progressTintColor=[CDVWKThemeableBrowserViewController colorFromRGBA:[self getStringFromDict:_browserOptions.browserProgress withKey: kThemeableBrowserPropProgressColor withDefault:@"#0000FF"]];
      self.progressView.trackTintColor=[CDVWKThemeableBrowserViewController colorFromRGBA:[self getStringFromDict:_browserOptions.browserProgress withKey:kThemeableBrowserPropProgressBgColor withDefault:@"#808080"]];
      if ([self getBoolFromDict:_browserOptions.browserProgress withKey:kThemeableBrowserPropShowProgress]) {
          [self.view addSubview:self.progressView];
      }
    
    
    self.view.backgroundColor = [CDVWKThemeableBrowserViewController colorFromRGBA:[self getStringFromDict:_browserOptions.statusbar withKey:kThemeableBrowserPropColor withDefault:@"#ffffffff"]];
    
     [self.view addSubview:self.toolbar];
    // [self.view addSubview:self.spinner];
}

- (void)layoutButtons
{
    CGFloat screenWidth = CGRectGetWidth(self.view.frame);
    CGFloat toolbarHeight = self.toolbar.frame.size.height;
    
    // Layout leftButtons and rightButtons from outer to inner.
    CGFloat left = 0;
    for (UIButton* button in self.leftButtons) {
        CGSize size = button.frame.size;
        button.frame = CGRectMake(left, floorf((toolbarHeight - size.height) / 2), size.width, size.height);
        left += size.width;
    }
    
    CGFloat right = 0;
    for (UIButton* button in self.rightButtons) {
        CGSize size = button.frame.size;
        button.frame = CGRectMake(screenWidth - right - size.width, floorf((toolbarHeight - size.height) / 2), size.width, size.height);
        right += size.width;
    }
}

- (void) setWebViewFrame : (CGRect) frame {
    NSLog(@"Setting the WebView's frame to %@", NSStringFromCGRect(frame));
    [self.webView setFrame:frame];
}

- (void)setCloseButtonTitle:(NSString*)title : (NSString*) colorString : (int) buttonIndex
{
    // the advantage of using UIBarButtonSystemItemDone is the system will localize it for you automatically
    // but, if you want to set this yourself, knock yourself out (we can't set the title for a system Done button, so we have to create a new one)
    //self.closeButton = nil;
    // Initialize with title if title is set, otherwise the title will be 'Done' localized
    //self.closeButton = title != nil ? [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleBordered target:self action:@selector(close)] : [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
//    self.closeButton.enabled = YES;
    // If color on closebutton is requested then initialize with that that color, otherwise use initialize with default
//    self.closeButton.tintColor = colorString != nil ? [self colorFromHexString:colorString] : [UIColor colorWithRed:60.0 / 255.0 green:136.0 / 255.0 blue:230.0 / 255.0 alpha:1];
    
//    NSMutableArray* items = [self.toolbar.items mutableCopy];
//    [items replaceObjectAtIndex:buttonIndex withObject:self.closeButton];
//    [self.toolbar setItems:items];
}

- (void)showLocationBar:(BOOL)show
{

    BOOL toolbarVisible = !self.toolbar.hidden;
    if (show) {
        if (toolbarVisible) {
            // toolBar at the bottom, leave as is
            // put locationBar on top of the toolBar
            
            CGRect webViewBounds = self.view.bounds;
            webViewBounds.size.height -= FOOTER_HEIGHT;
            [self setWebViewFrame:webViewBounds];
            
        } else {
            // no toolBar, so put locationBar at the bottom
            
            CGRect webViewBounds = self.view.bounds;
            webViewBounds.size.height -= LOCATIONBAR_HEIGHT;
            [self setWebViewFrame:webViewBounds];
            
        }
    } else {
        if (toolbarVisible) {
            // locationBar is on top of toolBar, hide locationBar
            
            // webView take up whole height less toolBar height
            CGRect webViewBounds = self.view.bounds;
            webViewBounds.size.height -= TOOLBAR_HEIGHT;
            [self setWebViewFrame:webViewBounds];
        } else {
            // no toolBar, expand webView to screen dimensions
            [self setWebViewFrame:self.view.bounds];
        }
    }
}

- (void)showToolBar:(BOOL)show : (NSString *) toolbarPosition
{
    CGRect toolbarFrame = self.toolbar.frame;
    
    CGFloat toolbarHeight = [self getFloatFromDict:_browserOptions.toolbar withKey:kThemeableBrowserPropHeight withDefault:TOOLBAR_HEIGHT];
    
    // prevent double show/hide
    if (show == !(self.toolbar.hidden)) {
        return;
    }
    
    if (show) {
        self.toolbar.hidden = NO;
        CGRect webViewBounds = self.view.bounds;
         
        webViewBounds.size.height -= TOOLBAR_HEIGHT;
        self.toolbar.frame = toolbarFrame;
        
        if ([toolbarPosition isEqualToString:kThemeableBrowserToolbarBarPositionTop]) {
            toolbarFrame.origin.y = 0;
            webViewBounds.origin.y += toolbarFrame.size.height;
            [self setWebViewFrame:webViewBounds];
        } else {
            toolbarFrame.origin.y = (webViewBounds.size.height + LOCATIONBAR_HEIGHT);
        }
        [self setWebViewFrame:webViewBounds];
        
    } else {
        self.toolbar.hidden = YES;
        [self setWebViewFrame:self.view.bounds];
    }
}

- (void)viewDidLoad
{
    viewRenderedAtLeastOnce = FALSE;
    [super viewDidLoad];
//    if ([[UIDevice currentDevice].systemVersion floatValue]>=7.0) {
//          if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
//              self.navigationController.interactivePopGestureRecognizer.enabled = YES;
//              self.navigationController.interactivePopGestureRecognizer.delegate = self;
//          }
//      }
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (isExiting && (self.navigationDelegate != nil) && [self.navigationDelegate respondsToSelector:@selector(browserExit)]) {
        [self.navigationDelegate browserExit];
        isExiting = FALSE;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    
    return _browserOptions.statusBarStyle;
}


- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (void)reload
{
    [self.webView reload];
}

- (void)setWebViewFullscreen:(BOOL) fullscreen
{
    _browserOptions.fullscreen = fullscreen;
    [self rePositionViews];
}


- (void)setStatusBarStyle:(NSString*) style
{
    if([@"dark" isEqualToString: style]){
        _browserOptions.statusBarStyle = UIStatusBarStyleLightContent;
    }else{
        _browserOptions.statusBarStyle = UIStatusBarStyleDefault;
    }
    [[UIApplication sharedApplication] setStatusBarStyle: _browserOptions.statusBarStyle];
}


- (void)setTitle:(NSString*) title
{
    self.titleLabel.text = title;
    self.currentTitle = title;
}

- (void)close
{
    [CDVUserAgentUtil releaseLock:&_userAgentLockToken];
    self.currentURL = nil;
    isDismiss = NO;
    __weak UIViewController* weakSelf = self;
    
    // Run later to avoid the "took a long time" log message.
    dispatch_async(dispatch_get_main_queue(), ^{
        isExiting = TRUE;
        if ([weakSelf respondsToSelector:@selector(presentingViewController)]) {
            [[weakSelf presentingViewController] dismissViewControllerAnimated:YES completion:nil];
        } else {
            [[weakSelf parentViewController] dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

- (void)navigateTo:(NSURL*)url
{
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
    if (_userAgentLockToken != 0) {
        [self.webView loadRequest:request];
    } else {
        __weak CDVWKThemeableBrowserViewController* weakSelf = self;
        [CDVUserAgentUtil acquireLock:^(NSInteger lockToken) {
            _userAgentLockToken = lockToken;
            [CDVUserAgentUtil setUserAgent:_userAgent lockToken:lockToken];
            [weakSelf.webView loadRequest:request];
        }];
    }
}

- (void)goBack:(id)sender
{
    [self emitEventForButton:_browserOptions.backButton];
    if (self.webView.canGoBack) {
        [self.webView goBack];
    } else {
        [self close];
    }
}


- (void)emitEventForButton:(NSDictionary*)buttonProps
{
    [self emitEventForButton:buttonProps withIndex:nil];
}

- (CGFloat) getWidthFromButton:(UIButton*)button
{
    return button.frame.size.width;
}

- (void)emitEventForButton:(NSDictionary*)buttonProps withIndex:(NSNumber*)index
{
    if (buttonProps) {
        NSString* event = buttonProps[kThemeableBrowserPropEvent];
        if (event) {
            NSMutableDictionary* dict = [NSMutableDictionary new];
            [dict setObject:event forKey:@"type"];
            [dict setObject:[self.navigationDelegate.themeBrowserViewController.currentURL absoluteString] forKey:@"url"];
            if (self.navigationDelegate.themeBrowserViewController.currentTitle != nil) {
                 [dict setObject:self.navigationDelegate.themeBrowserViewController.currentTitle forKey:@"title"];//add current title 2018-12-17
            }
            if (index) {
                [dict setObject:index forKey:@"index"];
            }
            [self.navigationDelegate emitEvent:dict];
        } else {
            [self.navigationDelegate emitWarning:kThemeableBrowserEmitCodeUndefined
                                     withMessage:@"Button clicked, but event property undefined. No event will be raised."];
        }
    }
}




- (void)goMenu:(id)sender
{
    [self emitEventForButton:_browserOptions.menu];

    if (_browserOptions.menu && _browserOptions.menu[kThemeableBrowserPropItems]) {
        NSArray* menuItems = _browserOptions.menu[kThemeableBrowserPropItems];
            // to do this going forward.
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:_browserOptions.menu[kThemeableBrowserPropTitle]
                                                  message:nil
                                                  preferredStyle:UIAlertControllerStyleActionSheet];
            alertController.popoverPresentationController.sourceView
                    = self.menuButton;
            alertController.popoverPresentationController.sourceRect
                    = self.menuButton.bounds;

            for (NSInteger i = 0; i < menuItems.count; i++) {
                NSInteger index = i;
                NSDictionary *item = menuItems[index];

                UIAlertAction *a = [UIAlertAction
                                     actionWithTitle:item[@"label"]
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction *action) {
                                         [self menuSelected:index];
                                     }];
                [alertController addAction:a];
            }

            if (_browserOptions.menu[kThemeableBrowserPropCancel]) {
                UIAlertAction *cancelAction = [UIAlertAction
                                               actionWithTitle:_browserOptions.menu[kThemeableBrowserPropCancel]
                                               style:UIAlertActionStyleCancel
                                               handler:nil];
                [alertController addAction:cancelAction];
            }

            [self presentViewController:alertController animated:YES completion:nil];
    } else {
        [self.navigationDelegate emitWarning:kThemeableBrowserEmitCodeUndefined
                                 withMessage:@"Menu items undefined. No menu will be shown."];
    }
}

- (void)goForward:(id)sender
{
    [self.webView goForward];
}

- (void) menuSelected:(NSInteger)index
{
    NSArray* menuItems = _browserOptions.menu[kThemeableBrowserPropItems];
    if (index < menuItems.count) {
        [self emitEventForButton:menuItems[index] withIndex:[NSNumber numberWithLong:index]];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    if (IsAtLeastiOSVersion(@"7.0") && !viewRenderedAtLeastOnce) {
        viewRenderedAtLeastOnce = TRUE;
        CGRect viewBounds = [self.webView bounds];
        viewBounds.origin.y = STATUSBAR_HEIGHT;
        viewBounds.size.height = viewBounds.size.height - STATUSBAR_HEIGHT;
        self.webView.frame = viewBounds;
        [[UIApplication sharedApplication] setStatusBarStyle:[self preferredStatusBarStyle]];
    }
    [self rePositionViews];
    
    [super viewWillAppear:animated];
}

//
// On iOS 7 the status bar is part of the view's dimensions, therefore it's height has to be taken into account.
// The height of it could be hardcoded as 20 pixels, but that would assume that the upcoming releases of iOS won't
// change that value.
//
- (float) getStatusBarOffset {
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    float statusBarOffset = IsAtLeastiOSVersion(@"7.0") ? MIN(statusBarFrame.size.width, statusBarFrame.size.height) : 0.0;
    return statusBarOffset;
}

- (BOOL) isIPhoneXSeries {
    BOOL iPhoneXSeries = NO;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
        return iPhoneXSeries;
    }
    if (@available(iOS 11, *)) {
        UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
        if (mainWindow.safeAreaInsets.bottom > 0.0) {
            iPhoneXSeries = YES;
        }
    }
    return iPhoneXSeries;
}

- (void) rePositionViews {
    // if (self.isIPhoneXSeries){
        
    //     CGFloat toolbarHeight = [self getFloatFromDict:_browserOptions.toolbar withKey:kThemeableBrowserPropHeight withDefault:TOOLBAR_HEIGHT];
    //     CGFloat statusBarOffset = [self getStatusBarOffset];
    //     CGFloat webviewOffset = _browserOptions.fullscreen ? 0.0 : toolbarHeight + statusBarOffset;
    //     CGFloat webviewHeight = _browserOptions.fullscreen ? self.view.frame.size.height : self.view.frame.size.height - webviewOffset;

    //     if ([_browserOptions.toolbarposition isEqualToString:kThemeableBrowserToolbarBarPositionTop]) {
    //         // The webview height calculated did not take the status bar into account. Thus we need to remove status bar height to the webview height.
    //         if(!isDismiss){
    //             [self.webView setFrame:CGRectMake(self.webView.frame.origin.x, webviewOffset, self.webView.frame.size.width, (self.webView.frame.size.height - 20))];
    //             // CGFloat height = self.webView.frame.size.height - 20;
    //             isDismiss = YES;
    //         } else {
    //             [self.webView setFrame:CGRectMake(self.webView.frame.origin.x, webviewOffset, self.webView.frame.size.width, (self.webView.frame.size.height))];
    //         }
            
    //         [self.toolbar setFrame:CGRectMake(self.toolbar.frame.origin.x, [self getStatusBarOffset], self.toolbar.frame.size.width, self.toolbar.frame.size.height)];
    //     }
    //     // When positionning the iphone to landscape mode, status bar is hidden. The problem is that we set the webview height just before with removing the status bar height. We need to adjust the phenomen by adding the preview status bar height. We had to add manually 20 (pixel) because in landscape mode, the status bar height is equal to 0.
    //     if (statusBarOffset == 0) {
    //         [self.webView setFrame:CGRectMake(self.webView.frame.origin.x, webviewOffset, self.webView.frame.size.width, (self.webView.frame.size.height+20))];
    //     }
        
    //     CGFloat screenWidth = CGRectGetWidth(self.view.frame);
    //     NSInteger width = floorf(screenWidth - self.titleOffset * 2.0f);
    //     if (self.titleLabel) {
    //         self.titleLabel.frame = CGRectMake(floorf((screenWidth - width) / 2.0f), 0, width, toolbarHeight);
    //     }
        
    //     [self layoutButtons];
        
    // } else {
        
        CGFloat toolbarHeight = [self getFloatFromDict:_browserOptions.toolbar withKey:kThemeableBrowserPropHeight withDefault:TOOLBAR_HEIGHT];
        CGFloat statusBarOffset = [self getStatusBarOffset];
        CGFloat webviewOffset = _browserOptions.fullscreen ? 0.0 : toolbarHeight + statusBarOffset;
        CGFloat webviewHeight = _browserOptions.fullscreen ? self.view.frame.size.height : self.view.frame.size.height - webviewOffset;
        
        if ([_browserOptions.toolbarposition isEqualToString:kThemeableBrowserToolbarBarPositionTop]) {
            [self.webView setFrame:CGRectMake(self.webView.frame.origin.x, webviewOffset, self.webView.frame.size.width, webviewHeight)];
            [self.toolbar setFrame:CGRectMake(self.toolbar.frame.origin.x, [self getStatusBarOffset], self.toolbar.frame.size.width, self.toolbar.frame.size.height)];
        }
        
        CGFloat screenWidth = CGRectGetWidth(self.view.frame);
        NSInteger width = floorf(screenWidth - self.titleOffset * 2.0f);
        if (self.titleLabel) {
            self.titleLabel.frame = CGRectMake(floorf((screenWidth - width) / 2.0f), 0, width, toolbarHeight);
        }
        
        [self layoutButtons];
    // }
}

// Helper function to convert hex color string to UIColor
// Assumes input like "#00FF00" (#RRGGBB).
// Taken from https://stackoverflow.com/questions/1560081/how-can-i-create-a-uicolor-from-a-hex-string
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

- (CGFloat) getFloatFromDict:(NSDictionary*)dict withKey:(NSString*)key withDefault:(CGFloat)def
{
    CGFloat result = def;
    if (dict && dict[key]) {
        result = [(NSNumber*) dict[key] floatValue];
    }
    return result;
}

- (NSString*) getStringFromDict:(NSDictionary*)dict withKey:(NSString*)key withDefault:(NSString*)def
{
    NSString* result = def;
    if (dict && dict[key]) {
        result = dict[key];
    }
    return result;
}


- (BOOL) getBoolFromDict:(NSDictionary*)dict withKey:(NSString*)key
{
    BOOL result = NO;
    if (dict && dict[key]) {
        result = [(NSNumber*) dict[key] boolValue];
    }
    return result;
}

+ (UIColor *)colorFromRGBA:(NSString *)rgba {
    unsigned rgbaVal = 0;
    
    if ([[rgba substringWithRange:NSMakeRange(0, 1)] isEqualToString:@"#"]) {
        // First char is #, get rid of that.
        rgba = [rgba substringFromIndex:1];
    }
    
    if (rgba.length < 8) {
        // If alpha is not given, just append ff.
        rgba = [NSString stringWithFormat:@"%@ff", rgba];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:rgba];
    [scanner setScanLocation:0];
    [scanner scanHexInt:&rgbaVal];
    
    return [UIColor colorWithRed:(rgbaVal >> 24 & 0xFF) / 255.0f
                           green:(rgbaVal >> 16 & 0xFF) / 255.0f
                            blue:(rgbaVal >> 8 & 0xFF) / 255.0f
                           alpha:(rgbaVal & 0xFF) / 255.0f];
}

/**
 * This is a rather unintuitive helper method to load images. The reason why this method exists
 * is because due to some service limitations, one may not be able to add images to native
 * resource bundle. So this method offers a way to load image from www contents instead.
 * However loading from native resource bundle is already preferred over loading from www. So
 * if name is given, then it simply loads from resource bundle and the other two parameters are
 * ignored. If name is not given, then altPath is assumed to be a file path _under_ www and
 * altDensity is the desired density of the given image file, because without native resource
 * bundle, we can't tell what densitiy the image is supposed to be so it needs to be given
 * explicitly.
 */
- (UIImage*) getImage:(NSString*) name altPath:(NSString*) altPath altDensity:(CGFloat) altDensity
{
    UIImage* result = nil;
    if (name) {
        result = [UIImage imageNamed:name];
    } else if (altPath) {
        NSString* path = [[[NSBundle mainBundle] bundlePath]
                          stringByAppendingPathComponent:[NSString pathWithComponents:@[@"www", altPath]]];
        if (!altDensity) {
            altDensity = 1.0;
        }
        NSData* data = [NSData dataWithContentsOfFile:path];
        result = [UIImage imageWithData:data scale:altDensity];
    }

    return result;
}

- (UIButton*) createButton:(NSDictionary*) buttonProps action:(SEL)action withDescription:(NSString*)description
{
    UIButton* result = nil;
    if (buttonProps) {
        UIImage *buttonImage = nil;
        if (buttonProps[kThemeableBrowserPropImage] || buttonProps[kThemeableBrowserPropWwwImage]) {
            buttonImage = [self getImage:buttonProps[kThemeableBrowserPropImage]
                                altPath:buttonProps[kThemeableBrowserPropWwwImage]
                                altDensity:[buttonProps[kThemeableBrowserPropWwwImageDensity] doubleValue]];

            if (!buttonImage) {
                [self.navigationDelegate emitError:kThemeableBrowserEmitCodeLoadFail
                                       withMessage:[NSString stringWithFormat:@"Image for %@, %@, failed to load.",
                                                    description,
                                                    buttonProps[kThemeableBrowserPropImage]
                                                    ? buttonProps[kThemeableBrowserPropImage] : buttonProps[kThemeableBrowserPropWwwImage]]];
            }
        } else {
            [self.navigationDelegate emitWarning:kThemeableBrowserEmitCodeUndefined
                                 withMessage:[NSString stringWithFormat:@"Image for %@ is not defined. Button will not be shown.", description]];
        }

        UIImage *buttonImagePressed = nil;
        if (buttonProps[kThemeableBrowserPropImagePressed] || buttonProps[kThemeableBrowserPropWwwImagePressed]) {
            buttonImagePressed = [self getImage:buttonProps[kThemeableBrowserPropImagePressed]
                                       altPath:buttonProps[kThemeableBrowserPropWwwImagePressed]
                                       altDensity:[buttonProps[kThemeableBrowserPropWwwImageDensity] doubleValue]];;

            if (!buttonImagePressed) {
                [self.navigationDelegate emitError:kThemeableBrowserEmitCodeLoadFail
                                       withMessage:[NSString stringWithFormat:@"Pressed image for %@, %@, failed to load.",
                                                    description,
                                                    buttonProps[kThemeableBrowserPropImagePressed]
                                                    ? buttonProps[kThemeableBrowserPropImagePressed] : buttonProps[kThemeableBrowserPropWwwImagePressed]]];
            }
        } else {
            [self.navigationDelegate emitWarning:kThemeableBrowserEmitCodeUndefined
                             withMessage:[NSString stringWithFormat:@"Pressed image for %@ is not defined.", description]];
        }

        if (buttonImage) {
            result = [UIButton buttonWithType:UIButtonTypeCustom];
            result.bounds = CGRectMake(0, 0, buttonImage.size.width, buttonImage.size.height);

            if (buttonImagePressed) {
                [result setImage:buttonImagePressed forState:UIControlStateHighlighted];
                result.adjustsImageWhenHighlighted = NO;
            }

            [result setImage:buttonImage forState:UIControlStateNormal];
            [result addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
        }
    } else if (!buttonProps) {
        [self.navigationDelegate emitWarning:kThemeableBrowserEmitCodeUndefined
                                 withMessage:[NSString stringWithFormat:@"%@ is not defined. Button will not be shown.", description]];
    } else if (!buttonProps[kThemeableBrowserPropImage]) {
    }

    return result;
}
#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)theWebView didStartProvisionalNavigation:(WKNavigation *)navigation{
    
    // loading url, start spinner, update back/forward
    // self.backButton.enabled = theWebView.canGoBack; anytime backButton is enabled modifed by zhaogx 2019/12/5
    // self.forwardButton.enabled = theWebView.canGoForward;
    
    self.progressView.hidden = NO;
    //开始加载网页的时候将progressView的Height恢复为1.5倍
    self.progressView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    //防止progressView被网页挡住
    [self.view bringSubviewToFront:self.progressView];
    
    NSLog(_browserOptions.hidespinner ? @"Yes" : @"No");
    if(!_browserOptions.hidespinner) {
        [self.spinner startAnimating];
    }
    
    return [self.navigationDelegate didStartProvisionalNavigation:theWebView];
}

- (void)webView:(WKWebView *)theWebView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    NSURL *mainDocumentURL = navigationAction.request.mainDocumentURL;
    
    BOOL isTopLevelNavigation = [url isEqual:mainDocumentURL];
    
    if (isTopLevelNavigation) {
        self.currentURL = url;
    }
    
    [self.navigationDelegate webView:theWebView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
}

- (void)webView:(WKWebView *)theWebView didFinishNavigation:(WKNavigation *)navigation
{
    // update url, stop spinner, update back/forward
    // self.backButton.enabled = theWebView.canGoBack;
    // self.forwardButton.enabled = theWebView.canGoForward;
    theWebView.scrollView.contentInset = UIEdgeInsetsZero;
    
    if (self.titleLabel && _browserOptions.title
        && !_browserOptions.title[kThemeableBrowserPropStaticText]
        && [self getBoolFromDict:_browserOptions.title withKey:kThemeableBrowserPropShowPageTitle]) {
        // Update title text to page title when title is shown and we are not
        // required to show a static text.
        [self.webView evaluateJavaScript:@"document.title" completionHandler:^(id object, NSError * error) {
            self.titleLabel.text = object;
            self.currentTitle = object;
        }];
    }
    
    [self.spinner stopAnimating];
    
    // Work around a bug where the first time a PDF is opened, all UIWebViews
    // reload their User-Agent from NSUserDefaults.
    // This work-around makes the following assumptions:
    // 1. The app has only a single Cordova Webview. If not, then the app should
    //    take it upon themselves to load a PDF in the background as a part of
    //    their start-up flow.
    // 2. That the PDF does not require any additional network requests. We change
    //    the user-agent here back to that of the CDVViewController, so requests
    //    from it must pass through its white-list. This *does* break PDFs that
    //    contain links to other remote PDF/websites.
    // More info at https://issues.apache.org/jira/browse/CB-2225
    BOOL isPDF = NO;
    //TODO webview class
    //BOOL isPDF = [@"true" isEqualToString :[theWebView evaluateJavaScript:@"document.body==null"]];
    if (isPDF) {
        [CDVUserAgentUtil setUserAgent:_prevUserAgent lockToken:_userAgentLockToken];
    }
    
    [self.navigationDelegate didFinishNavigation:theWebView];
}
    
- (void)webView:(WKWebView*)theWebView failedNavigation:(NSString*) delegateName withError:(nonnull NSError *)error{
    // log fail message, stop spinner, update back/forward
    NSLog(@"webView:%@ - %ld: %@", delegateName, (long)error.code, [error localizedDescription]);
    
    // self.backButton.enabled = theWebView.canGoBack;
    // self.forwardButton.enabled = theWebView.canGoForward;
    [self.spinner stopAnimating];
    
    [self.navigationDelegate webView:theWebView didFailNavigation:error];
}

- (void)webView:(WKWebView*)theWebView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error
{
     [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self webView:theWebView failedNavigation:@"didFailNavigation" withError:error];
}
    
- (void)webView:(WKWebView*)theWebView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error
{
    [self webView:theWebView failedNavigation:@"didFailProvisionalNavigation" withError:error];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.progressView.progress = self.webView.estimatedProgress;
        if (self.progressView.progress == 1) {
            /*
             *添加一个简单的动画，将progressView的Height变为1.4倍，在开始加载网页的代理中会恢复为1.5倍
             *动画时长0.25s，延时0.3s后开始动画
             *动画结束后将progressView隐藏
             */
            [UIView animateWithDuration:0.25f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.progressView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            } completion:^(BOOL finished) {
                self.progressView.hidden = YES;

            }];
        }
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark WKScriptMessageHandler delegate
- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    NSLog(@"Received script message %@", message.body);
    if ([message.name isEqualToString:IAB_BRIDGE_NAME]) {
        [self.navigationDelegate userContentController:userContentController didReceiveScriptMessage:message];
    } else if ([message.name isEqualToString:IAB_BRIDGE_EXTRA_API]){
        [self.navigationDelegate apiContentController:userContentController didReceiveScriptMessage:message];
    } else {
        return;
    }
}

#pragma mark CDVScreenOrientationDelegate

- (BOOL)shouldAutorotate
{
    if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotate)]) {
        return [self.orientationDelegate shouldAutorotate];
    }
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(supportedInterfaceOrientations)]) {
        return [self.orientationDelegate supportedInterfaceOrientations];
    }
    
    return 1 << UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotateToInterfaceOrientation:)]) {
        return [self.orientationDelegate shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    }
    
    return YES;
}


@end //CDVWKThemeableBrowserViewController
