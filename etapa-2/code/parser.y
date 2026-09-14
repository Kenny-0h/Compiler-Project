%{
/* Analisador Sintático */

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

void yyerror(const char *s);
void print_hash_table();
%}

%define parse.error detailed
%locations

/* ------------------ TOKENS ------------------- */

/* Palavras-chave */
%token KW_INT
%token KW_FLOAT

%token KW_IF
%token KW_ELSE
%token KW_WHILE

%token KW_PRINT
%token KW_READ
%token KW_RETURN

/* Identificadores */
%token ID

/* Literais */
%token INTNUM
%token FLOATNUM

/* Operadores relacionais */
%token LT GT LE GE EQ NE

/* Operadores lógicos */
%token AND OR NOT

/* Operadores aritméticos */
%token PLUS MINUS MULT DIV

/* Atribuição */
%token ASSIG

/* Delimitadores */
%token SEMCOL
%token COMMA

%token LPAREN RPAREN
%token LBRACE RBRACE

/* ---------------- PRECEDÊNCIA ---------------- */

/* resolve dangling else */
%nonassoc LOWER_THAN_ELSE
%nonassoc KW_ELSE

%left OR
%left AND
%left EQ NE
%left LT GT LE GE

%left PLUS MINUS
%left MULT DIV

%right NOT
%right UMINUS
%right ASSIG

%%

/* ---------------- PROGRAMA ---------------- */

program
    : declaration_list
    | /* vazio */
    ;

/* ---------------- DECLARAÇÕES ---------------- */

declaration_list
    : declaration_list declaration
    | declaration_list error SEMCOL
    | declaration_list error RBRACE
    | declaration
    ;

declaration
    : variable_declaration
    | function_declaration
    ;

/* ---------------- VARIÁVEIS ---------------- */

variable_declaration
    : type_specifier variable_list SEMCOL
    | type_specifier error SEMCOL
    ;

variable_list
    : variable_list COMMA variable
    | variable
    ;

variable
    : ID
    | ID ASSIG expression
    ;

type_specifier
    : KW_INT
    | KW_FLOAT
    ;

/* ---------------- FUNÇÕES ---------------- */

function_header
    : type_specifier ID LPAREN parameters RPAREN
    | type_specifier ID LPAREN error RPAREN
    ;
    
function_declaration
    : function_header compound_stmt
    | type_specifier ID LPAREN error compound_stmt { yyerrok; }
    ;

parameters
    : parameter_list
    | /* vazio */
    ;

parameter_list
    : parameter_list COMMA parameter
    | parameter
    ;

parameter
    : type_specifier ID
    ;

/* ---------------- BLOCOS ---------------- */
    
compound_stmt
    : LBRACE local_declarations statement_list RBRACE
    ;

local_declarations
    : local_declarations variable_declaration
    | /* vazio */
    ;

/* ---------------- COMANDOS ---------------- */

statement_list
    : statement_list statement
    | statement_list recovery_stmt
    | /* vazio */
    ;

recovery_stmt
    : error SEMCOL { yyerrok; }
    | error RBRACE { yyerrok; } 
    ;

statement
    : expression_stmt
    | compound_stmt
    | selection_stmt
    | iteration_stmt
    | io_stmt
    | return_stmt
    | SEMCOL
    ;

/* ---------------- EXPRESSÕES ---------------- */

expression_stmt
    : expression SEMCOL
    ;

expression
    : ID ASSIG expression
    | logical_or_expression
    ;

/* ---------------- IF / ELSE ---------------- */

selection_stmt
    : KW_IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
    | KW_IF LPAREN expression RPAREN statement KW_ELSE statement
    | KW_IF LPAREN error RPAREN statement
    | KW_IF LPAREN expression error statement
    ;

/* ---------------- WHILE ---------------- */

iteration_stmt
    : KW_WHILE LPAREN expression RPAREN statement
    | KW_WHILE LPAREN error RPAREN statement
    | KW_WHILE LPAREN expression error statement
    ;

/* ---------------- I/O ---------------- */

io_stmt
    : KW_PRINT LPAREN expression RPAREN SEMCOL
    | KW_PRINT LPAREN error RPAREN SEMCOL
    | KW_READ LPAREN ID RPAREN SEMCOL
    | KW_READ LPAREN error RPAREN SEMCOL
    ;

/* ---------------- RETURN ---------------- */

return_stmt
    : KW_RETURN expression SEMCOL
    ;

/* ---------------- EXPRESSÕES LÓGICAS ---------------- */

logical_or_expression
    : logical_or_expression OR logical_and_expression
    | logical_and_expression
    ;

logical_and_expression
    : logical_and_expression AND equality_expression
    | equality_expression
    ;

/* ---------------- EXPRESSÕES RELACIONAIS ---------------- */

equality_expression
    : equality_expression EQ relational_expression
    | equality_expression NE relational_expression
    | relational_expression
    ;

relational_expression
    : relational_expression LT additive_expression
    | relational_expression GT additive_expression
    | relational_expression LE additive_expression
    | relational_expression GE additive_expression
    | additive_expression
    ;

/* ---------------- EXPRESSÕES ARITMÉTICAS ---------------- */

additive_expression
    : additive_expression PLUS term
    | additive_expression MINUS term
    | term
    ;

term
    : term MULT factor
    | term DIV factor
    | factor
    ;

/* ---------------- FATORES ---------------- */

factor
    : LPAREN expression RPAREN
    | LPAREN error RPAREN
    | ID
    | INTNUM
    | FLOATNUM
    | function_call
    | NOT factor %prec NOT
    | MINUS factor %prec UMINUS
    ;

/* ---------------- CHAMADAS ---------------- */

function_call
    : ID LPAREN arguments RPAREN
    ;

arguments
    : argument_list
    | /* vazio */
    ;

argument_list
    : argument_list COMMA expression
    | expression
    ;

%%

/* ---------------- ERROS ---------------- */
const char *token_translate(const char *token) {
    if (strcmp(token, "SEMCOL") == 0) return "';'";
    if (strcmp(token, "COMMA") == 0) return "','";

    if (strcmp(token, "LPAREN") == 0) return "'('";
    if (strcmp(token, "RPAREN") == 0) return "')'";

    if (strcmp(token, "LBRACE") == 0) return "'{'";
    if (strcmp(token, "RBRACE") == 0) return "'}'";

    if (strcmp(token, "ASSIG") == 0) return "'='";

    if (strcmp(token, "PLUS") == 0) return "'+'";
    if (strcmp(token, "MINUS") == 0) return "'-'";
    if (strcmp(token, "MULT") == 0) return "'*'";
    if (strcmp(token, "DIV") == 0) return "'/'";

    if (strcmp(token, "LT") == 0) return "'<'";
    if (strcmp(token, "GT") == 0) return "'>'";
    if (strcmp(token, "LE") == 0) return "'<='";
    if (strcmp(token, "GE") == 0) return "'>='";
    if (strcmp(token, "EQ") == 0) return "'=='";
    if (strcmp(token, "NE") == 0) return "'!='";

    if (strcmp(token, "AND") == 0) return "'&&'";
    if (strcmp(token, "OR") == 0) return "'||'";
    if (strcmp(token, "NOT") == 0) return "'!'";

    if (strcmp(token, "ID") == 0) return "identifier";

    if (strcmp(token, "KW_INT") == 0) return "'int'";
    if (strcmp(token, "KW_FLOAT") == 0) return "'float'";

    if (strcmp(token, "KW_IF") == 0) return "'if'";
    if (strcmp(token, "KW_ELSE") == 0) return "'else'";
    if (strcmp(token, "KW_WHILE") == 0) return "'while'";

    if (strcmp(token, "KW_PRINT") == 0) return "'print'";
    if (strcmp(token, "KW_READ") == 0) return "'read'";
    if (strcmp(token, "KW_RETURN") == 0) return "'return'";

    if (strcmp(token, "INTNUM") == 0) return "integer literal";
    if (strcmp(token, "FLOATNUM") == 0) return "float literal";
    
    if (strcmp(token, "EOF") == 0) return "end of file";

    return token;
}

void yyerror(const char *s) {
    if (lexical_error)
        return;

    static int last_line = -1;
    static int last_col = -1;

    if (last_line == yylineno && last_col == yylloc.first_column) return;

    last_line = yylineno;
    last_col = yylloc.first_column;

    syntax_error = 1;
    
    if (yychar == YYEOF) {
        fprintf(stderr,
            "\n[SYNTAX ERROR] Unexpected end of file at Line %d, Column %d\n\n",
            yylineno,
            yylloc.first_column
        );
        return;
    }

    char *expecting = strstr(s, "expecting");

    if (expecting) {
        char buffer[512];
        char formatted[512];

        strcpy(buffer, expecting + strlen("expecting "));
        formatted[0] = '\0';
        
	char *eof_pos = strstr(buffer, "end of file");
	if (eof_pos) {
	    memmove(
		eof_pos + strlen("EOF"),
		eof_pos + strlen("end of file"),
		strlen(eof_pos + strlen("end of file")) + 1
	    );
	    memcpy(eof_pos, "EOF", 3);
	}

        char *token = strtok(buffer, " ");
        int first = 1;

        while (token) {
            if (strcmp(token, "or") != 0) {
                if (!first)
                    strcat(formatted, " or ");
                
                strcat(formatted, token_translate(token));
                first = 0;
            }

            token = strtok(NULL, " ");
        }

        fprintf(stderr,
            "\n[SYNTAX ERROR] Expected %s before '%s' at Line %d, Column %d\n\n",
            formatted,
            yytext,
            yylineno,
            yylloc.first_column
        );

        return;
    }

    fprintf(stderr,
        "\n[SYNTAX ERROR] Unexpected token '%s' at Line %d, Column %d\n\n",
        yytext,
        yylineno,
        yylloc.first_column
    );
}

/* ---------------- MAIN ---------------- */

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
    printf("STARTING LEXICAL AND SYNTACTIC ANALYSIS\n");
    printf("========================================\n\n");
    printf("%-15s | %-15s | %-5s | %-5s\n",
          "TOKEN",
          "LEXEMA",
          "LINE",
          "COLUMN");

    printf("------------------------------------------------------\n");

    yyparse();

    print_hash_table();

    if (!lexical_error && !syntax_error) {
        printf("\n========================================\n");
        printf("PROGRAM ACCEPTED\n");
        printf("========================================\n");
    } else {
        printf("\n========================================\n");
        printf("PROGRAM REJECTED\n");
        printf("========================================\n");
    }

    fclose(yyin);
    return 0;
}
