# Compilador para Linguagem Imperativa Simplificada

Projeto acadêmico de desenvolvimento incremental de um compilador para uma linguagem imperativa simplificada, abrangendo as etapas de **análise léxica**, **análise sintática**, **análise semântica** e **geração de código intermediário**.

O projeto foi desenvolvido de forma incremental, com cada etapa organizada separadamente e acompanhada de exemplos e mecanismos próprios de compilação e execução.

## 👥 Equipe

* [Thaís](https://github.com/thaisgiolopes)
* [Tobias](https://github.com/TobiasMaugus)
* [Kennedy](https://github.com/kenny-0h)

---

## 📚 Etapas do projeto

O desenvolvimento do compilador foi dividido em três etapas:

### 1. Analisador Léxico

Implementação do analisador léxico utilizando **Flex**, responsável por reconhecer os tokens da linguagem, identificar erros léxicos e construir a tabela de símbolos.

Esta etapa possui seus próprios arquivos de implementação, exemplos de entrada e `Makefile` para compilação e execução.

### 2. Analisador Sintático

Implementação do analisador sintático utilizando **Bison**, integrado ao analisador léxico desenvolvido na primeira etapa.

Nesta etapa são definidas as regras gramaticais da linguagem, realizado o reconhecimento da estrutura sintática dos programas e tratado o reconhecimento de erros sintáticos.

Assim como a primeira etapa, esta possui exemplos próprios e um `Makefile` para facilitar sua compilação e execução.

### 3. Análise Semântica e Geração de Código Intermediário

Implementação das verificações semânticas da linguagem e geração de código intermediário no formato de **três endereços**.

A análise semântica contempla verificações como tipos, declarações e escopos. Após a validação semântica, o compilador pode gerar a representação intermediária correspondente ao programa de entrada.

---

## 🗂️ Organização do repositório

A estrutura do repositório acompanha diretamente as três etapas de desenvolvimento:

```text
.
├── etapa-1/
│   ├── input/
│   ├── code/
│   └── Makefile
│
├── etapa-2/
│   ├── input/
│   ├── code/
│   └── Makefile
│
├── etapa-3/
│   ├── input/
│   ├── code/
│   └── Makefile
│
├── docs/
│   ├── Relatório de Implementação.pdf
│   ├── DFA_NUM.sgv
│   └── DFA_ID.svg
│
└── README.md
```

Cada diretório de etapa contém os arquivos necessários para executar aquela versão do compilador, incluindo seus respectivos exemplos e `Makefile`.

Dessa forma, é possível acompanhar a evolução do projeto desde o analisador léxico até a versão completa, com análise semântica e geração de código intermediário.

---

# 🔤 Etapa 1 — Analisador Léxico

A primeira etapa consiste na implementação de um analisador léxico utilizando **Flex**.

O analisador recebe um programa-fonte e realiza a identificação dos elementos léxicos definidos pela linguagem, produzindo os respectivos tokens.

### Responsabilidades

* reconhecimento de palavras reservadas;
* reconhecimento de identificadores;
* reconhecimento de constantes;
* reconhecimento de operadores;
* reconhecimento de delimitadores;
* tratamento de espaços em branco e comentários;
* identificação de erros léxicos;
* construção da tabela de símbolos.

### Diretório

```text
etapa-1/
```

O exemplo utilizado para testar o analisador está disponível em:

```text
etapa-1/input/
```

### Execução

A compilação e execução desta etapa são realizadas por meio do `Makefile` disponível no próprio diretório.

Consulte a seção [Utilização dos Makefiles](#-utilização-dos-makefiles) para os comandos disponíveis.

---

# 🌳 Etapa 2 — Analisador Sintático

A segunda etapa adiciona ao projeto o analisador sintático, desenvolvido utilizando **Bison** e integrado ao analisador léxico.

O analisador sintático recebe os tokens produzidos pela etapa anterior e verifica se eles estão organizados de acordo com a gramática definida para a linguagem.

### Responsabilidades

* definição da gramática da linguagem;
* reconhecimento das estruturas sintáticas;
* integração entre Flex e Bison;
* tratamento de ambiguidades;
* identificação de erros sintáticos;
* validação estrutural dos programas.

### Diretório

```text
etapa-2/
```

O programa utilizado para validar o analisador sintático está disponível em:

```text
etapa-2/input/
```

### Execução

A compilação e execução desta etapa são realizadas por meio do `Makefile` presente no diretório da etapa.

Consulte a seção [Utilização dos Makefiles](#-utilização-dos-makefiles).

---

# 🧠 Etapa 3 — Análise Semântica e Código Intermediário

A terceira etapa complementa o compilador com a **análise semântica** e a **geração de código intermediário**.

Após o reconhecimento sintático do programa, são realizadas verificações relacionadas ao significado das construções da linguagem. Quando o programa é considerado semanticamente válido, é realizada a geração da representação intermediária.

### Análise semântica

Entre as verificações realizadas estão:

* declaração e utilização de identificadores;
* compatibilidade de tipos;
* regras de escopo;
* validade das operações;
* consistência das atribuições;
* demais regras semânticas definidas para a linguagem.

### Código intermediário

A representação intermediária é gerada no formato de **código de três endereços**.

Por exemplo, uma expressão como:

```text
x = a + b * c;
```

pode ser representada como:

```text
t1 = b * c
t2 = a + t1
x = t2
```

A utilização de temporários permite representar operações complexas por meio de instruções mais simples, facilitando uma possível etapa posterior de otimização ou geração de código.

### Diretório

```text
etapa-3/
```

O exemplo utilizado para validar as regras semânticas e a geração de código intermediário está disponível em:

```text
etapa-3/input/
```

### Execução

A compilação e execução desta etapa são realizadas por meio do `Makefile` presente no diretório.

Consulte a seção [Utilização dos Makefiles](#-utilização-dos-makefiles).

---

# 🧪 Exemplos

Cada etapa possui um conjunto próprio de exemplos, permitindo testar as funcionalidades implementadas naquele momento do desenvolvimento.

A organização dos exemplos acompanha a evolução do compilador:

```text
etapa-1/
└── input/
    └── ...

etapa-2/
└── input/
    └── ...

etapa-3/
└── input/
    └── ...
```

O exemplo da primeira etapa foi utilizado principalmente para validar o reconhecimento dos tokens e o tratamento de erros léxicos.

Na segunda etapa, o exemplo permite validar as estruturas definidas pela gramática e o tratamento de erros sintáticos.

Na terceira etapa, é utilizado um exemplo para validar as regras semânticas e a geração do código intermediário.

---

# 🔨 Utilização dos Makefiles

Cada etapa do projeto possui um `Makefile` próprio, responsável por automatizar a compilação e a execução dos componentes correspondentes.

Para utilizar uma etapa, primeiro acesse seu respectivo diretório:

```bash
cd etapa-1
```

Em seguida, utilize os comandos disponibilizados pelo `Makefile`.

### Etapa 1

```bash
cd etapa-1

make run
```

### Etapa 2

```bash
cd etapa-2

make run
```

### Etapa 3

```bash
cd etapa-3

make run
```

> **Observação:** os comandos acima devem ser complementados conforme as regras efetivamente disponíveis em cada `Makefile`. Esta seção pode ser utilizada para documentar comandos específicos, como compilação, execução de exemplos, limpeza dos arquivos gerados e outras operações.

Por exemplo:

```bash
make run
make clean
```

---

# 🛠️ Tecnologias utilizadas

* **C/C++** — implementação do compilador;
* **Flex** — geração do analisador léxico;
* **Bison** — geração do analisador sintático;
* **Make** — automação da compilação e execução.

---

# 🎯 Objetivo

O objetivo do projeto é desenvolver, de forma incremental, um compilador para uma linguagem imperativa simplificada, aplicando conceitos relacionados às principais etapas do processo de compilação:

```text
                                                Código-fonte
                                                     │
                                                     ▼
                                            ┌──────────────────────┐
                                            │ 1. Análise Léxica    │
                                            │       Flex           │
                                            └──────────┬───────────┘
                                                       │ Tokens
                                                       ▼
                                            ┌──────────────────────┐
                                            │ 2. Análise Sintática │
                                            │       Bison          │
                                            └──────────┬───────────┘
                                                       │
                                                       ▼
                                            ┌───────────────────────┐
                                            │ 3. Análise Semântica  │
                                            │ + Código Intermediário│
                                            └───────────────────────┘
```

Além da implementação, o projeto registra as decisões de projeto, dificuldades encontradas e resultados obtidos durante o desenvolvimento de cada etapa.

---

## 📄 Contexto acadêmico

Projeto desenvolvido como atividade acadêmica relacionada ao estudo de **Construção de Compiladores**, abrangendo análise léxica, análise sintática, análise semântica e geração de código intermediário.

---
