#ifdef DEBUG
#define dprintf(msg, args...) printf(msg, ##args);
#else
#define dprintf(msg, args...)
#endif

#define SERVER_ERROR -3
#define CLIENT_ERROR -2
#define ERROR -1
#define VALUES 0


typedef struct _value_t {
  char* key;
  int flags;
  int len;
  int cas;
  char* data;
} value_t;

typedef struct _values_t {
  value_t* array;
  int len;
  int cap;
} values_t;

typedef struct _protocol_t {
  int cs;
  int type;
  char* mark;
  values_t values;
  char* error;
  char err_char;
  int err_pos;
} protocol_t;



int memcache_protocol_init(protocol_t *protocol);
int memcache_protocol_execute(protocol_t *protocol, char *buffer, int len, int off);
int memcache_protocol_is_finished(protocol_t *protocol);
int memcache_protocol_has_error(protocol_t *protocol);