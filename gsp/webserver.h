//
//  Created by Swordow on 2018/6/13.
//

#ifndef webserver_h
#define webserver_h

#include <stdio.h>
int mhd_config_pac_handle(const char* urlpath, const char* pac_file_path, const char* content_type);
int mhd_config_apn_handle(const char* urlpath, const char* content_type);
int mhd_start(int port);
#endif /* webserver_h */
