//
//  Created by Swordow on 2018/6/13.
//

#ifndef __CONFIGURATION_H__
#define __CONFIGURATION_H__
#define MAX_SIZE 260
#include <stdio.h>
typedef struct Profile
{
    char server[MAX_SIZE];
    char port[MAX_SIZE];
    char remarks[MAX_SIZE];
    char password[MAX_SIZE];
    char method[MAX_SIZE];
} Profile;

typedef struct Config
{
    Profile* profiles[MAX_SIZE];
    int size;
    int current;
    char pac_update_url[MAX_SIZE];
} Config;

Profile* create_profile_from_json(const char* json);
Profile* create_profile(const char* server, const char* server_port, const char* password, const char* method, const char* remarks);

int add_profile(Config* config, Profile* profile);
int remove_profile(Config* config, int idx);
int update_profile(Profile* profile, const char* server, const char* server_port, const char* password, const char* method, const char* remarks);
int save_config(const char* config_path);
Config* load_config(const char* config_path);
const char* config_get_pac_update_url();
void config_set_pac_update_url(const char* url);
int config_reload_worker();
#endif // __CONFIGURATION_H__
