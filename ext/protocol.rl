#include "protocol.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define CHAR_POS(arg) (int)(arg - buffer)
#define MARK_LEN(arg) (int)(arg - protocol->mark)

%%{
  machine memcache_protocol;
  newline = "\r\n";
  end = "END";

  action handle_error {
    protocol->err_char = fc;
    protocol->err_pos = CHAR_POS(fpc);
    dprintf("error occurred at char '%c' pos %d\n", fc, CHAR_POS(fpc));
  }

  action mark {
    dprintf("marking at %d\n", CHAR_POS(fpc));
    protocol->mark = fpc;
  }
  
  action key {
    len = MARK_LEN(fpc);
    dprintf("found key with len %d\n", len);
    dprintf("value is %d\n", value);
    value->key = (char*)malloc(len+1);
    strncpy(value->key, protocol->mark, len);
    value->key[len] = 0;
  }
  
  action flags {
    value->flags = atoi(protocol->mark);
  }
  
  action cas {
    value->cas = atoi(protocol->mark);
  }
  
  action data_len {
    data_read = 0;
    value->len = atoi(protocol->mark);
    value->data = malloc(value->len+1);
  }
  
  action data_len_test {
    data_read++ < value->len
  }
  
  action data {
    dprintf("found data with len %d\n", value->len);
    strncpy(value->data, protocol->mark, value->len);
    value->data[value->len] = 0;
  }
  
  action start_value {
    dprintf("calling start_value values is %d\n",values);
    if (values->cap <= values->len) {
      dprintf("reallocating values array cap %d len %d\n", values->cap, values->len);
      values->cap = values->cap == 0 ? 5 : values->cap * 2;
      dprintf("new capacity %d\n", values->cap);
      dprintf("array before realloc %d\n", values->array);
      values->array = realloc(values->array, values->cap * sizeof(value_t));
      dprintf("array after realloc %d\n", values->array);
      dprintf("zeroing %d for %d items\n", values->len, (values->cap - values->len));
      bzero(&values->array[values->len], (values->cap - values->len) * sizeof(value_t));
    }
    value = &values->array[values->len];
    dprintf("assigned value %d\n", values->len);
  }
  
  action end_value {
    dprintf("ending value %d\n", values->len);
    values->len++;
  }
  
  action handle_client_error {
    dprintf("setting type to client error.\n");
    protocol->type = CLIENT_ERROR;
  }
  
  action handle_server_error {
    dprintf("setting type to server error.\n");
    protocol->type = SERVER_ERROR;
  }
  
  action handle_reg_error {
    dprintf("setting type to command error.\n");
    protocol->type = ERROR;
  }
  
  action handle_get_response {
    protocol->type = VALUES;
    dprintf("got response\n");
  }
  
  action handle_error_string {
    len = (int)(fpc - protocol->mark);
    protocol->error = (char*)malloc(len+1);
    strncpy(protocol->error, protocol->mark, len);
    protocol->error[len] = 0;
  }
  
  action handle_stored {
    protocol->type = STORED;
  }
  
  action handle_not_stored {
    protocol->type = NOT_STORED;
  }
  
  action handle_exists {
    protocol->type = EXISTS;
  }
  
  action handle_not_found {
    protocol->type = NOT_FOUND;
  }
  
  action handle_deleted {
    protocol->type = DELETED;
  }
  
  action handle_inc_value {
    protocol->type = INC_VALUE;
    protocol->value = atol(protocol->mark);
  }
  
  action start_stats {
    protocol->type = STATS;
  }
  
  action start_stat {
    if (stats->cap <= stats->len) {
      stats->cap = stats->cap == 0 ? 5 : values->cap * 2;
      stats->array = realloc(stats->array, stats->cap * sizeof(stat_t));
      bzero(&stats->array[stats->len], (stats->cap - stats->len) * sizeof(stat_t));
    }
    stat = &stats->array[stats->len];
  }
  
  action handle_stat_key {
    len = MARK_LEN(fpc);
    stat->key = malloc(len+1);
    strncpy(stat->key, protocol->mark, len);
    stat->key[len] = 0;
  }
  
  action handle_stat_string {
    len = MARK_LEN(fpc);
    stat->string_val = malloc(len+1);
    strncpy(stat->string_val, protocol->mark, len);
    stat->string_val[len] = 0;
  }
  
  action handle_stat_long {
    stat->num_val = strtoul(protocol->mark, NULL, 10);
  }
  
  action end_stat {
    stats->len++;
  }
  
  action handle_flush_all {
    protocol->type = OK;
  }
  
  key = [^ ]+ >mark;
  string = [^\r]+ >mark;
  integer = digit+ >mark;
  value = ("VALUE" space key %key space integer %flags space integer %data_len (integer %cas)? newline) >start_value;
  get_response = (
      value %handle_get_response
      (any when data_len_test)+ >mark %data newline %end_value
    )* 
    end newline;
    
  inc_value = integer %handle_inc_value newline;
  stat_lines = (("STAT" space)? key %handle_stat_key space string %handle_stat_string newline %end_stat) >start_stat;
  size_stat_lines = integer space integer newline;
  
  reg_error = ("ERROR" %handle_reg_error newline);
  client_error = ("CLIENT_ERROR" %handle_client_error space string %handle_error_string newline);
  server_error = ("SERVER_ERROR" %handle_server_error space string %handle_error_string newline);
  errors = (reg_error | client_error | server_error);
  stored = ("STORED" %handle_stored newline);
  not_stored = ("NOT_STORED" %handle_not_stored newline);
  exists = ("EXISTS" %handle_exists newline);
  not_found = ("NOT_FOUND" %handle_not_found newline);
  deleted = ("DELETED" %handle_deleted newline);
  
  get := (get_response | errors) $!handle_error;
  set := (stored | not_stored | exists | not_found | errors) $!handle_error;
  delete := (deleted | not_found | errors) $!handle_error;
  inc := (not_found | inc_value | errors) $!handle_error;
  stats := ((stat_lines | size_stat_lines)* >start_stats end newline | errors) $!handle_error;
  flush_all := "OK" %handle_flush_all newline;
}%%

%% write data;

int memcache_protocol_get() { return memcache_protocol_en_get; }
int memcache_protocol_set() { return memcache_protocol_en_set; }
int memcache_protocol_delete() { return memcache_protocol_en_delete; }
int memcache_protocol_inc() { return memcache_protocol_en_inc; }
int memcache_protocol_stats() { return memcache_protocol_en_stats; }

#define VALUES_STARTING_CAP 5
#define STATS_STARTING_CAP 20

int memcache_protocol_init(protocol_t *protocol) {
  int cs = 0;
  %% write init;
  //we want to start in one of the prescribed modes
  protocol->cs = cs;
  protocol->error = NULL;
  protocol->mark = 0;
  protocol->values.cap = VALUES_STARTING_CAP;
  protocol->values.len = 0;
  protocol->values.array = malloc(VALUES_STARTING_CAP * sizeof(value_t));
  dprintf("allocated array is %d\n", protocol->values.array);
  bzero(protocol->values.array, VALUES_STARTING_CAP * sizeof(value_t));
  protocol->stats.cap = STATS_STARTING_CAP;
  protocol->stats.len = 0;
  protocol->stats.array = malloc(STATS_STARTING_CAP * sizeof(stat_t));
  bzero(protocol->stats.array, STATS_STARTING_CAP * sizeof(stat_t));
  return 0;
}

void memcache_protocol_mode(protocol_t *protocol, int mode) {
  protocol->cs = mode;
}

int memcache_protocol_execute(protocol_t *protocol, char* buffer, int len, int off) {
  char *p, *pe;
  char *eof = NULL;
  char *msg = NULL;
  int cs = protocol->cs;
  int data_read = 0;
  values_t *values = &protocol->values;
  value_t *value = NULL;
  stats_t *stats = &protocol->stats;
  stat_t *stat = NULL;
  
  p = buffer+off;
  pe = buffer+len;
  
  %% write exec;
  
  protocol->cs = cs;
  // protocol->nread += p - (buffer + off);
  return cs;
}

//anything above first final is a final state
int memcache_protocol_is_finished(protocol_t *protocol) {
  return protocol->cs >= memcache_protocol_first_final;
}

int memcache_protocol_has_error(protocol_t *protocol) {
  return protocol->cs == memcache_protocol_error;
}