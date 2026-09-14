%{
/* Analisador Sintático, Semântico e Gerador de Código Intermediário */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();

extern int yylineno;
extern int column;
extern int lexical_error;
extern char *yytext;

extern FILE *yyin;

int syntax_error = 0;
int semantic_error = 0;

void yyerror(const char *s);
void syntax_error_msg_bef(const char *msg);
void print_symbol_table();

FILE *out = NULL;


/* ---------------- ESTRUTURAS DA ÁRVORE SINTÁTICA ABSTRATA (AST) -------------*/                           

typedef enum {
    AST_VAR_DECL, AST_FUNC_DECL, AST_TYPE,
    AST_PARAM, AST_COMPOUND, AST_IF, AST_WHILE, AST_PRINT, AST_READ,
    AST_RETURN, AST_ASSIGN, AST_BINOP, AST_UNOP, AST_ID, AST_INT, AST_FLOAT,
    AST_FUNC_CALL
} ASTNodeType;

typedef struct ASTNode {
    ASTNodeType type;
    char *lexema;
    int int_val;
    float float_val;
    
    int line;    
    int column;
    char exp_type[20]; 
    char temp[20];     
    
    struct ASTNode *child1;
    struct ASTNode *child2;
    struct ASTNode *child3;
    struct ASTNode *child4;
    struct ASTNode *next;
} ASTNode;

ASTNode *root = NULL;

ASTNode* create_node(ASTNodeType type, ASTNode *c1, ASTNode *c2, ASTNode *c3, ASTNode *c4) {
    ASTNode *n = (ASTNode*)malloc(sizeof(ASTNode));
    n->type = type;
    n->lexema = NULL;
    n->int_val = 0;
    n->float_val = 0.0;
    
    // Se tiver um primeiro filho, herda a linha/coluna dele
    if (c1) {
        n->line = c1->line;
        n->column = c1->column;
    } else {
        n->line = yylineno; 
        n->column = column;
    }
    
    n->child1 = c1;
    n->child2 = c2;
    n->child3 = c3;
    n->child4 = c4;
    n->next = NULL;
    return n;
}

ASTNode* create_leaf_id(char *lex, int line, int col) {
    ASTNode *n = (ASTNode*)malloc(sizeof(ASTNode));
    n->type = AST_ID;
    // Evita Segfault se o lexer.l não mandar a string
    n->lexema = lex ? strdup(lex) : strdup("UNKNOWN_ID");
    n->line = line;
    n->column = col;
    n->child1 = n->child2 = n->child3 = n->child4 = n->next = NULL;
    return n;
}

ASTNode* create_leaf_int(int val, int line, int col) {
    ASTNode *n = (ASTNode*)malloc(sizeof(ASTNode));
    n->type = AST_INT;
    n->int_val = val;
    n->line = line;
    n->column = col;
    n->child1 = n->child2 = n->child3 = n->child4 = n->next = NULL;
    return n;
}

ASTNode* create_leaf_float(float val, int line, int col) {
    ASTNode *n = (ASTNode*)malloc(sizeof(ASTNode));
    n->type = AST_FLOAT;
    n->float_val = val;
    n->line = line;
    n->column = col;
    n->child1 = n->child2 = n->child3 = n->child4 = n->next = NULL;
    return n;
}

%}

%define parse.error detailed
%locations

%union {
    int ival;
    float fval;
    char *str;
    struct ASTNode *node;
}

/* ------------------------ TOKENS -------------------------- */

%token KW_INT KW_FLOAT
%token KW_IF KW_ELSE KW_WHILE
%token KW_PRINT KW_READ KW_RETURN
%token <str> ID
%token <ival> INTNUM
%token <fval> FLOATNUM
%token LT GT LE GE EQ NE
%token AND OR NOT
%token PLUS MINUS MULT DIV MOD
%token ASSIG
%token SEMCOL COMMA
%token LPAREN RPAREN LBRACE RBRACE

%type <node> program declaration_list declaration variable_declaration type_specifier function_declaration function_body local_declarations statements statement expression_stmt expression selection_stmt iteration_stmt io_stmt return_stmt statement_list compound_stmt parameters parameter_list parameter variable_list variable function_call arguments argument_list

/* ---------------- PRECEDÊNCIA ---------------- */

%nonassoc LOWER_THAN_ELSE
%nonassoc KW_ELSE

%right ASSIG
%left OR
%left AND
%left EQ NE
%left LT GT LE GE
%left PLUS MINUS
%left MULT DIV MOD
%right NOT
%right UMINUS

%%


/* ------------------ GRAMÁTICA E CONSTRUÇÃO DA AST ------------------------- */

program
    : declaration_list 		{ root = $1; $$ = $1; }
    ;

declaration_list
    : declaration_list declaration
    {
         if ($1 != NULL) {
           ASTNode *t = $1;
           while (t->next != NULL) t = t->next;
           t->next = $2;
           $$ = $1;
         } else { $$ = $2; }
    }
    | declaration_list error SEMCOL 	{ yyerrok; $$ = $1; }
    | declaration_list error RBRACE 	{ yyerrok; $$ = $1; }
    | declaration 			{ $$ = $1; }
    ;

declaration
    : variable_declaration 	{ $$ = $1; }
    | function_declaration 	{ $$ = $1; }
    ;

variable_declaration
    : type_specifier variable_list SEMCOL 	{ $$ = create_node(AST_VAR_DECL, $1, $2, NULL, NULL); }
    | type_specifier error SEMCOL 		{ syntax_error_msg_bef("Invalid variable declaration"); yyerrok; $$ = NULL; }
    ;

variable_list
    : variable_list COMMA variable
    {
        ASTNode *t = $1;
        while (t->next != NULL) t = t->next;
        t->next = $3;
        $$ = $1;
    }
    | variable		 { $$ = $1; }
    ;

variable
    : ID 	{ $$ = create_leaf_id($1, @1.first_line, @1.first_column); }
    | ID ASSIG expression
    {
        ASTNode *id_node = create_leaf_id($1, @1.first_line, @1.first_column);
        $$ = create_node(AST_ASSIGN, id_node, $3, NULL, NULL);
    }
    ;

type_specifier
    : KW_INT 		{ $$ = create_node(AST_TYPE, NULL, NULL, NULL, NULL); $$->lexema = strdup("int"); }
    | KW_FLOAT 		{ $$ = create_node(AST_TYPE, NULL, NULL, NULL, NULL); $$->lexema = strdup("float"); }
    ;

function_declaration
    : type_specifier ID LPAREN parameters RPAREN function_body
    {
        ASTNode *id_node = create_leaf_id($2, @2.first_line, @2.first_column);
        $$ = create_node(AST_FUNC_DECL, $1, id_node, $4, $6);
    }
    | type_specifier ID LPAREN parameters error function_body
    {
        syntax_error_msg_bef("Missing ')'");
        ASTNode *id_node = create_leaf_id($2, @2.first_line, @2.first_column);
        $$ = create_node(AST_FUNC_DECL, $1, id_node, $4, $6);
    }
    ;

parameters
    : parameter_list { $$ = $1; }
    | /* vazio */    { $$ = NULL; }
    ;

parameter_list
    : parameter_list COMMA parameter
    {
        ASTNode *t = $1;
        while (t->next != NULL) t = t->next;
	t->next = $3;
        $$ = $1;
    }
    | parameter { $$ = $1; }
    ;

parameter
    : type_specifier ID 
    { 
        ASTNode *id_node = create_leaf_id($2, @2.first_line, @2.first_column); 
        $$ = create_node(AST_PARAM, $1, id_node, NULL, NULL); 
    }
    ;

function_body
    : LBRACE local_declarations statements return_stmt RBRACE	{ $$ = create_node(AST_COMPOUND, $2, $3, $4, NULL); }
    | LBRACE local_declarations return_stmt RBRACE		{ $$ = create_node(AST_COMPOUND, $2, NULL, $3, NULL); }
    | LBRACE local_declarations statements RBRACE 		{ syntax_error = 1; fprintf(stderr, "\n[SYNTAX ERROR] Missing 'return'\n\n"); $$ = create_node(AST_COMPOUND, $2, $3, NULL, NULL); }
    | LBRACE local_declarations RBRACE 				{ syntax_error = 1; fprintf(stderr, "\n[SYNTAX ERROR] Missing 'return'\n\n"); $$ = create_node(AST_COMPOUND, $2, NULL, NULL, NULL); }
    ;

local_declarations
    : local_declarations variable_declaration
    {
        if ($1 != NULL) {
            ASTNode *t = $1;
            while (t->next != NULL) t = t->next;
            t->next = $2;
            $$ = $1;
        } else { $$ = $2; }
    }
    | /* vazio */ { $$ = NULL; }
    ;

statements
    : statements statement
    {
    	 if ($1 != NULL) {
              ASTNode *t = $1;
              while (t->next != NULL) t = t->next;
              t->next = $2;
              $$ = $1;
          } else { $$ = $2; }
    }
    | statement 	{ $$ = $1; }
    ;

statement
    : expression_stmt	{ $$ = $1; }
    | compound_stmt 	{ $$ = $1; }
    | selection_stmt 	{ $$ = $1; }
    | iteration_stmt 	{ $$ = $1; }
    | io_stmt 		{ $$ = $1; }
    | error SEMCOL 	{ syntax_error_msg_bef("Invalid command"); yyerrok; $$ = NULL; }
    ;

return_stmt
    : KW_RETURN expression SEMCOL 	{ $$ = create_node(AST_RETURN, $2, NULL, NULL, NULL); }
    | KW_RETURN SEMCOL 			{ $$ = create_node(AST_RETURN, NULL, NULL, NULL, NULL); }
    ;

compound_stmt
    : LBRACE local_declarations statement_list RBRACE 	{ $$ = create_node(AST_COMPOUND, $2, $3, NULL, NULL); }
    ;

statement_list
    : statements  	{ $$ = $1; }
    | statements return_stmt
      {
          if ($1 != NULL) {
              ASTNode *t = $1;
              while (t->next != NULL) t = t->next;
              t->next = $2;
              $$ = $1;
          } else { $$ = $2; }
      }
    | return_stmt 	{ $$ = $1; }
    | /* vazio */ 	{ $$ = NULL; }
    ;

expression_stmt
    : expression SEMCOL { $$ = $1; }
    | SEMCOL 		{ $$ = NULL; }
    ;

selection_stmt
    : KW_IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE 	{ $$ = create_node(AST_IF, $3, $5, NULL, NULL); }
    | KW_IF LPAREN expression RPAREN statement KW_ELSE statement 	{ $$ = create_node(AST_IF, $3, $5, $7, NULL); }
    ;

iteration_stmt
    : KW_WHILE LPAREN expression RPAREN statement 	{ $$ = create_node(AST_WHILE, $3, $5, NULL, NULL); }
    ;

io_stmt
    : KW_PRINT LPAREN expression RPAREN SEMCOL 		{ $$ = create_node(AST_PRINT, $3, NULL, NULL, NULL); }
    | KW_READ LPAREN ID RPAREN SEMCOL 			{ ASTNode *id_node = create_leaf_id($3, @3.first_line, @3.first_column); $$ = create_node(AST_READ, id_node, NULL, NULL, NULL); }
    ;

expression
    : ID ASSIG expression         	{ ASTNode *id_node = create_leaf_id($1, @1.first_line, @1.first_column); $$ = create_node(AST_ASSIGN, id_node, $3, NULL, NULL); }
    | expression PLUS expression  	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("+"); }
    | expression MINUS expression 	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("-"); }
    | expression MULT expression  	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("*"); }
    | expression DIV expression   	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("/"); }
    | expression MOD expression   	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("%"); }
    | expression LT expression    	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("<"); }
    | expression GT expression    	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup(">"); }
    | expression LE expression    	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("<="); }
    | expression GE expression    	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup(">="); }
    | expression EQ expression    	{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("=="); }
    | expression NE expression		{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("!="); }
    | expression AND expression		{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("&&"); }
    | expression OR expression		{ $$ = create_node(AST_BINOP, $1, $3, NULL, NULL); $$->lexema = strdup("||"); }
    | NOT expression          		{ $$ = create_node(AST_UNOP, $2, NULL, NULL, NULL); $$->lexema = strdup("!"); $$->line = @1.first_line; $$->column = @1.first_column;}
    | MINUS expression %prec UMINUS 	{ $$ = create_node(AST_UNOP, $2, NULL, NULL, NULL); $$->lexema = strdup("minus"); $$->line = @1.first_line; $$->column = @1.first_column;}
    | LPAREN expression RPAREN 		{ $$ = $2; }
    | ID 				{ $$ = create_leaf_id($1, @1.first_line, @1.first_column); }
    | INTNUM 				{ $$ = create_leaf_int($1, @1.first_line, @1.first_column); }
    | FLOATNUM 				{ $$ = create_leaf_float($1, @1.first_line, @1.first_column); }
    | function_call 			{ $$ = $1; }
    ;

function_call
    : ID LPAREN arguments RPAREN 
    { 
    	ASTNode *id_node = create_leaf_id($1, @1.first_line, @1.first_column);
    	$$ = create_node(AST_FUNC_CALL, id_node, $3, NULL, NULL); 
    }
    ;

arguments
    : argument_list 	{ $$ = $1; }
    | /* vazio */ 	{ $$ = NULL; }
    ;

argument_list
    : argument_list COMMA expression
      {
          ASTNode *t = $1;
          while (t->next != NULL) t = t->next;
          t->next = $3;
          $$ = $1;
      }
    | expression { $$ = $1; }
    ;

%%                                                  

void yyerror(const char *s) {
    if (strstr(s, "expecting ';'") || strstr(s, "expecting SEMCOL")) { syntax_error_msg_bef("Expected ';'"); return; }
    if (strstr(s, "expecting ')'") || strstr(s, "expecting RPAREN")) { syntax_error_msg_bef("Expected ')'"); return; }
    if (strstr(s, "expecting '('") || strstr(s, "expecting LPAREN")) { syntax_error_msg_bef("Expected '('"); return; }
    if (strstr(s, "expecting '}'") || strstr(s, "expecting RBRACE")) { syntax_error_msg_bef("Expected '}'"); return; }
    if (strstr(s, "expecting '{'") || strstr(s, "expecting LBRACE")) { syntax_error_msg_bef("Expected '{'"); return; }
    if (strstr(s, "expecting ID")) { syntax_error_msg_bef("Expected identifier"); return; }
    syntax_error_msg_bef("Unexpected token");
}

void syntax_error_msg_bef(const char *msg) {
    syntax_error = 1;
    fprintf(stderr, "\n[SYNTAX ERROR] %s at Line %d, Column %d\n\n", msg, yylineno, column);
}


/* ---------------------------- TABELA DE SÍMBOLOS --------------------------------- */


#define MAX_SCOPES 100

typedef struct Symbol {
    char name[50];
    char type[20];
    char category[20];
    int num_params;
    char param_types[10][20];
    struct Symbol *next;
} Symbol;

typedef struct SymbolTable {
    int table_id;               
    int scope_level;            // Profundidade (0=Global, 1=Função, etc)
    Symbol *symbols;
    struct SymbolTable *parent; 
} SymbolTable;

SymbolTable *current_table = NULL;
SymbolTable *all_tables[200];  // Histórico de todas as tabelas criadas
int total_tables_created = 0;

char current_func_type[20] = "";
int is_function_body = 1;

void open_scope() {
    SymbolTable *new_table = (SymbolTable*)malloc(sizeof(SymbolTable));
    new_table->symbols = NULL;
    new_table->parent = current_table;
    new_table->table_id = total_tables_created;
    if (current_table) {
        new_table->scope_level = current_table->scope_level + 1;
    } else {
        new_table->scope_level = 0;
    }
    
    current_table = new_table;
    all_tables[total_tables_created] = new_table;   // Guarda no histórico
    total_tables_created++;
}

void close_scope() {
    if (!current_table) return;
    // Volta para o pai, mantendo a tabela no histórico
    current_table = current_table->parent;
}

int add_symbol(const char *name, const char *type, const char *category) {
    if (!name || !current_table) return 0;
    // Verifica se a variável já existe no escopo atual
    Symbol *s = current_table->symbols;
    while (s) {
        if (strcmp(s->name, name) == 0) return 0; // Erro de redeclaração
        s = s->next;
    }
    
    // Cria e insere o símbolo no início da lista da tabela atual
    Symbol *ns = (Symbol*)malloc(sizeof(Symbol));
    strcpy(ns->name, name);
    strcpy(ns->type, type);
    strcpy(ns->category, category);
    ns->num_params = 0;
    
    ns->next = current_table->symbols;
    current_table->symbols = ns;
    
    return 1;
}

Symbol* lookup_symbol(const char *name) {
    if (!name) {
    	return NULL;
    }

    SymbolTable *table = current_table;
    while (table != NULL) {
        Symbol *s = table->symbols;
        while (s) {
            if (strcmp(s->name, name) == 0) {
            	return s; // Encontrou
            }
            s = s->next;
        }
        // Se não achou neste escopo, sobe para a tabela pai
        table = table->parent;
    }
    return NULL; // Se chegou à tabela Global e não achou, a variável não existe
}


void print_symbol_table() {
    printf("\n======================================================================================================\n");
    printf("                                      FINAL SYMBOL TABLES DUMP\n");
    printf("======================================================================================================\n");
    
    for (int i = 0; i < total_tables_created; i++) {
        SymbolTable *table = all_tables[i];
        printf("\n======================================================================================================\n");
        if (table->parent) {
            printf("            TABLE ID: %d  |  SCOPE LEVEL: %d  |  PARENT ID: %d (Level %d)\n", 
                   table->table_id, table->scope_level, table->parent->table_id, table->parent->scope_level);
        }
        else {
            printf("            TABLE ID: %d  |  SCOPE LEVEL: %d  |  PARENT ID: NULL (GLOBAL)\n", 
                   table->table_id, table->scope_level);
        }
        printf("======================================================================================================\n");
        
        printf("%-15s | %-10s | %-10s | %-10s | %-20s | %-15s\n", 
               "NAME", "TYPE", "CATEGORY", "NUM_PARAMS", "PARAM_TYPES", "NEXT SYMBOL");
        printf("------------------------------------------------------------------------------------------------------\n");
        
        Symbol *s = table->symbols;
        if (!s) {
            printf("  (Empty Table)\n");
        } else {
            while (s) {
                char params_str[100] = "";
                if (strcmp(s->category, "func") == 0 && s->num_params > 0) {
                    for (int p = 0; p < s->num_params; p++) {
                        strcat(params_str, s->param_types[p]);
                        if (p < s->num_params - 1) {
                        	strcat(params_str, ", ");
                        }
                    }
                } else {
                    strcpy(params_str, "-");
                }
                
                char next_name[50];
                if (s->next) {
                	strcpy(next_name, s->next->name);
                }
                else {
                	strcpy(next_name, "NULL");
                }
                
                int num_p = (strcmp(s->category, "func") == 0) ? s->num_params : 0;
                printf("%-15s | %-10s | %-10s | %-10d | %-20s | %-15s\n",
                       s->name, s->type, s->category, num_p, params_str, next_name);
                s = s->next;
            }
        }
    }
    printf("\n");
}

char* verificar_semantica(ASTNode *node) {
    if (!node) 
        return "void";
        
    switch (node->type) {
        case AST_VAR_DECL: {
            char *decl_type = node->child1->lexema;
            ASTNode *var = node->child2; 
            while (var) {
                if (var->type == AST_ID) {
                    if (!add_symbol(var->lexema, decl_type, "var")) {
                        fprintf(stderr, "[SEMANTIC ERROR] Variable '%s' redeclared in same scope at Line %d, Column %d.\n", var->lexema, var->line, var->column);
                        semantic_error = 1;
                    }
                } else if (var->type == AST_ASSIGN) {
                    char *vname = var->child1->lexema;
                    if (!add_symbol(vname, decl_type, "var")) {
                        // Aponta para a variável (child1) e não para a atribuição
                        fprintf(stderr, "[SEMANTIC ERROR] Variable '%s' redeclared in same scope at Line %d, Column %d.\n", vname, var->child1->line, var->child1->column);
                        semantic_error = 1;
                    }
                    
                    // Validação de tipo na inicialização
                    char *rtype = verificar_semantica(var->child2);
                    if (strcmp(decl_type, "int") == 0 && strcmp(rtype, "float") == 0) {
                        // Aponta para a variável que está recebendo o valor errado (child2)
                        fprintf(stderr, "[SEMANTIC ERROR] Type mismatch in initialization: cannot assign 'float' to 'int' variable '%s' at Line %d, Column %d.\n", vname, var->child2->line, var->child2->column);
                        semantic_error = 1;
                    }
                }
                var = var->next;
            }
            return "void";
        }
        
       case AST_FUNC_DECL: {
            char *ret_type = node->child1->lexema;
            char *fname = node->child2->lexema;
            strcpy(current_func_type, ret_type);

            if (strcmp(ret_type, "int") != 0 && strcmp(ret_type, "float") != 0) {
                // Aponta para o tipo de retorno que está errado (child1)
                fprintf(stderr, "[SEMANTIC ERROR] Invalid return type '%s' for function '%s' at Line %d, Column %d. Only 'int' and 'float' are allowed.\n", ret_type, fname, node->child1->line, node->child1->column);
                semantic_error = 1;
            }

            if (!add_symbol(fname, ret_type, "func")) {
                // Aponta para o nome da função (child2)
                fprintf(stderr, "[SEMANTIC ERROR] Function '%s' redeclared at Line %d, Column %d.\n", fname, node->child2->line, node->child2->column);
                semantic_error = 1;
            }

            // Salva a assinatura da função (Tipos dos parâmetros)
            Symbol *func_sym = lookup_symbol(fname);
            if (func_sym) {
                func_sym->num_params = 0;
                ASTNode *p = node->child3;
                while (p && func_sym->num_params < 10) {
                    strcpy(func_sym->param_types[func_sym->num_params], p->child1->lexema);
                    func_sym->num_params++;
                    p = p->next;
                }
            }

            open_scope();
            ASTNode *p2 = node->child3; // Parâmetros
            while (p2) {
                add_symbol(p2->child2->lexema, p2->child1->lexema, "param");
                p2 = p2->next;
            }
            is_function_body = 1;
            verificar_semantica(node->child4);
            close_scope();
            return "void";
        }
        
       case AST_COMPOUND: {
            int block_scope_created = 0;
            // Se for corpo de função, não abre escopo novo. Se for um bloco solto ou interno, abre escopo normal.
            if (is_function_body) {
                is_function_body = 0;
            } else {
                open_scope();
                block_scope_created = 1;
            }
            
            ASTNode *ld = node->child1;
            while (ld) { 
                verificar_semantica(ld); ld = ld->next; 
            }
            ASTNode *st = node->child2;
            while (st) { 
                verificar_semantica(st); st = st->next; 
            }
            if (node->child3) {
                verificar_semantica(node->child3);
            }
            if (block_scope_created) {
                close_scope();
            }
            return "void";
        }
        
        case AST_ID: {
            Symbol *s = lookup_symbol(node->lexema);
            if (!s) {
                fprintf(stderr, "[SEMANTIC ERROR] Variable '%s' undeclared at Line %d, Column %d.\n", node->lexema, node->line, node->column);
                semantic_error = 1;
                strcpy(node->exp_type, "int"); 
                return "int";
            }
            strcpy(node->exp_type, s->type);
            return s->type;
        }
        
        case AST_INT: {
            strcpy(node->exp_type, "int"); 
            return "int";
        }    
        case AST_FLOAT: {
            strcpy(node->exp_type, "float");
            return "float";
        }
        
        case AST_ASSIGN: {
            char *ltype = verificar_semantica(node->child1);
            char *rtype = verificar_semantica(node->child2);
            
            // Validação de tipo
            if (strcmp(ltype, "int") == 0 && strcmp(rtype, "float") == 0) {
                // Aponta para a variável (child1)
                fprintf(stderr, "[SEMANTIC ERROR] Type mismatch: cannot assign 'float' to 'int' variable '%s' at Line %d, Column %d.\n", node->child1->lexema ? node->child1->lexema : "variable", node->child1->line, node->child1->column);
                semantic_error = 1;
            }
            
            strcpy(node->exp_type, ltype);
            return ltype;
        }
        
        case AST_BINOP: {
            char *t1 = verificar_semantica(node->child1);
            char *t2 = verificar_semantica(node->child2);
            char *op = node->lexema;
            
            // Aritméticos: promoção implícita para float
            if (strcmp(op, "+") == 0 || strcmp(op, "-") == 0 || strcmp(op, "*") == 0 || strcmp(op, "/") == 0) {
                if (strcmp(t1, "float") == 0 || strcmp(t2, "float") == 0) {
                    strcpy(node->exp_type, "float");
                }
                else { 
                    strcpy(node->exp_type, "int");
                }
            } 
            // Módulo: exige int
            else if (strcmp(op, "%") == 0) {
                if (strcmp(t1, "float") == 0 || strcmp(t2, "float") == 0) {
                    fprintf(stderr, "[SEMANTIC ERROR] Operator '%%' only accepts int at Line %d, Column %d.\n", node->child1->line, node->child1->column);
                    semantic_error = 1;
                }
                strcpy(node->exp_type, "int");
            } 
            // Relacionais e Lógicos: produzem sempre int (0 ou 1)
            else if (strcmp(op, "<") == 0 || strcmp(op, ">") == 0 || strcmp(op, "<=") == 0 || 
                     strcmp(op, ">=") == 0 || strcmp(op, "==") == 0 || strcmp(op, "!=") == 0 ||
                     strcmp(op, "&&") == 0 || strcmp(op, "||") == 0) {
                strcpy(node->exp_type, "int");
            } 
            else {
                strcpy(node->exp_type, "int");
            }
            return node->exp_type;
        }
        
        case AST_UNOP: {
            char *t1 = verificar_semantica(node->child1);
            if (strcmp(node->lexema, "!") == 0) {
                strcpy(node->exp_type, "int");
            }
            else { 
                strcpy(node->exp_type, t1);
            }
            return node->exp_type;
        }
        
        case AST_IF:
        case AST_WHILE: {
            char *cond_type = verificar_semantica(node->child1);
            
            // Validação explícita do tipo da condição
            if (strcmp(cond_type, "int") != 0 && strcmp(cond_type, "float") != 0) {
                fprintf(stderr, "[SEMANTIC ERROR] Condition must be a numeric expression at Line %d, Column %d.\n", node->child1->line, node->child1->column);
                semantic_error = 1;
            }

            verificar_semantica(node->child2); 
            if (node->child3) {
                verificar_semantica(node->child3);
            } 
            return "void";
        }
        
        case AST_FUNC_CALL: {
            Symbol *s = lookup_symbol(node->child1->lexema);
            if (!s || strcmp(s->category, "func") != 0) {
                // Aponta para o nome da função (child1)
                fprintf(stderr, "[SEMANTIC ERROR] Function '%s' undeclared or invalid at Line %d, Column %d.\n", node->child1->lexema, node->child1->line, node->child1->column);
                semantic_error = 1;
                strcpy(node->exp_type, "int");
                return "int";
            }
            
            ASTNode *arg = node->child2;
            int arg_count = 0;
            
            while (arg) { 
                char *arg_type = verificar_semantica(arg);
                // Validação de tipos de argumentos
                if (arg_count < s->num_params) {
                    char *expected_type = s->param_types[arg_count];
                    // Bloqueia passar float para um parâmetro que espera int
                    if (strcmp(expected_type, "int") == 0 && strcmp(arg_type, "float") == 0) {
                        // Aponta diretamente para o argumento que está com o tipo errado
                        fprintf(stderr, "[SEMANTIC ERROR] Type mismatch in argument %d of function '%s': cannot pass 'float' to 'int' parameter at Line %d, Column %d.\n", arg_count + 1, s->name, arg->line, arg->column);
                        semantic_error = 1;
                    }
                }
                
                arg_count++;
                arg = arg->next; 
            }
            
            // Checa se passou a quantidade certa de parâmetros
            if (arg_count != s->num_params) {
                // Aponta para o nome da função (child1)
                fprintf(stderr, "[SEMANTIC ERROR] Function '%s' expects %d arguments, but got %d at Line %d, Column %d.\n", s->name, s->num_params, arg_count, node->child1->line, node->child1->column);
                semantic_error = 1;
            }
            strcpy(node->exp_type, s->type);
            return s->type;
        }
        
        case AST_PRINT:
        case AST_READ:{
            if (node->child1) {
                verificar_semantica(node->child1);
            }
            return "void";
        }
        
        case AST_RETURN: {
            if (node->child1) {
                char *rtype = verificar_semantica(node->child1);
                // Bloqueia retornar float numa função declarada como int
                if (strcmp(current_func_type, "int") == 0 && strcmp(rtype, "float") == 0) {
                    // Aponta para o valor que está sendo retornado (child1)
                    fprintf(stderr, "[SEMANTIC ERROR] Type mismatch: cannot return 'float' in a function returning 'int' at Line %d, Column %d.\n", node->child1->line, node->child1->column);
                    semantic_error = 1;
                }
            } else {
                // Se o return for vazio (return;) aponta para o próprio return
                fprintf(stderr, "[SEMANTIC ERROR] Missing return value: function expects '%s' at Line %d, Column %d.\n", current_func_type, node->line, node->column);
                semantic_error = 1;
            }
            return "void";
            // O nó return em si não devolve tipo para a árvore
        }
        
        default: 
            return "void";
    }
}



/* ---------------- GERAÇÃO DE CÓDIGO DE TRÊS ENDEREÇOS (TAC) ----------------- */

int temp_counter = 1;
int label_counter = 1;

char* new_temp() {
    char *t = malloc(10);
    sprintf(t, "t%d", temp_counter++);
    return t;
}

char* new_label() {
    char *l = malloc(10);
    sprintf(l, "L%d", label_counter++);
    return l;
}

void gerar_tac(ASTNode *node, FILE *out);

void gerar_condicao(ASTNode *node, char *l_true, char *l_false, FILE *out) {
    if (!node) {
    	return;
    }

    if (node->type == AST_BINOP && strcmp(node->lexema, "||") == 0) {
        // OR: Se o da esquerda for verdadeiro, pula logo pro l_true (Curto-circuito). Se for falso, avalia o da direita.
        char *l_next = new_label();
        gerar_condicao(node->child1, l_true, l_next, out);
        fprintf(out, "%s:\n", l_next);
        gerar_condicao(node->child2, l_true, l_false, out);
    }
    else if (node->type == AST_BINOP && strcmp(node->lexema, "&&") == 0) {
        // AND: Se o da esquerda for falso, pula logo pro l_false (Curto-circuito). Se for verdadeiro, avalia o da direita.
        char *l_next = new_label();
        gerar_condicao(node->child1, l_next, l_false, out);
        fprintf(out, "%s:\n", l_next);
        gerar_condicao(node->child2, l_true, l_false, out);
    }
    else if (node->type == AST_UNOP && strcmp(node->lexema, "!") == 0) {
        // NOT: Apenas inverte os rótulos alvo
        gerar_condicao(node->child1, l_false, l_true, out);
    }
    else if (node->type == AST_BINOP && (
                strcmp(node->lexema, "<") == 0 || strcmp(node->lexema, ">") == 0 ||
                strcmp(node->lexema, "<=") == 0 || strcmp(node->lexema, ">=") == 0 ||
                strcmp(node->lexema, "==") == 0 || strcmp(node->lexema, "!=") == 0)) {
        
        gerar_tac(node->child1, out); 
        gerar_tac(node->child2, out); 
        
        char op1_temp[20];
        char op2_temp[20];
        strcpy(op1_temp, node->child1->temp);
        strcpy(op2_temp, node->child2->temp);
        
        // Cast nas comparações se tiver mistura de tipos
        if (strcmp(node->child1->exp_type, "int") == 0 && strcmp(node->child2->exp_type, "float") == 0) {
            char *cast_temp = new_temp();
            fprintf(out, "%s = (float) %s\n", cast_temp, op1_temp);
            strcpy(op1_temp, cast_temp);
        } else if (strcmp(node->child1->exp_type, "float") == 0 && strcmp(node->child2->exp_type, "int") == 0) {
            char *cast_temp = new_temp();
            fprintf(out, "%s = (float) %s\n", cast_temp, op2_temp);
            strcpy(op2_temp, cast_temp);
        }
        
        fprintf(out, "if %s %s %s goto %s\n", op1_temp, node->lexema, op2_temp, l_true);
        fprintf(out, "goto %s\n", l_false);
    }
    else {
        // Caso seja uma variável solta como "if (x)" ou "while (1)"
        gerar_tac(node, out);
        fprintf(out, "if %s != 0 goto %s\n", node->temp, l_true);
        fprintf(out, "goto %s\n", l_false);
    }
}

void gerar_tac(ASTNode *node, FILE *out) {
    if (!node) {
    	return;
    }
    switch (node->type) {
        case AST_VAR_DECL: {
            char *decl_type = node->child1->lexema;
            ASTNode *var = node->child2;
            while (var) {
                if (var->type == AST_ASSIGN) {
                    gerar_tac(var->child2, out);
                    
                    char rhs_temp[20];
                    strcpy(rhs_temp, var->child2->temp);
                    
                    // Cast na inicialização se var é float e valor é int
                    if (strcmp(decl_type, "float") == 0 && strcmp(var->child2->exp_type, "int") == 0) {
                        char *cast_temp = new_temp();
                        fprintf(out, "%s = (float) %s\n", cast_temp, rhs_temp);
                        strcpy(rhs_temp, cast_temp);
                    }
                    
                    fprintf(out, "%s = %s\n", var->child1->lexema, rhs_temp);
                }
                var = var->next;
            }
            break;
        }
        
        case AST_FUNC_DECL: {
            fprintf(out, "\n%s:\n", node->child2->lexema);
            // Apanha os parâmetros explicitamente no TAC
            ASTNode *p = node->child3;
            while (p) {
                fprintf(out, "pop_param %s\n", p->child2->lexema);
                p = p->next;
            }
            
            gerar_tac(node->child4, out);
            // Corpo da Função
            break;
        }
            
        case AST_COMPOUND: {
            ASTNode *ld = node->child1;
            while (ld) { 
                gerar_tac(ld, out); ld = ld->next; 
            }
            ASTNode *st = node->child2;
            while (st) { 
                gerar_tac(st, out); st = st->next; 
            }
            if (node->child3) {
                gerar_tac(node->child3, out);
            }
            // Return
            break;
        }
        
        case AST_INT: {
            sprintf(node->temp, "%d", node->int_val);
            break;
        }
        case AST_FLOAT: {
            sprintf(node->temp, "%.2f", node->float_val);
            break;
        }   
        case AST_ID: {
            strcpy(node->temp, node->lexema);
            break;
        }
            
        case AST_ASSIGN: {
            gerar_tac(node->child2, out);
            
            char rhs_temp[20];
            strcpy(rhs_temp, node->child2->temp);
            
            // Cast na atribuição
            if (strcmp(node->child1->exp_type, "float") == 0 && strcmp(node->child2->exp_type, "int") == 0) {
                char *cast_temp = new_temp();
                fprintf(out, "%s = (float) %s\n", cast_temp, rhs_temp);
                strcpy(rhs_temp, cast_temp);
            }
            
            fprintf(out, "%s = %s\n", node->child1->lexema, rhs_temp);
            strcpy(node->temp, node->child1->lexema);
            break;
        }
            
        case AST_BINOP: {
            gerar_tac(node->child1, out);
            gerar_tac(node->child2, out);
            
            char op1_temp[20];
            char op2_temp[20];
            strcpy(op1_temp, node->child1->temp);
            strcpy(op2_temp, node->child2->temp);
            
            // Verifica se precisa se cast no operando 1
            if (strcmp(node->child1->exp_type, "int") == 0 && strcmp(node->child2->exp_type, "float") == 0) {
                char *cast_temp = new_temp();
                fprintf(out, "%s = (float) %s\n", cast_temp, op1_temp);
                strcpy(op1_temp, cast_temp);
            }
            
            // Verifica se precisa se cast no operando 2
            else if (strcmp(node->child1->exp_type, "float") == 0 && strcmp(node->child2->exp_type, "int") == 0) {
                char *cast_temp = new_temp();
                fprintf(out, "%s = (float) %s\n", cast_temp, op2_temp);
                strcpy(op2_temp, cast_temp);
            }
            
            strcpy(node->temp, new_temp());
            fprintf(out, "%s = %s %s %s\n", node->temp, op1_temp, node->lexema, op2_temp);
            break;
        }
        
        case AST_UNOP: {
            gerar_tac(node->child1, out);
            strcpy(node->temp, new_temp());
            fprintf(out, "%s = %s %s\n", node->temp, node->lexema, node->child1->temp);
            break;
        }
        case AST_IF: {
            char *l_true = new_label();
            char *l_false = new_label();
            
            // Otimização: se não tiver ELSE, o l_end é o próprio l_false
            char *l_end = node->child3 ? new_label() : l_false;
            
            // Gera o código da condição em formato de curto-circuito
            gerar_condicao(node->child1, l_true, l_false, out);
            
            // Bloco TRUE
            fprintf(out, "%s:\n", l_true);
            gerar_tac(node->child2, out); // Stmt do if
            
            // Bloco FALSE / ELSE
            if (node->child3) {
                fprintf(out, "goto %s\n", l_end);
                fprintf(out, "%s:\n", l_false);
                gerar_tac(node->child3, out); // Stmt do else
            }
            
            // Fim 
            fprintf(out, "%s:\n", l_end);
            break;
        }
        
        case AST_WHILE: {
            char *l_start = new_label();
            char *l_true = new_label();
            char *l_false = new_label();
            
            // Início do loop
            fprintf(out, "%s:\n", l_start);
           
            // Condição
            gerar_condicao(node->child1, l_true, l_false, out);
            
            // Bloco TRUE
            fprintf(out, "%s:\n", l_true);
            gerar_tac(node->child2, out);
            fprintf(out, "goto %s\n", l_start);
            
            // Saída do loop (FALSE)
            fprintf(out, "%s:\n", l_false);
            break;
        }
        
        case AST_PRINT: {
            gerar_tac(node->child1, out);
            fprintf(out, "print %s\n", node->child1->temp);
            break;
        }    
        case AST_READ: {
            fprintf(out, "read %s\n", node->child1->lexema);
            break;
        }    
        case AST_RETURN: {
            if (node->child1) {
                gerar_tac(node->child1, out);
                fprintf(out, "return %s\n", node->child1->temp);
            } else {
                fprintf(out, "return\n");
            }
            break;
        }    
        case AST_FUNC_CALL: {
            ASTNode *arg = node->child2;
            int params = 0;
            while (arg) {
                gerar_tac(arg, out);
                fprintf(out, "param %s\n", arg->temp);
                params++;
                arg = arg->next;
            }
            strcpy(node->temp, new_temp());
            fprintf(out, "%s = call %s, %d\n", node->temp, node->child1->lexema, params);
            break;
        }
        
        default: break;
    }
}


/* -------------------------------- MAIN ------------------------------- */

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: ./parser <source_file>\n");
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        printf("Error opening file.\n");
        return 1;
    }

    printf("\n========================================\n");
    printf("1. STARTING LEXICAL AND SYNTACTIC ANALYSIS\n");
    printf("========================================\n");

    yyparse();
    
    if (lexical_error || syntax_error) {
        printf("\nPROGRAM REJECTED DUE TO LEXICAL OR SYNTAX ERRORS\n");
        fclose(yyin);
        return 1;
    }

    printf("\n========================================\n");
    printf("2. STARTING SEMANTIC ANALYSIS\n");
    printf("========================================\n");
    
    open_scope();
    //Dispara a varredura percorrendo a lista global
    ASTNode *curr = root;
    while (curr) {
        verificar_semantica(curr);
        curr = curr->next;
    }

    if (semantic_error) {
        printf("\nPROGRAM REJECTED DUE TO SEMANTIC ERRORS\n");
        fclose(yyin);
        return 1;
    }

    printf("Semantic analysis passed successfully.\n");
    print_symbol_table();

    out = fopen("output.tac", "w");
    if (!out) {
        printf("Error creating output.tac file.\n");
        fclose(yyin);
        return 1;
    }

    // Dispara a geração de código percorrendo a lista global
    curr = root;
    while (curr) {
        gerar_tac(curr, out);
        curr = curr->next;
    }
    fclose(out);
    printf("\n========================================\n");
    printf("PROGRAM ACCEPTED. Intermediate code generated in 'output.tac'.\n");
    printf("========================================\n\n");

    fclose(yyin);
    return 0;
}
