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

#import "CDVThemeableBrowser.h"
#import "CDVWKThemeableBrowserOptions.h"
#import "CDVWKThemeableBrowser.h"
#import <Cordova/CDVPluginResult.h>


#pragma mark CDVThemeableBrowser

@implementation CDVThemeableBrowser

- (void)pluginInitialize
{
#if __has_include("CDVWKWebViewEngine.h")
    self.wkwebviewavailable = YES;
#else
    self.wkwebviewavailable = NO;
#endif
}

- (void)open:(CDVInvokedUrlCommand*)command
{
    if(!self.wkwebviewavailable){
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:@{@"type":@"loaderror", @"message": @"usewkwebview option specified but but no plugin that supplies a WKWebView engine is present"}] callbackId:command.callbackId];
        return;
    }
   [[CDVWKThemeableBrowser getInstance] open:command];
}

- (void)close:(CDVInvokedUrlCommand*)command
{
    [[CDVWKThemeableBrowser getInstance] close:command];
}

- (void)reload:(CDVInvokedUrlCommand*)command
{
    [[CDVWKThemeableBrowser getInstance] reload:command];
}


- (void)show:(CDVInvokedUrlCommand*)command
{
     [[CDVWKThemeableBrowser getInstance] show:command];
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
     [[CDVWKThemeableBrowser getInstance] hide:command];
}


- (void)injectScriptCode:(CDVInvokedUrlCommand*)command
{
     [[CDVWKThemeableBrowser getInstance] injectScriptCode:command];
}

- (void)injectScriptFile:(CDVInvokedUrlCommand*)command
{
     [[CDVWKThemeableBrowser getInstance] injectScriptFile:command];
}

- (void)injectStyleCode:(CDVInvokedUrlCommand*)command
{
    [[CDVWKThemeableBrowser getInstance] injectStyleCode:command];
}

- (void)injectStyleFile:(CDVInvokedUrlCommand*)command
{
   [[CDVWKThemeableBrowser getInstance] injectStyleFile:command];
}

- (void)loadAfterBeforeload:(CDVInvokedUrlCommand*)command
{
    [[CDVWKThemeableBrowser getInstance] loadAfterBeforeload:command];
}


@end
