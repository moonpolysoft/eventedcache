#include "ruby.h"
#include "protocol.h"

static VALUE cProtocolError;
static VALUE cCommandError;
static VALUE cClientError;
static VALUE cServerError;

static VALUE mEventedCache;
static VALUE cMemcacheProtocol;
static VALUE cValues;
static VALUE cValue;

static void rb_memcache_protocol_free(void *ptr) {
  //will need to recursively free all of the bullshit associated with this
  dprintf("entering free\n");
  protocol_t *protocol = (protocol_t *)ptr;
  int i, n;
  value_t *value;
  
  for(i=0; i<protocol->values.len; i++) {
    value = &protocol->values.array[i];
    dprintf("freeing key for %d\n", i);
    if (value->key) {free(value->key);}
    dprintf("freeing data for %d\n", i);
    if (value->data) {free(value->data);}
  }
  if (protocol->values.array) {
    dprintf("freeing values array %p\n", protocol->values.array);
    free(protocol->values.array);
  }
  if (protocol->error) {
    free(protocol->error);
  }
  dprintf("freeing protocol\n");
  free(protocol);
}

static void rb_null_free(void *ptr) {
  //do nothing here, will be taken care of higher
  dprintf("bullshit free\n");
}

static VALUE rb_memcache_protocol_alloc(VALUE klass) {
  protocol_t *protocol = ALLOC_N(protocol_t, 1);
  memcache_protocol_init(protocol);

  return Data_Wrap_Struct(klass, NULL, rb_memcache_protocol_free, protocol);
}

static VALUE rb_memcache_protocol_execute(VALUE self, VALUE data) {
  protocol_t *protocol = NULL;
  int cs;
  char * msg;
  Data_Get_Struct(self, protocol_t, protocol);
  dprintf("executing with data '%s'\n", RSTRING(data)->ptr);
  cs = memcache_protocol_execute(protocol, RSTRING(data)->ptr, RSTRING(data)->len, 0);
  if (memcache_protocol_has_error(protocol)) {
    rb_raise(cProtocolError, "Memcache protocol encountered an error with char '%c' at pos %d\n", protocol->err_char, protocol->err_pos);
  } else {
    switch (protocol->type) {
      case SERVER_ERROR:
        rb_raise(cServerError, protocol->error);
      case CLIENT_ERROR:
        rb_raise(cClientError, protocol->error);
      case ERROR:
        rb_raise(cCommandError, "Memcache returned a command error.\n");
    }
    return INT2FIX(cs);
  }
}

static VALUE rb_memcache_protocol_has_error(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return memcache_protocol_has_error(protocol) ? Qtrue : Qfalse;
}

static VALUE rb_memcache_protocol_is_finished(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return memcache_protocol_is_finished(protocol) ? Qtrue : Qfalse;
}

static VALUE rb_memcache_protocol_values(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return Data_Wrap_Struct(cValues, NULL, rb_null_free, &protocol->values);
}

static VALUE rb_values_subscript(VALUE self, VALUE index) {
  values_t *values = NULL;
  int i;
  Data_Get_Struct(self, values_t, values);
  
  i = FIX2INT(index);
  
  if (i >= values->len) {
    return Qnil;
  } else {
    return Data_Wrap_Struct(cValue, NULL, rb_null_free, &values->array[i]);
  }
}

static VALUE rb_values_each(VALUE self) {
  values_t *values = NULL;
  int i = 0;
  value_t *value = NULL;
  Data_Get_Struct(self, values_t, values);
  
  for(i=0; i<values->len; i++) {
    value = &values->array[i];
    rb_yield(Data_Wrap_Struct(cValue, NULL, rb_null_free, value));
  }
}

static VALUE rb_values_len(VALUE self) {
  values_t *values = NULL;
  Data_Get_Struct(self, values_t, values);
  
  return INT2FIX(values->len);
}

static VALUE rb_value_key(VALUE self) {
  value_t *value = NULL;
  Data_Get_Struct(self, value_t, value);
  return rb_str_new2(value->key);
}

static VALUE rb_value_data(VALUE self) {
  value_t *value = NULL;
  Data_Get_Struct(self, value_t, value);
  return rb_str_new(value->data, value->len);
}

#define DECL_GET_VALUE_INTEGER(name) static VALUE rb_value_##name(VALUE self) {\
  value_t *value = NULL;\
  Data_Get_Struct(self, value_t, value);\
  return INT2FIX(value->name);\
}

DECL_GET_VALUE_INTEGER(flags);
DECL_GET_VALUE_INTEGER(len);
DECL_GET_VALUE_INTEGER(cas);

void Init_memcache_protocol() {
  mEventedCache = rb_define_module("EventedCache");
  
  cProtocolError = rb_define_class_under(mEventedCache, "ProtocolError", rb_eIOError);
  cCommandError = rb_define_class_under(mEventedCache, "CommandError", rb_eStandardError);
  cClientError = rb_define_class_under(mEventedCache, "ClientError", rb_eStandardError);
  cServerError = rb_define_class_under(mEventedCache, "ServerError", rb_eStandardError);
  
  cMemcacheProtocol = rb_define_class_under(mEventedCache, "MemcacheProtocol", rb_cObject);
  rb_define_alloc_func(cMemcacheProtocol, rb_memcache_protocol_alloc);
  rb_define_method(cMemcacheProtocol, "execute", rb_memcache_protocol_execute,1);
  rb_define_method(cMemcacheProtocol, "error?", rb_memcache_protocol_has_error,0);
  rb_define_method(cMemcacheProtocol, "finished?", rb_memcache_protocol_is_finished,0);
  rb_define_method(cMemcacheProtocol, "values", rb_memcache_protocol_values,0);
  
  cValues = rb_define_class_under(mEventedCache, "Values", rb_cObject);
  rb_define_method(cValues, "[]", rb_values_subscript, 1);
  rb_define_method(cValues, "each", rb_values_each, 0);
  rb_define_method(cValues, "length", rb_values_len, 0);
  rb_include_module(cValues, rb_const_get(rb_cObject, rb_intern("Enumerable")));
  
  cValue = rb_define_class_under(mEventedCache, "Value", rb_cObject);
  rb_define_method(cValue, "key", rb_value_key, 0);
  rb_define_method(cValue, "flags", rb_value_flags, 0);
  rb_define_method(cValue, "length", rb_value_len, 0);
  rb_define_method(cValue, "cas", rb_value_cas, 0);
  rb_define_method(cValue, "data", rb_value_data, 0);
}