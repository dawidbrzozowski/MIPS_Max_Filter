#C:\Users\dawid\OneDrive\Pulpit\arko\Filtr_docelowy\niepodzielne4.bmp
.data
EnterInput:		.asciiz	"Input file name:\n"
EnterOutput:			.asciiz	"Output file name:\n"
inputFile:			.space	128 
outputFile: 			.space  128		
ErrorInput:			.asciiz "Error while loading input file\n"
ErrorOutput: 			.asciiz "Error while loading output file\n"
inputBuffer:			.space	131072
outputBuffer:			.space  131072
header: 			.space   54
EnterMask:		.asciiz "Enter mask size: \n"	
.text
main:
	#Enter input filename
	li		$v0, 4			
	la		$a0, EnterInput	
	syscall
	#read filename
	li		$v0, 8			
	la		$a0, inputFile		
	li		$a1, 128		
	syscall
	#Enter output filename
	li		$v0, 4			
	la		$a0, EnterOutput	
	syscall
	#read output filename
	li 		$v0, 8			
	la 		$a0, outputFile	
	li 		$a1, 128		
	syscall
	
	#removes '\n' from the filenames
	li $t0, 0
	li $t1, 0
inputCorrection:
	lb $t2, inputFile($t0)
	addiu $t0, $t0, 1		#incrementing as long as it finds '\n'
	bne $t2, '\n' , inputCorrection
	#after we find it :	
	subiu $t0, $t0, 1		#the actual change we're making
	sb $zero, inputFile($t0)

		
outputCorrection:	
	lb $t2, outputFile($t1)
	addiu $t1, $t1, 1		
	bne $t2, '\n' , outputCorrection
	#after we find it :
	subiu $t1, $t1, 1	 	#the actual change we're making
	sb $zero, outputFile($t1)		
	
fileDescryption:
	#Firstly opening the input file
	li		$v0, 13		
	la		$a0, inputFile	
	li 		$a1, 0		#flag to read
	li		$a2, 0		
	syscall
	bltz		$v0, wrongInput	#if less than 0 -> mistake -> something went wrong with input
	move		$s0, $v0		#save input file descryption to $s0
	
	#Read header from input file
	li		$v0, 14		
	move		$a0, $s0	
	la		$a1, header	
	li		$a2, 54		#the header consists of 54 bytes
	syscall
	
	#WIDTH
	lw 		$s6, header+18	#header + 18 is the adress of width of the picture
	mul		$s6, $s6, 3	#we have to multiply that by 3, because every pixel is described by RGB
	
	#SIZE
	lw		$s1, header+34   #size of picture
	#read first inputBuffer
	li		$s2, 131072	#s2 will store our inputBufferer size = 131072
	li		$v0, 14		
	move		$a0, $s0		#s0 holds the descryptor
	la		$a1, inputBuffer	#loading inputBuffer
	move		$a2, $s2		#131072
	syscall
	
	#open output file
	li		$v0, 13
	la		$a0, outputFile
	li		$a1, 1		#flag to write
	li		$a2, 0
	syscall
	
	# copy output file descriptor
	move		$s4, $v0		#since now, $s4 holds output descriptor 
	bltz		$s4, wrongOutput #if the descriptor is below 0, it means that there was a mistake
	li		$v0, 15		#write to file
	move 		$a0, $s4
	la		$a1, header
	addi    	$a2, $zero, 54
	syscall	
	
#initialization

	la $a0, EnterMask
	la $v0, 4
	syscall
	la $v0, 5			#read mask
	syscall
	move $s7, $v0			#s7 contains the size of a window
	
									
	move		$t0, $zero  	  #main iterator
	la		$t1, inputBuffer  #iterator of the inputBuffer
	la		$s3, outputBuffer #iterator of the outputBuffer	  ax value
	srl		$s5, $s7, 1	  #saving the value of sizeof(window) / 2, (will be needed)

	# now we have to calculate which byte is the last to be analysed, to still be able to read from somewhere
	divu		$t6, $s2, $s6 #how many full lines are there in inputBuffer
	# this number should be substracted by size of window / 2, not to get off the picture (during searching max value)
	subu		$t6, $t6, $s5 #full lines without the window/2 ones
	# so the number of pixels that can be iterated in inputBufferer is:
	mul		$t6, $t6, $s6 #full lines * width
	# the address of the last pixel is
	#start of inputBuffer + all the ones that can be iterated
	addu		$t6, $t1, $t6 #and that's the answer = $t6
repeat:

	#if we have already iterated the whole picture, then clear outputBuffer, and write the last section to the output file
	#we need also the address of the last element in outputBuffer
	la $t9, outputBuffer
	addu $t9, $t9, $s2 #s2 is 131702 #t9 = end of outputbuffer
	
	bne $t0, $s1, continue
	#if it is equal then do what written 
	# clears the end of outputBuffer
	move		$t0, $s3
clearOutputBuffer:
	
	bleu		$t0, $t9, clear
	li		$v0, 15		#write to the output File
	move 		$a0, $s4
	la		$a1, outputBuffer
	subu		$a2, $s3, $a1	#write s3-a1+1 pixels //a1 holds the start of outputBuffer
	addiu		$a2, $a2, 1
	syscall
	b fin
clear:
	sb		$zero, ($t0)
	addiu		$t0, $t0, 1
	
	b clearOutputBuffer

continue:
	
	bltu $s3, $t9, doNotSave	#$t9 - end of the outputbuffer
	#if it is equal, then save outputBuffer to the output file and continue to analyse pixels
	
	move 		$a0, $s4
	li		$v0, 15		
	la		$a1, outputBuffer
	move		$a2, $s2 #number of bytes saved in s2
	syscall
	# save to  the file and set s3 back to the beginning of outpuBuffer
	la		$s3, outputBuffer
doNotSave:
	
	blt $t1, $t6, readNewColor #t6 last analisable element of inputBuffer
	#if it it's not true, then rewrite the end of the inputBuffer to the beginning and write new inputBuffer
	# after the last byte
	la		$t9, inputBuffer
	addu		$t9, $t9, $s2 #set $t9 on the last inputBuffer element
	mul		$t4, $s5, $s6 #$t4 = windowsize/2 * width
	subu		$t1, $t1, $t4 #get $t1 back by $t4 bytes because we need this line to analyse from
	la		$t4, inputBuffer 
	li		$t7, 0	#counts how many bytes have been copied on the beginning of the inputBuffer
getTail:
		
	bgeu		$t1, $t9, RewriteBufferAfterTail
	lb		$t5, ($t1)
	sb		$t5, ($t4)
	addiu		$t4, $t4, 1	#t4 is the beginning of the inputBuffer
	addiu		$t1, $t1, 1	#till t1 reaches the end of inputBuffer
	addiu		$t7, $t7, 1	#count how many times already
	b getTail

RewriteBufferAfterTail:
	
	li		$v0, 14		
	move		$a0, $s0
	move		$a1, $t4
	subu		$a2, $s2, $t7	# a2 = how many characters = s2 - t7
	syscall				# (size of the buffer - size of the tail)
	
	la		$t1, inputBuffer	#get t1 back on track (start of inputBuffer)
	mul		$t4, $s5, $s6		#and move it right after the tail, that has just been included
	addu		$t1, $t1, $t4 		#to the beginning of the inputBuffer

readNewColor:
	
	li $a0, 0	#$a0= max value ; $a1= row iterator
	li $a2, 0	#$a2 =column iterator; $t4 = helpful var
	addiu $t4, $s6, 3	#$s6 =width $s5= window/2
	mul $t4, $t4, $s5	#$t3= byte to iterate and search max
	subu $t3, $t1, $t4	#t1= inputBuffer iterator ;$s7 =window 

columnLoopFilter:
	li $a1, 0
	bne $a2, $s7, csiar #continue searching in another row
	#if it is equal save max to outputinputBufferer and ++s and onther repeat
	sb $a0, ($s3)
	addiu $s3, $s3, 1
	addiu $t1, $t1, 1
	addiu $t0, $t0, 1
	b repeat

csiar: #continue searching in another row
	bne $a1, $s7, checkNextByte
	mul $t4, $s7, 3
	subiu $t4, $t4, 3
	subu $t3, $t3, $t4
	addu $t3, $t3, $s6 #all these 4 lines are to go back to the most left byte in this row, and go one column up
	addiu $a2, $a2, 1
	b columnLoopFilter

checkNextByte:
	lb $t5, ($t3)
	bleu $t5, $a0, dontSwapMax
	move $a0, $t5 #swap max
dontSwapMax: #dont swap max means actually what happens after swap or not swap
	addiu $a1, $a1, 1
	addiu $t3, $t3, 3
	b csiar
	#koniec readnewbyte


wrongInput:
	li $v0, 4
	la $a0, ErrorInput
	syscall
	li $v0, 10
wrongOutput:
	li $v0, 4
	la $a0, ErrorOutput
	syscall
	
fin:
	#close file
	move		$a0, $s0		
	li		$v0, 16			
	syscall
	move		$a0, $s4
	li		$v0, 16
	syscall
	
	li 		$v0, 10
	syscall
