%option noyywrap yylineno

%{
#include <stdio.h>
#include <stdlib.h>

#define HASH_SIZE 1019

typedef struct Node {
    char lexema[100];
    struct Node *next;
} Node;

int column = 1;
Node *hash_table[HASH_SIZE];

void print_token(char* type, char* lexema);
void print_token_attr(char* token, char* lexema);
void print_token_id(char* lexema, void* address);
void print_hash_table();
Node* process_id(char *lexema);
%}

/* ------------------------ DEFINIÇÕES ------------------------ */

DIGIT      [0-9]
LETTER     [a-zA-Z]
ID         {LETTER}({LETTER}|{DIGIT})*
INT        {DIGIT}+
FLOAT      {DIGIT}+"."{DIGIT}+

ARITOP     "-"|"+"|"/"|"*"
RELOP      "=="|"!="|"<="|">="|"<"|">"
ASSIG      "="
LOGOP      "&&"|"||"|"!"

SEMCOL     ";"
COMMA      ","
PAREN      "("|")"
BRACE      "{"|"}"

%x COMMENT

%%
%{
/* ------------------------ Palavras-chave ------------------------ */
%}
"int"      { print_token("KW_INT", yytext); }
"float"    { print_token("KW_FLOAT", yytext); }
"if"       { print_token("KW_IF", yytext); }
"else"     { print_token("KW_ELSE", yytext); }
"while"    { print_token("KW_WHILE", yytext); }
"print"    { print_token("KW_PRINT", yytext); }
"read"     { print_token("KW_READ", yytext); }

%{
/* ------------------------ Operadores ------------------------ */
%}
{RELOP}    { print_token_attr("OP_REL", yytext); }
{ASSIG}    { print_token("ASSIG", yytext); }
{LOGOP}    { print_token_attr("OP_LOG", yytext); }
{ARITOP}   { print_token_attr("OP_ARIT", yytext); }

%{
/* ------------------------ Símbolos ------------------------ */
%}
{SEMCOL}   { print_token("SEMCOL", yytext); }
{COMMA}    { print_token("COMMA", yytext); }
{PAREN}    { print_token_attr("PAREN", yytext); }
{BRACE}    { print_token_attr("BRACE", yytext); }

%{
/* ------------------------ Literais ------------------------ */
%}
{FLOAT}    { print_token_attr("FLOAT", yytext); }
{INT}      { print_token_attr("INT", yytext); }

%{
/* ------------------------ Identificadores ------------------------ */
%}
{ID} {
    Node* address = process_id(yytext);
    print_token_id(yytext, (void*) address);
}

%{
/* ------------------------ Comentários ------------------------ */
%}
"//".*     { column += yyleng; }

"/*"       { column += 2; BEGIN(COMMENT); }

<COMMENT>{
    "*/"   { column += 2; BEGIN(INITIAL); }
    \n     { column = 1; }
    .      { column++; }
}

%{
/* ------------------------ Espaços ------------------------ */
%}
[ \t\r]+   { column += yyleng; }
\n         { column = 1; }

%{
/* ------------------------ Erros ------------------------ */
%}
{DIGIT}+{LETTER}({LETTER}|{DIGIT})* {
    printf("Lexical error: Invalid identifier '%s' (Line: %d, Column: %d)\n", yytext, yylineno, column);
    column += yyleng;
}

. {
    printf("Lexical error: '%s' (Line: %d, Column: %d)\n", yytext, yylineno, column);
    column += yyleng;
}

%%

/* ------------------------ FUNÇÕES ------------------------ */

/* ------------------------ Funções de Impressão ------------------------ */

void print_token(char* type, char* lexema) {
    printf("%-22s | %-15s | %-4d | %-4d\n", type, lexema, yylineno, column);
    column += yyleng;
}

void print_token_attr(char* token, char* lexema) {
    printf("(%-10s, %-8s) | %-15s | %-4d | %-4d\n", token, lexema, lexema, yylineno, column);
    column += yyleng;
}

void print_token_id(char* lexema, void* address) {
    printf("(ID, %-16p) | %-15s | %-4d | %-4d\n", address, lexema, yylineno, column);
    column += yyleng;
}

/* ------------------------ Tabela Hash ------------------------ */

void print_hash_table() {
    printf("\n============================================================\n");
    printf("                  SIMBOL TABLE (HASH)                  \n");
    printf("============================================================\n");
    printf("%-25s | %-20s\n", "LEXEMA", "ADDRESS");
    printf("------------------------------------------------------------\n");

    for (int i = 0; i < HASH_SIZE; i++) {
        Node *n = hash_table[i];

        while (n != NULL) {
            printf("%-25s | %-20p\n", n->lexema, (void*) n);
            n = n->next;
        }
    }

    printf("============================================================\n");
}

/* ------------------------ Processamento de ID ------------------------ */

Node* process_id(char *lexema) {
    unsigned int h = 0;

    for (int i = 0; lexema[i] != '\0'; i++) {
        h = (h * 31) + lexema[i];
    }

    h = h % HASH_SIZE;

    Node *current = hash_table[h];

    while (current != NULL) {
        if (strcmp(current->lexema, lexema) == 0)
            return current;

        current = current->next;
    }

    Node *new = (Node*) malloc(sizeof(Node));
    strcpy(new->lexema, lexema);

    new->next = hash_table[h];
    hash_table[h] = new;

    return new;
}

/* ------------------------ Main ------------------------ */

int main(int argc, char *argv[]) {
    for (int i = 0; i < HASH_SIZE; i++) {
        hash_table[i] = NULL;
    }

    yyin = fopen(argv[1], "r");

    if (!yyin) {
        printf("Error opening file\n");
        return 1;
    }

    printf("\n================= BEGINNING OF LEXICAL ANALYSIS =================\n");
    printf("%-23s| %-15s | %-4s | %-4s\n", "TOKEN", "LEXEMA", "LIN", "COL");
    printf("----------------------------------------------------------------\n");
    yylex();

    printf("\n====================== END OF LEXICAL ANALYSIS ======================\n\n");

    print_hash_table();

    fclose(yyin);
    return 0;
}
