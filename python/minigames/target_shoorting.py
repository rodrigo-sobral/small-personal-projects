from random import randint
from turtle import Turtle, exitonclick, Screen
from math import sqrt
from tkinter import simpledialog, messagebox, Tk

#   Aux Funcs   ======================
def goTo(turtle, x, y):
    turtle.pu()
    turtle.goto(x, y)
    turtle.pd()

#   Drawers ==========================
def drawTargetCircle(target_turtle: Turtle, y: int, color: str, points: int) -> None:
    goTo(target_turtle, 0, -y)
    target_turtle.begin_fill()
    target_turtle.fillcolor(color)
    target_turtle.circle(y)
    target_turtle.end_fill()
    target_turtle.pencolor("white")
    target_turtle.circle(y)
    target_turtle.pencolor("black")
    target_turtle.pensize(1.4)
    goTo(target_turtle, 0, -y + 25)
    target_turtle.circle(y-25)
    target_turtle.pensize(3)
    goTo(target_turtle, -y + 5, 0)
    if color=="black": target_turtle.pencolor("white")
    target_turtle.write(points)
    
def drawPanel(target_turtle):
    goTo(target_turtle, -290, 290)
    target_turtle.begin_fill()
    target_turtle.fillcolor('#612d17')
    for _ in range(4):
        target_turtle.fd(580)
        target_turtle.right(90)
    target_turtle.end_fill()

def drawTarget():
    Screen().title("Target Shooting by Rodrigo Sobral")
    target_turtle= Turtle()
    target_turtle.speed(0)
    target_turtle.hideturtle()
    target_turtle.pu()
    target_turtle.setposition(-300, 300)
    target_turtle.pd()
    
    target_turtle.begin_fill()
    target_turtle.fillcolor('black')
    for _ in range(4):
        target_turtle.fd(600)
        target_turtle.right(90)
    target_turtle.end_fill()

    drawPanel(target_turtle)
    drawTargetCircle(target_turtle, 255, "black", 5)
    drawTargetCircle(target_turtle, 195, "blue", 15)
    drawTargetCircle(target_turtle, 135, "red", 25)
    drawTargetCircle(target_turtle, 75, "yellow", 50)

#   Play Func   ======================
def play():
    bullets_turtle= Turtle()
    window= Tk()
    window.withdraw()
    confirmation= True
    while confirmation:
        bullets_turtle.clear()
        bullets_turtle.speed(0)
        bullets_turtle.hideturtle()
        shots_to_fire = simpledialog.askinteger(title="", prompt="How many shots you want to fire:")
        points = 0
        for _ in range(shots_to_fire):
            x, y = randint(-285,285), randint(-285,285)
            
            goTo(bullets_turtle, x, y - 5)
            bullets_turtle.pensize(3)
            bullets_turtle.pencolor("black")

            bullets_turtle.begin_fill()
            bullets_turtle.fillcolor("white")
            bullets_turtle.circle(10)
            bullets_turtle.end_fill()

            dist_cent= sqrt(x**2 + y**2)
            if (dist_cent<=75): points += 50
            elif (dist_cent<=135): points += 25
            elif (dist_cent<=195): points += 15
            elif (dist_cent<=255): points += 5
            
        confirmation = messagebox.askyesno(title='Results', message=f'Congratulations! You scored {points} points.\nDo you want to shoot again?')

if __name__ == "__main__":
    drawTarget()
    play()
    exitonclick()