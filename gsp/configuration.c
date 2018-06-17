//
//  configuration.c
//
//  Created by Swordow on 2018/6/13.
//
#include <stdlib.h>
#include <memory.h>
#include <stdio.h>
#include "cJSON.h"
#include "log.h"
#include "ss_worker.h"
#include "configuration.h"

static Config* config = 0;
void config_init()
{
    if (config == 0)
    {
        config = (Config*)malloc(sizeof(Config));
        config->current = 0;
        config->size = 0;
        memset(config->profiles, 0, sizeof(Profile*)*MAX_SIZE);
    }
}
Profile* create_profile_from_json(const char* json)
{
    return 0;
}

int update_profile(Profile* profile, const char* server, const char* server_port, const char* password, const char* method, const char* remarks)
{
    memset(profile, 0, sizeof(Profile));
    strcpy(profile->server, server);
    strcpy(profile->password, password);
    strcpy(profile->method, method);
    strcpy(profile->remarks, remarks);
    strcpy(profile->port, server_port);
    logln_info("server:%s port:%s method:%s password:%s remarks:%s",
           profile->server, profile->port, profile->method, profile->password, profile->remarks);
    return 0;
}

Profile* create_profile(const char* server, const char* server_port, const char* password, const char* method, const char* remarks)
{
    Profile* profile = (Profile*)malloc(sizeof(Profile));
    update_profile(profile, server, server_port, password, method, remarks);
    return profile;
}

int add_profile(Config* config, Profile* profile)
{
    config->profiles[config->size] = profile;
    config->size += 1;
    return 0;
}

int remove_profile(Config* config, int idx)
{
    if (idx < 0 || idx >= config->size) return 0;
    free(config->profiles[idx]);
    memcpy(&config->profiles[idx], &config->profiles[idx+1], sizeof(struct Profile*)*(config->size-idx-1));
    config->size -= 1;
    return 0;
}
int config_reload_worker()
{
    if (config->current == -1)
    {
        worker_set_using_public_server(1);
        worker_reload_config();
        return 0;
    }
    Profile *profile = config->profiles[config->current];
    if (profile == 0)
    {
        return 0;
    }
    worker_set_using_public_server(0);
    worker_update(profile->server, profile->port, profile->password, profile->method);
    worker_reload_config();
    return 0;
}

int save_config(const char* config_path)
{
    config_init();
    Config* conf = config;
    cJSON* json = cJSON_CreateObject();
    cJSON_AddNumberToObject(json, "current", conf->current);
    cJSON_AddStringToObject(json, "PACUpdateURL", conf->pac_update_url);
    cJSON* ar = cJSON_CreateArray();
    for (size_t i=0; i<conf->size; ++i)
    {
        cJSON* pj = cJSON_CreateObject();
        cJSON_AddStringToObject(pj, "server", conf->profiles[i]->server);
        cJSON_AddStringToObject(pj, "method", conf->profiles[i]->method);
        cJSON_AddStringToObject(pj, "password", conf->profiles[i]->password);
        cJSON_AddStringToObject(pj, "remarks", conf->profiles[i]->remarks);
        cJSON_AddStringToObject(pj, "port", conf->profiles[i]->port);
        cJSON_AddItemToArray(ar, pj);
    }
    cJSON_AddItemToObject(json, "profiles", ar);
    FILE* fp = fopen(config_path, "wt");
    const char* buf = cJSON_PrintBuffered(json, 10240, 1);
    logln_info("Save Config: %s\n", buf);
    fwrite(buf, 1, strlen(buf)*sizeof(char), fp);
    fclose(fp);
    cJSON_Delete(json);
    config_reload_worker();
    return 0;
}

Config* load_config(const char* config_path)
{
    config_init();
    FILE* fp = fopen(config_path, "rt");
    if (!fp)
    {
        return config;
    }
    char buffer[10240] = {0};
    size_t bytes = fread(buffer,1, 10240, fp);
    if (bytes == 0)
    {
        fclose(fp);
        return config;
    }
    for (size_t i=0; i<config->size; ++i)
    {
        free(config->profiles[i]);
        config->profiles[i] = 0;
    }
    config->size = 0;
    cJSON* json = cJSON_Parse(buffer);
    cJSON* ar = cJSON_GetObjectItem(json, "profiles");
    int size = cJSON_GetArraySize(ar);
    for (size_t i=0; i<size; ++i)
    {
        cJSON* pj = cJSON_GetArrayItem(ar, (int)i);
        add_profile(config,
                        create_profile(
                           cJSON_GetObjectItem(pj, "server")->valuestring,
                           cJSON_GetObjectItem(pj, "port")->valuestring,
                           cJSON_GetObjectItem(pj, "password")->valuestring,
                           cJSON_GetObjectItem(pj, "method")->valuestring,
                           cJSON_GetObjectItem(pj, "remarks")->valuestring
                                       )
                    );
    }
    config->current = cJSON_GetObjectItem(json, "current")->valueint;
    cJSON* url = cJSON_GetObjectItem(json, "PACUpdateURL");
    if (url!=0)
    {
        strcpy(config->pac_update_url, cJSON_GetObjectItem(json, "PACUpdateURL")->valuestring);
    }
    fclose(fp);
    cJSON_Delete(json);
    return config;
}

const char* config_get_pac_update_url()
{
    config_init();
    return config->pac_update_url;
}

void config_set_pac_update_url(const char* url)
{
    config_init();
    strcpy(config->pac_update_url, url);
    
}



//
//g_profile_mgr.config.size = 0;
//g_profile_mgr.config.active = 0;
//g_profile_mgr.config.profiles = 0;

