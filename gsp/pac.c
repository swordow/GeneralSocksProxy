//
//  Created by Swordow on 2018/6/12.
//
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <stdint.h>
#include <stdio.h>
#include <curl/curl.h>
#include <stdlib.h>
#include <memory.h>
#include "log.h"
#include "webserver.h"
#include "pac.h"
#include "configuration.h"
#include "ss_common.h"
CURLcode Curl_base64_decode(const char *src, unsigned char **outptr, size_t *outlen);
typedef struct PACData
{
    char *pac_template;
    char *pac_default;
    char *pac_working;
    char template_path[MAX_SIZE];
    char default_path[MAX_SIZE];
    char working_path[MAX_SIZE];
}PACData;

static PACData* s_pac_data = 0;
static char* s_template = 0;
struct HTTPResponse
{
    size_t recv_bytes;
    char* buf;
    size_t total_bytes;
};

size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
    struct HTTPResponse* ret = (struct HTTPResponse*)userdata;
    memcpy(&ret->buf[ret->recv_bytes], ptr, size*nmemb);
    ret->recv_bytes += size*nmemb;
    return size*nmemb;
}

int convert_list_to_pac(char* data, size_t insize)
{
    int base_lines = 1000;
    int line_idx = 0;
    const char** lines = (const char**)malloc(sizeof(const char*)*base_lines);
//    lines[line_idx] = data;
//    line_idx++;
    for (size_t i=0; i < insize; ++i)
    {
        if (data[i] == '\n' || data[i] == '\r')
        {
            data[i] = 0;
            continue;
        }
        if (data[i] !='!' && data[i] != '[')
        {
            lines[line_idx] = &data[i];
            line_idx++;
            if (line_idx >= base_lines)
            {
                base_lines += 1000;
                lines = realloc(lines, sizeof(const char*)*base_lines);
            }
        }
        // to end
        const char* p = strchr(&data[i],'\n');
        i = p - &data[0]-1;
    }
    
    log_info("total %d lines", base_lines);
    
    
//    for (int i=0; i<line_idx; ++i)
//    {
//        logln_info("%s", lines[i]);
//    }
    
    const char* fmt = "\"%s\",\n";
    int fmt_len = strlen(fmt)*sizeof(char)-2;
    
    size_t total_bytes = strlen(s_pac_data->pac_template)*sizeof(char)+insize+base_lines*fmt_len+100;
    char* template = (char*)malloc(total_bytes);
    memset(template, 0, total_bytes);
    
    
    // find __RULES__
    // __RULES__ = ["line1","line2","line3"]
    char *rule_start = strstr(s_pac_data->pac_template, "__RULES__");
    
    // copy begin
    memcpy(template, s_pac_data->pac_template, rule_start-s_pac_data->pac_template);
    
    // contruse rules
    strcat(template, "[");
    
    char *p = template + strlen(template)*sizeof(char);
   
    for (int i=0; i<line_idx; ++i)
    {
        sprintf(p, fmt, lines[i]);
        p += strlen(lines[i])*sizeof(char)+fmt_len;
    }
    strcat(p, "]");
    logln_info("Template bytes %d", strlen(template));
    strcpy(&template[strlen(template)], rule_start+strlen("__RULES__"));
   
    FILE* fp = fopen(s_pac_data->working_path, "wb");
    fwrite(template, 1, strlen(template)*sizeof(char), fp);
    fclose(fp);
    
    if (s_pac_data->pac_working != 0)
    {
        free(s_pac_data->pac_working);
        s_pac_data->pac_working = 0;
    }
    s_pac_data->pac_working = (char*)malloc(total_bytes);
    memcpy(s_pac_data->pac_working, template, total_bytes);
    
    free(lines);
    free(template);
    return 0;
}

int pac_update_from_url()
{
    const char* url = config_get_pac_update_url();
    CURL *curl;
    CURLcode res;
    struct HTTPResponse ret;
    
    curl_global_init(CURL_GLOBAL_DEFAULT);
    
    curl = curl_easy_init();
    if (!curl)
    {
        curl_global_cleanup();
        return 1;
    }
    curl_easy_setopt(curl, CURLOPT_URL, url);
    
#ifdef SKIP_PEER_VERIFICATION
    /*
     * If you want to connect to a site who isn't using a certificate that is
     * signed by one of the certs in the CA bundle you have, you can skip the
     * verification of the server's certificate. This makes the connection
     * A LOT LESS SECURE.
     *
     * If you have a CA cert for the server stored someplace else than in the
     * default bundle, then the CURLOPT_CAPATH option might come handy for
     * you.
     */
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
#endif
    
#ifdef SKIP_HOSTNAME_VERIFICATION
    /*
     * If the site you're connecting to uses a different host name that what
     * they have mentioned in their server certificate's commonName (or
     * subjectAltName) fields, libcurl will refuse to connect. You can skip
     * this check, but this will make the connection less secure.
     */
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
#endif
    curl_easy_setopt(curl, CURLOPT_NOBODY, 1);
    /* Perform the request, res will get the return code */
    res = curl_easy_perform(curl);
    long length = 0;
    
    curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &length);
    //printf("length=%d", length);
    ret.total_bytes = length+40;
    ret.buf = (char*)malloc(ret.total_bytes);
    ret.recv_bytes = 0;
    memset(ret.buf, 0, ret.total_bytes);
    curl_easy_setopt(curl, CURLOPT_NOBODY, 0);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &ret);
    res = curl_easy_perform(curl);
    /* Check for errors */
    if(res != CURLE_OK)
        fprintf(stderr, "curl_easy_perform() failed: %s\n",
                curl_easy_strerror(res));
    
    /* always cleanup */
    curl_easy_cleanup(curl);
    
    curl_global_cleanup();
    //printf("Data size %d\n=======\n",ret.recv_bytes);
    //printf("Data is \n=======\n%s\n=======\n", ret.buf);
    unsigned char* raw_decode_data = 0;
    size_t decode_size = 0;
    for (int i=0; i<ret.total_bytes; ++i)
    {
        if (ret.buf[i] == '\n')
        {
            memcpy(&ret.buf[i], &ret.buf[i+1], ret.total_bytes-i-1);
        }
    }
    CURLcode rc = Curl_base64_decode(ret.buf, &raw_decode_data, &decode_size);
    if (rc != CURLE_OK)
    {
        logln_info("size should be %d",decode_size);
    }
    if (decode_size == 0)
    {
        return -1;
    }
    char* decode_data = (char*)malloc(decode_size);
    memcpy(decode_data, raw_decode_data, decode_size);
    //printf("Data is \n=======\n%s\n=======\n", decode_data);
    int r = convert_list_to_pac(decode_data, decode_size);
    free(decode_data);
    free(ret.buf);
    free(raw_decode_data);
    return r;
}

const char* load_pac(const char* file, size_t* size)
{
    return 0;
}

#define LOAD_DATA(path, buf)            \
    fp = fopen((path), "rb");           \
    if (fp != 0)                        \
    {                                   \
        fseek(fp, 0, SEEK_END);         \
        size = ftell(fp);               \
        fseek(fp, 0, SEEK_SET);         \
        (buf) = (char*)malloc(size+1);  \
        memset((buf), 0, size+1);       \
        fread((buf), 1, size+1, fp);    \
        fclose(fp);                     \
    }

void pac_init(const char* pac_template_path,
              const char* default_pac_path,
              const char* working_pac_path)
{
    if (s_pac_data == 0)
    {
        s_pac_data = (PACData*)malloc(sizeof(PACData));
        s_pac_data->pac_default = 0;
        s_pac_data->pac_template = 0;
        s_pac_data->pac_working = 0;
       
    }
    memset(s_pac_data->default_path, 0, MAX_SIZE);
    memset(s_pac_data->working_path, 0, MAX_SIZE);
    memset(s_pac_data->template_path, 0, MAX_SIZE);
    if (s_pac_data->pac_default)
    {
        free(s_pac_data->pac_default);
        s_pac_data->pac_default = 0;
    }
    if (s_pac_data->pac_working)
    {
        free(s_pac_data->pac_working);
        s_pac_data->pac_working = 0;
    }
    if (s_pac_data->pac_template)
    {
        free(s_pac_data->pac_template);
        s_pac_data->pac_template = 0;
    }
    FILE* fp = 0;
    size_t size = 0;
   
    LOAD_DATA(pac_template_path, s_pac_data->pac_template)
    LOAD_DATA(default_pac_path, s_pac_data->pac_default)
    LOAD_DATA(working_pac_path, s_pac_data->pac_working)
    
    strcpy(s_pac_data->default_path, default_pac_path);
    strcpy(s_pac_data->working_path, working_pac_path);
    strcpy(s_pac_data->template_path, pac_template_path);
}

void pac_server_start()
{
    mhd_config_pac_handle("/proxy.pac", s_pac_data->pac_working, "application/x-ns-proxy-autoconfig");
    mhd_start(9890);
}

