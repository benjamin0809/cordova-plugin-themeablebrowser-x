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

#import "CDVInAppBrowserOptions.h"

@implementation CDVInAppBrowserOptions

- (id)init
{
    if (self = [super init]) {
        // default values
        self.usewkwebview = NO;
        self.location = YES;
        self.closebuttoncaption = nil;
        self.toolbarposition = @"bottom";
        self.cleardata = NO;
        self.clearcache = NO;
        self.clearsessioncache = NO;
        self.hidespinner = NO;

        self.enableviewportscale = NO;
        self.mediaplaybackrequiresuseraction = NO;
        self.allowinlinemediaplayback = NO;
        self.keyboarddisplayrequiresuseraction = YES;
        self.suppressesincrementalrendering = NO;
        self.hidden = NO;
        self.disallowoverscroll = NO;
        self.hidenavigationbuttons = NO;
        self.closebuttoncolor = nil;
        self.lefttoright = false;
        self.toolbarcolor = nil;
        self.toolbartranslucent = YES;
        self.beforeload = @"";
        self.menu = nil;
        self.backButton = nil;
        self.closeButton = nil;
        self.title = nil;
        self.toolbar = nil;
        self.statusbar = nil;
        
        self.fullscreen = false;
    }

    return self;
}

+ (CDVInAppBrowserOptions*)parseOptions:(NSString*)options
{
    CDVInAppBrowserOptions* obj = [[CDVInAppBrowserOptions alloc] init];

    if (options && [options length] > 0) {
          // Min support, iOS 5. We will use the JSON parser that comes with iOS
          // 5.
          NSError *error = nil;
        NSString *string = [options stringByReplacingOccurrencesOfString:@"\\" withString:@""];
        
          NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
          id jsonObj = [NSJSONSerialization
                        JSONObjectWithData:data
                        options:0
                        error:&error];
          
          if(error) {
//              [self emitError:kThemeableBrowserEmitCodeCritical
//                  withMessage:[NSString stringWithFormat:@"Invalid JSON %@", error]];
          } else if([jsonObj isKindOfClass:[NSDictionary class]]) {
              NSDictionary *dict = jsonObj;
              for (NSString *key in dict) {
                  if ([obj respondsToSelector:NSSelectorFromString(key)]) {
                      [obj setValue:dict[key] forKey:key];
                  }
              }
          }
      } else {
//          [self emitWarning:kThemeableBrowserEmitCodeUndefined
//                withMessage:@"No config was given, defaults will be used, which is quite boring."];
      }
    // NOTE: this parsing does not handle quotes within values
//    NSArray* pairs = [options componentsSeparatedByString:@","];
//
//    // parse keys and values, set the properties
//    for (NSString* pair in pairs) {
//        NSArray* keyvalue = [pair componentsSeparatedByString:@"="];
//
//        if ([keyvalue count] == 2) {
//            NSString* key = [[keyvalue objectAtIndex:0] lowercaseString];
//            NSString* value = [keyvalue objectAtIndex:1];
//            NSString* value_lc = [value lowercaseString];
//
//            BOOL isBoolean = [value_lc isEqualToString:@"yes"] || [value_lc isEqualToString:@"no"];
//            NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
//            [numberFormatter setAllowsFloats:YES];
//            BOOL isNumber = [numberFormatter numberFromString:value_lc] != nil;
//
//            // set the property according to the key name
//            if ([obj respondsToSelector:NSSelectorFromString(key)]) {
//                if (isNumber) {
//                    [obj setValue:[numberFormatter numberFromString:value_lc] forKey:key];
//                } else if (isBoolean) {
//                    [obj setValue:[NSNumber numberWithBool:[value_lc isEqualToString:@"yes"]] forKey:key];
//                } else {
//                    [obj setValue:value forKey:key];
//                }
//            }
//        }
//    }

    return obj;
}

@end
