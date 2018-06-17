//
//  Created by Swordow on 2018/6/14.
//
#include <stdlib.h>
#include <memory.h>
#include <string.h>
#include <curl/curl.h>
#include "log.h"
#include "ss_worker.h"
#include "local.h"

CURLcode Curl_base64_encode(struct SessionHandle *data, const char *src, size_t insize, unsigned char **outptr);

static SSWorker g_worker;

void worker_init()
{
    memset(&g_worker, 0, sizeof(g_worker));
    g_worker.use_public = 0;

}

int worker_is_using_public_server()
{
    return g_worker.use_public;
}

void worker_set_using_public_server(int use_pubilc)
{
    g_worker.use_public = use_pubilc;
}

int worker_is_ready()
{
    if (!g_worker.use_public &&(
        g_worker.proxy_ip[0] == 0 ||
        g_worker.proxy_port[0] == 0  ||
        g_worker.proxy_password[0] == 0))
    {
        return 0;
    }
    return 1;
}

int worker_run_proxy()
{
    if (worker_is_ready()) {
        local_main();
        return 1;
    }
    else
    {
        logln_info("warning: settings are not complete");
        return 0;
    }
}

int worker_reload_config()
{
    if (!worker_is_ready()) return 0;
    if (g_worker.use_public)
    {
        set_config("106.186.124.182", "8911", "GSP", "aes-128-cfb");
        memcpy(GSP_key, "\x45\xd1\xd9\x9e\xbd\xf5\x8c\x85\x34\x55\xdd\x65\x46\xcd\x06\xd3", 16);
        return 0;
    }
    
    if (g_worker.proxy_encryption[0] == 0)
    {
        strcpy(g_worker.proxy_encryption, "aes-256-cfb");
    }
    logln_info("Reload Config: %s %s %s %s", g_worker.proxy_ip, g_worker.proxy_port, g_worker.proxy_password,g_worker.proxy_encryption);
    set_config(g_worker.proxy_ip,
               g_worker.proxy_port,
               g_worker.proxy_password,
               g_worker.proxy_encryption);
    return 0;
}

const char* worker_generate_ssurl()
{
    if (g_worker.use_public)
    {
        return 0;
    }
    sprintf(g_worker.ssurl, "%s:%s@%s:%s",
            g_worker.proxy_encryption,
            g_worker.proxy_password,
            g_worker.proxy_ip,
            g_worker.proxy_port);
    unsigned char* outptr;
    Curl_base64_encode(0, g_worker.ssurl, strlen(g_worker.ssurl), &outptr);
    sprintf(g_worker.ssurl, "ss://%s", outptr);
    free(outptr);
    logln_info("SSWorker:: ss url %s", g_worker.ssurl);
    return g_worker.ssurl;
}

int worker_update(const char* ip, const char* port, const char* password, const char* method)
{
    strcpy(g_worker.proxy_encryption, method);
    strcpy(g_worker.proxy_password, password);
    strcpy(g_worker.proxy_ip, ip);
    strcpy(g_worker.proxy_port, port);
    g_worker.use_public = 0;
    logln_info("Worker Updated: server %s port %s password %s method %s use public %d",
               g_worker.proxy_ip,
               g_worker.proxy_port,
               g_worker.proxy_password,
               g_worker.proxy_encryption,
               g_worker.use_public);
    worker_reload_config();
    return 0;
}

int worker_update_from_url(const char* url)
{
    //find ss://
    const char* check_start = url;
    const char* prefix = strstr(url, "ss://");
    if (prefix!=0)
    {
        check_start += 5;
    }
    const char* first_col = strchr(check_start, ':');
    const char* last_col = strrchr(check_start, ':');
    const char* last_at = strrchr(check_start, '@');
    if (first_col == 0)
        return 1;
    if (last_col == first_col)
        return 2;
    if (last_at == 0)
        return 3;
    if (!(last_at < last_col && last_at > first_col))
        return 4;
    strncpy(g_worker.proxy_encryption, check_start, first_col-check_start);
    strncpy(g_worker.proxy_password, first_col+1, last_at-first_col-1);
    strncpy(g_worker.proxy_ip, last_at+1, last_col-last_at-1);
    strncpy(g_worker.proxy_port, last_col+1, strlen(check_start)-(last_col-check_start+1));
    g_worker.use_public = 0;
    logln_info("Worker Updated: server %s port %s password %s method %s use public %d",
           g_worker.proxy_ip,
           g_worker.proxy_port,
           g_worker.proxy_password,
           g_worker.proxy_encryption,
           g_worker.use_public);
    worker_reload_config();
    return 0;
}

const char* worker_ip() {return g_worker.proxy_ip;}
const char* worker_port() {return g_worker.proxy_port;}
const char* worker_password() {return g_worker.proxy_password;}
const char* worker_method() {return g_worker.proxy_encryption;}



