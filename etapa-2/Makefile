all:
	bison -d code/parser.y
	flex code/lexer.l
	gcc parser.tab.c lex.yy.c -o parser

run: all
	./parser input/teste.txt

clean:
	rm -f parser parser.tab.c parser.tab.h lex.yy.c
