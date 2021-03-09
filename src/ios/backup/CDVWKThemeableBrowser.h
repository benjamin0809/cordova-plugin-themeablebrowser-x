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

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
#import <Cordova/CDVScreenOrientationDelegate.h>
#import "CDVWKThemeableBrowserUIDelegate.h"
#import "CDVWKThemeableBrowserOptions.h"
#import "CDVWKThemeableBrowserNavigationController.h"

@class CDVWKThemeableBrowserViewController;

@interface CDVWKThemeableBrowser : CDVPlugin {
    UIWindow * tmpWindow;

    @private
    NSString* _beforeload;
    BOOL _waitForBeforeload;
}

@property (nonatomic, retain) CDVWKThemeableBrowser* instance;
@property (nonatomic, retain) CDVWKThemeableBrowserViewController* themeBrowserViewController;
@property (nonatomic, copy) NSString* callbackId;
@property (nonatomic, copy) NSRegularExpression *callbackIdPattern;

+ (id) getInstance;
- (void)open:(CDVInvokedUrlCommand*)command;
- (void)close:(CDVInvokedUrlCommand*)command;
- (void)injectScriptCode:(CDVInvokedUrlCommand*)command;
- (void)show:(CDVInvokedUrlCommand*)command;
- (void)hide:(CDVInvokedUrlCommand*)command;
- (void)reload:(CDVInvokedUrlCommand*)command;
- (void)loadAfterBeforeload:(CDVInvokedUrlCommand*)command;

@end

@interface CDVWKThemeableBrowserViewController : UIViewController <CDVScreenOrientationDelegate,WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler>{
    @private
    NSString* _userAgent;
    NSString* _prevUserAgent;
    NSInteger _userAgentLockToken;
    CDVWKThemeableBrowserOptions *_browserOptions;
}

@property (nonatomic, strong) IBOutlet WKWebView* webView;
@property (nonatomic, strong) IBOutlet WKWebViewConfiguration* configuration;
@property (nonatomic, strong) IBOutlet UIButton* closeButton;
@property (nonatomic, strong) IBOutlet UILabel* addressLabel;
@property (nonatomic, strong) IBOutlet UIButton* backButton;
 @property (nonatomic, strong) IBOutlet UILabel* titleLabel;
@property (nonatomic, strong) IBOutlet UIBarButtonItem* forwardButton;
@property (nonatomic, strong) IBOutlet UIButton* menuButton;

@property (nonatomic, strong) NSArray* leftButtons;
@property (nonatomic, strong) NSArray* rightButtons;

@property (nonatomic, strong) IBOutlet UIActivityIndicatorView* spinner;
@property (nonatomic, strong) IBOutlet UIProgressView* progressView;
@property (nonatomic, strong) IBOutlet UIView* toolbar;
@property (nonatomic, strong) IBOutlet CDVWKThemeableBrowserUIDelegate* webViewUIDelegate;

@property (nonatomic, weak) id <CDVScreenOrientationDelegate> orientationDelegate;
@property (nonatomic, weak) CDVWKThemeableBrowser* navigationDelegate;
@property (nonatomic) CGFloat titleOffset;
@property (nonatomic) NSURL* currentURL;
@property (nonatomic) NSString* currentTitle; //add current title by zhaogx 2018-12-17
@property (nonatomic) BOOL isDismiss;

- (void)close;
- (void)setWebViewFullscreen:(BOOL)show;
- (void)setStatusBarStyle:(NSString *) style;
- (void)setTitle:(NSString *) title;
- (void)reload;
- (void)navigateTo:(NSURL*)url;
- (void)showLocationBar:(BOOL)show;
- (void)showToolBar:(BOOL)show : (NSString *) toolbarPosition;
- (void)setCloseButtonTitle:(NSString*)title : (NSString*) colorString : (int) buttonIndex;

- (id)initWithUserAgent:(NSString*)userAgent prevUserAgent:(NSString*)prevUserAgent browserOptions: (CDVWKThemeableBrowserOptions*) browserOptions;

@end
