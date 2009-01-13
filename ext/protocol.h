

#ifdef DEBUG
#define dprintf(msg, args...) printf(msg, ##args);
#else
#define dprintf(msg, args...)
#endif

#define SERVER_ERROR -3
#define CLIENT_ERROR -2
#define ERROR -1
#define VALUES 0
#define STORED 1
#define NOT_STORED 2
#define EXISTS 3
#define NOT_FOUND 4
#define DELETED 5
#define INC_VALUE 6
#define STATS 7
#define OK 8
#define VERSION 9


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

typedef struct _stat_t {
  char *key;
  char *string_val;
  unsigned long num_key;
  unsigned long num_val;
} stat_t;

typedef struct _stats_t {
  stat_t* array;
  int len;
  int cap;
} stats_t;

typedef struct _protocol_t {
  int cs;
  int type;
  stats_t stats;
  long value;
  char* mark;
  values_t values;
  char* error;
  char err_char;
  int err_pos;
  char* version;
} protocol_t;

int memcache_protocol_get();
int memcache_protocol_set();
int memcache_protocol_delete();
int memcache_protocol_inc();
int memcache_protocol_stats();
int memcache_protocol_flush_all();
int memcache_protocol_version();

int memcache_protocol_init(protocol_t *protocol);
int memcache_protocol_reset(protocol_t *protocol);
void memcache_protocol_mode(protocol_t *protocol, int mode);
int memcache_protocol_execute(protocol_t *protocol, char *buffer, int len, int off);
int memcache_protocol_is_start_state(protocol_t *protocol);
int memcache_protocol_is_finished(protocol_t *protocol);
int memcache_protocol_has_error(protocol_t *protocol);