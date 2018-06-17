#include <microhttpd.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <sys/types.h>
#include <memory.h>
#include <stdlib.h>
#include "log.h"
#include "ss_common.h"
typedef const char* (*Respone)(void *handle);

typedef struct MHDHandle
{
    char urlpath[MAX_SIZE];
    char content_type[MAX_SIZE];
    const char* data;
    Respone reponse_func;
}MHDHandle;

struct MHDHandleMgr
{
    struct MHDHandle* handles[MAX_SIZE];
    int size;
};

static struct MHDHandleMgr* s_mhd_handle_mgr = 0;

static int
ahc_echo (void *cls,
          struct MHD_Connection *connection,
          const char *url,
          const char *method,
          const char *version,
          const char *upload_data,
          size_t *upload_data_size, void **ptr)
{
    static int aptr;
    struct MHD_Response *response;
    int ret;
    int fd;
    struct stat buf;
    (void)cls;               /* Unused. Silent compiler warning. */
    (void)version;           /* Unused. Silent compiler warning. */
    (void)upload_data;       /* Unused. Silent compiler warning. */
    (void)upload_data_size;  /* Unused. Silent compiler warning. */
    
    if ( (0 != strcmp (method, MHD_HTTP_METHOD_GET)) &&
        (0 != strcmp (method, MHD_HTTP_METHOD_HEAD)) )
        return MHD_NO;              /* unexpected method */
    if (&aptr != *ptr)
    {
        /* do never respond on first call */
        *ptr = &aptr;
        return MHD_YES;
    }
    *ptr = NULL;                  /* reset when done */
    /* WARNING: direct usage of url as filename is for example only!
     * NEVER pass received data directly as parameter to file manipulation
     * functions. Always check validity of data before using.
     */
    MHDHandle* handle = 0;
    for (int i=0; i<s_mhd_handle_mgr->size; ++i)
    {
        if (strcmp(s_mhd_handle_mgr->handles[i]->urlpath, url)==0)
        {
            handle = s_mhd_handle_mgr->handles[i];
            break;
        }
    }
    logln_info ("MHD: %s");
    if (handle != 0)
    {
        const char* data = (*handle->reponse_func)(handle);
        if (data == 0)
        {
            return MHD_NO;
        }
        response = MHD_create_response_from_buffer (
                        strlen (data),(void *) data,
                        MHD_RESPMEM_PERSISTENT);
        MHD_add_response_header (response,MHD_HTTP_HEADER_CONTENT_TYPE,handle->content_type);
        ret = MHD_queue_response (connection, MHD_HTTP_OK, response);
        logln_info ("MHD: %s %d",url,ret);
        MHD_destroy_response (response);
    }
    return ret;
}

static struct MHD_Daemon *sd = 0;
int mhd_start(int port)
{
    sd = MHD_start_daemon (MHD_USE_THREAD_PER_CONNECTION | MHD_USE_INTERNAL_POLLING_THREAD | MHD_USE_ERROR_LOG,
                          port,
                          NULL, NULL, &ahc_echo, 0, MHD_OPTION_END);
    if (sd == NULL)
        return -1;
    return 0;
}

int mhd_stop()
{
    if (sd == NULL)
        return 0;
    MHD_stop_daemon (sd);
    return 0;
}

const char* PACResponseHandle(void *handle)
{
    MHDHandle* mhandle = (struct MHDHandle*)handle;
    return mhandle->data;
}

void init_mhd_handle_mgr()
{
    if (s_mhd_handle_mgr == 0)
    {
        s_mhd_handle_mgr = (struct MHDHandleMgr*)malloc(sizeof(struct MHDHandleMgr));
        s_mhd_handle_mgr->size = 0;
    }
}

int mhd_config_pac_handle(const char* urlpath, const char* response_pac_data, const char* content_type)
{
    init_mhd_handle_mgr();
    struct MHDHandle *handle = (struct MHDHandle*)malloc(sizeof(struct MHDHandle));
    memset(handle, 0, sizeof(struct MHDHandle));
    s_mhd_handle_mgr->handles[s_mhd_handle_mgr->size] = handle;
    s_mhd_handle_mgr->size+=1;
    
    strcpy(handle->urlpath, urlpath);
    strcpy(handle->content_type, content_type);
    handle->data = response_pac_data;
    handle->reponse_func = PACResponseHandle;
    return 0;
}
int mhd_config_apn_handle(const char* urlpath, const char* content_type)
{
    init_mhd_handle_mgr();
    return 0;
}

