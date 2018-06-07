//
//  utilities.m
//  multi_path
//
//  Created by Joseph Shenton on 7/6/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#import "utilities.h"
#include <sys/stat.h>
#include <mach/mach.h>
#include <sys/utsname.h>
#include <stdlib.h>
#include <spawn.h>
#include <sys/dirent.h>

@implementation utilities

NSString* getPathForDir(NSString *dir_name) {
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *final_path = [docDir stringByAppendingPathComponent:dir_name];
    
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:final_path isDirectory:&isDir])
    {
        if([fm createDirectoryAtPath:final_path withIntermediateDirectories:YES attributes:nil error:nil])
            printf("[INFO]: created houdini dir with name: %s\n", [dir_name UTF8String]);
        else
            printf("[ERROR]: could not create dir with name: %s\n", [dir_name UTF8String]);
    }
    
    return final_path;
}

kern_return_t set_file_permissions (char * destination_path, int uid, int gid, int perm_num) {
    
    // Chown the destination
    int ret = chown(destination_path, uid, gid);
    
    if (ret == -1) {
        printf("[ERROR]: could not chown destination file: %s\n", destination_path);
        return KERN_FAILURE;
    }
    
    // Chmod the destination
    ret = chmod(destination_path, perm_num);
    
    if (ret == -1) {
        printf("[ERROR]: could not chmod destination file: %s\n", destination_path);
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}

kern_return_t copy_file(char * source_path, char * destination_path, int uid, int gid, int num_perm) {
    
    printf("[INFO]: deleting %s\n", destination_path);
    
    // unlink destination first
    unlink(destination_path);
    
    printf("[INFO]: copying files from (%s) to (%s)..\n", source_path, destination_path);
    
    size_t read_size, write_size;
    char buffer[100];
    
    int read_fd = open(source_path, O_RDONLY, 0);
    int write_fd = open(destination_path, O_RDWR | O_CREAT | O_APPEND, 0777);
    
    FILE *read_file = fdopen(read_fd, "r");
    FILE *write_file = fdopen(write_fd, "wb");
    
    if(read_file == NULL) {
        printf("[ERROR]: can't copy. failed to read file from path: %s\n", source_path);
        return KERN_FAILURE;
        
    }
    
    if(write_file == NULL) {
        printf("[ERROR]: can't copy. failed to write file with path: %s\n", destination_path);
        return KERN_FAILURE;
    }
    
    while(feof(read_file) == 0) {
        
        if((read_size = fread(buffer, 1, 100, read_file)) != 100) {
            
            if(ferror(read_file) != 0) {
                printf("[ERROR]: could not read from: %s\n", source_path);
                return KERN_FAILURE;
            }
        }
        
        if((write_size = fwrite(buffer, 1, read_size, write_file)) != read_size) {
            printf("[ERROR]: could not write to: %s\n", destination_path);
            return KERN_FAILURE;
        }
    }
    
    fclose(read_file);
    fclose(write_file);
    
    close(read_fd);
    close(write_fd);
    
    
    // Chown the destination
    kern_return_t ret = set_file_permissions(destination_path, uid, gid, num_perm);
    if (ret != KERN_SUCCESS) {
        return KERN_FAILURE;
    }
    
    
    return KERN_SUCCESS;
}

void change_carrier_name(NSString *new_name) {
    
    char *path = "/var/mobile/Library/Carrier Bundles/Overlay";
    
    DIR *mydir;
    struct dirent *myfile;
    
    FILE *f = fopen("/var/mobile/.roottest", "w");
    if (f == 0) {
        //        FAILURE
    } else {
        
        //         SUCCESS
    }
    fclose(f);
    
    printf("[INFO]: opening %s carriers folder\n", path);
    int fd = open(path, O_RDONLY, 0);
    
    if (fd < 0)
        return;
    
    // output path
    NSString *output_dir_path = getPathForDir(@"carriers");
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        char *name = myfile->d_name;
        
        if(strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
            continue;
        
        // get the file (path + name)
        copy_file(strdup([[NSString stringWithFormat:@"%s/%s", path, name] UTF8String]), strdup([[NSString stringWithFormat:@"%@/%s", output_dir_path, name] UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
        
        // backup the original file
        rename(strdup([[NSString stringWithFormat:@"%s/%s", path, name] UTF8String]),
               strdup([[NSString stringWithFormat:@"%s/%s.backup", path, name] UTF8String]));
        
        
    }
    
    closedir(mydir);
    close(fd);
    
    // read each file we copied
    NSArray *directory_content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:output_dir_path error:NULL];
    for (NSString *plist_name in directory_content) {
        
        
        NSString *copied_plist_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, plist_name];
        printf("[INFO]: copied file: %s\n", strdup([copied_plist_path UTF8String]));
        
        // read each plist and do the renaming
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:copied_plist_path];
        
        if(dict == NULL)
            continue;
        
        [dict setObject:new_name forKey:@"CarrierName"];
        
        if ([dict objectForKey:@"MVNOOverrides"]) {
            
            NSObject *object = [dict objectForKey:@"MVNOOverrides"];
            
            if([object isKindOfClass:[NSMutableDictionary class]]){
                NSMutableDictionary *mv_no_overriders_dict = (NSMutableDictionary *)object;
                
                if([mv_no_overriders_dict objectForKey:@"StatusBarImages"]) {
                    
                    NSMutableArray *status_bar_images_array = [mv_no_overriders_dict objectForKey:@"StatusBarImages"];
                    
                    for (NSMutableDictionary *item in status_bar_images_array) {
                        
                        if([item objectForKey:@"StatusBarCarrierName"]) {
                            [item setObject:new_name forKey:@"StatusBarCarrierName"];
                        }
                        
                        if([item objectForKey:@"CarrierName"]) {
                            [item setObject:new_name forKey:@"CarrierName"];
                        }
                    }
                }
                
            }
        }
        
        [dict setObject:new_name forKey:@"OverrideOperatorName"];
        [dict setObject:new_name forKey:@"OverrideOperatorWiFiName"];
        
        if ([dict objectForKey:@"IMSConfigSecondaryOverlay"]) {
            
            NSMutableDictionary *ims_config_dict = (NSMutableDictionary *)[dict objectForKey:@"IMSConfigSecondaryOverlay"];
            
            if([ims_config_dict objectForKey:@"CarrierName"]) {
                [ims_config_dict setValue:new_name forKey:@"CarrierName"];
            }
        }
        
        if ([dict objectForKey:@"StatusBarImages"]) {
            
            NSMutableArray *status_bar_images_array = [dict objectForKey:@"StatusBarImages"];
            
            for (NSMutableDictionary *item in status_bar_images_array) {
                
                if([item objectForKey:@"StatusBarCarrierName"]) {
                    [item setObject:new_name forKey:@"StatusBarCarrierName"];
                }
                
                if([item objectForKey:@"CarrierName"]) {
                    [item setObject:new_name forKey:@"CarrierName"];
                }
            }
            
        }
        
        
        NSString *saved_plist_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, [plist_name lastPathComponent]];
        
        printf("[INFO]: saving carrier plist to: %s\n", strdup([saved_plist_path UTF8String]));
        [dict writeToFile:saved_plist_path atomically:YES];
        
        // move the file back
        copy_file(strdup([saved_plist_path UTF8String]), strdup([[NSString stringWithFormat:@"%s/%@", path, plist_name] UTF8String]), INSTALL_UID, INSTALL_GID, 0755);
        
    }
    
    sleep(3);
    printf("[INFO]: saved carrier, please respring and pray it fucking works and you don't bootloop!\n");
}

kern_return_t set_custom_hosts(boolean_t use_custom) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    // revert first
    copy_file("/etc/bck_hosts", "/etc/hosts", ROOT_UID, WHEEL_GID, 0644);
    
    // delete the old 'bck_hosts' file
    unlink("/etc/bck_hosts");
    
    if(use_custom) {
        
        printf("[INFO]: requested a custom hosts file!\n");
        
        // backup the original one
        copy_file("/etc/hosts", "/etc/bck_hosts", ROOT_UID, WHEEL_GID, 0644);
        
        // copy our custom hosts file
        char *custom_hosts_path = strdup([[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/custom_hosts"] UTF8String]);
        copy_file(custom_hosts_path, "/etc/hosts", ROOT_UID, WHEEL_GID, 0644);
    }
    
    return ret;
}


@end
