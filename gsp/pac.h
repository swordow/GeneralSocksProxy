//
//  Created by Swordow on 2018/6/12.
//

#ifndef __PAC_H__
#define __PAC_H__

#include <stdio.h>

int pac_update_from_url();
const char* load_pac(const char* file, size_t* size);
void pac_init(const char* pac_template_path,
              const char* default_pac_path,
              const char* working_pac_path);
void pac_server_start();
#endif //__PAC_H__
