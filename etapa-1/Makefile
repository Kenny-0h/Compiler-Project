all:
	flex code/lexer.l
	gcc lex.yy.c -o parser

run: all
	./parser input/teste.txt

clean:
	rm -f lex.yy.c parser
