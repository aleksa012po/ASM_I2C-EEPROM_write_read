;
; I2C EEPROM_write_read.asm
;
; Created: 9.11.2022. 01:18:49
; Author : Aleksandar Bogdanovic
;

/* Arduino Asembler, I2C EEPROM, pisanje, citanje */
/* Arduino program koji koristi softverski TWI/I2C interfejs kako bi
   pisao i citao na EEPROM (24LC256 256K I2C CMOS Serial EEPROM) 2 bajta.
   prvo jedan pa drugi i vrednost istih izbacio na OUTPUT na 8 LED dioda (PORTD). */ 

.dseg

.equ SCL		= 2				// SCL pin (Port B)
.equ SDA		= 3				// SDA pin (Port B)

.equ dir_bit	= 0				// Direction bit transfer u twi_adr

.equ read_bit	= 1				// Bit za TWI citanje
.equ write_bit	= 0				// Bit za TWI upisivanje

.equ half		= 22			// half - 1/2 period TWI delay (normal: 5.0us / fast: 1.3us)
.equ quar		= 11			// quar - 1/4 period TWI delay (normal: 2.5us / fast: 0.6us)

/* TWI = I2C */

.def twi_delay	= r16			// Delay loop promenljiva
.def twi_data	= r17			// TWI data transfer registar
.def twi_address= r18			// Adresni TWI registar
.def twi_bus	= r19			// TWI bus status registar

.def	first_byte	  = r20		// Prvi byte koji cuva i cita sa EEPROM-a na LED diode
.def	second_byte	  = r21		// Drugi byte koji cuva i cita sa EEPROM-a na LED diode
.def	eeprom_byte    = r22	// Byte koji se cuva u EEPROM

.include "m328pdef.inc"
.org 0x0000

.cseg

rjmp main_program

main_program:
	rcall twi_init				// TWI inicijalizacija
/* Podesavanja za prvi i drugi bajt */
	ldi	first_byte,  0b10101010
	ldi	second_byte, 0b01010101
///////////////////////////////////////
loop:
	rcall wr_byte_eeprom1
	rcall read_eeprom
	rcall led
	rcall delay1sek
	rcall wr_byte_eeprom2
	rcall read_eeprom
	rcall led
	rcall delay1sek
	rcall loop

/* Kraj programa koji je u loop-u */

/* U ovom programu koristimo Normal mode (100KHz)
   Podesavanja:
   half - 1/2 period TWI delay (normal: 5.0us / fast: 1.3us)
   quar - 1/4 period TWI delay (normal: 2.5us / fast: 0.6us)

   Normal mode: half 22, quar 11 100KHz
   Fast mode: half 2, quar 1 */
///////////////////////////////////////
twi_half_d:
	ldi twi_delay, half
loop2:
	dec twi_delay
	brne loop2
	ret

twi_quar_d:
	ldi twi_delay, quar
loop1:
	dec twi_delay
	brne loop1
	ret
///////////////////////////////////////
// Inicijalizacija
///////////////////////////////////////
twi_init:
	clr twi_bus
	out PORTB, twi_bus
	out DDRB, twi_bus
	ret
///////////////////////////////////////
// TWI Repeat start
///////////////////////////////////////
twi_rep_start:
	sbi DDRB, SCL
	cbi DDRB, SDA
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_quar_d
///////////////////////////////////////
// TWI start
///////////////////////////////////////
twi_start:
	mov twi_data, twi_address
	sbi DDRB, SDA
	rcall twi_quar_d
///////////////////////////////////////
// TWI Write
///////////////////////////////////////
twi_write:
	sec
	rol twi_data
	rjmp twi1_wr
twi1_bit:
	lsl twi_data
twi1_wr:
	breq twi_get_ack
	sbi DDRB, SCL
	brcc twi_low
	nop							
	cbi DDRB, SDA
	rjmp twi_high
twi_low:
	sbi DDRB, SDA
	rjmp twi_high
twi_high:
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_half_d
	rjmp twi1_bit
///////////////////////////////////////
// Get acknowledge
///////////////////////////////////////
twi_get_ack:
	sbi DDRB, SCL
	cbi DDRB, SDA
	rcall twi_half_d
	cbi DDRB, SCL
wait:
	sbis PINB, SCL
	rjmp wait
	clc
	sbic PINB, SDA
	sec
	rcall twi_half_d
	ret
///////////////////////////////////////


///////////////////////////////////////
// TWI transfer
///////////////////////////////////////
twi_transfer:
	sbrs twi_address, dir_bit
	rjmp twi_write
///////////////////////////////////////
// TWI read
///////////////////////////////////////
twi_read:
	rol twi_bus
	ldi twi_data, 0x01
twi_readb:
	sbi DDRB, SCL
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_half_d
	clc
	sbis PINB, SDA
	sec
	rol twi_data
	brcc twi_readb
///////////////////////////////////////
// Put acknowledge
///////////////////////////////////////
twi_put_ack:
	sbi DDRB, SCL
	ror twi_bus
	brcc put_ack_l
	cbi DDRB, SDA
	rjmp put_ack_h
put_ack_l:
	sbi DDRB, SDA
put_ack_h:
	rcall twi_half_d
	cbi DDRB, SCL
twi_put_ackW:
	sbis PINB, SCL
	rjmp twi_put_ackW
	rcall twi_half_d
	ret
///////////////////////////////////////
// TWI stop
///////////////////////////////////////
twi_stop:
	sbi DDRB, SCL
	sbi DDRB, SDA
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_half_d
	cbi DDRB, SDA
	rcall twi_half_d
	ret
///////////////////////////////////////
// Write byte EEPROM prva vrednost
///////////////////////////////////////
wr_byte_eeprom1:
	mov	r24, first_byte
	mov eeprom_byte, r24
	rcall write_eeprom

// Delay 4ms na 16MHz

	ldi  r25, 84
    ldi  r26, 29
L1: dec  r26
    brne L1
    dec  r25
    brne L1
	ret
///////////////////////////////////////
// 8 bitna LED
///////////////////////////////////////
led:
	ser r26
	out DDRD, r26
	out PORTD, twi_data
	ret 

wr_byte_eeprom2:
	mov	r24, second_byte
	mov eeprom_byte, r24
	rcall write_eeprom

	ldi  r25, 84
    ldi  r26, 29
L3: dec  r26
    brne L3
    dec  r25
    brne L3
	ret

	delay1sek:
	ldi  r25, 82
    ldi  r26, 43
    ldi  r27, 0
L2: dec  r27
    brne L2
    dec  r26
    brne L2
    dec  r25
    brne L2
    lpm
    nop
	ret

write_eeprom:
	ldi twi_address, 0xA0 + write_bit
	rcall twi_start

	ldi twi_data, 0x00
	rcall twi_transfer

	ldi twi_data, 0x00
	rcall twi_transfer

	mov twi_data, eeprom_byte
	rcall twi_transfer
	rcall twi_stop

read_eeprom:
	ldi twi_address, 0xA0 + write_bit
	rcall twi_start

	ldi twi_data, 0x00
	rcall twi_transfer

	ldi twi_data, 0x00
	rcall twi_transfer

	ldi twi_address, 0xA0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer

	rcall twi_stop
	ret

