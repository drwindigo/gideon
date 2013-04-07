%{
  
#include "compiler/ast/ast.hpp"
#include "compiler/parser.hpp"
#include "rtlparser.hpp"
#include "rtlscanner.hpp"
#include <iostream>
  
  using namespace raytrace;
  
  int yyerror(YYLTYPE *yylloc, yyscan_t scanner, ast::gideon_parser_data *gd_data, const char *msg) {
    std::cerr << "Parser Error: " << msg << std::endl;
    std::cerr << "Column: " << yylloc->first_column << std::endl;
  }
 %}

%locations

%define api.pure
%lex-param { void * scanner }
%parse-param { void *scanner }
%parse-param { ast::gideon_parser_data *gd_data }

%error-verbose

%code requires {
  #ifndef RT_PARSER_NODE_DEF
  #define RT_PARSER_NODE_DEF
  #include "compiler/ast/ast.hpp"
  
  typedef struct {
    int i;
    float f;
    std::string s;
    raytrace::type_spec tspec;

    std::vector<std::string> id_list;
    
    raytrace::ast::expression_ptr expr;
    std::vector<raytrace::ast::expression_ptr> expr_list;
    
    raytrace::ast::lvalue_ptr lval;
    
    raytrace::ast::statement_ptr stmt;
    std::vector<raytrace::ast::statement_ptr> stmt_list;
    
    raytrace::function_argument arg;
    std::vector<raytrace::function_argument> arg_list;
    raytrace::ast::prototype_ptr ptype;
    
    raytrace::ast::function_ptr func;
    
    raytrace::ast::global_declaration_ptr global;
    std::vector<raytrace::ast::global_declaration_ptr> global_list;
  } YYSTYPE;

  #endif
 }

//Define terminal symbols
%token <s> IDENTIFIER STRING_LITERAL
%token <i> INTEGER_LITERAL BOOL_LITERAL
%token <f> FLOAT_LITERAL
%token <tspec> FLOAT_TYPE INT_TYPE BOOL_TYPE VOID_TYPE STRING_TYPE
%token <tspec> RAY_TYPE INTERSECTION_TYPE
%token <tspec> FLOAT3_TYPE FLOAT4_TYPE SCENE_PTR_TYPE

%token <i> EXTERN
token <i> OUTPUT

%token <i> IF ELSE
%token <i> FOR
%token <i> BREAK CONTINUE
%token <i> RETURN

%token <i> IMPORT

//Operators
%right <i> '='
%left <i> '+'
%left <i> '<'
%left <i> '(' ')'

//Non-terminals
%type <global_list> rt_file
%type <global_list> global_declarations_opt global_declarations
%type <global> global_declaration

%type <id_list> identifier_list
%type <global> import_declaration

%type <func> function_definition
%type <ptype> function_prototype external_function_declaration
%type <arg_list> function_formal_params function_formal_params_opt
%type <arg> function_formal_param

%type <i> outputspec
%type <tspec> typespec
%type <tspec> simple_typename

%type <stmt_list> statement_list
%type <stmt> statement

%type <stmt> local_declaration variable_declaration
%type <stmt> conditional_statement scoped_statement

%type <stmt> loop_statement
%type <stmt> loop_mod_statement
%type <stmt> for_init_statement

%type <stmt> return_statement

%type <expr> expression binary_expression
%type <expr> assignment_expression variable_ref
%type <expr> type_constructor

%type <expr> function_call
%type <expr_list> function_args_opt function_args

%type <lval> variable_lvalue

%start rt_file

%%

/* Basic Structure */

rt_file : global_declarations_opt { *gd_data->globals = $1; } ;

global_declarations_opt
 : global_declarations
 | { } //empty
 ;

global_declarations
 : global_declaration { if ($1) $$ = std::vector<ast::global_declaration_ptr>(1, $1); }
 | global_declarations global_declaration { $$ = $1; if ($2) $$.push_back($2); } 
 ;

global_declaration
 : function_definition { $$ = $1; }
 | function_prototype ';' { $$ = $1; }
 | external_function_declaration { $$ = $1; }
 | typespec IDENTIFIER ';' { $$ = ast::global_declaration_ptr(new ast::global_variable_decl(gd_data->state, $2, $1)); }
 | import_declaration
 ;

identifier_list
 : IDENTIFIER { $$ = std::vector<std::string>(1, $1); }
 | identifier_list ',' IDENTIFIER { $$ = $1; $$.push_back($3); }
 ;

import_declaration
 : IMPORT identifier_list ';' { $$ = nullptr; gd_data->dependencies->insert(gd_data->dependencies->end(), $2.begin(), $2.end()); }
 ;

/** Functions **/

function_prototype
 : typespec IDENTIFIER '(' function_formal_params_opt ')' { $$ = ast::prototype_ptr(new ast::prototype(gd_data->state, $2, $1, $4)); }
 ;

external_function_declaration
 : EXTERN function_prototype ':' IDENTIFIER ';' { $$ = $2; $$->set_external($4); }
 ;

function_definition
 : function_prototype '{' statement_list '}' { $$ = ast::function_ptr(new ast::function(gd_data->state, $1, ast::statement_list($3))); }
 ;

function_formal_params_opt
 : function_formal_params
 | { } //empty
 ;

function_formal_params
 : function_formal_param { $$ = std::vector<function_argument>(1, $1); }
 | function_formal_params ',' function_formal_param { $$ = $1; $$.push_back($3); }
 ;

function_formal_param
 : outputspec typespec IDENTIFIER { $$ = {$3, $2, ($1 ? true :false)}; }
 ;

outputspec
 : OUTPUT { $$ = 1; }
 | { $$ = 0; }
 ;

simple_typename
 : FLOAT_TYPE { $$ = gd_data->state->types["float"]; }
 | FLOAT3_TYPE { $$ = gd_data->state->types["vec3"]; }
 | FLOAT4_TYPE { $$ = gd_data->state->types["vec4"]; }

 | SCENE_PTR_TYPE { $$ = gd_data->state->types["scene_ptr"]; }
 | RAY_TYPE { $$ = gd_data->state->types["ray"]; }
 | INTERSECTION_TYPE { $$ = gd_data->state->types["isect"]; }

 | INT_TYPE { $$ = gd_data->state->types["int"]; }
 | BOOL_TYPE { $$ = gd_data->state->types["bool"]; }
 | STRING_TYPE { $$ = gd_data->state->types["string"]; }
 | VOID_TYPE { $$ = gd_data->state->types["void"]; }
;

typespec
 : simple_typename
 ;


/* Statements */

statement_list
 : statement_list statement { $$ = $1; if ($2) $$.push_back($2); }
 | { }
 ;

statement
 : scoped_statement
 | conditional_statement
 | local_declaration
 | loop_statement
 | loop_mod_statement
 | return_statement
 | expression ';' { $$ = ast::statement_ptr(new ast::expression_statement(gd_data->state, $1)); }
 | ';' { $$ = nullptr; }
 ;

scoped_statement
 : '{' statement_list '}' { $$ = ast::statement_ptr(new ast::scoped_statement(gd_data->state, $2)); }
 ;

conditional_statement
 : IF '(' expression ')' statement { $$ = ast::statement_ptr(new ast::conditional_statement(gd_data->state, $3, $5, nullptr)); }
 | IF '(' expression ')' statement ELSE statement { $$ = ast::statement_ptr(new ast::conditional_statement(gd_data->state, $3, $5, $7)); }
 ;

loop_mod_statement
 : BREAK ';' { $$ = ast::statement_ptr(new ast::break_statement(gd_data->state)); }
 | CONTINUE ';' { $$ = ast::statement_ptr(new ast::continue_statement(gd_data->state)); }
 ;

loop_statement
 : FOR '(' for_init_statement expression ';' expression ')' statement { $$ = ast::statement_ptr(new ast::for_loop_statement(gd_data->state, $3, $4, $6, $8)); }
 ;

for_init_statement
 : variable_declaration
 | expression ';' { $$ = ast::statement_ptr(new ast::expression_statement(gd_data->state, $1)); }
 | ';' { $$ = nullptr; }
 ;

local_declaration
 : variable_declaration
 ;

variable_declaration
 : typespec IDENTIFIER '=' expression ';' { $$ = ast::statement_ptr(new ast::variable_decl(gd_data->state, $2, $1, $4)); }
 | typespec IDENTIFIER ';' { $$ = ast::statement_ptr(new ast::variable_decl(gd_data->state, $2, $1, nullptr)); }
 ;


return_statement
 : RETURN expression ';' { $$ = ast::statement_ptr(new ast::return_statement(gd_data->state, $2)); }
 | RETURN ';' { $$ = ast::statement_ptr(new ast::return_statement(gd_data->state, nullptr)); }
 ;

expression
 : INTEGER_LITERAL { $$ = ast::expression_ptr(new ast::literal<int>(gd_data->state, $1)); }
 | FLOAT_LITERAL { $$ = ast::expression_ptr(new ast::literal<float>(gd_data->state, $1)); }
 | BOOL_LITERAL { $$ = ast::expression_ptr(new ast::literal<bool>(gd_data->state, $1)); }
 | STRING_LITERAL { $$ = ast::expression_ptr(new ast::literal<std::string>(gd_data->state, $1)); }
 | assignment_expression
 | binary_expression
 | type_constructor
 | function_call
 | '(' expression ')' { $$ = $2; }
 | variable_ref
 ;

assignment_expression
 : variable_lvalue '=' expression { $$ = ast::expression_ptr(new ast::assignment(gd_data->state, $1, $3)); }
 ;

type_constructor
 : typespec '(' function_args_opt ')' { $$ = ast::expression_ptr(new ast::type_constructor(gd_data->state, $1, $3)); }
 ;

variable_lvalue
 : IDENTIFIER { $$ = ast::lvalue_ptr(new ast::variable_lvalue(gd_data->state, $1)); }
 ;

variable_ref
 : variable_lvalue { $$ = ast::expression_ptr(new ast::variable_ref(gd_data->state, $1)); }
 ;

function_call
 : IDENTIFIER '(' function_args_opt ')' { $$ = ast::expression_ptr(new ast::func_call(gd_data->state, $1, $3)); }
 ;

function_args_opt
 : function_args
 | { }
 ;

function_args
 : function_args ',' expression { $$ = $1; $$.push_back($3); }
 | expression { $$ = std::vector<ast::expression_ptr>(1, $1); }
 ;

binary_expression
 : expression '+' expression { $$ = ast::expression_ptr(new ast::binary_expression(gd_data->state, "+", $1, $3)); }
 | expression '<' expression { $$ = ast::expression_ptr(new ast::binary_expression(gd_data->state, "<", $1, $3)); }
 ;

%%

