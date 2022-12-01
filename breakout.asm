################ CSC258H1F Fall 2022 Assembly Final Project ##################
# This file contains our implementation of Breakout.
#
# Student 1: Chris Wangzheng Jiang, 1008109574
# Student 2: Yahya Elgabra, 1008553030
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       4
# - Unit height in pixels:      4
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
# 
# Note: I wanted to use units of 2, or even 1, but doing so led to memory leaks,
# since the bitmap display was only allocated memory for around 8192 pixels 
# before the addresses would overlap with existing data storage.
# 
##############################################################################

.data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000

# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# The color of the walls (and top bar)
COLOR_WALLS:
	.word 0x00888888

# The thickness (in units) of the top bar
TOP_BAR_THICKNESS:
	.word 8

# The thickness (in units) of the side wall
SIDE_WALL_THICKNESS:
	.word 2

# The amount of gap (unis) between the top bar and the top-most row of bricks
TOP_GAP_THICKNESS:
	.word 8

# The thickness (in units) of a row of bricks
BRICK_ROW_THICKNESS:
	.word 2

# The number of brick rows 
BRICK_ROW_AMOUNT:
	.word 7

# An array containg the possible color that a row of bricks can have,
# is cycled through when drawing the bricks row by row
BRICK_COLORS:
	.word 0x007962e0
	.word 0x007073c6
	.word 0x006184ac
	.word 0x00529592
	.word 0x0043a678
	.word 0x0034b75e
	.word 0x0025c844

# Y position of the paddle , this is constant
# (the paddle is 1 unit thick)
PADDLE_Y:
	.word 61
	
# Y position of the second paddle , this is constant
# (the paddle is 1 unit thick)
PADDLE_2_Y:
	.word 58

# The movement vector for the ball.
# For each loop, BALL_X += VEC_X and BALL_Y += VEC_Y
# As of now, VEC_X and VEC_Y can only be 1 or -1.
VEC_X:
	.word 1
VEC_Y:
	.word 1

# The width of a single brick: (hardcoded)
# Note that a row of bricks has width of 60 units.
BRICK_WIDTH:
	.word 6

##############################################################################
# Mutable Data
##############################################################################

# The position of the ball (1 unit by 1 unit). Initial value is initial position.
# These 2 variables are dynamic.
BALL_X:
	.word 31
BALL_Y: 
	.word 57

# X position of the paddle, this is dynamic, 2 variables helps with
# collision detection, this also means the length of the paddle is adjustable
PADDLE_X_LEFT:
	.word 26
PADDLE_X_RIGHT:
	.word 36
	
# X position of the second paddle, this is dynamic, 2 variables helps with
# collision detection, this also means the length of the paddle is adjustable
PADDLE_2_X_LEFT:
	.word 26
PADDLE_2_X_RIGHT:
	.word 36
	
# The player's score, each time a brick is hit the score increments by 1
SCORE:
	.word 0
	
# Keeps track of the players' lives
LIVES:
	.word 0x00FF0000
	.word 0x00FF0000
	.word 0x00FF0000
	
##############################################################################
# Code
##############################################################################
.text
.globl main		# Run the Brick Breaker game.

main:
    # Initializing the game: 
	# Step 1: Draw the top bar and 2 side walls in the game
		jal draw_walls  # draw_walls() : draw the walls (and top bar) of the game
	# Step 2: Draw the bricks (a few colored rows)
		jal draw_bricks
    	# Step 3: Draw the paddle in the initial position
		jal draw_paddle
		jal draw_paddle_2
	# Step 4: Draw the ball in the initial position
		jal draw_ball
	# Step 5: Draw lives
		jal draw_lives
		# eMARS stuff
		lw   $t8, ADDR_DSPL
		li   $t9, 0x00888888
		sw   $t9, 0($t8)
		b pause
	

game_loop:
	# 1. Check if key has been pressed & which one has been pressed
		lw $t0, ADDR_KBRD			# t0 = address of the keyboard
		lw $t9, 0($t0)				# bool t9 = keyboard.isPressed();
		beq $t9, 1, keyboard_input  # if (t9 == 1): goto keyboard_input
		j no_keyboard_input			# else: goto no_keyboard_input

	keyboard_input:					# keyboard input detected
		lw $t9, 4($t0)				# t9 = ASCII(keyboard.keyPressed());
		
		beq $t9, 113, respond_to_q	# key is q: quit
		beq $t9, 97, respond_to_a	# key is a: move paddle left by 1 unit
		beq $t9, 100, respond_to_d	# key is d: move paddle right by 1 unit
		beq $t9, 44, respond_to_comma	# key is ,: move paddle_2 left by 1 unit
		beq $t9, 46, respond_to_period	# key is .: move paddle_2 right by 1 unit
		beq $t9, 112, respond_to_p	# key is p: pause game
		j end_key_responding		# key is invalid, continue as usual
		
		respond_to_q:  # Quit game
			li $v0, 10
			syscall
		respond_to_a:  # Move paddle left by 1 unit (if not at leftmost edge)
			jal move_paddle_left
			j end_key_responding
		respond_to_d:  # Move paddle right by 1 unit (if not at rightmost edge)
			jal move_paddle_right
			j end_key_responding
		respond_to_comma:  # Move paddle_2 left by 1 unit (if not at leftmost edge)
			jal move_paddle_2_left
			j end_key_responding
		respond_to_period:  # Move paddle_2 right by 1 unit (if not at rightmost edge)
			jal move_paddle_2_right
			j end_key_responding
		respond_to_p: # Pause game
			jal pause
			j end_key_responding
		end_key_responding:
			nop
	no_keyboard_input:				# no key pressed, continue as usual
    
	# 2a. Check for collisions (of ball), and, if bump into brick, delete brick
	# Method: adjust directional vectors of ball if ball touches edges
		# Step 1: Check top of ball : (BALL_X, BALL_Y - 1)
		jal collision_top
		# Step 2: Check left of ball: (BALL_X - 1, BALL_Y)
		jal collision_left
		# Step 3: Check right of ball: (BALL_X + 1, BALL_Y)
		jal collision_right
		# Step 4: Check bottom of ball: (BALL_X, BALL_Y + 1); also check for game-over
		jal collision_bottom

	# 2b. Update locations (ball)
		jal redraw_ball
		
	# 3. Draw the screen (misc updates - do we even have any?)

		lw $t8, SCORE
		beq $t8, 280, game_over
	# 4. Sleep
		# eMARS stuff
		lw   $t8, ADDR_DSPL
		li   $t9, 0x00888888
		sw   $t9, 0($t8)
		
		li $v0, 32
		li $a0, 50
		syscall

    #5. Go back to 1
    b game_loop


# void pause();
#
# Pauses the game.
# This function uses t0, t9. (unop)
pause:
	lw $t0, ADDR_KBRD		# t0 = address of the keyboard
	lw $t9, 0($t0)			# bool t9 = keyboard.isPressed();
	beq $t9, 1, pause_input		# if (t9 == 1): goto pause_input
	j no_pause_input		# else: goto no_pause_input
	
	pause_input:
	lw $t9, 4($t0)			# t9 = ASCII(keyboard.keyPressed());
	beq $t9, 112, unpause		# key is p: unpause game
	
	no_pause_input:
	b pause
	
	unpause:
	b game_loop
# =======================================================================================


# void redraw_ball();
# 
# Erases the ball at (BALL_X, BALL_Y) and redraws it at (BALL_X + VEC_X, BALL_Y + VEC_Y)
#
# This function uses t0, t1, t9.
redraw_ball:
	# PROLOGUE:
		nop
	# BODY
		lw $t0, BALL_X
		lw $t1, BALL_Y
		
		# Get the address of (BALL_X, BALL_Y) using get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		move $a0, $t0
		move $a1, $t1

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		# Now we erase the ball:
		li $t9, 0x00000000
		sw $t9, 0($v0)

		# Now, update the addresses of BALL_X and BALL_Y 
		lw $t9, VEC_X
		la $t2, BALL_X
		add $t0, $t0, $t9			# t0 = BALL_X + VEC_X
		sw $t0, 0($t2)				# BALL_X = BALL_X + VEC_X
		
		lw $t9, VEC_Y
		la $t2, BALL_Y
		add $t1, $t1, $t9			# t1 = BALL_Y + VEC_Y
		sw $t1, 0($t2)				# BALL_Y = BALL_Y + VEC_Y

		# Get the address of the new (BALL_X, BALL_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		move $a0, $t0
		move $a1, $t1

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		# Now we draw the new ball:
		li $t9, 0x00ffffff
		sw $t9, 0($v0)

	# EPILOGUE
		jr $ra
# =======================================================================================


# void game_over();
# 
# Game over! Currently only stops the game from running.
game_over:
	# sound stuff
	li $a0, 63
	li $a1, 1000
	li $a2, 120
	li $a3, 100
	li $v0, 33
	syscall
	# exit shamefully
	li $v0, 10
	syscall
	
	
# void reduce_hp();
#
# if player has more than 1 hp, remove 1 hp and retry, else, game over
reduce_hp:
	la $t0, LIVES
	lw $t1, 4($t0)
	beq $t1, 0, third_death
	lw $t1, 8($t0)
	beq $t1, 0, second_death
	first_death:
		li $t1, 0
		sw $t1, 8($t0)
		b reinitialize
		
	second_death: 
		li $t1, 0
		sw $t1, 4($t0)
		
	reinitialize: # resets ball and paddles positions, redraw them and lives
		la $t0, BALL_X
		li $t1, 31
		sw $t1, 0($t0)
		
		la $t0, BALL_Y
		li $t1, 57
		sw $t1, 0($t0)
		
		la $t0, PADDLE_X_LEFT
		li $t1, 26
		sw $t1, 0($t0)
		
		la $t0, PADDLE_X_RIGHT
		li $t1, 36
		sw $t1, 0($t0)
		
		la $t0, PADDLE_2_X_LEFT
		li $t1, 26
		sw $t1, 0($t0)
		
		la $t0, PADDLE_2_X_RIGHT
		li $t1, 36
		sw $t1, 0($t0)
		
		jal erase_ball_paddles
		jal draw_paddle
		jal draw_paddle_2
		jal draw_ball
		jal draw_lives
		# eMARS stuff
		lw   $t8, ADDR_DSPL
		li   $t9, 0x00888888
		sw   $t9, 0($t8)
		b pause
	third_death:
		li $t1, 0
		sw $t1, 0($t0)
		jal draw_lives
		# eMARS stuff
		lw   $t8, ADDR_DSPL
		li   $t9, 0x00888888
		sw   $t9, 0($t8)
		b game_over
		

# void erase_ball_paddles();
#
# cleans the area between the walls and under the bricks
erase_ball_paddles:
	# PROLOGUE:
		nop
	# BODY:
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		li $a0, 0
		la $t0, SIDE_WALL_THICKNESS
		lw $t0, 0($t0)		# x_start
		li $t3, 63		# y_end
		sub $t2, $t3, $t0	# x_end
		la $t4 TOP_BAR_THICKNESS
		lw $t5, 0($t4)
		move $t1, $t5
		la $t4 TOP_GAP_THICKNESS
		lw $t5, 0($t4)
		add $t1, $t1, $t5
		la $t4 BRICK_ROW_THICKNESS
		lw $t5, 0($t4)
		la $t4 BRICK_ROW_AMOUNT
		lw $t4, 0($t4)
		mult $t5, $t4
		mflo $t4
		add $t1, $t1, $t4	# y_start
		addi $sp, $sp, -16
		sw $t0, 0($sp)
		sw $t1, 4($sp)
		sw $t2, 8($sp)
		sw $t3, 12($sp)
		jal draw_rectangle

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ----------------------------------------------
	# EPILOGUE:
		jr $ra
# =======================================================================================

# void collision_bottom();
#
# Collision for the bottom of the ball (BALL_X, BALL_Y + 1).
# First, if BALL_Y + 1 == 64, then game over, otherwise:
# if it's a brick (i.e. not a paddle and not a wall), delete the corresponding brick.
# 
# This function uses t0, t1, t9.
collision_bottom:
	# PROLOGUE:
		nop
	# BODY:
		lw $t0, BALL_X
		lw $t1, BALL_Y
		addi $t1, $t1, 1			# (t0,t1) = (BALL_X , BALL_Y + 1)

		# Check for game-over conditions.
		beq $t1, 64, reduce_hp

		# Obtain the address for (BALL_X, BALL_Y + 1) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		move $a0, $t0
		move $a1, $t1

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ----------------------------------------------
		
		lw $t9, 0($v0)				# Get color from address
		
		beq $t9, 0x00000000, collision_bottom_end
		lw $t0, COLOR_WALLS
		beq $t9, $t0, collision_bottom_bounce
		beq $t9, 0x00ffffff, collision_bottom_bounce
		
		j collision_bottom_brick	# If not those colors, then it's a brick:

		collision_bottom_bounce:	# Flip the sign of VEC_Y
			# Call function play_sound(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			la $t0, VEC_Y
			lw $t1, VEC_Y
			sub $t1, $0, $t1
			sw $t1, 0($t0)
			j collision_bottom_end

		collision_bottom_brick:	
			# Call function play_sound() and update_score(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			jal update_score
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			# Flip the sign of VEC_Y
			la $t0, VEC_Y
			lw $t1, VEC_Y
			sub $t1, $0, $t1
			sw $t1, 0($t0)

			# Call function change_brick_at_pos(BALL_X, BALL_Y + 1): ----------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
		
			lw $a0, BALL_X
			lw $a1, BALL_Y
			addi $a1, $a1, 1		# (a0,a1) = (BALL_X, BALL_Y + 1)

			jal change_brick_at_pos

			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------

	collision_bottom_end:
	# EPILOGUE:
		jr $ra
# =======================================================================================



# void collision_right();
#
# Collision for the right of the ball (BALL_X + 1, BALL_Y).
# And if it's a brick (i.e. not a paddle and not a wall), delete the corresponding brick.
# 
# This function uses t0, t1, t9.
collision_right:
	# PROLOGUE:
		nop
	# BODY:
		lw $t0, BALL_X
		lw $t1, BALL_Y
		addi $t0, $t0, 1			# (t0,t1) = (BALL_X + 1, BALL_Y)

		# Obtain the address for (BALL_X + 1, BALL_Y) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		move $a0, $t0
		move $a1, $t1

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ----------------------------------------------
		
		lw $t9, 0($v0)				# Get color from address
		
		beq $t9, 0x00000000, collision_right_end
		lw $t0, COLOR_WALLS
		beq $t9, $t0, collision_right_bounce
		beq $t9, 0x00ffffff, collision_right_bounce

		j collision_right_brick		# If not those colors, then it's a brick:

		collision_right_bounce:		# Flip the sign of VEC_X
			# Call function play_sound(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			la $t0, VEC_X
			lw $t1, VEC_X
			sub $t1, $0, $t1
			sw $t1, 0($t0)
			j collision_right_end

		collision_right_brick:
			# Call function play_sound() and update_score(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			jal update_score
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			# Flip the sign of VEC_X
			la $t0, VEC_X
			lw $t1, VEC_X
			sub $t1, $0, $t1
			sw $t1, 0($t0)
		
			# Call function change_brick_at_pos(BALL_X + 1, BALL_Y): ----------
			addi $sp, $sp, -4
			sw $ra, 0($sp)

			lw $a0, BALL_X
			lw $a1, BALL_Y
			addi $a0, $a0, 1		# (a0,a1) = (BALL_X + 1, BALL_Y)

			jal change_brick_at_pos

			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------

	collision_right_end:
	# EPILOGUE:
		jr $ra
# =======================================================================================



# void collision_left();
#
# Collision for the left of the ball (BALL_X - 1, BALL_Y).
# And if it's a brick (i.e. not a paddle and not a wall), delete the corresponding brick.
# 
# This function uses t0, t1, t9.
collision_left:
	# PROLOGUE:
		nop
	# BODY:
		lw $t0, BALL_X
		lw $t1, BALL_Y
		addi $t0, $t0, -1			# (t0,t1) = (BALL_X - 1, BALL_Y)

		# Obtain the address for (BALL_X - 1, BALL_Y) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		move $a0, $t0
		move $a1, $t1

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ----------------------------------------------
		
		lw $t9, 0($v0)				# Get color from address
		
		beq $t9, 0x00000000, collision_left_end
		lw $t0, COLOR_WALLS
		beq $t9, $t0, collision_left_bounce
		beq $t9, 0x00ffffff, collision_left_bounce
		
		j collision_left_brick		# If not those colors, then it's a brick:

		collision_left_bounce:		# Flip the sign of VEC_X
			# Call function play_sound(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			la $t0, VEC_X
			lw $t1, VEC_X
			sub $t1, $0, $t1
			sw $t1, 0($t0)
			j collision_left_end

		collision_left_brick:
			# Call function play_sound() and update_score(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			jal update_score
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			# Flip the sign of VEC_X
			la $t0, VEC_X
			lw $t1, VEC_X
			sub $t1, $0, $t1
			sw $t1, 0($t0)
		
			# Call function change_brick_at_pos(BALL_X - 1, BALL_Y): ----------
			addi $sp, $sp, -4
			sw $ra, 0($sp)

			lw $a0, BALL_X
			lw $a1, BALL_Y
			addi $a0, $a0, -1		# (a0,a1) = (BALL_X - 1, BALL_Y)

			jal change_brick_at_pos

			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------

	collision_left_end:
	# EPILOGUE:
		jr $ra
# =======================================================================================



# void collision_top();
#
# Collision for the top of the ball (BALL_X, BALL_Y - 1).
# And if it's a brick (i.e. not a paddle and not a wall), delete the corresponding brick.
# 
# This function uses t0, t1.
collision_top:
	# PROLOGUE:
		nop
	# BODY:
		lw $t0, BALL_X
		lw $t1, BALL_Y
		addi $t1, $t1, -1			# (t0,t1) = (BALL_X, BALL_Y - 1)

		# Obtain the address for (BALL_X, BALL_Y - 1) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		move $a0, $t0
		move $a1, $t1

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ----------------------------------------------
		
		lw $t9, 0($v0)				# Get color from address
		
		beq $t9, 0x00000000, collision_top_end
		lw $t0, COLOR_WALLS
		beq $t9, $t0, collision_top_bounce
		beq $t9, 0x00ffffff, collision_top_bounce
		
		j collision_top_brick		# If not those colors, then it's a brick:

		collision_top_bounce:		# Flip the sign of VEC_Y
			# Call function play_sound(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			la $t0, VEC_Y
			lw $t1, VEC_Y
			sub $t1, $0, $t1
			sw $t1, 0($t0)
			j collision_top_end

		collision_top_brick:
			# Call function play_sound() and update_score(): ------------------------------------
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			jal play_sound
			jal update_score
			
			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------
			# Flip the sign of VEC_Y
			la $t0, VEC_Y
			lw $t1, VEC_Y
			sub $t1, $0, $t1
			sw $t1, 0($t0)
			# Call function change_brick_at_pos(BALL_X, BALL_Y - 1): ----------
			addi $sp, $sp, -4
			sw $ra, 0($sp)

			lw $a0, BALL_X
			lw $a1, BALL_Y
			addi $a1, $a1, -1		# (a0,a1) = (BALL_X, BALL_Y - 1)

			jal change_brick_at_pos

			lw $ra, 0($sp)
			add $sp, $sp, 4
			# Function call complete ------------------------------------------

	collision_top_end:
	# EPILOGUE:
		jr $ra
# =======================================================================================
# void play_sound();
# Produces sound when a collision is detected
# mutates a0, a1, a2, a3, v0
play_sound:
	# PROLOGUE:
		nop
	# BODY:
		li $a0, 63
		li $a1, 500
		li $a2, 121
		li $a3, 100
		li $v0, 31
		syscall
	# EPILOGUE:
		jr $ra
		
# void update_score();
# Increments score when a brick is hit
update_score:
	# PROLOGUE:
		nop
	# BODY:
		lw $t0, SCORE
		addi $t0, $t0, 1
		sw $t0, SCORE
		move $a0, $t0
		move $a1, $a0
		la $a0, ADDR_DSPL
		addi $a0, $a0, 1
	# EPILOGUE:
		jr $ra
# =======================================================================================


# void change_brick_at_pos(int X, int Y);
# 
# Changes the brick's color that contains the corresponding pixel (X,Y).
# Parameters:
#		a0 = X ; a1 = Y
# This function uses t0.
change_brick_at_pos:
	# PROLOGUE:
		nop
	# BODY
		# Step 0: get next color
		addi $sp, $sp, -16
		sw $t0, 0($sp)
		sw $t1, 4($sp)
		sw $t2, 8($sp)
		sw $t3, 12($sp)
			
		srl $t1, $t9, 16
		sll $t1, $t1, 16 		# $t1 is R
		srl $t2, $t9, 8
		sll $t2, $t2, 24
		srl $t2, $t2, 16		# $t2 is G
		sll $t3, $t9, 24
		srl $t3, $t3, 24		# $t3 is B
		li $t0, 0x000F0000
		sub $t1, $t1, $t0 		# $t1 is next R
		addi $t2, $t2, 0x00001100	# $t2 is next G
		li $t0, 0x0000001a
		sub $t3, $t3, $t0 		# $t3 is next B
		add $a2, $t1, $t2
		add $a2, $a2, $t3		# $a2 is next color
			
		lw $t0, 0($sp)
		lw $t1, 4($sp)
		lw $t2, 8($sp)
		lw $t3, 12($sp)
		addi $sp, $sp, 16
		# Call function check_color(ignore, ignore, color COLOR): --------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		jal check_color

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ------------------------------------------
		# Step 1: change X, Y to their relative positions
		# (X - SIDE_WALL_TKNS, Y - TOP_BAR_TKNS - TOP_GAP_TKNS)
		lw $t0, SIDE_WALL_THICKNESS
		sub $a0, $a0, $t0
		lw $t0, TOP_BAR_THICKNESS
		sub $a1, $a1, $t0
		lw $t0, TOP_GAP_THICKNESS
		sub $a1, $a1, $t0
		# Step 2: X = (X / BRICK_WIDTH) * BRICK_WIDTH ;
		# Y = (Y / BRICK_ROW_THICKNESS) * BRICK_ROW_THICKNESS ;
		lw $t0, BRICK_WIDTH
		div $a0, $t0
		mflo $a0
		mult $a0, $t0
		mflo $a0
		
		lw $t0, BRICK_ROW_THICKNESS
		div $a1, $t0
		mflo $a1
		mult $a1, $t0
		mflo $a1
		# Step 3: X = X + SIDE_WALL_TKNS ; Y = Y + TOP_BAR_TKNS + TOP_GAP_TKNS
		lw $t0, SIDE_WALL_THICKNESS
		add $a0, $a0, $t0
		lw $t0, TOP_BAR_THICKNESS
		add $a1, $a1, $t0
		lw $t0, TOP_GAP_THICKNESS
		add $a1, $a1, $t0
		
		# Step 4: Call function draw_rectangle to draw COLOR from (X,Y) to 
		# (X + BRICK_WIDTH - 1, Y + BRICK_ROW_THICKNESS - 1): -----------------
		add $sp, $sp, -4
		sw $ra, 0($sp)				# Preserve $ra
		
		# Parameters: 
		addi $sp, $sp, -16
		sw $a0, 0($sp)
		sw $a1, 4($sp)

		lw $t0, BRICK_WIDTH
		add $a0, $a0, $t0
		addi $a0, $a0, -1
		sw $a0, 8($sp)

		lw $t0, BRICK_ROW_THICKNESS
		add $a1, $a1, $t0
		addi $a1, $a1, -1
		sw $a1, 12($sp)

		move $a0, $a2

		jal draw_rectangle			# FUNCTION CALL

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete ----------------------------------------------
	# EPILOGUE
		jr $ra

# check_color(ignore, ignore, color COLOR):
# checks the new color at a2 and, if it is 0xTODO, change it to black to delete the brick
check_color:
	bne $a2, 0x0016D92A, check_color_end
	li $a2, 0x00000000
	check_color_end:
		jr $ra

# =======================================================================================


# void move_paddle_left();
#
# If the paddle hasn't reached the left-most possible position, move the paddle left
# by 1 unit. (including actually drawing)
# 
# This function uses t0, t1, t9.
move_paddle_left:
	# PROLOGUE
		nop
	# BODY
		# check if the paddle is touching the left wall, if so, terminate
		lw $t0, SIDE_WALL_THICKNESS
		lw $t1, PADDLE_X_LEFT
		beq $t0, $t1, move_paddle_left_end

		# Move the paddle to the left by 1 unit:

		# Change the coords first:
		la $t0, PADDLE_X_LEFT
		addi $t1, $t1, -1		# t1 = PADDLE_X_LEFT - 1
		sw $t1, 0($t0)			# PADDLE_X_LEFT = t1
		
		la $t0, PADDLE_X_RIGHT
		lw $t1, PADDLE_X_RIGHT
		addi $t1, $t1, -1		# t1 = PADDLE_X_RIGHT - 1
		sw $t1, 0($t0)			# PADDLE_X_RIGHT = t1

		# Then change the pixels:
		# First, get the address of (PADDLE_X_LEFT, PADDLE_Y) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_X_LEFT
		lw $a1, PADDLE_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00ffffff
		sw $t9, 0($v0)			# Draw the left pixel

		# Then, get the address of (PADDLE_X_RIGHT + 1, PADDLE_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_X_RIGHT
		addi $a0, $a0, 1
		lw $a1, PADDLE_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00000000
		sw $t9, 0($v0)			# Erase the right pixel
		
	move_paddle_left_end:
	# EPILOGUE
		jr $ra
# =======================================================================================


# void move_paddle_right();
#
# If the paddle hasn't reached the right-most possible position, move the paddle right
# by 1 unit. (including actually drawing)
# 
# This function uses t0, t1, t9.
move_paddle_right:
	# PROLOGUE
		nop
	# BODY
		# check if the paddle is touching the right wall, if so, terminate
		lw $t0, SIDE_WALL_THICKNESS
		li $t1, 63
		sub $t0, $t1, $t0		# t0 = 63 - SIDE_WALL_THICKNESS
		lw $t1, PADDLE_X_RIGHT	# t1 = PADDLE_X_RIGHT
		beq $t0, $t1, move_paddle_right_end

		# Move the paddle to the right by 1 unit:

		# Change the coords first:		
		la $t0, PADDLE_X_RIGHT
		addi $t1, $t1, 1		# t1 = PADDLE_X_RIGHT + 1
		sw $t1, 0($t0)			# PADDLE_X_RIGHT = t1

		la $t0, PADDLE_X_LEFT
		lw $t1, PADDLE_X_LEFT
		addi $t1, $t1, 1		# t1 = PADDLE_X_LEFT + 1
		sw $t1, 0($t0)			# PADDLE_X_LEFT = t1

		# Then change the pixels:
		# First, get the address of (PADDLE_X_RIGHT, PADDLE_Y) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_X_RIGHT
		lw $a1, PADDLE_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00ffffff
		sw $t9, 0($v0)			# Draw the right pixel

		# Then, get the address of (PADDLE_X_LEFT - 1, PADDLE_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_X_LEFT
		addi $a0, $a0, -1
		lw $a1, PADDLE_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00000000
		sw $t9, 0($v0)			# Erase the left pixel

	move_paddle_right_end:
	# EPILOGUE
		jr $ra

# void move_paddle_2_left();
#
# If the second paddle hasn't reached the left-most possible position, move the paddle left
# by 1 unit. (including actually drawing)
# 
# This function uses t0, t1, t9.
move_paddle_2_left:
	# PROLOGUE
		nop
	# BODY
		# check if the paddle is touching the left wall, if so, terminate
		lw $t0, SIDE_WALL_THICKNESS
		lw $t1, PADDLE_2_X_LEFT
		beq $t0, $t1, move_paddle_2_left_end

		# Move the paddle to the left by 1 unit:

		# Change the coords first:
		la $t0, PADDLE_2_X_LEFT
		addi $t1, $t1, -1		# t1 = PADDLE_2_X_LEFT - 1
		sw $t1, 0($t0)			# PADDLE_2_X_LEFT = t1
		
		la $t0, PADDLE_2_X_RIGHT
		lw $t1, PADDLE_2_X_RIGHT
		addi $t1, $t1, -1		# t1 = PADDLE_2_X_RIGHT - 1
		sw $t1, 0($t0)			# PADDLE_2_X_RIGHT = t1

		# Then change the pixels:
		# First, get the address of (PADDLE_2_X_LEFT, PADDLE_2_Y) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_2_X_LEFT
		lw $a1, PADDLE_2_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00ffffff
		sw $t9, 0($v0)			# Draw the left pixel

		# Then, get the address of (PADDLE_2_X_RIGHT + 1, PADDLE_2_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_2_X_RIGHT
		addi $a0, $a0, 1
		lw $a1, PADDLE_2_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00000000
		sw $t9, 0($v0)			# Erase the right pixel
		
	move_paddle_2_left_end:
	# EPILOGUE
		jr $ra
# =======================================================================================


# void move_paddle_2_right();
#
# If the second paddle hasn't reached the right-most possible position, move the paddle right
# by 1 unit. (including actually drawing)
# 
# This function uses t0, t1, t9.
move_paddle_2_right:
	# PROLOGUE
		nop
	# BODY
		# check if the paddle is touching the right wall, if so, terminate
		lw $t0, SIDE_WALL_THICKNESS
		li $t1, 63
		sub $t0, $t1, $t0		# t0 = 63 - SIDE_WALL_THICKNESS
		lw $t1, PADDLE_2_X_RIGHT	# t1 = PADDLE_2_X_RIGHT
		beq $t0, $t1, move_paddle_2_right_end

		# Move the paddle to the right by 1 unit:

		# Change the coords first:		
		la $t0, PADDLE_2_X_RIGHT
		addi $t1, $t1, 1		# t1 = PADDLE_2_X_RIGHT + 1
		sw $t1, 0($t0)			# PADDLE_2_X_RIGHT = t1

		la $t0, PADDLE_2_X_LEFT
		lw $t1, PADDLE_2_X_LEFT
		addi $t1, $t1, 1		# t1 = PADDLE_2_X_LEFT + 1
		sw $t1, 0($t0)			# PADDLE_2_X_LEFT = t1

		# Then change the pixels:
		# First, get the address of (PADDLE_2_X_RIGHT, PADDLE_2_Y) with get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_2_X_RIGHT
		lw $a1, PADDLE_2_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00ffffff
		sw $t9, 0($v0)			# Draw the right pixel

		# Then, get the address of (PADDLE_2_X_LEFT - 1, PADDLE_2_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, PADDLE_2_X_LEFT
		addi $a0, $a0, -1
		lw $a1, PADDLE_2_Y
		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------
		li $t9, 0x00000000
		sw $t9, 0($v0)			# Erase the left pixel

	move_paddle_2_right_end:
	# EPILOGUE
		jr $ra
# =======================================================================================

# void draw_ball();
# 
# Draws the ball (1 unit by 1 unit) at (BALL_X, BALL_Y).
# No draw_rectangle call needed. Ball's color is 0x00ffffff.
# 
# This function uses t9.
draw_ball:
	# PROLOGUE:
		nop
	# BODY:
		# Get the address of (BALL_X, BALL_Y) using get_address_from_coords
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)

		lw $a0, BALL_X
		lw $a1, BALL_Y

		jal get_address_from_coords

		lw $ra, 0($sp)
		add $sp, $sp, 4
		# Function call complete  ---------------------------------------------

		li $t9, 0x00ffffff
		sw $t9, 0($v0)
	# EPILOGUE:
		jr $ra
# =======================================================================================


# void draw_paddle();
# 
# Draws the paddle at it's position. 
# The y-level of the paddle is constant, at PADDLE_Y.
# The x-position of the paddle is stored in PADDLE_X_LEFT and PADDLE_X_RIGHT.
# Note: PADDLE_Y is a constant. PADDLE_X_LEFT and PADDLE_X_RIGHT are dynamic.
# This also means that the length and the y-level of the paddle is adjustable.
# Also Note: Paddle's color is hardcoded to 0x00ffffff, same as the ball.
# 
# This function uses t9.
draw_paddle:
	# PROLOGUE:
		nop
	# BODY:
		# Draw a line from (PADDLE_X_LEFT, PADDLE_Y) to (PADDLE_X_RIGHT, PADDLE_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)			# preserve $ra

		li $a0, 0x00ffffff
		
		addi $sp, $sp, -16

		lw $t9, PADDLE_Y
		sw $t9, 4($sp)
		sw $t9, 12($sp)

		lw $t9, PADDLE_X_LEFT
		sw $t9, 0($sp)

		lw $t9, PADDLE_X_RIGHT
		sw $t9, 8($sp)

		jal draw_rectangle		# FUNCTION CALL

		lw $ra, 0($sp)
		addi $sp, $sp, 4		# restore $ra
		# Function call complete ----------------------------------------------
	# EPILOGUE:
		jr $ra
# =======================================================================================


# void draw_paddle_2();
# 
# Draws the second paddle at it's position. 
# The y-level of the paddle is constant, at PADDLE_2_Y.
# The x-position of the paddle is stored in PADDLE_2_X_LEFT and PADDLE_2_X_RIGHT.
# Note: PADDLE_2_Y is a constant. PADDLE_2_X_LEFT and PADDLE_2_X_RIGHT are dynamic.
# This also means that the length and the y-level of the paddle is adjustable.
# Also Note: Paddle's color is hardcoded to 0x00ffffff, same as the ball.
# 
# This function uses t9.
draw_paddle_2:
	# PROLOGUE:
		nop
	# BODY:
		# Draw a line from (PADDLE_X_LEFT, PADDLE_Y) to (PADDLE_X_RIGHT, PADDLE_Y)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)			# preserve $ra

		li $a0, 0x00ffffff
		
		addi $sp, $sp, -16

		lw $t9, PADDLE_2_Y
		sw $t9, 4($sp)
		sw $t9, 12($sp)

		lw $t9, PADDLE_2_X_LEFT
		sw $t9, 0($sp)

		lw $t9, PADDLE_2_X_RIGHT
		sw $t9, 8($sp)

		jal draw_rectangle		# FUNCTION CALL

		lw $ra, 0($sp)
		addi $sp, $sp, 4		# restore $ra
		# Function call complete ----------------------------------------------
	# EPILOGUE:
		jr $ra
# =======================================================================================


# void draw_bricks();
# 
# Draws BRICK_ROW_AMOUNT rows of bricks. Each row is BRICK_ROW_THICKNESS units thick.
# Color is stored in the BRICK_COLORS[7] array.
# 
# This function uses t0, t1, t2, t9.
draw_bricks:
	# PROLOGUE:
		nop
	# BODY:
		# Loop BRICK ROW_AMOUNT times for drawing the rows of bricks
		la $t0, BRICK_COLORS	# t0 = base address of BRICK_COLORS[7] array
		li $t1, 0
		lw $t2, BRICK_ROW_AMOUNT
	draw_bricks_loop:
		beq $t1, $t2, draw_bricks_loop_end

		# Draw a rectangle from:
		# (SIDE_WALL_TKNS, TOP_BAR_TKNS + TOP_GAP_TKNS + t1 * BRICK_ROW_TKNS) 
		# to 
		# (63 - SIDE_WALL_TKNS, TOP_BAR_TKNS + TOP_GAP_TKNS + (t1+1) * BRICK_ROW_TKNS - 1)
		# with color
		# BRICK_COLORS[t1] (the value at BRICK_COLORS + (4*t1))
		# Function call: ------------------------------------------------------
		
		# Preserve variables on stack: $ra, t0, t1, t2 
		# (since they will be altered by draw_rectangle)
		addi $sp, $sp, -16
		sw $ra, 0($sp)
		sw $t0, 4($sp)
		sw $t1, 8($sp)
		sw $t2, 12($sp)

		# Passing the parameters: (color)
		lw $a0, 0($t0)			# a0 = BRICK_COLORS[t1]
	
		# Passing the parameters: (coordinates)
		addi $sp, $sp, -16
		
		lw $t9, SIDE_WALL_THICKNESS
		sw $t9, 0($sp)

		lw $t9, BRICK_ROW_THICKNESS
		mult $t9, $t1			# t1 * BRICK_ROW_THICKNESS
		mflo $t9				# t9 = t1 * BRICK_ROW_THICKNESS
		lw $t0, TOP_GAP_THICKNESS
		add $t9, $t9, $t0
		lw $t0, TOP_BAR_THICKNESS
		add $t9, $t9, $t0
		sw $t9, 4($sp)

		li $t9, 63
		lw $t0, SIDE_WALL_THICKNESS
		sub $t9, $t9, $t0
		sw $t9, 8($sp)

		move $t9, $t1			# t9 = t1
		addi $t9, $t9, 1		# t9 = t1 + 1
		lw $t0, BRICK_ROW_THICKNESS
		mult $t9, $t0			# (t1 + 1) * BRICK_ROW_THICKNESS
		mflo $t9
		lw $t0, TOP_GAP_THICKNESS
		add $t9, $t9, $t0
		lw $t0, TOP_BAR_THICKNESS
		add $t9, $t9, $t0
		addi $t9, $t9, -1
		sw $t9, 12($sp)
		
		jal draw_rectangle		# FUNCTION CALL

		# Restore variables from stack: $ra, t0, t1, t2 
		lw $ra, 0($sp)
		lw $t0, 4($sp)
		lw $t1, 8($sp)
		lw $t2, 12($sp)
		addi $sp, $sp, 16
		# Function call complete ----------------------------------------------

		addi $t0, $t0, 4
		addi $t1, $t1, 1
		j draw_bricks_loop
	draw_bricks_loop_end:
	# EPILOGUE:
		jr $ra
# =======================================================================================


# void draw_walls();
# 
# Draws the 2 side walls, and the top bar of the game.
# No parameters, uses global variables: COLOR_WALLS, TOP_BAR_THICKNESS, SIDE_WALL_THICKNESS
# 
# This function uses t1, t2.
draw_walls:
	# PROLOGUE:
		nop
	# BODY:
		# Draw the top bar: a rectangle from (0,0) to (63, TOP_BAR_THICKNESS - 1)
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)			# Preserve $ra first, then pass parameters!

		lw $a0, COLOR_WALLS

		addi $sp, $sp, -16

		sw $0, 0($sp)
		sw $0, 4($sp)

		li $t1, 63
		sw $t1, 8($sp)

		lw $t1, TOP_BAR_THICKNESS
		addi $t1, $t1, -1
		sw $t1, 12($sp)

		jal draw_rectangle		# FUNCTION CALL

		lw $ra, 0($sp)
		addi $sp, $sp, 4		# Restore $ra
		# Function call complete ----------------------------------------------
		
		# Draw the left side bar: a rectangle from (0, TOP_BAR_THICKNESS) to 
		# (SIDE_WALL_THICKNESS - 1, 63), function call: ----------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)			# Preserve $ra first, then pass parameters!

		lw $a0, COLOR_WALLS

		addi $sp, $sp, -16

		sw $0, 0($sp)

		lw $t1, TOP_BAR_THICKNESS
		sw $t1, 4($sp)

		lw $t1, SIDE_WALL_THICKNESS
		addi $t1, $t1, -1
		sw $t1, 8($sp)

		li $t1, 63
		sw $t1, 12($sp)

		jal draw_rectangle		# FUNCTION CALL

		lw $ra, 0($sp)
		addi $sp, $sp, 4		# Restore $ra
		# Function call complete ----------------------------------------------
		
		# Draw the right side bar: a rectangle from (64 - SIDE_WALL_THICKNESS,
		# TOP_BAR_THICKNESS) to (63, 63). Function call: --------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)			# Preserve $ra first, then pass parameters!

		lw $a0, COLOR_WALLS

		addi $sp, $sp, -16

		lw $t1, SIDE_WALL_THICKNESS
		li $t2, 64
		sub $t1, $t2, $t1
		sw $t1, 0($sp)

		lw $t1, TOP_BAR_THICKNESS
		sw $t1, 4($sp)

		li $t1, 63
		sw $t1, 8($sp)
		sw $t1, 12($sp)

		jal draw_rectangle		# FUNCTION CALL

		lw $ra, 0($sp)
		addi $sp, $sp, 4		# Restore $ra
		# Function call complete ----------------------------------------------

	# EPILOGUE:
		jr $ra
# =======================================================================================

# void draw_lives();
#
# Draws squares at the top of the screen, 3 if players have 3 lives, 2 if players have
# 2, and 1 if players have 1
draw_lives:
	# PROLOGUE:
		nop
	# BODY:
		# Function call: ------------------------------------------------------
		addi $sp, $sp, -4
		sw $ra, 0($sp)			# Preserve $ra first, then pass parameters!

		
		# draw the three hearts
		la $a0, LIVES
		lw $a0, 0($a0)
		li $t0, 2		# x_start
		li $t1, 2		# y_start
		li $t2, 4		# x_end
		li $t3, 4		# y_end
		addi $sp, $sp, -16
		sw $t0, 0($sp) 
		sw $t1, 4($sp)
		sw $t2, 8($sp)
		sw $t3, 12($sp)		
		jal draw_rectangle		# FUNCTION CALL
		
		la $a0, LIVES
		lw $a0, 4($a0)
		li $t0, 6
		li $t1, 2
		li $t2, 8
		li $t3, 4
		addi $sp, $sp, -16
		sw $t0, 0($sp)
		sw $t1, 4($sp)
		sw $t2, 8($sp)
		sw $t3, 12($sp)		
		jal draw_rectangle		# FUNCTION CALL
		
		la $a0, LIVES
		lw $a0, 8($a0)
		li $t0, 10
		li $t1, 2
		li $t2, 12
		li $t3, 4
		addi $sp, $sp, -16
		sw $t0, 0($sp)
		sw $t1, 4($sp)
		sw $t2, 8($sp)
		sw $t3, 12($sp)		
		jal draw_rectangle		# FUNCTION CALL


		lw $ra, 0($sp)
		addi $sp, $sp, 4		# Restore $ra
		# Function call complete ----------------------------------------------
	# EPILOGUE:
		jr $ra

# =======================================================================================


# void draw_rectangle(int x_start, int y_start, int x_end, int y_end, Color color); 
# 
# Draws a rectangle from (x_start, y_start) to (x_end, y_end), INCLUSIVE.
# (Can also be used to draw lines, just sayin')
#
# Parameter preconditions: 0 <= x_start <= x_end <= 63 ; 0 <= y_start <= y_end <= 63
# 
# parameters are passed through like so: 
#		$a0 = color
#		Stack: [ y_end, x_end, y_start, x_start <- ($sp)
# 
# This function will mutate t0, t1, t2, t3, t9 (and a0, a1, v0).
draw_rectangle:
	# PROLOGUE: takes the parameters from stack; reserves space for s0, s1, s2, s3
		# Pop parameters from stack:
		lw $t0, 0($sp)			# t0 = x_start
		lw $t1, 4($sp)			# t1 = y_start
		lw $t2, 8($sp)			# t2 = x_end
		lw $t3, 12($sp)			# t3 = y_end
		addi $sp, $sp, 16  	 	# retract stack for 4 words
		# Back up s0, s1, s2, s3
		addi $sp, $sp, -16  	# extend the stack for 4 words
		sw $s0, 0($sp)			# s0 -> sp
		sw $s1, 4($sp)			# s1 -> sp + 4
		sw $s2, 8($sp)			# s2 -> sp + 8
		sw $s3, 12($sp)			# s3 -> sp + 12
	# BODY:
		add $s0, $0, $t0		# s0 = x_start
		add $s1, $0, $t1		# s1 = y_start
		add $s2, $0, $t2		# s2 = x_end
		add $s3, $0, $t3		# s3 = y_end

		# Looping through [y_start, y_end], INCLUSIVE:
		addi $t0, $s1, 0		# t0 = y_start
		addi $t1, $s3, 1		# t1 = y_end + 1
	draw_rectangle_loop_y:
		beq $t0, $t1, draw_rectangle_loop_y_end  # for t0 in [y_start, y_end]
		
		# Looping through [x_start, x_end], INCLUSIVE:
		addi $t2, $s0, 0		# t2 = x_start
		addi $t3, $s2, 1		# t3 = x_end + 1
	draw_rectangle_loop_x:
		beq $t2, $t3, draw_rectangle_loop_x_end  # for t2 in [x_start, x_end]

		# Setting the color at the address for (t2, t0) as "color":

		# Calling function get_address_from_coords(t2, t0) --------------------
		# Preserve $ra, a0
		addi $sp, $sp, -8		# extend stack by 2
		sw $ra, 0($sp)			# Back up $ra
		sw $a0, 4($sp)			# Back up $a0 (the color)
		
		add $a0, $0, $t2		# load parameter a0 = t2
		add $a1, $0, $t0		# load parameter a1 = t0

		jal get_address_from_coords  # FUNCTION CALL
		
		lw $ra, 0($sp)			# restore $ra
		lw $a0, 4($sp)			# restore $a0 (the color)
		addi $sp, $sp, 8		# retract stack by 2
		# Function call complete ----------------------------------------------

		sw $a0, 0($v0)			# puts color in the current pixel address for (t2, t0)
		
		addi $t2, $t2, 1
		j draw_rectangle_loop_x
	draw_rectangle_loop_x_end:

		addi $t0, $t0, 1
		j draw_rectangle_loop_y
	draw_rectangle_loop_y_end:
	# EPILOGUE: restore s0, s1, s2, s3
		lw $s0, 0($sp)
		lw $s1, 4($sp)
		lw $s2, 8($sp)
		lw $s3, 12($sp)
		addi $sp, $sp, 16

		jr $ra
# =======================================================================================


# Address get_address_from_coords(int x, int y);
# 
# Returns the address in memory for the pixel at position (x,y). 
#		Parameters: $a0 = x, $a1 = y
#		Result: $v0 = addr(x,y)
# 
# This function mutates no registers of importance (only a0, a1, v0).
get_address_from_coords:
	# PROLOGUE:
		nop
	# BODY:
		sll $a0, $a0, 2			# a0 = a0 * 4 * 1 (a0 is now x * 4)
		sll $a1, $a1, 8			# a1 = a1 * 4 * 64 (a1 is now y * 256)

		lw $v0, ADDR_DSPL		# v0 = ADDR_DSPL[0]
		add $v0, $v0, $a0		# v0 += a0 
		add $v0, $v0, $a1		# v0 += a1 (v0 is now ADDR_DSPL[0] + (x*4) + (y*4*64))
	# EPILOGUE:
		jr $ra
# =======================================================================================

