.186

STATE_START         equ  0   ; новое число ещё не вводилось
STATE_PLUS          equ  1   ; введён плюс
STATE_POS_DEC       equ  2   ; вводится положительное десятичное число
STATE_POS_HEX_START equ  3   ; обозначено начало положительного шестнадцатеричного числа
STATE_POS_HEX       equ  4   ; вводится положительное шестнадцатеричное число
STATE_POS_ZERO      equ  127 ; введён нуль без минуса
STATE_MINUS         equ -1   ; введён минус
STATE_NEG_DEC       equ -2   ; вводится отрицательное десятичное число
STATE_NEG_HEX_START equ -3   ; обозначено начало отрицательного шестнадцатеричного числа
STATE_NEG_HEX       equ -4   ; вводится отрицательное шестнадцатеричное число
STATE_NEG_ZERO      equ -127 ; введён нуль с минусом

Scanner_D1 segment para public 'data'
    ;;; Сообщения об ошибках ;;;
    err_unknown_mess          db "Unknown error!",10,13,'$'
    err_invalid_char_mess     db "Any of numbers contains invalid character: $"
    err_unexpected_space_mess db "Unexpected space!",10,13,'$'
    err_overflow_mess         db "Any of numbers is out of range!",10,13,'$'
    err_double_zero_mess      db "Double zero at begin of any number!",10,13,'$'

    newline db 10,13,'$'
Scanner_D1 ends


Scanner_C1 segment para public 'code'
assume cs:Scanner_C1
public scan

; @args
; cx    - длина входной строки
; ds:si - адрес начала входной строки
; cs:bx - адрес кода, вызываемого при ошибке
;
; @returns
; ds:di + 2 - адрес начала массива
; ds:di     - адрес количества чисел в массиве
scan proc
    push    ds
    pusha
    push    di    ; сохраняем в стек адрес начала массива и увеличиваем его на размер количества чисел
    inc     di
    inc     di

    xor     bx,bx ; текущее число будем хранить в bx, обнуляем его
    xor     ah,ah ; в ah будем хранить состояние
    xor     bp,bp ; промежуточное количество чисел будем хранить в bp

process: ; начало цикла обработки
    mov     al,[si] ; получаем следующий символ в al

    ; проверяем состояние и отправляемся на одну из веток лексера
    cmp     ah,STATE_START
    je      .process@new
    cmp     ah,STATE_PLUS
    je      .process@plus
    cmp     ah,STATE_POS_DEC
    je      .process@dec_num
    cmp     ah,STATE_POS_HEX_START
    je      .process@hex_num_start
    cmp     ah,STATE_POS_HEX
    je      .process@hex_num
    cmp     ah,STATE_POS_ZERO
    je      .process@zero
    cmp     ah,STATE_MINUS
    je      .process@minus
    cmp     ah,STATE_NEG_DEC
    je      .process@dec_num
    cmp     ah,STATE_NEG_HEX_START
    je      .process@hex_num_start
    cmp     ah,STATE_NEG_HEX
    je      .process@hex_num
    cmp     ah,STATE_NEG_ZERO
    je      .process@zero
    jmp     err_unknown ; если вдруг ah в каком то неопределённом состоянии

.process@new:           jmp new
.process@plus:          jmp plus
.process@dec_num:       jmp dec_num
.process@hex_num_start: jmp hex_num_start
.process@hex_num:       jmp hex_num
.process@zero:          jmp zero
.process@minus:         jmp minus

next: ; если всё, то всё. если не всё, то обрабатывать символы дальше
    inc     si
    loop    process

    ; закончить разбор
    cmp     ah,STATE_START
    je      exit ; если последнее число уже разобрано, переходим к выходу

    ; если ah не STATE_START, то значит, в bx последнее число
    mov     [di],bx ; кладём bx в массив
    inc     bp      ; увеличиваем количество чисел в массиве

exit: ; выход из процедуры
    pop     di
    mov     [di],bp ; сохраняем количество чисел перез самими числами в начале массива
    popa
    pop     ds
    ret

new: ; когда число ещё не разбиралось
    cmp     al,' '
    je      .new@next
    cmp     al,'+'
    je      new_plus
    cmp     al,'-'
    je      new_minus
    cmp     al,'0'
    jb      .new@err_invalid_char
    je      new_zero
    cmp     al,'9'
    ja      .new@err_invalid_char
    jmp     new_dec_digit ; если это десятичная цифра

.new@next:              jmp next
.new@err_invalid_char:  jmp err_invalid_char

new_plus: ; если в начале числа плюс
    mov     ah,STATE_PLUS
    jmp     next

new_minus: ; если в начале числа минус
    mov     ah,STATE_MINUS
    jmp     next

new_zero: ; если в начале числа ноль
    mov     ah,STATE_POS_ZERO
    jmp     next

new_dec_digit: ; если в начале числа десятичная цифра
    mov     ah,STATE_POS_DEC
    sub     al,30h
    mov     bl,al ; поскольку число только началось и bx пуст, нет смысла конвертировать al в слово, можно просто записать его в младшую часть ax
                  ; также нет смысла домножать пустой bx на 10
    jmp     next

plus: ; когда введён плюс
    cmp     al,' '
    je      .plus@err_unexpected_space
    cmp     al,'0'
    jb      .plus@err_invalid_char
    je      .plus@new_zero
    cmp     al,'9'
    ja      .plus@err_invalid_char
    jmp     new_dec_digit ; если это десятичная цифра

.plus@new_zero:             jmp new_zero
.plus@err_unexpected_space: jmp err_unexpected_space
.plus@err_invalid_char:     jmp err_invalid_char

minus: ; когда введён минус
    cmp     al,' '
    je      .minus@err_unexpected_space
    cmp     al,'0'
    jb      .minus@err_invalid_char
    je      minus_zero
    cmp     al,'9'
    ja      .minus@err_invalid_char
    jmp     minus_dec_digit ; если это десятичная цифра

.minus@err_unexpected_space:    jmp err_unexpected_space
.minus@err_invalid_char:        jmp err_invalid_char

minus_zero: ; если после минуса введён нуль
    mov     ah,STATE_NEG_ZERO
    jmp     next

minus_dec_digit: ; если после минуса стоит десятичная цифра
    mov     ah,STATE_NEG_DEC
    jmp     dec_digit

dec_digit: ; когда введена десятичная цифра
    sub     al,30h
    push    ax

    mov     ax,bx
    mov     dx,10
    imul    dx ; умножаем со знаком bx на 10
    jo      .dec_digit@err_overflow_pop
    mov     bx,ax

    pop     ax
    push    ax
    cmp     ah,STATE_NEG_DEC ; проверяем, не отрицательное ли это число
    je      .dec_digit@digit_neg
    jmp     .dec_digit@digit_pos

.dec_digit@digit_neg:           jmp digit_neg
.dec_digit@digit_pos:           jmp digit_pos
.dec_digit@err_overflow_pop:    jmp err_overflow_pop

digit_pos: ; если число положительное
    cbw           ; получившееся число всегда меньше 10, поэтому ah будет 0
    add     bx,ax ; прибавляем новый младший разряд к bx
    jo      .digit_pos@err_overflow_pop
    jmp     digit_next

.digit_pos@err_overflow_pop:    jmp err_overflow_pop

digit_neg: ; если число отрицательное
    cbw           ; получившееся число всегда меньше 10, поэтому ah будет 0
    sub     bx,ax ; вычитаем из bx новый младший разряд
    jo      .digit_neg@err_overflow_pop
    jmp     digit_next

.digit_neg@err_overflow_pop:    jmp err_overflow_pop

digit_next: ; закончили обрабатывать цифру
    pop     ax
    jmp     next

zero: ; когда введён нуль
    cmp     al,' '
    je      .zero@eon
    cmp     al,'#'
    je      zero_hex
    cmp     al,'0'
    jb      .zero@err_invalid_char
    je      .zero@err_double_zero
    cmp     al,'9'
    ja      .zero@err_invalid_char
    jmp     zero_dec_digit ; если это десятичная цифра

.zero@eon:              jmp eon
.zero@err_invalid_char: jmp err_invalid_char
.zero@err_double_zero:  jmp err_double_zero

eon: ; когда достигнут конец числа
    mov     [di],bx ; кладём bx в массив
    inc     di
    inc     di
    inc     bp      ; увеличиваем количество чисел в массиве

    xor     bx,bx   ; возвращаем всё как было для принятия следующего числа
    xor     ah,ah
    jmp     next

zero_hex: ; если обозначено начало шестнадцатеричного числа
    cmp     ah,STATE_NEG_ZERO ; проверяем, был ли минус перед числом
    je      zero_hex_neg

    ; если минуса не было
    mov     ah,STATE_POS_HEX_START
    jmp     next
    
zero_hex_neg: ; если перед шестнадцатеричным числом стоял минус
    mov     ah,STATE_NEG_HEX_START
    jmp     next

zero_dec_digit: ; если после нуля стоит обычная десятичная цифра
    cmp     ah,STATE_NEG_ZERO ; проверяем, был ли минус перед числом
    je      zero_dec_digit_neg
    
    ; если минуса не было
    mov     ah,STATE_POS_DEC
    jmp     dec_digit
    
zero_dec_digit_neg: ; если после нуля с минусом обычная десятичная цифра
    mov     ah,STATE_NEG_DEC
    jmp     dec_digit

dec_num: ; когда десятичное число в процессе разбора
    cmp     al,' '
    je      .dec_num@eon
    cmp     al,'0'
    jb      .dec_num@err_invalid_char
    cmp al,'9'
    ja      .dec_num@err_invalid_char
    jmp     .dec_num@dec_digit ; если это цифра

.dec_num@eon:               jmp eon
.dec_num@dec_digit:         jmp dec_digit
.dec_num@err_invalid_char:  jmp err_invalid_char

hex_num_start: ; когда обозначено начало шестнадцатеричного числа
    cmp     al,' '
    je      .hex_num_start@err_unexpected_space
    cmp     al,'0'
    jb      .hex_num_start@err_invalid_char
    cmp     al,'9'
    jbe     hex_num_start_digit
    cmp     al,'A'
    jb      .hex_num_start@err_invalid_char
    cmp     al,'F'
    jbe     hex_num_start_digit
    cmp     al,'a'
    jb      .hex_num_start@err_invalid_char
    cmp     al,'f'
    jbe     hex_num_start_digit
    jmp     .hex_num_start@err_invalid_char ; если это не шестнадцатеричная цифра

.hex_num_start@err_unexpected_space:    jmp err_unexpected_space
.hex_num_start@err_invalid_char:        jmp err_invalid_char

hex_num_start_digit: ; если это шестнадцатеричная цифра
    cmp     ah,STATE_NEG_HEX_START ; проверяем, не стоял ли минус перед числом
    je      hex_num_start_digit_neg
    
    ; если минуса не было
    mov     ah,STATE_POS_HEX
    jmp     hex_digit

hex_num_start_digit_neg: ; если перед числом стоял минус
    mov     ah,STATE_NEG_HEX
    jmp     hex_digit

hex_digit: ; когда введена десятичная цифра
    cmp     al,'9'
    jbe     hex_digit_dec
    cmp     al,'F'
    jbe     hex_digit_upper
    cmp     al,'f'
    jbe     hex_digit_lower
    jmp     err_unknown ; если вдруг это оказалась не шестнадцатеричная цифра

hex_digit_dec: ; когда введена десятичная цифра 0-9
    sub     al,30h
    jmp     hex_digit_process

hex_digit_upper:
    sub     al,41h-10
    jmp     hex_digit_process

hex_digit_lower:
    sub     al,61h-10
    jmp     hex_digit_process

hex_digit_process: ; обработать новый шестнадцатеричный разряд, находящийся в al
    push    ax

    mov     ax,bx
    mov     dx,16
    imul    dx               ; умножаем со знаком bx на 16
    jo      err_overflow_pop
    mov     bx,ax

    pop     ax
    push    ax
    cmp     ah,STATE_NEG_HEX ; проверяем, не отрицательное ли это число
    je      .hex_digit_process@digit_neg
    jmp     digit_pos

.hex_digit_process@digit_neg:           jmp digit_neg
.hex_digit_process@err_overflow_pop:    jmp err_overflow_pop

hex_num: ; когда вводится шестнадцатеричное число
    cmp     al,' '
    je      .hex_num@eon
    cmp     al,'0'
    jb      .hex_num@err_invalid_char
    cmp     al,'9'
    jbe     .hex_num@hex_digit
    cmp     al,'A'
    jb      .hex_num@err_invalid_char
    cmp     al,'F'
    jbe     .hex_num@hex_digit
    cmp     al,'a'
    jb      .hex_num@err_invalid_char
    cmp     al,'f'
    jbe     .hex_num@hex_digit
    jmp     .hex_num@err_invalid_char ; если это не шестнадцатеричная цифра

.hex_num@eon:               jmp eon
.hex_num@hex_digit:         jmp hex_digit
.hex_num@err_invalid_char:  jmp err_invalid_char

err_unknown: ; неизвестная ошибка
    mov     ax,Scanner_D1
    mov     ds,ax
    lea     dx,err_unknown_mess
    mov     ah,9
    int     21
    jmp     error

err_invalid_char: ; неверный символ
    mov     bx,Scanner_D1
    mov     ds,bx
    lea     dx,err_invalid_char_mess
    mov     ah,9
    int     21h
    mov     dl,al
    mov     ah,2
    int     21h
    lea     dx,newline
    mov     ah,9
    int     21h
    jmp     error

err_unexpected_space: ; неожиданный пробел
    mov     ax,Scanner_D1
    mov     ds,ax
    lea     dx,err_unexpected_space_mess
    mov     ah,9
    int     21h
    jmp     error

err_overflow_pop: ; переполнение текущего числа, вытолкнуть слово
    pop     ax
    jmp     err_overflow

err_overflow: ; переполнение текущего числа
    mov     ax,Scanner_D1
    mov     ds,ax
    lea     dx,err_overflow_mess
    mov     ah,9
    int     21h
    jmp     error

err_double_zero: ; двойной нуль в начале числа
    mov     ax,Scanner_D1
    mov     ds,ax
    lea     dx,err_double_zero
    mov     ah,9
    int     21h
    jmp     error

error: ; выход из процедуры при ошибке
    pop     di
    popa
    pop     ds

    inc     sp
    inc     sp
    push    bx ; подменяем адрес возврата

    ret

scan endp
Scanner_C1 ends


Scanner_S1 segment para stack 'stack'
    dw 100 dup(?)
Scanner_S1 ends

end process
