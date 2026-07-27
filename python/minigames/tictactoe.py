import turtle
from math import sqrt
from tkinter import messagebox

GRID_SIZE=430
DRAWING_SPEED= 0.5
players_plays= [[], []]
playing_player = 0
players_turtle= turtle.Turtle()

#   Aux Funcs --------------------------------------
def goTo(turtle, x, y):
    turtle.pu()
    turtle.goto(x, y)
    turtle.pd()

#   Drawers ----------------------------------------
def drawGridLine(turtle, toX, toY):
    goTo(turtle, toX, toY)
    turtle.fd(GRID_SIZE)
def drawGridDot(turtle, toX:int, toY:int):
    goTo(turtle, toX, toY)
    turtle.dot(9)
def drawGrid():
    grid_turtle=turtle.Turtle()
    grid_turtle.speed(0)
    grid_turtle.hideturtle()
    grid_turtle.pensize(5)
    goTo(grid_turtle, -GRID_SIZE/2, GRID_SIZE/2)
    
    for _ in range(4):
        grid_turtle.fd(GRID_SIZE)
        grid_turtle.right(90)

    grid_turtle.pensize(1)
    drawGridLine(grid_turtle, -GRID_SIZE/2, GRID_SIZE/2-GRID_SIZE/3)
    drawGridLine(grid_turtle, -GRID_SIZE/2, GRID_SIZE/2-2*GRID_SIZE/3)
    grid_turtle._rotate(-90)
    drawGridLine(grid_turtle, -GRID_SIZE/2+GRID_SIZE/3, GRID_SIZE/2)
    drawGridLine(grid_turtle, -GRID_SIZE/2+2*GRID_SIZE/3, GRID_SIZE/2)
    
    drawGridDot(grid_turtle, -GRID_SIZE/6, GRID_SIZE/6)
    drawGridDot(grid_turtle, GRID_SIZE/6, -GRID_SIZE/6)
    drawGridDot(grid_turtle, -GRID_SIZE/6, -GRID_SIZE/6)
    drawGridDot(grid_turtle, GRID_SIZE/6, GRID_SIZE/6)

#   Players Draws   --------------------------------
def initPlayersTurtle():
    players_turtle.hideturtle()
    players_turtle.speed(DRAWING_SPEED)
    players_turtle.pensize(3)

def playDrawCross(spot: int):
    if spot == 1 or spot == 4 or spot == 7: x = -GRID_SIZE/2 + 30
    elif spot == 2 or spot == 5 or spot == 8: x = -GRID_SIZE/6 + 30
    else: x = GRID_SIZE/6 + 30

    if spot == 1 or spot == 2 or spot == 3: y = GRID_SIZE/6 + 30
    elif spot == 4 or spot == 5 or spot == 6: y = -GRID_SIZE/6 + 30
    else: y = -GRID_SIZE/2 + 30

    cross_size= 110
    players_turtle.pencolor("blue")
    goTo(players_turtle, x, y)
    players_turtle.left(45)
    players_turtle.fd(cross_size)
    goTo(players_turtle, x+sqrt(cross_size**2/2), y)
    players_turtle.left(90)
    players_turtle.fd(cross_size)
    #   reset turtle
    players_turtle.right(135)
    return 1  
def playDrawCircle(spot: int):
    if spot == 1 or spot == 4 or spot == 7: x = -GRID_SIZE/3
    elif spot == 2 or spot == 5 or spot == 8: x = 0
    else: x = GRID_SIZE/3
    
    if spot == 1 or spot == 2 or spot == 3: y = GRID_SIZE/6 + 25
    elif spot == 4 or spot == 5 or spot == 6: y = -GRID_SIZE/6 + 25
    else: y = -GRID_SIZE/2 + 25
    
    players_turtle.pencolor("red")
    goTo(players_turtle, x, y)
    players_turtle.circle(45)
    return 1

def checkWinning(players_plays: list):
    WINNING_CONDITIONS = [[1,2,3], [4,5,6], [7,8,9], [1,4,7], [2,5,8], [3,6,9], [1,5,9], [3,5,7]]
    if len(players_plays[0]) + len(players_plays[1]) > 9: return -1
    for player_id, player in enumerate(players_plays):
        if len(player) > 2:
            for cond in WINNING_CONDITIONS:
                if set(cond).issubset(player) == True: return player_id

def endGame(winner):
    global players_plays
    if winner == -1: confirmation = messagebox.askyesno("Draw Game", "And it's a tie! :(\nDo you want to play again?")
    else: confirmation = messagebox.askyesno(f"Player {winner+1} Wins!", f"Congratulations Player {winner+1}, you won the Game!\nDo you want to play again?")

    if confirmation == True: 
        players_turtle.clear()
        players_plays= [[], []]
    else: turtle.exitonclick()


def getMouseClickCoor(x, y):
    global playing_player, players_plays
    spot = 0
    if   x > -GRID_SIZE/2               and x < -GRID_SIZE/2+GRID_SIZE/3   and y >  GRID_SIZE/2-GRID_SIZE/3   and y < GRID_SIZE/2:                spot = 1
    elif x > -GRID_SIZE/2+GRID_SIZE/3   and x < -GRID_SIZE/2+2*GRID_SIZE/3 and y >  GRID_SIZE/2-GRID_SIZE/3   and y < GRID_SIZE/2:                spot = 2
    elif x > -GRID_SIZE/2+2*GRID_SIZE/3 and x <  GRID_SIZE/2               and y >  GRID_SIZE/2-GRID_SIZE/3   and y < GRID_SIZE/2:                spot = 3
    elif x > -GRID_SIZE/2               and x < -GRID_SIZE/2+GRID_SIZE/3   and y >  GRID_SIZE/2-2*GRID_SIZE/3 and y < GRID_SIZE/2:                spot = 4
    elif x > -GRID_SIZE/2+GRID_SIZE/3   and x < -GRID_SIZE/2+2*GRID_SIZE/3 and y >  GRID_SIZE/2-2*GRID_SIZE/3 and y < GRID_SIZE/2:                spot = 5
    elif x > -GRID_SIZE/2+2*GRID_SIZE/3 and x <  GRID_SIZE/2               and y >  GRID_SIZE/2-2*GRID_SIZE/3 and y < GRID_SIZE/2:                spot = 6
    elif x > -GRID_SIZE/2               and x < -GRID_SIZE/2+GRID_SIZE/3   and y > -GRID_SIZE/2               and y < GRID_SIZE/2-2*GRID_SIZE/3:  spot = 7
    elif x > -GRID_SIZE/2+GRID_SIZE/3   and x < -GRID_SIZE/2+2*GRID_SIZE/3 and y > -GRID_SIZE/2               and y < GRID_SIZE/2-2*GRID_SIZE/3:  spot = 8
    elif x > -GRID_SIZE/2+2*GRID_SIZE/3 and x <  GRID_SIZE/2               and y > -GRID_SIZE/2               and y < GRID_SIZE/2-2*GRID_SIZE/3:  spot = 9
    
    if spot!=0: 
        players_plays[playing_player].append(spot)
        if playing_player == 0:
            playDrawCross(spot)
            playing_player+=1
        else:
            playDrawCircle(spot)
            playing_player-=1
        status= checkWinning(players_plays)
        if status == -1 or status == 0 or status == 1: endGame(status)


if __name__  ==  "__main__":
    initPlayersTurtle()
    drawGrid()
    turtle.Screen().title("Rooster Game by Rodrigo Sobral")
    turtle.onscreenclick(getMouseClickCoor)      
    turtle.mainloop()    
