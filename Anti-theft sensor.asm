.device ATMEGA328P              ; กำหนดชนิดของไมโครคอนโทรเลอร์ (ใช้กับ ATmega328P)
.def TMP = R18                  ; กำหนดชื่อตัวแปร TMP ให้ R18

.org 0x0000 jmp SETUP_PIN       ; กระโดดไปทำงานที่ SETUP_PIN
.org 0x0002 jmp INTO_SENSOR     ; กระโดดไปทำงานที่ INTO_SENSOR เมื่อมีการ Active

;-------------------------------------- ตั้งค่า PIN ---------------------------------------------
SETUP_PIN:
    ldi R19, 0b11111011         ; กำหนดให้ PORTD เป็น OUTPUT ยกเว้น PD2 เป็น INPUT
    ldi R20, 0b00000011         ; กำหนดให้ PORTB เป็น OUTPUT คือ PB0-1
    ldi R24, 0b00010000         ; กำหนดให้ PORTC เป็น INPUT (เฉพาะ PC4)

    out DDRB, R20               ; ตั้งค่าพอร์ต B
    out DDRC, R24               ; ตั้งค่าพอร์ต C

    ldi TMP, 0x01
    out EIMSK, TMP              ; เปิดใช้งาน Interrupt INT0

    ldi ZL, low(EICRA)
    ldi ZH, high(EICRA)
    ldi TMP, 0x01
    st Z, TMP                   ; ตั้งค่าการกระตุ้น INT0 แบบขอบขาขึ้น

    out DDRD, R19               ; ตั้งค่าพอร์ต D

    sbi PORTC, 4                ; ตั้งค่าขา PC4 เป็น HIGH
    sei                         ; เปิดใช้งาน Interrupt ทั่วไป

;-------------------------------------- เริ่มต้น LCD --------------------------------------------
LCD_write:
    CBI PORTB, 0                ; ปิดการเปิด EN
    RCALL delay_ms              ; รอให้ LCD เปิดตัว
    RCALL LCD_init              ; โปรแกรมย่อยสาหรับเริ่มต้น LCD              

again:
    RJMP again                  ; กระโดดไปที่ again เพื่อรันอีกครั้ง

;-------------------------------------- รูทีนควบคุม LCD -----------------------------------------
LCD_init:
    LDI R16, 0x33               ; เริ่มต้น LCD เพื่อข้อมูล 4 บิต
    RCALL command_wrt           ; ส่งไปยังที่ลงทะเบียนคาสั่ง
    RCALL delay_ms

    LDI R16, 0x32               ; เริ่มต้น LCD เพื่อข้อมูล 4 บิต
    RCALL command_wrt
    RCALL delay_ms

    LDI R16, 0x28               ; LCD 2 บรรทัด, เมทริกซ์ 5x7
    RCALL command_wrt
    RCALL delay_ms

    LDI R16, 0x0C               ; แสดงผลเปิด, ปิดเคอร์เซอร์
    RCALL command_wrt

    LDI R16, 0x01               ; เคลียร์ LCD
    RCALL command_wrt
    RCALL delay_ms

    LDI R16, 0x06               ; เลื่อนเคอร์เซอร์ไปทางขวา
    RCALL command_wrt
    RET

;-------------------------------------- ส่งคำสั่งไป LCD ----------------------------------------
command_wrt:
    MOV R27, R16                ; เก็บข้อมูลใน R27
    ANDI R27, 0xF0              ; มาสก์ไนเบิลสูง
    OUT PORTD, R27              ; ส่งข้อมูลไปที่ PORTD

    CBI PORTB, 1                ; RS = 0
    SBI PORTB, 0                ; EN = 1
    RCALL delay_short           ; ขยายช่องโหว่ EN
    CBI PORTB, 0                ; EN = 0
    RCALL delay_us              ; ล่าช้าในไมโครวินาที

    MOV R27, R16                ; สลับข้อมูล
    SWAP R27                    
    ANDI R27, 0xF0              ; มาสก์ไนเบิลสูง
    OUT PORTD, R27              ; ส่งข้อมูลไปที่ PORTD
    SBI PORTB, 0                ; EN = 1
    RCALL delay_short           ; ขยายช่องโหว่ EN
    CBI PORTB, 0                ; EN = 0
    RCALL delay_us              ; ล่าช้าในไมโครวินาที
    RET

;-------------------------------------- ส่งข้อมูลไป LCD ----------------------------------------
data_wrt:
    MOV R27, R16                ; เก็บข้อมูลใน R27
    ANDI R27, 0xF0              ; มาสก์ไนเบิลสูง
    OUT PORTD, R27              ; ส่งข้อมูลไปที่ PORTD

    SBI PORTB, 1                ; RS = 1
    SBI PORTB, 0                ; EN = 1
    RCALL delay_short           ; ขยายช่องโหว่ EN
    CBI PORTB, 0                ; EN = 0
    RCALL delay_us              ; ล่าช้าในไมโครวินาที

    MOV R27, R16                ; สลับข้อมูล
    SWAP R27                    
    ANDI R27, 0xF0              ; มาสก์ไนเบิลสูง
    OUT PORTD, R27              ; ส่งข้อมูลไปที่ PORTD
    SBI PORTB, 0                ; EN = 1
    RCALL delay_short           ; ขยายช่องโหว่ EN
    CBI PORTB, 0                ; EN = 0
    RCALL delay_us              ; ล่าช้าในไมโครวินาที
    RET

;-------------------------------------- รูทีนขัดจังหวะ ------------------------------------------
INTO_SENSOR:
    LDI R16, 0x01               ; แสดงผล "Active"
    RCALL command_wrt
    RCALL delay_ms

    IN TMP, PIND                 ; อ่านค่าจาก PIN
    ANDI TMP, 0x04               ; ตรวจสอบค่าจากเซ็นเซอร์
    LSR TMP                       ; เลื่อนค่าของ TMP
    LSR TMP
    CPI TMP, 0x01                 ; เปรียบเทียบกับ 0x01
    BREQ no_active                ; ถ้าไม่ใช่ Active กระโดดไป no_active
    RJMP check_work               ; ถ้าเป็น Active กระโดดไปตรวจสอบการทำงาน

;-------------------------------------- ไม่มีการ Active -----------------------------------------
no_active:
    LDI R16, ' '                 ; แสดงข้อความ "not active"
    RCALL data_wrt
    LDI R16, ' '
    RCALL data_wrt
    LDI R16, 'n'
    RCALL data_wrt
    LDI R16, 'o'
    RCALL data_wrt
    LDI R16, 't'
    RCALL data_wrt
    LDI R16, ' '
    RCALL data_wrt
    LDI R16, 'a'
    RCALL data_wrt
    LDI R16, 'c'
    RCALL data_wrt
    LDI R16, 't'
    RCALL data_wrt
    LDI R16, 'i'
    RCALL data_wrt
    LDI R16, 'v'
    RCALL data_wrt
    LDI R16, 'e'
    RCALL data_wrt
    LDI R16, ' '
    RCALL data_wrt
    LDI R16, ' '
    RCALL data_wrt
    RCALL delay_seconds
    SBI PORTC, 4                 ; ตั้งค่า PORTC เป็น HIGH
    RETI

;-------------------------------------- ตรวจสอบการทำงาน -----------------------------------------
check_work:
    IN R18, PINC                 ; อ่านค่าจาก DIP Switch
    ANDI R18, 0x0F               ; ตรวจสอบค่า DIP
    CPI R18, 0x03                ; เปรียบเทียบกับ 0x03
    BREQ disp_wrn                 ; ถ้าค่าตรงให้แสดงข้อความ Warning
    CPI R18, 0x0C                ; เปรียบเทียบกับ 0x0C
    BREQ disp_steal               ; ถ้าค่าตรงให้แสดงข้อความ "Found a thief"
    RETI

;-------------------------------------- แสดงข้อความ Warning ------------------------------------
disp_wrn:
    LDI R16, ' '                 ; แสดงข้อความ Warning
    RCALL data_wrt
    LDI R16, 'W'
    RCALL data_wrt
    LDI R16, 'a'
    RCALL data_wrt
    LDI R16, 'r'
    RCALL data_wrt
    LDI R16, 'n'
    RCALL data_wrt
    LDI R16, 'i'
    RCALL data_wrt
    LDI R16, 'n'
    RCALL data_wrt
    LDI R16, 'g'
    RCALL data_wrt
    LDI R16, '!'
    RCALL data_wrt
    RCALL delay_seconds
    CBI PORTC, 4                 ; ตั้งค่า PORTC เป็น LOW
    RETI

;-------------------------------------- แสดงข้อความ ขโมย ----------------------------------------
disp_steal:
    LDI R16, 'F'                 ; แสดงข้อความ "Found a thief!"
    RCALL data_wrt
    LDI R16, 'o'
    RCALL data_wrt
    LDI R16, 'u'
    RCALL data_wrt
    LDI R16, 'n'
    RCALL data_wrt
    LDI R16, 'd'
    RCALL data_wrt
    LDI R16, ' '
    RCALL data_wrt
    LDI R16, 'a'
    RCALL data_wrt
    LDI R16, ' '
    RCALL data_wrt
    LDI R16, 't'
    RCALL data_wrt
    LDI R16, 'h'
    RCALL data_wrt
    LDI R16, 'i'
    RCALL data_wrt
    LDI R16, 'e'
    RCALL data_wrt
    LDI R16, 'f'
    RCALL data_wrt
    LDI R16, '!'
    RCALL data_wrt
    RCALL delay_seconds
    CBI PORTC, 4                 ; ตั้งค่า PORTC เป็น LOW
    RETI

;-------------------------------------- ดีเลย์ -----------------------------------------------
delay_short:
    NOP
    NOP
    RET

delay_us:
    LDI R20, 90
l4:
    RCALL delay_short
    DEC R20
    BRNE l4
    RET

delay_ms:
    LDI R21, 40
l5:
    RCALL delay_us
    DEC R21
    BRNE l5
    RET

delay_seconds:
    LDI R20, 255
l6:
    LDI R21, 255
l7:
    LDI R22, 20
l8:
    DEC R22
    BRNE l8
    DEC R21
    BRNE l7
    DEC R20
    BRNE l6
    RET
