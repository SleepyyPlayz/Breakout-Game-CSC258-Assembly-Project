################ CSC258H1F Fall 2022 Assembly Final Project ##################
# This file contains our implementation of Breakout.
#
# Student 1: Chris Wangzheng Jiang, 1008109574
# Student 2: Yahya Elgabra, 
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
	.word 0x00cccccc

# The thickness (in units) of the top bar
TOP_BAR_THICKNESS:
	.word 8

# The thickness (in units) of the side wall
SIDE_WALL_THICKNESS:
	.word 2

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
.text
.globl main		# Run the Brick Breaker game.

main:
    # Initializing the game: 
	# Step 1: drawing the top bar and 2 side walls in the game
		jal draw_walls  # draw_walls() : draw the walls (and top bar) of the game
	# Step 2: 
    

game_loop:
	# 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	# 3. Draw the screen
	# 4. Sleep

    #5. Go back to 1
    b game_loop


# void draw_walls();
# Draws the 2 side walls, and the top bar of the game.
# No parameters, uses global variables: COLOR_WALLS, TOP_BAR_THICKNESS, SIDE_WALL_THICKNESS
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


# void draw_rectangle(int x_start, int y_start, int x_end, int y_end, Color color); 
# Draws a rectangle from (x_start, y_start) to (x_end, y_end), INCLUSIVE.
# (Can also be used to draw lines, just sayin')
# parameters are passed through like so: 
#		$a0 = color
#		Stack: [ y_end, x_end, y_start, x_start <- ($sp)
# This function will mutate t0, t1, t2, t3, t9.
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
		addi $sp, $sp, -4		# extend stack by 1
		sw $ra, 0($sp)			# Back up $ra
		
		add $a0, $0, $t2		# load parameter a0 = t2
		add $a1, $0, $t0		# load parameter a1 = t0

		jal get_address_from_coords  # FUNCTION CALL
		
		lw $ra, 0($sp)			# restore $ra
		addi $sp, $sp, 4		# retract stack by 1
		# Function call complete ----------------------------------------------

		lw $t9, COLOR_WALLS
		sw $t9, 0($v0)			# puts color in the current pixel address for (t2, t0)
		
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
# Returns the address in memory for the pixel at position (x,y). 
#		Parameters: $a0 = x, $a1 = y
#		Result: $v0 = addr(x,y)
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

