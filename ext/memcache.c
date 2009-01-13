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

static ID cGetId;
static ID cSetId;
static ID cDeleteId;
static ID cIncId;
static ID cStatsId;
static ID cFlushAllId;
static ID cVersionId;

static ID cValuesId;
static ID cStoredId;
static ID cNotStoredId;
static ID cExistsId;
static ID cNotFoundId;
static ID cDeletedId;
static ID cIncValueId;
static ID cOkId;

static VALUE rb_memcache_protocol_reset(VALUE self) {
  protocol_t *protocol;
  Data_Get_Struct(self, protocol_t, protocol);
  
  memcache_protocol_reset(protocol);
  return Qnil;
}

static void rb_memcache_protocol_free(void *ptr) {
  //will need to recursively free all of the bullshit associated with this
  dprintf("entering free\n");
  protocol_t *protocol = (protocol_t *)ptr;
  memcache_protocol_free(protocol);
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

static VALUE rb_memcache_protocol_is_finished(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return memcache_protocol_is_finished(protocol) ? Qtrue : Qfalse;
}

static VALUE rb_memcache_protocol_is_start_state(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return memcache_protocol_is_start_state(protocol) ? Qtrue : Qfalse;
}

static VALUE rb_memcache_protocol_execute(VALUE self, VALUE data) {
  protocol_t *protocol = NULL;
  int cs;
  char * msg;
  Data_Get_Struct(self, protocol_t, protocol);
  dprintf("executing with data '%s'\n", RSTRING(data)->ptr);
  cs = memcache_protocol_execute(protocol, RSTRING(data)->ptr, RSTRING(data)->len, 0);
  if (memcache_protocol_has_error(protocol)) {
    rb_raise(cProtocolError, "Memcache protocol encountered an error with char '%c' at pos %d", protocol->err_char, protocol->err_pos);
  } else {
    switch (protocol->type) {
      case SERVER_ERROR:
        rb_raise(cServerError, protocol->error);
      case CLIENT_ERROR:
        rb_raise(cClientError, protocol->error);
      case ERROR:
        rb_raise(cCommandError, "Memcache returned a command error.\n");
    }
    return rb_memcache_protocol_is_finished(self);
  }
}

static VALUE rb_memcache_protocol_setmode(VALUE self, VALUE mode) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  int code = 0;
  ID mode_id = SYM2ID(mode);
  if (cGetId == mode_id){ code = memcache_protocol_get(); }
  else if (cSetId == mode_id){ code = memcache_protocol_set(); }
  else if (cDeleteId == mode_id) { code = memcache_protocol_delete(); }
  else if (cIncId == mode_id) { code = memcache_protocol_inc(); }
  else if (cStatsId == mode_id) { code = memcache_protocol_stats(); }
  else if (cFlushAllId == mode_id) { code = memcache_protocol_flush_all(); }
  else if (cVersionId == mode_id) { code = memcache_protocol_version(); }
  
  memcache_protocol_mode(protocol, code);
}

static VALUE rb_memcache_protocol_has_error(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return memcache_protocol_has_error(protocol) ? Qtrue : Qfalse;
}

static VALUE rb_memcache_protocol_type(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  switch(protocol->type) {
    case VALUES:
      return ID2SYM(cValuesId);
    case STORED:
      return ID2SYM(cStoredId);
    case NOT_STORED:
      return ID2SYM(cNotStoredId);
    case EXISTS:
      return ID2SYM(cExistsId);
    case NOT_FOUND:
      return ID2SYM(cNotFoundId);
    case DELETED:
      return ID2SYM(cDeletedId);
    case INC_VALUE:
      return ID2SYM(cIncValueId);
    case STATS:
      return ID2SYM(cStatsId);
    case OK:
      return ID2SYM(cOkId);
    case VERSION:
      return ID2SYM(cVersionId);
  }
  return Qnil;
}

static VALUE rb_memcache_protocol_values(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return Data_Wrap_Struct(cValues, NULL, rb_null_free, &protocol->values);
}

static VALUE rb_memcache_protocol_stats(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  VALUE hash = rb_hash_new();
  int i;
  
  for(i=0;i<protocol->stats.len; i++) {
    VALUE key, value;
    stat_t* stat = &protocol->stats.array[i];
    key = (stat->key) ? rb_str_new2(stat->key) : ULONG2NUM(stat->num_key);
    value = (stat->string_val) ? rb_str_new2(stat->string_val) : ULONG2NUM(stat->num_val);
    rb_hash_aset(hash, key, value);
  }
  
  return hash;
}

static VALUE rb_memcache_protocol_version(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  if (protocol->version) {
    return rb_str_new2(protocol->version);
  } else {
    return Qnil;
  }
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

static VALUE rb_memcache_protocol_inc_value(VALUE self) {
  protocol_t *protocol = NULL;
  Data_Get_Struct(self, protocol_t, protocol);
  
  return LONG2FIX(protocol->value);
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
  
  cGetId = rb_intern("get");
  cSetId = rb_intern("set");
  cDeleteId = rb_intern("delete");
  cIncId = rb_intern("inc");
  cStatsId = rb_intern("stats");
  cFlushAllId = rb_intern("flush_all");
  cVersionId = rb_intern("version");
  
  cValuesId = rb_intern("values");
  cStoredId = rb_intern("stored");
  cNotStoredId = rb_intern("not_stored");
  cExistsId = rb_intern("exists");
  cNotFoundId = rb_intern("not_found");
  cDeletedId = rb_intern("deleted");
  cIncValueId = rb_intern("inc_value");
  cOkId = rb_intern("ok");
  
  cMemcacheProtocol = rb_define_class_under(mEventedCache, "MemcacheProtocol", rb_cObject);
  rb_define_alloc_func(cMemcacheProtocol, rb_memcache_protocol_alloc);
  rb_define_method(cMemcacheProtocol, "mode=", rb_memcache_protocol_setmode,1);
  rb_define_method(cMemcacheProtocol, "execute", rb_memcache_protocol_execute,1);
  rb_define_method(cMemcacheProtocol, "error?", rb_memcache_protocol_has_error,0);
  rb_define_method(cMemcacheProtocol, "type", rb_memcache_protocol_type,0);
  rb_define_method(cMemcacheProtocol, "finished?", rb_memcache_protocol_is_finished,0);
  rb_define_method(cMemcacheProtocol, "start_state?", rb_memcache_protocol_is_start_state,0);
  rb_define_method(cMemcacheProtocol, "reset!", rb_memcache_protocol_reset,0);
  rb_define_method(cMemcacheProtocol, "values", rb_memcache_protocol_values,0);
  rb_define_method(cMemcacheProtocol, "stats", rb_memcache_protocol_stats,0);
  rb_define_method(cMemcacheProtocol, "version", rb_memcache_protocol_version,0);
  rb_define_method(cMemcacheProtocol, "inc_value", rb_memcache_protocol_inc_value,0);
  
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