#include "Interface.h"

//------------------------------------------SECUNDARY FUNCTIONS------------------------------------------

PlayerNode addPlayer(PlayerNode tree, PlayerInfo new_player) {
    int cond;
    if (tree == NULL) {
        new_player->games= new_player->losses= new_player->wins = 0;
        tree = (PlayerNode) malloc(sizeof(struct aux_player_node));
        tree->player= (PlayerInfo) malloc(sizeof(struct aux_player_info));
        tree->player= new_player;
        tree->left= tree->right= NULL;
    } 
    else if (new_player->id==tree->player->id) return tree;
    else if ((cond = strcasecmp(new_player->name, tree->player->name))<=0) tree->left= addPlayer(tree->left, new_player);
    else tree->right = addPlayer(tree->right, new_player);
    return tree;
}
ThemeNode addTheme(ThemeNode tree, ThemeInfo new_theme) {
    int cond;
    if (tree == NULL) {
        tree = (ThemeNode) malloc(sizeof(struct aux_theme_node));
        tree->theme_info= (ThemeInfo) malloc(sizeof(struct aux_theme_info));
        tree->theme_info= new_theme;
        tree->left= tree->right= NULL;
    } 
    else if (new_theme->id==tree->theme_info->id) return tree;
    else if ((cond = strcasecmp(new_theme->theme, tree->theme_info->theme))<=0) tree->left= addTheme(tree->left, new_theme);
    else tree->right = addTheme(tree->right, new_theme);
    return tree;
}
WordNode addWord(WordNode tree, WordInfo new_word) {
    int cond;
    if (tree == NULL) {
        tree = (WordNode) malloc(sizeof(struct aux_word_node));
        tree->word_info = (WordInfo) malloc(sizeof(struct aux_word_info));
        tree->word_info= new_word;
        tree->left= tree->right= NULL;
    } 
    else if (new_word->id==tree->word_info->id) return tree;
    else if ((cond = strcasecmp(new_word->word, tree->word_info->word))<=0) tree->left= addWord(tree->left, new_word);
    else tree->right = addWord(tree->right, new_word);
    return tree;
}

//===================VERIFIERS===================
int verifyDate(born_date date) {
    if (date.year>1910 && date.year<2010) {
        if (date.month==1 || date.year==3 || date.month==5 || date.month==7 || date.month==8 || date.month==10 || date.month==12) {
            if (date.day>0 && date.day<=31) return 1;
            else return 0;
        } else if (date.month==2) {
            if (date.day>0 && date.day<28) return 1;
            else return 0;
        } else if (date.month==4 || date.month==6 || date.month==9 || date.month==11) {
            if (date.day>0 && date.day<=30) return 1;
            else return 0;
        } else return 0;
    } else return 0;
}

//===================COUNTERS===================
int wordsInFileCounter(char *line) {
    int counter=0;
    for (int i=0; line[i]!='\0'; i++) {
        if (line[i]=='|') counter++;
        else continue;
    } return counter;
}
int playersCounter(PlayerNode players_tree, int counter) {
    if (players_tree != NULL) {
        counter+= playersCounter(players_tree->left, 0);        
        counter+= playersCounter(players_tree->right, 0);
        return ++counter;
    } else return 0;
}
int themesCounter(ThemeNode themes_tree, int counter) {
    if (themes_tree != NULL) {
        counter+= themesCounter(themes_tree->left, 0);        
        counter+= themesCounter(themes_tree->right, 0);
        return ++counter;
    } else return 0;
}
int wordsInTreeCounter(WordNode words_tree, int counter) {
    if (words_tree != NULL) {
        counter+= wordsInTreeCounter(words_tree->left, 0);        
        counter+= wordsInTreeCounter(words_tree->right, 0);
        return ++counter;
    } else return 0;
}

//===================FILE READERS===================
void saveUsers(PlayerNode players, FILE* fp) {
    if (players!=NULL) {
        saveUsers(players->left, fp);
        fprintf(fp, "\n%d|%s|%d|%s|%d/%d/%d|%d|%d|%d", players->player->id, players->player->name, players->player->gender, players->player->nationality, players->player->born.day, players->player->born.month, players->player->born.year, players->player->games, players->player->wins, players->player->losses);
        saveUsers(players->right, fp);
    } 
}
PlayerNode usersFileReader(PlayerNode players) {
    FILE *fp= fopen(PLAYERS_FILE_DIR, "r");
    char line[DIM_LINE];
    PlayerInfo new_player= (PlayerInfo) malloc(sizeof(struct aux_player_info));
    if (fp==NULL) return NULL;
    else {
        fgets(line, DIM_LINE, fp);
        fgets(line, DIM_LINE, fp);
        while (!feof(fp)) {
            fgets(line, DIM_LINE, fp);
            new_player->id= atoi(strtok(line, "|"));
            strcpy(new_player->name, strtok(NULL, "|"));
            new_player->gender= atoi(strtok(NULL, "|"));
            strcpy(new_player->nationality, strtok(NULL, "|"));
            new_player->born.day= atoi(strtok(NULL, "/"));
            new_player->born.month= atoi(strtok(NULL, "/"));
            new_player->born.year= atoi(strtok(NULL, "|"));
            new_player->games= atoi(strtok(NULL, "|"));
            new_player->wins= atoi(strtok(NULL, "|"));
            new_player->losses= atoi(strtok(NULL, "\n"));
            players= addPlayer(players, new_player);
        }        
    }
    fclose(fp);
    return players;
}
ThemeNode themesAndWordsFileReader(ThemeNode themes_tree) {
    ThemeInfo new_theme;
    WordInfo new_word;
    FILE *fp=fopen(WORDS_FILE_DIR, "r");
    char line[DIM_LINE];
    int theme_id=1, words_size;

    if (fp==NULL) return NULL;
    else {
        while (!feof(fp)) {
            fgets(line, DIM_LINE, fp);
            new_theme= (ThemeInfo) malloc(sizeof(struct aux_theme_info));
            strcpy(new_theme->theme, line);
            new_theme->id=theme_id++;

            new_theme->words_tree=NULL;

            fgets(line, DIM_LINE, fp);
            words_size=wordsInFileCounter(line)+1;
            for (int i=1; i<=words_size; i++) {
                new_word= (WordInfo) malloc(sizeof(struct aux_word_info));
                new_word->id=i;
                if (i==1) {
                    strcpy(new_word->word, strtok(line, "|"));
                    new_theme->words_tree= addWord(new_theme->words_tree, new_word);
                } else if (i==words_size) {
                    strcpy(new_word->word, strtok(NULL, "\n"));
                    new_theme->words_tree= addWord(new_theme->words_tree, new_word);
                } else {
                    strcpy(new_word->word, strtok(NULL, "|"));
                    new_theme->words_tree= addWord(new_theme->words_tree, new_word);
                }
            }
            themes_tree=addTheme(themes_tree, new_theme);
            fgets(line, DIM_LINE, fp);
        }
    }
    fclose(fp);
    return themes_tree;
}

//===================PRINTERS===================
void printPlayers(PlayerNode players_tree, int printMode) {
    if (players_tree!=NULL) {
        printPlayers(players_tree->left, printMode);
        if (printMode==PRINT_PLAYERS_INFO) {
            if (players_tree->player->gender==0) printf(" %d\t%s\tM\t%s\t\t%d/%d/%d\t%d\t%d\t%d\n", players_tree->player->id, players_tree->player->name, players_tree->player->nationality, players_tree->player->born.day, players_tree->player->born.month, players_tree->player->born.year, players_tree->player->games, players_tree->player->wins, players_tree->player->losses);
            else printf(" %d\t%s\tF\t%s\t\t%d/%d/%d\t%d\t%d\t%d\n", players_tree->player->id, players_tree->player->name, players_tree->player->nationality, players_tree->player->born.day, players_tree->player->born.month, players_tree->player->born.year, players_tree->player->games, players_tree->player->wins, players_tree->player->losses);
        } else printf("\t%d => %s\n", players_tree->player->id, players_tree->player->name);
        printPlayers(players_tree->right, printMode);
    }
}
void printThemesWords(ThemeNode themes_tree, int printMode) {
    if (themes_tree!=NULL) {
        printThemesWords(themes_tree->left, printMode);
        printf("\t%d => %s\n", themes_tree->theme_info->id, themes_tree->theme_info->theme);
        if (printMode==PRINT_THEMES_WORDS) { printWords(themes_tree->theme_info->words_tree); printf("\n"); }
        printThemesWords(themes_tree->right, printMode);
    }   
}
void printWords(WordNode words_tree) {
    if (words_tree!=NULL) {
        printWords(words_tree->left);
        printf("\t%d => %s\n", words_tree->word_info->id, words_tree->word_info->word);
        printWords(words_tree->right);
    }   
}

//===================SEARCHERS===================
PlayerInfo searchPlayer(PlayerNode players_tree, int id) {
    if (players_tree!=NULL) {
        if (players_tree->player->id==id) return players_tree->player;
        else {
            PlayerInfo player_found= (PlayerInfo)malloc(sizeof(struct aux_player_info));
            player_found->id=-1;
            player_found= searchPlayer(players_tree->left, id);
            if (player_found!=NULL && player_found->id!=-1) return player_found;
            else player_found= searchPlayer(players_tree->right, id);
            return player_found;
        }
    }
}
ThemeInfo searchTheme(ThemeNode themes_tree, int id) {
    if (themes_tree!=NULL) {
        if (themes_tree->theme_info->id==id) return themes_tree->theme_info;
        else {
            ThemeInfo theme_found= (ThemeInfo) malloc(sizeof(struct aux_theme_info));
            theme_found->id=-1;
            theme_found= searchTheme(themes_tree->left, id);
            if (theme_found!=NULL && theme_found->id!=-1) return theme_found;
            else theme_found= searchTheme(themes_tree->right, id);
            return theme_found;
        }
    }
}
WordInfo searchWord(WordNode words_tree, int id) {
    if (words_tree!=NULL) {
        if (words_tree->word_info->id==id) return words_tree->word_info;
        else {
            WordInfo word_found= (WordInfo) malloc(sizeof(struct aux_word_info));
            word_found->id=-1;
            word_found= searchWord(words_tree->left, id);
            if (word_found!=NULL && word_found->id!=-1) return word_found;
            else word_found= searchWord(words_tree->right, id);
            return word_found;
        }
    }
}

//===================OTHERS===================
void enterToContinue() {
    char enter;
    do {
        getchar();
        printf("\n\tEnter to continue... ");
        enter= getchar();
    } while (enter!='\n');
}
int choiceMenu(PlayerNode players_tree, ThemeNode themes_tree, int choose_mode) {
    int option;
    if (choose_mode==PLAYER_CHOICE) {
        do {
            system("cls");
            printf("\t|===============================|\n");
            printf("\t|       AVAILABLE PLAYERS       |\n");
            printf("\t|===============================|\n\n");
            printPlayers(players_tree, 0);
            printf("\t0 => EXIT");
            printf("\n\n\tOPTION: ");
            scanf("%d", &option);
        } while (option<0 || option>playersCounter(players_tree, 0));
    } else if (choose_mode==THEME_CHOICE) {
        do {
            system("cls");
            printf("\t|===============================|\n");
            printf("\t|        AVAILABLE THEMES       |\n");
            printf("\t|===============================|\n\n");
            printThemesWords(themes_tree, PRINT_ONLY_THEMES);
            printf("\t0 => EXIT");
            printf("\n\n\tOPTION: ");
            scanf("%d", &option);
        } while (option<0 || option>themesCounter(themes_tree, 0));
    } return option;
}
void initializeWord(char* playing_word, char* original_word) {
    for (int i=0; i< (int)(strlen(original_word)); i++) {
        if (original_word[i]==' ') playing_word[i]=' ';
        else playing_word[i]='_';
    }
}

bool changeWord(char* original_word, char* playing_word, char letter) {
    bool flag=false;
    for (int i = 0; i < (int)(strlen(original_word)); i++) {
        if (original_word[i]==letter) {
            playing_word[i]= original_word[i]; 
            flag=true;
        }
    }
    return flag;
}
bool letterPlay(char* original_word, char* playing_word) {
    char played_letter;
    do {
        getchar();
        printf("\n\tINSERT A LETTER OR NUMBER: ");
        scanf("%c", &played_letter);
    } while (played_letter<'A' && played_letter>'Z' && played_letter<'a' && played_letter>'z' && played_letter<'0' && played_letter>'9');
    return changeWord(original_word, playing_word, played_letter);
}

PlayerInfo engine(PlayerInfo player, char* original_word, char* theme) {
    int option, lifes=TOT_LIFES;
    char playing_word[DIM_STRING];
    initializeWord(playing_word, original_word);

    while (1) {
        system("cls");
        if (lifes==0) {
            printf("\n\tYOU HAVE NO MORE LIFES, NICE TRY, BUT IT IS JUST IT!\n\n\t\tGAME OVER BITCH");
            player->losses++;
            break;
        } else {
            printf("\n\t\tFIND OUT THE WORD\n\n\tTHEME: %s\tLIFES: %d\n\n\t", theme, lifes);
            for (int i=0; i<(int)(strlen(playing_word)); i++) printf(" %c", playing_word[i]);

            printf("\n\n\t1=> GET ONLY A LETTER\n\t2=> GET THE WHOLE WORD\n\t0=> GIVE UP");
            do { printf("\n\n\tOPTION=> "); scanf("%d", &option); } while (option<0 || option>2);
            
            if (option==0) {
                printf("\tYOU FAILED!! THE %s WAS %s!\n", theme, original_word);
                player->losses++;
                break;
            } else if (option==1) {
                if (letterPlay(original_word, playing_word)==true) {
                    printf("\tYOU GOT IT! THAT LETTER BELONGS!\n");
                    if (strcasecmp(original_word, playing_word)==0) {
                        sleep(2);
                        printf("\n\tYOU GOT IT %s! YOU WON!\n\n", theme);
                        player->wins++;
                        break;
                    }
                } else {
                    printf("\tYOU FAILED! THAT LETTER DOESN'T BELONG TO %s!\n\tTRY AGAIN!", theme); 
                    lifes--;
                }
            } else if (option==2) {
                char played_word[DIM_STRING];
                printf("\n\tINSERT A NAME OF %s: ", theme);
                scanf(" %[^\n]", played_word);
                if (strcasecmp(played_word, original_word)==0) {
                    printf("\n\tYOU GOT IT %s! YOU WON!\n\n", theme);
                    player->wins++;
                } else {
                    printf("\n\tYOU FAILED! THE %s WAS %s!\n\n\t\tGAME OVER BITCH!\n\n", theme, original_word);
                    player->losses++;
                } break;
            }
        } enterToContinue();
    }
    enterToContinue();
    player->games++;
    return player;
}


//------------------------------------------MAIN FUNCTIONS------------------------------------------

short menu() {
    system("cls");
    short option;
    do {
        printf("\t|===============================|\n");
        printf("\t|           HANGED GAME         |\n");
        printf("\t|===============================|\n");
        printf("\t|   1-> NEW PLAYER              |\n");
        printf("\t|   2-> RANKINGS                |\n");
        printf("\t|   3-> PLAY                    |\n");
        printf("\t|   0-> EXIT                    |\n");
        printf("\t|===============================|\n");
        printf("\t OPTION: ");
        scanf("%d", &option);
    } while (option<0 && option>5);
    return option;
}

PlayerNode createPlayer(PlayerNode players) {
    PlayerInfo new_player= (PlayerInfo) malloc(sizeof(struct aux_player_info));

    new_player->id=playersCounter(players, 0)+1;
    system("cls");
    printf("INSERT YOUR NAME: ");
    scanf(" %[^\n]", new_player->name);
    printf("INSERT YOUR NATIONALITY: ");
    scanf(" %[^\n]", new_player->nationality);

    do {
        printf("INSERT YOUR GENDER [0-MALE, 1-FEMALE]: ");
        scanf("%hd", &new_player->gender);
    } while (new_player->gender!=0 && new_player->gender!=1);
    do {
        printf("INSERT YOUR BORN DATE [dd/mm/aaaa]: ");
        scanf("%d/%d/%d", &new_player->born.day, &new_player->born.month, &new_player->born.year);
    } while (verifyDate(new_player->born)==0);
    
    players= addPlayer(players, new_player);
    printf("\nPLAYER CREATED WITH SUCESS!\n\n");
    enterToContinue();
    return players;
}

void printRegisteredPlayers(PlayerNode players) {
    system("cls");  
    if (players==NULL) 
        printf("\tERROR! THERE IS NO PLAYERS REGISTERED YET!\n\tBACKING TO MAIN MENU...\n");
    else {
        printf("----------------------REGISTERED PLAYERS----------------------\n");
        printf(" ID\tNAME\t\tGENDER\tNATIONALITY\t\tBORN\t\tGAMES\tWINS\tLOSSES\n");
        printPlayers(players, PRINT_PLAYERS_INFO);
    }
    enterToContinue();
}
void printRegisteredThemesAndWords(ThemeNode themes) {
    system("cls");  
    printf("------------------REGISTERED THEMES AND WORDS------------------\n");
    printThemesWords(themes, PRINT_THEMES_WORDS);
    enterToContinue();
}

PlayerNode play(PlayerNode players, ThemeNode themes) {
    if (players==NULL || themes==NULL) {
        printf("\tERROR! THERE IS NO PLAYERS OR THEMES REGISTERED YET!\n\tBACKING TO MAIN MENU...\n");
        enterToContinue();
        return players;
    } 
    int choosen_player_id= choiceMenu(players, NULL, PLAYER_CHOICE);
    if (choosen_player_id==0) return players;
    int choosen_theme_id= choiceMenu(NULL, themes, THEME_CHOICE);
    if (choosen_theme_id==0) return players;

    int random_word_id;
    PlayerInfo playing_player= searchPlayer(players, choosen_player_id);
    ThemeInfo playing_theme= searchTheme(themes, choosen_theme_id);

    system("cls");
    srand(time(NULL));
    random_word_id= (rand() % wordsInTreeCounter(playing_theme->words_tree, 0))+1;

    playing_player= engine(playing_player, searchWord(playing_theme->words_tree, random_word_id)->word, playing_theme->theme);
    return players;
}

void closeGame(PlayerNode players) {
    FILE *fp= fopen(PLAYERS_FILE_DIR, "w");
    fprintf(fp, "ID|NAME|GENDER|NATIONALITY|BORN|GAMES|WINS|LOSSES\n");
    saveUsers(players, fp);
    fclose(fp);
}

//------------------------------------------MAIN------------------------------------------
int main() {
    PlayerNode players=NULL;
    ThemeNode themes=NULL;
    players=usersFileReader(players);
    themes=themesAndWordsFileReader(themes);
    short option;
    
    while (1) {
        option=menu();
        if (option==0) break;
        else if (option==1) players=createPlayer(players);
        else if (option==2) printRegisteredPlayers(players);
        else if (option==3) players=play(players, themes);
        else if (option==4) printRegisteredThemesAndWords(themes);
        else continue;
        closeGame(players);
    }
    printf("\n\n\tGAME EXIT WITH SUCESS!\n\n");
    return 0;
}
