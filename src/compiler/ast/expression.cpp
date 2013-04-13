#include "compiler/ast/expression.hpp"
#include "compiler/operations.hpp"

#include <iostream>

using namespace std;
using namespace raytrace;
using namespace llvm;

/** Expression Base **/

codegen_value raytrace::ast::expression::codegen_ptr(Module *module, IRBuilder<> &builder) {
  return compile_error("Cannot convert expression to lvalue");
}

typecheck_value ast::expression::typecheck_safe() {
  try { return typecheck(); }
  catch (compile_error &e) { return e; }
}

typed_value_container ast::expression::codegen_safe(llvm::Module *module, llvm::IRBuilder<> &builder) {
  typecheck_value type = typecheck_safe();
  codegen_value val = codegen(module, builder);
  return errors::combine_arg_list(val, type);
}

/** Binary Expression **/

raytrace::ast::binary_expression::binary_expression(parser_state *st, const string &op, const expression_ptr &lhs, const expression_ptr &rhs,
						    unsigned int line_no, unsigned int column_no) :
  expression(st, line_no, column_no), op(op), lhs(lhs), rhs(rhs)
{
  
}

raytrace::type_spec raytrace::ast::binary_expression::typecheck() {
  try {
    if (op == "+" || op == "*") return get_add_result_type(lhs, rhs);
    if (op == "-" || op == "/") return get_sub_result_type(lhs, rhs);
    if (op == "<") return state->types["bool"];
  }
  catch (compile_error &e) {
    stringstream tagged;
    tagged << "Error on line " << line_no << ":" << column_no << " - " << e.what();
    throw compile_error(tagged.str());
  }
}

codegen_value raytrace::ast::binary_expression::codegen(Module *module, IRBuilder<> &builder) {
  try {
    if (op == "+") return generate_add(lhs, rhs, state->types, module, builder);
    if (op == "-") return generate_sub(lhs, rhs, state->types, module, builder);
    if (op == "*") return generate_mul(lhs, rhs, state->types, module, builder);
    if (op == "/") return generate_div(lhs, rhs, state->types, module, builder);
    if (op == "<") return generate_less_than(lhs, rhs, state->types, module, builder);
    return compile_error("Unsupported binary operation");
  }
  catch (compile_error &e) { return e; }
}

