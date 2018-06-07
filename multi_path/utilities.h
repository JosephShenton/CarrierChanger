//
//  utilities.h
//  multi_path
//
//  Created by Joseph Shenton on 7/6/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#import <Foundation/Foundation.h>
#define INSTALL_UID                                    33
#define INSTALL_GID                                    33

#define ROOT_UID                                    0
#define WHEEL_GID                                   0

#define MOBILE_UID                                    501
#define MOBILE_GID                                    501

NS_ASSUME_NONNULL_BEGIN

@interface utilities : NSObject
size_t kread(uint64_t where, void *p, size_t size);
uint64_t kread_uint64(uint64_t where);
uint32_t kread_uint32(uint64_t where);
size_t kwrite(uint64_t where, const void *p, size_t size);
size_t kwrite_uint64(uint64_t where, uint64_t value);
size_t kwrite_uint32(uint64_t where, uint32_t value);
void change_carrier_name(NSString *new_name);
kern_return_t set_custom_hosts(boolean_t use_custom);
@end

NS_ASSUME_NONNULL_END
