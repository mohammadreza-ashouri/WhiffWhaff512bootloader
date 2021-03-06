
SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200

# pong constants
PONG_HEIGHT = 20
PONG_WIDTH = 4
PONG_OFFSET = 10
PONG_MOVEMENT_SPEED = 8
PONG_COMPUTER_SPEED = 2
PONG_FORCE_FIELD = 4 

# computed values
TWICE_SCREEN_WIDTH = SCREEN_WIDTH * 2
HALF_SCREEN_WIDTH = SCREEN_WIDTH / 2
SCREEN_WIDTH_TIMES_MOVEMENT_SPEED = PONG_MOVEMENT_SPEED * SCREEN_WIDTH

PONG_HEIGHT_HALF = PONG_HEIGHT / 2
PONG_DEFAULT_Y = SCREEN_HEIGHT / 2 - PONG_HEIGHT_HALF
PONG_OFFSET_RIGHT = SCREEN_WIDTH - PONG_OFFSET - PONG_WIDTH

PONG_COLLISION_MIN_Y = -1 * PONG_FORCE_FIELD
PONG_COLLISION_MAX_Y = PONG_HEIGHT + PONG_FORCE_FIELD

PONG_MIN_Y = 0
PONG_MAX_Y = SCREEN_HEIGHT - PONG_HEIGHT

PONG_BALL_MIN_X = PONG_OFFSET + PONG_WIDTH
PONG_BALL_MAX_X = PONG_OFFSET_RIGHT - PONG_WIDTH

# memory
VGA_START = 0xA000
PONG_MEMORY_LEFT_Y = 0xFA00
PONG_MEMORY_RIGHT_Y = 0xFA02
PONG_MEMORY_BALL_X = 0xFA06
PONG_MEMORY_BALL_Y = 0xFA08
PONG_MEMORY_BALL_DIRECTION_X = 0xFA0A
PONG_MEMORY_BALL_DIRECTION_Y = 0xFA0C
PONG_MEMORY_GAME_END = 0xFA0E
PONG_MEMORY_RIGHT_TEMP = 0xFA10

# keyboard scancodes
KEY_UP = 0x48
KEY_DOWN = 0x50

.code16
.global init

init:
    # set graphics mode to 13h (320x200, 256bit color)
    mov $0x00, %ah
    mov $0x13, %al
    int $0x10

    # set default values for application variables
    mov $1, %ax
    mov %ax, (PONG_MEMORY_BALL_DIRECTION_X)

    mov $0, %ax
    mov %ax, (PONG_MEMORY_BALL_DIRECTION_Y)

    mov $HALF_SCREEN_WIDTH, %ax
    mov %ax, (PONG_MEMORY_BALL_X)

    mov $PONG_DEFAULT_Y, %ax
    mov %ax, (PONG_MEMORY_LEFT_Y)
    mov %ax, (PONG_MEMORY_RIGHT_Y)

    add $0x8, %ax
    mov %ax, (PONG_MEMORY_BALL_Y)

    jmp keyboard

main:
    # frame delay
    mov $0x00, %al
    mov $0x86, %ah
    mov $0x0000, %cx
    mov $0x2000, %dx
    int $0x15

keyboard:
    # check if a key is pressed
    mov $0x01, %ah
    int $0x16

    # prepare %cx
    mov (PONG_MEMORY_LEFT_Y), %cx
    # when a key is pressed get it
    jz drawLeft
    mov $0x00, %ah
    int $0x16

    cmp $KEY_UP, %ah
    je moveUp

    cmp $KEY_DOWN, %ah
    je moveDown

    jmp drawLeft

moveUp:
    sub $PONG_MOVEMENT_SPEED, %cx
    jmp afterLeftMove

moveDown:
    add $PONG_MOVEMENT_SPEED, %cx

afterLeftMove:
    call sanityCheckBottom

drawLeft:
    # persist position
    mov %cx, (PONG_MEMORY_LEFT_Y)

    mov $SCREEN_WIDTH, %ax
    mul %cx
    add $PONG_OFFSET, %ax

    call drawPlayer

drawRight:
    mov (PONG_MEMORY_RIGHT_Y), %ax
    mov $SCREEN_WIDTH, %cx
    mul %cx
    add $PONG_OFFSET_RIGHT, %ax

    call drawPlayer

ballPhysicsRight:
    # check if the right side (or right player) was hit
    mov (PONG_MEMORY_BALL_X), %ax

    cmp $PONG_BALL_MAX_X, %ax
    jl ballPhysicsLeft

    # we're behind the right player
    # let's check whether to trigger defeat
    mov (PONG_MEMORY_BALL_Y), %ax
    sub (PONG_MEMORY_RIGHT_Y), %ax

    call playerPhysics

    mov $-1, %cx
    mov %cx, (PONG_MEMORY_BALL_DIRECTION_X)
    jmp ballPhysicsTop

ballPhysicsLeft:
    # check if the left side (or left player) was hit
    cmp $PONG_BALL_MIN_X, %ax
    jg ballPhysicsTop

    # we're behind the left player
    # let's check whether to trigger defeat
    mov (PONG_MEMORY_BALL_Y), %ax
    sub (PONG_MEMORY_LEFT_Y), %ax

    call playerPhysics

    mov $1, %cx
    mov %cx, (PONG_MEMORY_BALL_DIRECTION_X)

ballPhysicsTop:
    # bounce from the top
    mov (PONG_MEMORY_BALL_Y), %ax
    cmp $0, %ax

    jg ballPhysicsBottom

    mov $1, %cx
    mov %cx, (PONG_MEMORY_BALL_DIRECTION_Y)

ballPhysicsBottom:
    # bounce from the bottom
    add $4, %ax
    cmp $SCREEN_HEIGHT, %ax

    jl moveBall

    mov $-1, %cx
    mov %cx, (PONG_MEMORY_BALL_DIRECTION_Y)

moveBall:
    # update ball's position
    mov (PONG_MEMORY_BALL_X), %ax
    add (PONG_MEMORY_BALL_DIRECTION_X), %ax
    mov %ax, (PONG_MEMORY_BALL_X)

    mov (PONG_MEMORY_BALL_Y), %ax
    add (PONG_MEMORY_BALL_DIRECTION_Y), %ax
    mov %ax, (PONG_MEMORY_BALL_Y)

moveRight:
    # update right player's position
    # follows the ball's Y
    mov (PONG_MEMORY_RIGHT_TEMP), %bx
    inc %bx
    cmp $PONG_COMPUTER_SPEED, %bx
    mov %bx, (PONG_MEMORY_RIGHT_TEMP)
    jl drawBall

    xor %bx, %bx
    mov %bx, (PONG_MEMORY_RIGHT_TEMP)

    mov (PONG_MEMORY_RIGHT_Y), %cx
    cmp (PONG_MEMORY_BALL_Y), %cx
    je drawBall
    jl rightMoveDown

    # move up
    dec %cx
    jmp afterRightMove

rightMoveDown:
    inc %cx

afterRightMove:
    # force the right player to not go out of screen (bottom)
    call sanityCheckBottom
    mov %cx, (PONG_MEMORY_RIGHT_Y)

drawBall:
    push %ds

    mov (PONG_MEMORY_BALL_Y), %ax
    mov $SCREEN_WIDTH, %cx
    mul %cx
    add (PONG_MEMORY_BALL_X), %ax

    push %ax
    push $VGA_START

    pop %ds
    pop %di

    sub $TWICE_SCREEN_WIDTH, %di
    call clear
    movl $0x00000000, (%di)
    call clear
    movl $0x000f0f00, (%di)
    call clear
    movl $0x0f0f0f0f, (%di)
    call clear
    movl $0x0f0f0f0f, (%di)
    call clear
    movl $0x000f0f00, (%di)
    call clear
    movl $0x00000000, (%di)

    pop %ds
    jmp main

# procedures
clear:
    add $SCREEN_WIDTH, %di
    movl $0x00000000, -1(%di)
    movl $0x00000000, 1(%di)
    ret

drawPlayer:
    push %ds
    push %ax
    push $VGA_START

    pop %ds
    pop %di

    sub $SCREEN_WIDTH, %di
    sub $SCREEN_WIDTH_TIMES_MOVEMENT_SPEED, %di

    xor %cx, %cx
    clearPlayerTopLoop:
        inc %cx

        movl $0x0000000, (%di)
        add $SCREEN_WIDTH, %di

        cmp $PONG_MOVEMENT_SPEED, %cx
        jle clearPlayerTopLoop

    xor %cx, %cx
    drawPlayerLoop:
        inc %cx

        movl $0x0f0f0f0f, (%di)
        add $SCREEN_WIDTH, %di

        cmp $PONG_HEIGHT, %cx
        jle drawPlayerLoop

    xor %cx, %cx
    clearPlayerBottomLoop:
        inc %cx

        movl $0x0000000, (%di)
        add $SCREEN_WIDTH, %di

        cmp $PONG_MOVEMENT_SPEED, %cx
        jle clearPlayerBottomLoop

    pop %ds
    ret

playerPhysics:
    # ends the game if either left or right side was hit
    cmp $PONG_COLLISION_MIN_Y, %ax
    jl init
    cmp $PONG_FORCE_FIELD, %ax
    jg playerPhysicsSecondCheck

    # change ball's vertical velocity if the player was hit from the bottom
    mov $-1, %cx
    mov %cx, (PONG_MEMORY_BALL_DIRECTION_Y)

playerPhysicsSecondCheck:
    cmp $PONG_COLLISION_MAX_Y, %ax
    jg init
    cmp $PONG_HEIGHT_HALF, %ax
    jl playerPhysicsEnd

    # change ball's vertical velocity if the player was hit from the top
    mov $1, %cx
    mov %cx, (PONG_MEMORY_BALL_DIRECTION_Y)

playerPhysicsEnd:
    ret

sanityCheckBottom:
    # force the player to not go out of screen (bottom)
    cmp $PONG_MAX_Y, %cx
    jl sanityCheckTop
    mov $PONG_MAX_Y, %cx

sanityCheckTop:
    # force the player to not go out of screen (top)
    cmp $PONG_MIN_Y, %cx
    jg sanityCheckEnd
    mov $PONG_MIN_Y, %cx

sanityCheckEnd:
    ret

.fill 510-(.-init), 1, 0
.word 0xaa55

