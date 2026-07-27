//  ========================================
//                  LIBRARIES
//  ========================================

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <stdbool.h>

//  ========================================
//                  CONSTATNS
//  ========================================

#define DIM_STRING 50
#define DIM_LINE 150

#define PRINT_ONLY_PLAYERS 0
#define PRINT_PLAYERS_INFO 1
#define PRINT_ONLY_THEMES 0
#define PRINT_THEMES_WORDS 1

#define PLAYER_CHOICE 0
#define THEME_CHOICE 1

#define TOT_LIFES 5

#define PLAYERS_FILE_DIR "players_database.txt"
#define WORDS_FILE_DIR "words_database.txt"

//  ==============================================
//                  DATA STRUCTURES
//  ==============================================

//  =============
//  WORDS TREE   
//  =============

typedef struct aux_word_info *WordInfo;
struct aux_word_info {
    int id;
    char word[DIM_STRING];
};

typedef struct aux_word_node *WordNode;
struct aux_word_node {
    WordInfo word_info;
    WordNode left;
    WordNode right;
};

//  =============
//  THEMES TREE  
//  =============

typedef struct aux_theme_info *ThemeInfo;
struct aux_theme_info {
    int id;
    char theme[DIM_STRING];
    WordNode words_tree;
};

typedef struct aux_theme_node *ThemeNode;
struct aux_theme_node {
    ThemeInfo theme_info;
    ThemeNode left;
    ThemeNode right;
};

//  =============
//  PLAYERS TREE 
//  =============

typedef struct { int day, month, year; }born_date;

typedef struct aux_player_info *PlayerInfo;
struct aux_player_info {
    int id;
    char name[DIM_STRING];
    short gender; 
    born_date born;
    char nationality[DIM_STRING];
    int games, wins, losses;
};

typedef struct aux_player_node *PlayerNode;
struct aux_player_node {
    PlayerInfo player;
    PlayerNode left;
    PlayerNode right;
};

//  ========================================
//                  FUNCTIONS
//  ========================================

//===================VERIFIERS===================
int verifyDate(born_date date);

//===================COUNTERS===================
int wordsInFileCounter(char *line);
int playersCounter(PlayerNode players_tree, int counter);
int themesCounter(ThemeNode themes_tree, int counter);
int wordsInTreeCounter(WordNode words_tree, int counter);

//===================FILE READERS===================
void saveUsers(PlayerNode players, FILE* fp);
PlayerNode usersFileReader(PlayerNode players);
ThemeNode themesAndWordsFileReader(ThemeNode themes_tree);

//===================PRINTERS===================
void printPlayers(PlayerNode players_tree, int printMode);
void printThemesWords(ThemeNode themes_tree, int printMode);
void printWords(WordNode words_tree);

//===================SEARCHERS===================
PlayerInfo searchPlayer(PlayerNode players_tree, int id);
ThemeInfo searchTheme(ThemeNode themes_tree, int id);
WordInfo searchWord(WordNode words_tree, int id);

//===================OTHERS===================
void enterToContinue();
int choiceMenu(PlayerNode players_tree, ThemeNode themes_tree, int choose_mode);
void initializeWord(char* playing_word, char* original_word);
bool changeWord(char* original_word, char* playing_word, char letter);
bool letterPlay(char* original_word, char* playing_word);
PlayerInfo engine(PlayerInfo player, char* original_word, char* theme);

//===================MAIN FUNCTIONS===================
short menu();
PlayerNode createPlayer(PlayerNode players);
void printRegisteredPlayers(PlayerNode players);
void printRegisteredThemesAndWords(ThemeNode themes);
PlayerNode play(PlayerNode players, ThemeNode themes);
void closeGame(PlayerNode players);