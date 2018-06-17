//
//  ss_runner.h
//  gsp
//
//  Created by Swordow on 2018/6/14.
//

#ifndef __SS_WORKER_H__
#define __SS_WORKER_H__

#include <stdio.h>
#include "ss_common.h"

#define kGSPIPKey @"proxy ip"
#define kGSPPortKey @"proxy port"
#define kGSPPasswordKey @"proxy password"
#define kGSPEncryptionKey @"proxy encryption"
#define kGSPProxyModeKey @"proxy mode"
#define kGSPUsePublicServer @"public server"


typedef struct SSWorker
{
    int use_public;
    char ssurl[MAX_SIZE];
    char proxy_ip[MAX_SIZE];
    char proxy_port[MAX_SIZE];
    char proxy_password[MAX_SIZE];
    char proxy_encryption[MAX_SIZE];
    char proxy_mode[MAX_SIZE];
}SSWorker;

int worker_is_using_public_server();
void worker_set_using_public_server(int use_public);
const char* worker_generate_ssurl();
int worker_update_from_url(const char* url);
int worker_update(const char* ip,const char* port, const char* password, const char* method);
const char* worker_ip();
const char* worker_port();
const char* worker_password();
const char* worker_method();
int worker_reload_config();

#endif // __SS_RUNNER_H__
