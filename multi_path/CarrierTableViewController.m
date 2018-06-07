//
//  CarrierTableViewController.m
//  multi_path
//
//  Created by Joseph Shenton on 7/6/18.
//  Copyright © 2018 JJS Digital PTY LTD. All rights reserved.
//

#import "CarrierTableViewController.h"
#include "sploit.h"
#include "jelbrek/jelbrek.h"
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/spawn.h>
#include <mach/mach.h>
#include <sys/utsname.h>
#include <sys/dirent.h>
#include "utilities.h"

mach_port_t taskforpidzero;

uint64_t find_kernel_base() {
#define IMAGE_OFFSET 0x2000
#define MACHO_HEADER_MAGIC 0xfeedfacf
#define MAX_KASLR_SLIDE 0x21000000
#define KERNEL_SEARCH_ADDRESS_IOS10 0xfffffff007004000
#define KERNEL_SEARCH_ADDRESS_IOS9 0xffffff8004004000
#define KERNEL_SEARCH_ADDRESS_IOS 0xffffff8000000000
    
#define ptrSize sizeof(uintptr_t)
    
    uint64_t addr = KERNEL_SEARCH_ADDRESS_IOS10+MAX_KASLR_SLIDE;
    
    
    while (1) {
        char *buf;
        mach_msg_type_number_t sz = 0;
        kern_return_t ret = vm_read(taskforpidzero, addr, 0x200, (vm_offset_t*)&buf, &sz);
        
        if (ret) {
            goto next;
        }
        
        if (*((uint32_t *)buf) == MACHO_HEADER_MAGIC) {
            int ret = vm_read(taskforpidzero, addr, 0x1000, (vm_offset_t*)&buf, &sz);
            if (ret != KERN_SUCCESS) {
                printf("Failed vm_read %i\n", ret);
                goto next;
            }
            
            for (uintptr_t i=addr; i < (addr+0x2000); i+=(ptrSize)) {
                mach_msg_type_number_t sz;
                int ret = vm_read(taskforpidzero, i, 0x120, (vm_offset_t*)&buf, &sz);
                
                if (ret != KERN_SUCCESS) {
                    printf("Failed vm_read %i\n", ret);
                    exit(-1);
                }
                if (!strcmp(buf, "__text") && !strcmp(buf+0x10, "__PRELINK_TEXT")) {
                    
                    printf("kernel base: 0x%llx\nkaslr slide: 0x%llx\n", addr, addr - 0xfffffff007004000);
                    
                    return addr;
                }
            }
        }
        
    next:
        addr -= 0x200000;
    }
}

@interface CarrierTableViewController ()

@end

@implementation CarrierTableViewController

- (void)jelbrek {
    get_root(getpid());
    empower(getpid());
    unsandbox(getpid());
    
    
    if (geteuid() == 0) {
        FILE *f = fopen("/var/mobile/.carrier_changer", "w");
        if (f == 0) {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"sandbox" message:@"Failed to escape sandbox! Please press and hold the home + power button (home + volume down button) for 6 seconds and try again!" preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
            
            [alert addAction:defaultAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            //                set_custom_hosts(true);
            change_carrier_name(self.carrierName.text);
            reboot(0);
        }
        fclose(f);
    }
    else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Carrier Changer" message:@"Failed to get root! Please press and hold the home + power button (home + volume down button) for 6 seconds and try again!" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (IBAction)go:(id)sender {
    taskforpidzero = go();
    
    if (taskforpidzero != MACH_PORT_NULL) {
        init_jelbrek(taskforpidzero, find_kernel_base());
        [self jelbrek];
    }
    else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Carrier Changer" message:@"Exploit failed! Please press and hold the home + power button (home + volume down button) for 6 seconds and try again!" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
