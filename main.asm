; Autor: Oliver Polo. C.I: 28.161.706

list p=16f1787
include <p16f1787.inc>

__CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF 

centesimas			equ		0x20
segundos			equ		0x21
minutos				equ		0x22
banderas			equ		0x23
barrido				equ		PORTA
current_display		equ		0x24
bcd_unidad			equ		0X25
bcd_decena			equ		0X26
check_zero			equ		0x27 ;Cuando se decrementa, si check_zero = .3 se detuvo el temp
cursor				equ		0x28 ;Almacena el registro del display que est� seteando el usuario
cont_ms				equ		0x29
parp_ms				equ		0x30
alarma1_ms			equ		0x31
alarma2_ms			equ		0x32
alarma3_ms			equ		0x33
parp_display		equ		0x34

			;Inicio
			org 	0x00
			goto	CONFIG__
			;Interrupcion
			org 	0x04
			goto 	INTER
			org 	0x05

			;Configuraci�n de puertos y registros
CONFIG__	
			banksel OSCCON
			movlw 	0x6F
			movwf 	OSCCON
			banksel ANSELA
			clrf 	ANSELA
			clrf 	ANSELB
			;Configuraci�n de entradas y salidas
			banksel TRISA
			movlw	b'10000000'
			movwf	TRISA
			clrf	TRISB
			movlw	b'11001111'
			movwf	TRISC
			banksel	OPTION_REG
			movlw	b'00000010'
			movwf	OPTION_REG

			;Limpiando los registros
			clrf	BSR
			clrf	centesimas
			clrf	segundos
			clrf	minutos
			clrf	banderas
			clrf	barrido
			clrf	FSR0L
			clrf	FSR0H
			clrf	FSR1L
			clrf	FSR1H
			clrf	PORTC
			
			;Inicializando registro de barrido
			movlw	0x01
			movwf	barrido
			movwf	PORTA
	
			;Inicializando registro de display
			movlw	0x20
			movwf	current_display
			movwf	cursor

			;Inicializando registro para contar 10ms
			movlw	.10
			movwf	cont_ms

			;Inicializando tiempo de parpadeo para modo ajuste (60ms)
			movlw	.60
			movwf	parp_ms

			;Inicializando tiempo de alarma (50*2*100)ms = 10000ms = 10s
			movlw	.50
			movwf	alarma1_ms
			movlw	.2
			movwf	alarma2_ms
			movlw	.100
			movwf	alarma3_ms
	
			;Configuraci�n de interrupciones
			movlw	b'11101000'
			movwf	INTCON
			banksel	IOCCN
			movlw	0x0f
			movwf	IOCCN
			clrf	BSR

PROGRAMA	goto 	$


INTER		call	SHOW_STATUS
			btfsc	INTCON, TMR0IF
			goto	TMR_INT
			goto	FLANCO_INT

;Interrupci�n por TMR0
TMR_INT		call	ROTA_DISP
			call	SHOW_DISP
			
			btfsc	banderas, 6
			goto	ALARMA
			btfss	banderas, 1
			goto	CRONOMETRO
			btfsc	banderas, 3
			goto	TEMPORIZADOR
		
RESET_TMR	movlw	.131
			movwf	TMR0
			bcf		INTCON, TMR0IF
			retfie

;Interrupci�n por cambio de nivel (flanco de bajada)
FLANCO_INT	call	CHECK_ALARMA
			banksel	IOCCF
			btfsc	IOCCF, 0
			call	BOTON0
			btfsc	IOCCF, 1
			call	BOTON1
			btfsc	IOCCF, 2
			call	BOTON2
			btfsc	IOCCF, 3
			call	BOTON3
			banksel	IOCCF
			clrf	IOCCF
			clrf	BSR
			retfie


;Configuraci�n para el bot�n 0 (RC0)________________________________________
BOTON0		clrf	BSR
			btfss	banderas, 1
			goto	BTN0_CRON
			goto	BTN0_TEMP
			
;Bot�n START/PAUSE
BTN0_CRON	btfsc	banderas, 2
			goto	PAUSE
			bsf		banderas, 2
			return
;Si el cronometro est� contando se detiene
PAUSE		bcf		banderas, 2	
			bcf		IOCCF, 0
			return

BTN0_TEMP	btfss	banderas, 4
			goto	BTN0_TEMP_PAUSE
			call	RL_CURSOR
			banksel	IOCCF
			return

BTN0_TEMP_PAUSE
			btfsc	banderas, 2
			goto	TEMP_PAUSE
			bsf		banderas, 2
			banksel	IOCCF
			return
TEMP_PAUSE	bcf		banderas, 2
			banksel	IOCCF
			return
;___________________________________________________________________________


;Configuraci�n para el bot�n 1 (RC1)________________________________________
BOTON1		clrf	BSR
			btfss	banderas, 1
			goto	BTN1_CRON
			goto	BTN1_TEMP

BTN1_CRON	clrf	BSR
			bcf		banderas, 2
			clrf	centesimas
			clrf	segundos
			clrf	minutos
			banksel	IOCCF
			return

BTN1_TEMP	btfss	banderas, 4
			goto	$+4		
			movf	cursor, W
			movwf	FSR1L
			;incf	INDF1, F
			call	INC_FILE
			banksel	IOCCF
			return
;___________________________________________________________________________


;Configuraci�n para el bot�n 2 (RC2)________________________________________
BOTON2		clrf	BSR
			btfss	banderas, 4
			goto	$+6
			btfss	banderas, 1
			goto	$+4
			movf	cursor, W
			movwf	FSR1L
			call	DEC_FILE
			banksel	IOCCF
			return
;___________________________________________________________________________


;Configuraci�n para el bot�n 3 (RC3)________________________________________
BOTON3		clrf	BSR
			btfsc	banderas, 4
			goto	BTN3_ADJ
			bcf		banderas, 2
			clrf	centesimas
			clrf	segundos
			clrf	minutos
			bsf		banderas, 1
			bcf		banderas, 2
			bsf		banderas, 4
			return

BTN3_ADJ	movlw	centesimas
			xorwf	cursor, W
			btfss	STATUS, Z
			goto	RR_CURSOR
			bcf		banderas, 4
			bcf		banderas, 1
			clrf	centesimas
			clrf	segundos
			clrf	minutos
			banksel	IOCCF
			return
			
;___________________________________________________________________________


;Incremeta el registro en modo ajuste
;Si el valor de las centesimas es 99, el incremento coloca el registro en 0
;Si el valor de los segundos o minutos es 59, el incremento coloca el registro en 0
INC_FILE	movlw	centesimas
			xorwf	cursor, W
			btfsc	STATUS, Z
			goto	INC_LIM99
			goto	INC_LIM59
INC_LIM99	incf	INDF1, F
			movf	INDF1, W
			xorlw	.100
			btfss	STATUS, Z
			return
			clrf	INDF1
			return
INC_LIM59	incf	INDF1, F
			movf	INDF1, W
			xorlw	.60
			btfss	STATUS, Z
			return
			clrf	INDF1
			return


;Decrementa el registro en modo ajuste
;Si el valor de las centesimas es 0, el decremento coloca el registro en 99
;Si el valor de los segundos o minutos es 0, el decremento coloca el registro en 59
DEC_FILE	movlw	centesimas
			xorwf	cursor, W
			btfsc	STATUS, Z
			goto	DEC_LIM99
			goto	DEC_LIM59
DEC_LIM99	decf	INDF1, F
			movf	INDF1, W
			xorlw	.255
			btfss	STATUS, Z
			return
			movlw	.99
			movwf	INDF1
			return
DEC_LIM59	decf	INDF1, F
			movf	INDF1, W
			xorlw	.255
			btfss	STATUS, Z
			return
			movlw	.59
			movwf	INDF1
			return
			

;Rota el cursor de ajuste a la izquierda
RL_CURSOR	movlw	minutos
			xorwf	cursor, W
			btfsc	STATUS, Z
			goto	CHECK_RLCUR
			incf	cursor, F
			return

;Comprueba si los registros ya tienen datos
;sino el cursor vuelve al display de centesimas
CHECK_RLCUR movlw	.0
			xorwf	centesimas, W
			btfss	STATUS, Z
			bsf		banderas, 3
			movlw	.0
			xorwf	segundos, W
			btfss	STATUS, Z
			bsf		banderas, 3
			movlw	.0
			xorwf	minutos, W
			btfss	STATUS, Z
			bsf		banderas, 3
			btfss	banderas, 3
			goto	$+6
			movf	minutos, W
			xorwf	cursor, W
			btfss	STATUS, Z
			goto	$+2
			goto	TEMPORIZADOR
			movlw	0x20
			movwf	cursor
			return

RR_CURSOR	decf	cursor, F
			banksel	IOCCF
			return
			

;Mostrando los d�gitos en los display (bcd_decena, bcd_unidad)
SHOW_DISP	movf	INDF0, W
			call	DECIMAL_A_BCD
			btfsc	banderas, 0
			goto	SHOW_UNI
			goto	SHOW_DEC
SHOW_UNI	movf	bcd_unidad, W
			call	TABLA_7SEG_AC
			btfsc	banderas, 4
			call	BCD_PARP
			movwf	PORTB
			call	PUNTOS
			bcf		banderas, 0	
			return
SHOW_DEC	movf	bcd_decena, W
			call	TABLA_7SEG_AC
			btfsc	banderas, 4
			call	BCD_PARP
			movwf	PORTB
			call	PUNTOS
			bsf		banderas, 0
			return


;Activa el display a la izq y lo deja as� por 1ms (base de tiempo del TMR0)
;barrido = PORTA
ROTA_DISP	rlf		barrido, F
			btfsc	barrido, 6
			goto	CORREGIR
			btfsc	banderas, 0
			incf	current_display, F
			movf	current_display, W
			movwf	FSR0L
			return
CORREGIR	movlw	0x01
			movwf	barrido
			movlw 	0x20
			movwf	current_display
			movwf	FSR0L
			return


CRONOMETRO	btfss	banderas, 2
			goto	RESET_TMR
			decfsz	cont_ms, F
			goto	RESET_TMR
			call	INCREMENTA
			goto	RESET_TMR


INCREMENTA	movlw	.10
			movwf	cont_ms
			movf	centesimas, W
			xorlw	.99
			btfsc	STATUS, Z
			goto	INC_SEG
			incf	centesimas, F
			return
INC_SEG		clrf	centesimas
			movf	segundos, W
			xorlw	.59
			btfsc	STATUS, Z
			goto	INC_MIN
			incf	segundos, F
			return
INC_MIN		clrf	segundos
			movf	minutos, W
			xorlw	.59
			btfsc	STATUS, Z
			goto	CLR_INC
			incf	minutos, F
			return
CLR_INC		clrf	centesimas
			clrf	segundos
			clrf	minutos
			return


TEMPORIZADOR
			btfss	banderas, 2
			decfsz	cont_ms, F
			goto	RESET_TMR
			call	DECREMENTA
			goto	RESET_TMR


DECREMENTA	bcf		banderas, 4
			goto	CHECK_DEC
DECR		movlw	.10
			movwf	cont_ms
			movf	centesimas, W
			xorlw	.0
			btfsc	STATUS, Z
			goto	DEC_SEG
			decf	centesimas, F
			return
DEC_SEG		movlw	.99
			movwf	centesimas
			movf	segundos, W
			xorlw	.0
			btfsc	STATUS, Z
			goto	DEC_MIN
			decf	segundos, F
			return
DEC_MIN		movlw	.59
			movwf	segundos
			decf	minutos, F

;Se verifica si todos los registros est�n en cero (minutos=0, segundos=0, centesimas=0)
CHECK_DEC	movf	minutos, W
			xorlw	.0
			btfss	STATUS, Z
			goto	DECR
			movf	segundos, W
			xorlw	.0
			btfss	STATUS, Z
			goto	DECR
			movf	centesimas, W
			xorlw	.0
			btfss	STATUS, Z
			goto	DECR
			bcf		banderas, 3
			bsf		banderas, 4
			movlw	centesimas
			movwf	cursor
			bsf		banderas, 6 ;Si todos los registro llegan a cero se activa la alarma
			retfie	


;Se hacen varias temporizaciones "anidadas", cada dos temporizaciones de 100ms
;se alterna el bit 4 del puerto C, haciendo esto 50 veces la alarma dura 10s
ALARMA		decfsz	alarma3_ms, F
			goto	RESET_TMR
			movlw	.100
			movwf	alarma3_ms
			decfsz	alarma2_ms, F
			goto	ALARMA
			call	TOGGLE_BEEP
			movlw	.2
			movwf	alarma2_ms
			decfsz	alarma1_ms, F
			goto	ALARMA
			bcf		banderas, 6
			movlw	.50
			movwf	alarma1_ms
			bcf		PORTC, 4
			goto	RESET_TMR
TOGGLE_BEEP	btfss	PORTC, 4
			goto	$+3
			bcf		PORTC, 4
			return
			bsf		PORTC, 4
			return


;Luego de la interrupci�n por cambio de nivel, si est� transcurriendo el tiempo de alarma
;se detiene colocando a cero el bit 4 del puerto C
CHECK_ALARMA
			btfss	banderas, 6
			return
			bcf		banderas, 6
			bcf		PORTC, 4
			goto	RESET_TMR


;Si est� en modo ajuste, env�a al display donde se encuentra el cursor
;0xff por 60ms y luego el dato que deber�a ir al display por otros 60ms
BCD_PARP	movwf	parp_display
			movf	FSR0L, W
			xorwf	cursor, W
			btfsc	STATUS, Z
			goto	COMP_PARP
			movf	parp_display, W
			return		
COMP_PARP	decfsz	parp_ms, F
			goto	FIN_PARP
			movlw	.60
			movwf	parp_ms
			btfsc	banderas, 5
			goto	PARP_ON
			goto	PARP_OFF
PARP_ON		bcf		banderas, 5
			movf	parp_display, W
			return
PARP_OFF	bsf		banderas, 5
			movlw	0xff
			return
FIN_PARP	btfss	banderas, 5
			goto	$+3
			movlw	0xff
			return
			movf	parp_display, W
			return


;Separa los digitos de un registro
;deja la decena en bcd_decena y la unidad en bcd_unidad
DECIMAL_A_BCD	
			movwf	bcd_unidad
			clrf	bcd_decena
RESTA_DECENA	
			movlw	.10
			subwf	bcd_unidad
			btfss	STATUS, C
			goto	SUMA_UNIDAD
			incf	bcd_decena, F
			goto	RESTA_DECENA
SUMA_UNIDAD	addwf	bcd_unidad, F
			return


;Muestra si está en modo Cronómetro o Temporizador a través del bit 5 del puerto C
SHOW_STATUS btfss	banderas, 1
			goto	$+3
			bsf		PORTC, 5
			return
			bcf		PORTC, 5
			return


PUNTOS		btfss	banderas, 0
			return
			movf	current_display, W
			xorlw	centesimas
			btfsc	STATUS, Z
			return
			bcf		PORTB, 7
			return


;Tabla display 7seg �nodo com�n
TABLA_7SEG_AC	
			brw	
			retlw b'11000000'	; CERO
			retlw b'11111001'	; UNO
			retlw b'10100100'	; DOS
			retlw b'10110000'	; TRES
			retlw b'10011001'	; CUATRO
			retlw b'10010010'	; CINCO
			retlw b'10000010'	; SEIS
			retlw b'11111000'	; SIETE
			retlw b'10000000'	; OCHO
			retlw b'10010000'	; NUEVE
end