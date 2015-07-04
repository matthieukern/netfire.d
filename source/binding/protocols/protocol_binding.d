module binding.protocols.protocol_binding;

public import core.vararg;
public import std.string;

public import ruby;

template rb_ProtocolBinding(Type, StructType, string attr) {
  import std.traits;

  public string rb_ProtocolBinding() {
    string ret = "
      static VALUE new_(int ac, VALUE* av, VALUE cl) {
        " ~ StructType.stringof ~ "* ptr = new " ~ StructType.stringof ~ ";
        VALUE tdata = Data_Wrap_Struct(cl, null, &free, ptr);
        rb_obj_call_init(tdata, ac, av);
        return tdata;
      }
    ";
    string classStaticCtor = "
      static VALUE singInst;
      static this() {
        singInst = rb_define_class(\"" ~ Type.stringof ~ "\", rb_cObject);
        rb_define_singleton_method(singInst, \"new\".toStringz, &new_, -1);
        rb_define_method(singInst, \"initialize\".toStringz, &initialize, -1);
    ";

    foreach(name; __traits(allMembers, Type)) {
      static if (__traits(getProtection, mixin("Type." ~ name)) == "public") {
        foreach(symbol; __traits(getOverloads, Type, name)) {
          static if (isCallable!symbol && (functionAttributes!symbol & FunctionAttribute.property)) {
            static if ((ParameterTypeTuple!symbol).length > 0) {
              static if (is(ParameterTypeTuple!symbol[0] == int) ||
                is(ParameterTypeTuple!symbol[0] == short) ||
                is(ParameterTypeTuple!symbol[0] == byte)) {
                ret ~= "static VALUE " ~ name ~ "_set(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  VALUE tmp = va_arg!VALUE(_argptr);
                  ptr." ~ attr ~ "." ~ name ~ " = cast(" ~ (ParameterTypeTuple!symbol[0]).stringof ~ ")rb_num2int(tmp);
                  return self;
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "=\".toStringz, &" ~ name ~ "_set, 1);\n";
              } else static if (is(ParameterTypeTuple!symbol[0] == uint) ||
                is(ParameterTypeTuple!symbol[0] == ushort) ||
                is(ParameterTypeTuple!symbol[0] == ubyte)) {
                ret ~= "static VALUE " ~ name ~ "_set(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  VALUE tmp = va_arg!VALUE(_argptr);
                  ptr." ~ attr ~ "." ~ name ~ " = cast(" ~ (ParameterTypeTuple!symbol[0]).stringof ~ ")rb_num2uint(tmp);
                  return self;
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "=\".toStringz, &" ~ name ~ "_set, 1);\n";
              } else static if (is(ParameterTypeTuple!symbol[0] == string)) {
                ret ~= "static VALUE " ~ name ~ "_set(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  VALUE tmp = va_arg!VALUE(_argptr);
                  ptr." ~ attr ~ "." ~ name ~ " = rb_string_value_cstr(&tmp);
                  return self;
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "=\".toStringz, &" ~ name ~ "_set, 1);\n";
              } else static if (is(ParameterTypeTuple!symbol[0] == ubyte[]) ||
                is(ParameterTypeTuple!symbol[0] == byte[])) {
                ret ~= "static VALUE " ~ name ~ "_set(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  VALUE tmp = va_arg!VALUE(_argptr);
                  VALUE val = rb_funcall(tmp, rb_intern(\"pack\"), 1, rb_str_new_cstr(\"c*\"));
                  ptr." ~ attr ~ "." ~ name ~ " = cast(" ~ (ParameterTypeTuple!symbol[0]).stringof ~ ")fromStringz(rb_string_value_cstr(&val));
                  return self;
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "=\".toStringz, &" ~ name ~ "_set, 1);\n";
              }
            } else {
              static if (is(ReturnType!symbol == int) ||
                is(ReturnType!symbol == short) ||
                is(ReturnType!symbol == byte)) {
                ret ~= "static VALUE " ~ name ~ "_get(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  return rb_int_new(ptr." ~ attr ~ "." ~ name ~ ");
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "\".toStringz, &" ~ name ~ "_get, 0);\n";
              } else static if (is(ReturnType!symbol == uint) ||
                is(ReturnType!symbol == ushort) ||
                is(ReturnType!symbol == ubyte)) {
                ret ~= "static VALUE " ~ name ~ "_get(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  return rb_uint_new(ptr." ~ attr ~ "." ~ name ~ ");
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "\".toStringz, &" ~ name ~ "_get, 0);\n";
              } else static if (is(ReturnType!symbol == string)) {
                ret ~= "static VALUE " ~ name ~ "_get(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  return rb_str_new_cstr(ptr." ~ attr ~ "." ~ name ~ ".toStringz);
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "\".toStringz, &" ~ name ~ "_get, 0);\n";
              } else static if (is(ReturnType!symbol == const(ubyte[]))) {
                ret ~= "static VALUE " ~ name ~ "_get(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  VALUE array = rb_ary_new();
                  foreach(ubyte b; ptr." ~ attr ~ "." ~ name ~ ") {
                    rb_ary_push(array, rb_int_new(b));
                  }
                  return array;
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "\".toStringz, &" ~ name ~ "_get, 0);\n";
              } else static if (is(ReturnType!symbol == const(byte[]))) {
                ret ~= "static VALUE " ~ name ~ "_get(VALUE self, ...) {
                  " ~ StructType.stringof ~ "* ptr = Data_Get_Struct!" ~ StructType.stringof ~ "(self);
                  VALUE array = rb_ary_new();
                  foreach(byte b; ptr." ~ attr ~ "." ~ name ~ ") {
                    rb_ary_push(array, rb_int_new(b));
                  }
                  return array;
                }";
                classStaticCtor ~= "rb_define_method(singInst, \"" ~ name ~ "\".toStringz, &" ~ name ~ "_get, 0);\n";
              }
            }
          }
        }
      }
    }
    classStaticCtor ~= "}";
    return ret ~ classStaticCtor;
  }
}
