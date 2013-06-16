#include "compiler/types/special.hpp"
#include "compiler/llvm_helper.hpp"

#include "shading/distribution.hpp"
#include "geometry/ray.hpp"

using namespace raytrace;
using namespace llvm;
using namespace std;

//Ray

Type *ray_type::llvm_type() const {
  Type *byte_type = Type::getInt8Ty(getGlobalContext());
  return ArrayType::get(byte_type, sizeof(ray));
}

//Intersection

Type *intersection_type::llvm_type() const {
  Type *byte_type = Type::getInt8Ty(getGlobalContext());
  return ArrayType::get(byte_type, sizeof(intersection));
}

//Light Source

Type *light_type::llvm_type() const {
  return Type::getInt32PtrTy(getGlobalContext());
}

//Distribution Object

dfunc_type::dfunc_type(type_table *types) :
  type(types, "dfunc", "dist")
{
  
}

Type *dfunc_type::llvm_type() const {
  Type *byte_type = Type::getInt8Ty(getGlobalContext());
  return ArrayType::get(byte_type, sizeof(shade_tree::node_ptr));
}

typed_value_container dfunc_type::initialize(Module *, IRBuilder<> &) const {
  return errors::make_error<errors::error_message>("No default initialization for distributions.", 0, 0);
}

Value *dfunc_type::copy(Value *value, Module *module, IRBuilder<> &builder) {
  Type *pointer_type = llvm_type()->getPointerTo();
  vector<Type*> arg_type({pointer_type, pointer_type});
  FunctionType *ty = FunctionType::get(Type::getVoidTy(getGlobalContext()), arg_type, false);
  Function *copy_f = cast<Function>(module->getOrInsertFunction("gd_builtin_copy_dfunc", ty));

  Value *val_ptr = CreateEntryBlockAlloca(builder, llvm_type(), "dfunc_src");
  builder.CreateStore(value, val_ptr, false);

  Value *copy = CreateEntryBlockAlloca(builder, llvm_type(), "dfunc_dst");
  builder.CreateCall2(copy_f, val_ptr, copy);
  return builder.CreateLoad(copy);
}

codegen_void dfunc_type::destroy(Value *value, Module *module, IRBuilder<> &builder) {
  vector<Type*> arg_type({llvm_type()->getPointerTo()});
  FunctionType *ty = FunctionType::get(Type::getVoidTy(getGlobalContext()), arg_type, false);
  Function *dtor = cast<Function>(module->getOrInsertFunction("gd_builtin_destroy_dfunc", ty));

  builder.CreateCall(dtor, value);
  return empty_type();
}

typed_value_container dfunc_type::create(Module *module, IRBuilder<> &builder,
					 typed_value_vector &args,
					 const type_conversion_table &conversions) const {
  boost::function<typed_value_container (vector<typed_value>&)> ctor = [this, module, &builder] (vector<typed_value> &args) -> typed_value_container {
    vector<Value*> shader_args;
    
    //ensure the argument types are {shader_handle, ray, vec2, isect}.
    vector<type_spec> expected_args({types->at("shader_handle"), types->at("ray"), types->at("vec2"), types->at("isect")});

    if (args.size() != 4) {
      stringstream err_ss;
      err_ss << "dfunc constructor expected 4 arguments, received " << args.size();
      return errors::make_error<errors::error_message>(err_ss.str(), 0, 0);
    }
    for (unsigned int i = 0; i < args.size(); ++i) {
      type_spec arg_ty = args[i].get<1>();
      if (*arg_ty != *expected_args[i]) {
	stringstream err_ss;
	err_ss << "Error in argument " << i << ": Expected type '" << expected_args[i]->name << "' found '" << arg_ty->name << "'";
	return errors::make_error<errors::error_message>(err_ss.str(), 0, 0);
      }
    }
    
    auto arg_it = args.begin();
    Value *shader_func = arg_it->get<0>().extract_value();
    ++arg_it;

    while (arg_it != args.end()) {
      shader_args.push_back(arg_it->get<0>().extract_value());
      ++arg_it;
    }

    return typed_value(builder.CreateCall(shader_func, shader_args), types->at("dfunc"));
  };

  return errors::codegen_call<typed_value_vector, typed_value_container>(args, ctor);
}

//Shader Handle

Type *shader_handle_type::llvm_type() const {
  vector<Type*> arg_ty({types->at("ray")->llvm_type(), types->at("vec2")->llvm_type(), types->at("isect")->llvm_type()});
  FunctionType *ft = FunctionType::get(types->at("dfunc")->llvm_type(), arg_ty, false);
  return ft->getPointerTo();
}

//Context Pointer

Type *context_ptr_type::llvm_type() const {
  return Type::getInt32PtrTy(getGlobalContext());
}
