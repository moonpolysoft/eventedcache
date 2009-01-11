#include "protocol.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

%%{
  machine memcache_protocol;
  newline = "\r\n";
  end = "END";

  action handle_error {
    protocol->err_char = fc;
    protocol->err_pos = (int)(fpc - buffer);
    dprintf("error occurred at char '%c' pos %d\n", fc, (int)(fpc - buffer));
  }

  action mark {
    dprintf("marking at %d\n", (int)(fpc - buffer));
    protocol->mark = fpc;
  }
  
  action key {
    len = (int)(fpc - protocol->mark);
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
  
  key = [^ ]+ >mark;
  error_string = [^\r]+ >mark %handle_error_string;
  integer = digit+ >mark;
  value = ("VALUE" space key %key space integer %flags space integer %data_len (integer %cas)? newline) >start_value;
  get_response = (
      value
      (any when data_len_test)+ >mark %data newline %end_value
    )* 
    end newline %handle_get_response;
  
  reg_error = ("ERROR" %handle_reg_error newline);
  client_error = ("CLIENT_ERROR" %handle_client_error space error_string newline);
  server_error = ("SERVER_ERROR" %handle_server_error space error_string newline);
    
  main := (get_response | reg_error | client_error | server_error) $!handle_error;
}%%

%% write data;

int memcache_protocol_init(protocol_t *protocol) {
  int cs = 0;
  %% write init;
  protocol->cs = cs;
  protocol->error = NULL;
  protocol->mark = 0;
  protocol->values.cap = 5;
  protocol->values.len = 0;
  protocol->values.array = malloc(5 * sizeof(value_t));
  dprintf("allocated array is %d\n", protocol->values.array);
  bzero(protocol->values.array, 5 * sizeof(value_t));
  return 0;
}

int memcache_protocol_execute(protocol_t *protocol, char* buffer, int len, int off) {
  char *p, *pe;
  char *eof = NULL;
  char *msg = NULL;
  int cs = protocol->cs;
  int data_read = 0;
  values_t *values = &protocol->values;
  value_t *value = NULL;
  
  p = buffer+off;
  pe = buffer+len;
  
  %% write exec;
  
  protocol->cs = cs;
  // protocol->nread += p - (buffer + off);
  return cs;
}

int memcache_protocol_is_finished(protocol_t *protocol) {
  return protocol->cs == memcache_protocol_first_final;
}

int memcache_protocol_has_error(protocol_t *protocol) {
  return protocol->cs == memcache_protocol_error;
}