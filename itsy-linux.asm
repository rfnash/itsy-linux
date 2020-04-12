;; [[file:~/ghq/github.com/rfnash/itsy-linux/README.org::*itsy-linux.asm][itsy-linux.asm:1]]
; Itsy Forth
;    Written by John Metcalf
;    Commentary by John Metcalf and Mike Adams
;
; Itsy Forth was written for use with NASM, the "Netwide Assembler"
; that's available for free download (http://www.nasm.us/).
; The command line for assembling Itsy is:
;
;      nasm itsy-linux.asm -fbin -l itsy-linux.lst -o itsy-linux && chmod +x itsy-linux
;
; If you wish to have an assembly listing, give it this command:
;
;      nasm itsy.asm -fbin -l itsy.lst -o itsy.com
;
;--------------------------------------------------------------------------
; Implementation notes:
;
; Register Usage:
;   esp - data stack pointer.
;   ebp - return stack pointer.
;   esi - Forth instruction pointer.
;   edi - pointer to current XT (CFA of word currently being executed).
;   ebx - TOS (top of data stack). The top value on the data stack is not
;         actually kept on the CPU's data stack. It's kept in the BX register.
;         Having it in a register like this speeds up the operation of
;         the primitive words. They don't have to take the time to pull a
;         value off of the stack; it's already in a register where it can
;         be used right away!
;    eax, ecd, edx - Can all be freely used for processing data. The other
;         registers can still be used also, but only with caution. Their
;         contents must be pushed to the stack and then restored before
;         exiting from the word or calling any other Forth words. LOTS of
;         potential for program crashes if you don't do this correctly.
;         The notable exception is the EDI register, which can (and is, below)
;         used pretty freely in assembly code, since the concept of a pointer
;         to the current CFA is rather irrelevant in assembly.
;
;
; Structure of an Itsy word definition:
;     # of
;    Bytes:   Description:
;    ------   ---------------------------------------------------------
;      4      Link Field. Contains the address of the link field of the
;                definition preceding this one in the dictionary. The link
;                field of the first def in the dictionary contains 0.
;    Varies   Name Field. The first byte of the name field contains the length
;                of the name; succeeding bytes contain the ASCII characters of
;                the name itself. If the high bit of the length is set, the
;                definition is tagged as being an "immediate" word.
;      4      Code Field. Contains the address of the executable code for
;                the word. For primitives, this will likely be the address
;                of the word's own data field. Note that the header creation
;                macros automatically generate labels for the code field
;                addresses of the words they're used to define, though the
;                CFA labels aren't visible in the code shown below. The
;                assembler macros create labels, known as "execution tags"
;                or XTs, for the code field of each word.
;    Varies   Data Field. Contains either a list of the code field addresses
;                of the words that make up this definition, or assembly-
;                language code for primitives, or numeric data for variables
;                 and constants and such.


;-----------------------------------------------------------------------------
;
; Beginning of actual code.
;
; Itsy Forth uses a number of macros to deal with the tedium
; of generating the headers for the words that are defined in Itsy's source
; code file. The macros, and the explanations of what they're doing, are
; listed below:

;--------------------------------------------------------------------------
; First, two variables are defined for use by the macros:
        ; link is the initial value for the first link field that'll
        ; be defined. It's value will be updated with each header
        ; that's created.
        %define link 0

        ; A bitmask that'll be called "immediate" will be used to
        ; encode the flag into the length bytes of word names in order
        ; to indicate that the word will be of the immediate type.
        %define immediate 080h

;--------------------------------------------------------------------------
; The first macro defined is the primary one used by the others, "head".
; It does the lion's share of the work for the other macros that'll be
; defined afterwards. Its commands perform the following operations:

        ; The first line of the macro declares it's name as "head".
        ; The 4 in this line signifies that it expects to receive
        ; 4 parameters when it's invoked: the string that will be the
        ; word's name and will be encoded into the header along with
        ; the string's name; an "execution tag" name that will have the
        ; prefix "xt_" attached to it and will be used as a label for
        ; the word's code field; a flag that will be 080h if the word
        ; will be immediate and a 0 otherwise; and the label for the
        ; word's runtime code, whose address will be put into the
        ; word's code field.
        %macro head 4

        ; Okay, what we're doing in this odd-looking bit of code is
        ; declaring a variable called "%%link" that's local only to this
        ; macro and is independent of the earlier variable we declared
        ; as "link". It's a label that will represent the current
        ; location in the object code we're creating. Then we lay down
        ; some actual object code, using the "dd" command to write the
        ; current value of "link" into the executable file.
        %%link dd link

        ; Here's one of the tricky parts. We now redefine the value of
        ; "link" to be whatever the current value of "%%link" is, which
        ; is basically the address of the link field that was created
        ; during this particular use of this macro. That way, the next
        ; time head is called, the value that will be written into the
        ; code in the "dw" command above will be whatever the value of
        ; "%%link" was during THIS use of the macro. This way, each time
        ; head is called, the value that'll be written into the new
        ; link field will be the address that was used for the link
        ; field the previous time head was called, which is just how
        ; we want the link fields to be in a Forth dictionary. Note that
        ; the first time that head is called, the value of link was
        ; predefined as 0, so that the link field of the first word in
        ; the dictionary will contain the value of 0 to mark it as
        ; being the first word in the dictionary.
        %define link %%link

        ; Now the name field. The first argument passed to head is the
        ; string defining the new word's name. The next line in the macro
        ; measures the length of the string (the "%1" tells it that it's
        ; supposed to look at argument #1) and assigns it to a macro-local
        ; variable called "%%count".
        %strlen %%count %1

        ; In this next line, we're writing data into the object code on
        ; a byte-by-byte basis. We first write a byte consisting of the
        ; value of argument 3 (which is 080h if we're writing the header
        ; for an immediate word or a 0 otherwise) added to the length of
        ; the name string to produce the length byte in the header. Then
        ; we write the name string itself into the file.
        db %3 + %%count,%1

        ; Okay, don't get confused by the "+" in this next line. Take
        ; careful note of the spaces; the actual command is "%+", which
        ; is string concatenation, not numeric addition. We're going to
        ; splice a string together. The first part consists of the "xt_",
        ; then we splice the macro's 2nd argument onto it. The resulting
        ; string is used as the head's "execution tag", the address of
        ; it's code field. This label is then used for the "dd" command
        ; that writes the value of argument #4 (the address of the word's
        ; runtime code) into the header's code field.
        xt_ %+ %2 dd %4

        ; As you might guess, the next line marks the end of the
        ; macro's definition. The entire header's been defined at this
        ; point, and we're now ready for the data field, whether it's
        ; composed of assembly code, a list of Forth words, or the
        ; numeric data for a variable or constant.
        %endmacro

; For example, calling head with the following line:
;
;      head,'does>',does,080h,docolon
;
; will produce the following header code...
;
;               dw (address of link of previous header)
;               db 085h,'does>'
;      xt_does  dw docolon
;
; ...and records the address of this header's link field so that it can
; be written into the link field of the next word, just as the address
; of the previous link field was written into this header.
; This method saves the programmer a lot of tedium in manually generating
; the code for word headers when writing a Forth system's kernel in
; assembly language. Note that argument #2 is surrounded by single quotes.
; That's the format that the assembler expects to see when being told to
; lay down a string of characters byte-by-byte in a db command, so they
; have to be present when they're given as an arg to this macro so that
; the macro puts them in their proper place.

;--------------------------------------------------------------------------
; The next macro is called "primitive", and is used for setting up a header
; for a word written in assembly language.
;
        ; Here we declare the definition of the macro called "primitive".
        ; Note, though, the odd manner in which the number of required
        ; arguments is stated. Yes, that really does mean that it can
        ; take from 2 to 3 arguments. Well, what does it do if the user
        ; only gives it 2? That's what that 0 is: the default value that's
        ; to be used for argument #3 if the user doesn't specify it. Most
        ; of the time he won't; the only time arg #3 will be specifically
        ; given will be if the user is defining an immediate word.
        %macro primitive 2-3 0

        ; All primitive does is to pass its arguments on to head, which
        ; does most of the actual work. It passes on the word name and
        ; the execution tag name as-is. Parameter #3 will be given the
        ; default value of 0 unless the user specifically states it.
        ; This is meant to allow the user to add "immediate" to the
        ; macro invocation to create an immediate word. The 4th arg,
        ; "$+4", means that when head goes to write the address of the
        ; run-time code into the code field, the address it's going to
        ; use will be 2 bytes further along than the code field address,
        ; i.e. the address of the start of the code immediately after
        ; the code field. (The "$" symbol is used by most assemblers
        ; to represent the address of the code that's currently being
        ; assembled.)
        head %1,%2,%3,$+4

        ; End of the macro definition.
        %endmacro

;--------------------------------------------------------------------------
; The macro "colon" operates very similarly to "primitive", except that
; it's used for colon definitions:
;
        ; Declare the macro, with 2 to 3 arguments, using 0 for the default
        ; value of arg #3 if one isn't specifically given.
        %macro colon 2-3 0

        ; Pass the args on to head, using docolon as the runtime code.
        head %1,%2,%3,docolon

        ; End of macro definition.
        %endmacro

;--------------------------------------------------------------------------
; The rest of the macros all require a specific number of arguments, since
; none of them have the option of being immediate. This one defines
; a constant:

        ; Macro name is, unsurprisingly, "constant", and gets 3 arguments.
        ; As with head and primitive, the first 2 are the word's name and
        ; the label name that'll be used for the word. The third argument
        ; is the value that we want the constant to hold.
        %macro constant 3

        ; Use the head macro. Args 1 and 2, the names, get passed on as-is.
        ; Constants are never defined as immediate (though it's an intriguing
        ; idea; a constant whose value is one thing when compiling and
        ; another when interpreting might be useful for something), so arg #3
        ; passed on to head is always a 0, and arg #4 will always be doconst,
        ; the address of the runtime code for constants.
        head %1,%2,0,doconst

        ; Similar to the way that the label is created for the execution
        ; tags, here we create a label for the data field of the constant,
        ; though this time we're prefixing the name with "val_" instead
        ; of the "xt_" used for the execution tags. Then we use a dw to
        ; write constant's arg #3, the constant's value, into the code.
        val_ %+ %2 dw %3

        ; End of the definition.
        %endmacro

;--------------------------------------------------------------------------
; The macro for variables is very similar to the one for constants.

        ; Macro name "variable", 3 arguments, with arg #3 being the
        ; initial value that will be given to the variable.
        %macro variable 3

        ; Just like in "constant", except that the runtime code is dovar.
        head %1,%2,0,dovar

        ; Exact same line as used in "constant", with the same effects.
        val_ %+ %2 dd %3

        ; End of the definition.
        %endmacro

;--------------------------------------------------------------------------
;
; That's the last of the macros.
;
;--------------------------------------------------------------------------
%define TEXTORG 0x00400000
%define MEMSIZE 1048576
%define TIBSIZE 80
%define STACKSIZE 4096
%define TIBPTR TEXTORG + MEMSIZE - TIBSIZE

;-----------------------------------------------------------------------------
; Define the location for the stack. -256 decimal = 0ff00h
;-----------------------------------------------------------------------------
%define SP0 TIBPTR - 4

%define RP0 SP0 - STACKSIZE

BITS 32
;-----------------------------------------------------------------------------
; Set the starting point for the executable code. TEXTORG is the standard
; origin for elf programs.
;-----------------------------------------------------------------------------
        org     TEXTORG

ehdr:                           ; Elf32_Ehdr
        db   0x7F, "ELF", 1, 1, 1, 0     ; e_ident
        times 8 db   0
        dw   2                  ; e_type
        dw   3                  ; e_machine
        dd   1                  ; e_version
        dd   xt_abort + 4       ; e_entry
        dd   phdr - $$  ; e_phoff
        dd   0                  ; e_shoff
        dd   0                  ; e_flags
        dw   ehdrsize   ; e_ehsize
        dw   phdrsize   ; e_phentsize
        dw   1                  ; e_phnum
        dw   0                  ; e_shentsize
        dw   0                  ; e_shnum
        dw   0                  ; e_shstrndx

ehdrsize   equ   $ - ehdr

phdr:                           ; Elf32_Phdr
        dd   1                  ; p_type
        dd   0                  ; p_offset
        dd   $$                 ; p_vaddr
        dd   $$                 ; p_paddr
        dd   filesize   ; p_filesz
        dd   MEMSIZE    ; p_memsz
        dd   7                  ; p_flags
        dd   0x1000             ; p_align

phdrsize   equ   $ - phdr


; -------------------
; System Variables
; -------------------

        ; state - ( -- addr ) true = compiling, false = interpreting
        variable 'state',state,0

        ; >in - ( -- addr ) next character in input buffer
        variable '>in',to_in,0

        ; #tib - ( -- addr ) number of characters in the input buffer
        variable '#tib',number_t_i_b,0

        ; dp - ( -- addr ) first free cell in the dictionary
        variable 'dp',dp,freemem

        ; base - ( -- addr ) number base
        variable 'base',base,10

        ; last - ( -- addr ) the last word to be defined
        ; NOTE: The label "final:" must be placed immediately before
        ; the last word defined in this file. If new words are added,
        ; make sure they're either added before the "final:" label
        ; or the "final:" label is moved to the position immediately
        ; before the last word added.
        variable 'last',last,final

        ; tib - ( -- addr ) address of the input buffer
        variable 'tib',t_i_b,TIBPTR

; execute - ( xt -- ) call the word at xt
        primitive 'execute',execute
        mov eax, ebx   ; Move the jump-to address to EAX
                       ; eax is important here, it is used by docolon and dovar
        pop ebx        ; Pop the next number on the stack into the TOS.
        jmp dword[eax] ; Jump to the address pointed to by EAX

; -------------------
; Initialisation
; -------------------

; abort - ( -- ) initialise Itsy then jump to interpret
        primitive 'abort',abort
        mov eax,dword[val_number_t_i_b] ; Load EAX with the value contained
                                        ; in the data field of #tib (which
                                        ; was pre-defined above as 0).
        mov dword[val_to_in],eax        ; Save the same number to >in.
        xor ebp,ebp                     ; Clear the ebp register, which is going
                                        ; to be used as the return stack
                                        ; pointer. Since it'll first be
                                        ; decremented when a value is pushed
                                        ; onto it, this means that the first
                                        ; value pushed onto the return stack
                                        ; will be stored at
                                        ; the very end of memory space, and
                                        ; the stack will grow downward from
                                        ; there.
        mov dword[val_state],ebp        ; Clear the value of state.
        mov esp, SP0                    ; Set the date stack and return stack
        mov ebp, RP0                    ; pointers to the values defined above.
        mov esi,xt_interpret+4          ; Initialize Itsy's instruction pointer
                                        ; to the outer interpreter loop.
        jmp next                        ; Jump to the inner interpreter and
                                        ; actually start running Itsy.

; -------------------
; Compilation
; -------------------

; , - ( x -- ) compile x to the current definition.
;    Stores the number on the stack to the memory location currently
;    pointed to by dp.
        primitive ',',comma
        xchg eax, ebx       ; Move the top of the stack into EAX.
        mov ebx, val_dp     ; Put the value of dp into the EDI register,
        mov edi, [ebx]      ; by way of EBX. [TODO: check to make sure this is right]
        stosd               ; Store the 32-bit value in EAX directly
                            ; into the address pointed to by EDI, and
                            ; automatically increment EDI in the
                            ; process.
        mov [ebx], edi      ; Store the incremented value in EDI as the
                            ; new value for the dictionary pointer.
        pop ebx             ; Pop the new stack top into its proper place.
        jmp next            ; Go do the next word.

; lit - ( -- ) push the value in the cell straight after lit.
;   lit is the word that is compiled into a definition when you put a
;   "literal" number in a Forth definition. When your word is compiled,
;   the CFA of lit gets stored in the definition followed immediately
;   by the value of the number you put into the code. At run time, lit
;   pushes the value of your number onto the stack.
        primitive 'lit',lit
        push ebx     ; Push the value in EBX to the stack, so that now it'll
                     ; be 2nd from the top on the stack. The old value is
                     ; still in EBX, though. Now we need to get the new
                     ; value into EBX.
        lodsd        ; Load into the EAX register the 16-bit value pointed
                     ; to by the ESI register (Itsy's instruction pointer,
                     ; which this op then automatically increments SI by 4).
                     ; The net result is that we just loaded into EAX the
                     ; 32-bit data immediately following the call to lit,
                     ; which'll be the data that lit is supposed to load.
        xchg eax,ebx ; Now swap the contents of the EAX and EBX registers.
                     ; lit's data is now in EBX, the top of the stack, where
                     ; we want it. Slick, eh?
        jmp next     ; Go do the next word.

; -------------------
; Stack
; -------------------

; rot - ( x y z -- y z x ) rotate x, y and z.
;   Standard Forth word that extracts number 3rd from the top of the stack
;   and puts it on the top, effectively rotating the top 3 values.
        primitive 'rot',rote
        pop edx       ; Unload "y" from the stack.
        pop eax       ; Unload "x" from the stack. Remember that "z" is
                      ; already in EBX.
        push edx      ; Push "y" back onto the stack.
        push ebx      ; Push "z" down into the stack on top of "y".
        xchg eax,ebx  ; Swap "x" into the EBX register so that it's now
                      ; at the top of the stack.
        jmp next      ; Go do the next word.

; drop - ( x -- ) remove x from the stack.
        primitive 'drop',drop
        pop ebx      ; Pop the 2nd item on the stack into the EBX register,
                     ; writing over the item that was already at the top
                     ; of the stack in EBX. It's that simple.
        jmp next     ; Go do the next word.

; dup - ( x -- x x ) add a copy of x to the stack
        primitive 'dup',dupe
        push ebx      ; Remember that EBX is the top of the stack. Push an
                     ; extra copy of what's in EBX onto the stack.
        jmp next     ; Go do the next word.

; # swap - ( x y -- y x ) exchange x and y
        primitive 'swap',swap
        xchg ebx, [esp] ; EBX is TOS, ESP points to the 2nd from the top
        jmp next        ; Go do the next word.

; -------------------
; Maths / Logic
; -------------------

; + - ( x y -- z) calculate z=x+y then return z
        primitive '+',plus
        pop eax      ; Pop the value of "x" off of the stack.
        add ebx,eax  ; Add "x" to the value of "y" that's at the top of the
                     ; stack in the EBX register. The way the opcode is
                     ; written, the result is left in the BX register,
                     ; conveniently at the top of the stack.
        jmp next     ; Go do the next word.

; exit - ( -- ) return from the current word
        primitive 'exit',exit
        xchg ebp, esp ; The EBP register is used as Itsy's return stack pointer.
        pop esi       ; The value at its top is the address of the instruction
        xchg ebp, esp ; being pointed to before the word currently being
                      ; executed was called. This sequence pops that address
                      ; into the ESI register (Itsy's instruction pointer).
       ; inc bp       ; Now we have to increment BP twice to do a manual
                      ; "pop" of the return stack pointer.
       ; inc bp       ; 
       ; jmp net      ; jmp next not needed as the body of next is right below.
; -------------------
; Inner Interpreter
; -------------------

; This routine is the very heart of the Forth system. After execution, all
; Forth words jump to this routine, which pulls up the code field address
; of the next word to be executed and then executes it. Note that next
; doesn't have a header of its own.
next    lodsd          ; Load into the EAX register the 32-bit value pointed
                       ; to by the ESI register (Itsy's instruction pointer,
                       ; which this op then automatically increments ESI by 4).
                       ; The net result is that we just loaded into EAX the
                       ; CFA of the next word to be executed and left the
                       ; instruction pointer pointing to the word that
                       ; follows the next one.
        jmp dword[eax] ; Jump and start executing code at the address pointed to
                       ; by the value in the EAX register.
                       ; (EAX is later used by docolon and dovar)

; = - ( x y -- flag ) return true if x=y
        primitive '=',equals
        pop eax     ; Get the "x" value into a register.
        sub ebx,eax ; Perform EBX-EAX (or y-x)and leave result in EBX. If x and
                    ; y are equal, this will result in a 0 in EBX. But a zero
                    ; is a false flag in just about all Forth systems, and we
                    ; want a TRUE flag if the numbers are equal. So...
        sub ebx,1   ; Subtract 1 from it. If we had a zero before, now we've
                    ; got a -1, and a carry flag was generated.
                    ; Any other value in EBX will not generate a carry.
        sbb ebx,ebx ; This has the effect of moving the carry bit into the EBX
                    ; register. So, if the numbers were not equal, then the
                    ; "sub ebx,1" didn't generate a carry, so the result will
                    ; be a 0 in the EBX (numbers were not equal, result is
                    ; false). If the original numbers on the stack were equal,
                    ; though, then the carry bit was set and then copied
                    ; into the EBX register to act as our true flag.
                    ; This may seem a bit cryptic, but it produces smaller
                    ; code and runs faster than a bunch of conditional jumps
                    ; and immediate loads would.
        jmp next    ; Go do the next word.

; -------------------
; Peek and Poke
; -------------------

; @ - ( addr -- x ) read x from addr
; "Fetch", as the name of this word is pronounced, reads a 16-bit number from
; a given memory address, the way the Basic "peek" command does, and leaves
; it at the top of the stack.
        primitive '@',fetch
        mov ebx,dword[ebx] ; Read the value in the memory address pointed to by
                           ; the EBX register and move that value directly into
                           ; EBX, replacing the address at the top of the stack.
        jmp next           ; Go do the next word.

; ! - ( x addr -- ) store x at addr
; Similar to @, ! ("store") writes a value directly to a memory address, like
; the Basic "poke" command.
        primitive '!',store
        pop dword[ebx] ; Okay, this is a bit slick. All in one opcode, we pop
                       ; the number that's 2nd from the top of the stack
                       ; (i.e. "x" in the argument list) and send it directly
                       ; to the memory address pointed to by EBX (the address
                       ; at the top of the stack).
        pop ebx        ; Pop whatever was 3rd from the top of the stack into
                       ; the EBX register to become the new TOS.
        jmp next       ; Go do the next word.

; -------------------
; Flow Control
; -------------------

; 0branch - ( x -- ) jump if x is zero
; This is the primitive word that's compiled as the runtime code in
; an IF...THEN statement. The number compiled into the word's definition
; immediately after 0branch is the address of the word in the definition
; that we're branching to. That address gets loaded into the instruction
; pointer. In essence, this word sees a false flag (i.e. a zero) and
; then jumps over the words that comprise the "do this if true" clause
; of an IF...ELSE...THEN statement.
        primitive '0branch',zero_branch
        lodsd        ; Load into the EAX register the 16-bit value pointed
                     ; to by the ESI register (Itsy's instruction pointer,
                     ; which this op then automatically increments SI by 4).
                     ; The net result is that we just loaded into EAX the
                     ; CFA of the next word to be executed and left the
                     ; instruction pointer pointing to the word that
                     ; follows the next one.
        test ebx,ebx ; See if there's a 0 at the top of the stack.
        jne zerob_z  ; If it's not zero, jump.
        xchg eax,esi ; If the flag is a zero, we want to move the CFA of
                     ; the word we want to branch to into the Forth
                     ; instruction pointer. If the TOS was non-zero, the
                     ; instruction pointer is left still pointing to the CFA
                     ; of the word that follows the branch reference.
zerob_z pop ebx      ; Throw away the flag and move everything on the stack
                     ; up by one spot.
        jmp next     ; Oh, you know what this does by now...

; branch - ( addr -- ) unconditional jump
; This is one of the pieces of runtime code that's compiled by
; BEGIN/WHILE/REPEAT, BEGIN/AGAIN, and BEGIN/UNTIL loops. As with 0branch,
; the number compiled into the dictionary immediately after the branch is
; the address of the word in the definition that we're branching to.
        primitive 'branch',branch
        mov esi,dword[esi] ; The instruction pointer has already been
                           ; incremented to point to the address immediately
                           ; following the branch statement, which means it's
                           ; pointing to where our branch-to address is
                           ; stored. This opcode takes the value pointed to
                           ; by the ESI register and loads it directly into
                           ; the ESI, which is used as Forth's instruction
                           ; pointer.
        jmp next



; -------------------
; String
; -------------------

; count - ( addr -- addr2 len )
; count is given the address of a counted string (like the name field of a
; word definition in Forth, with the first byte being the number of
; characters in the string and immediately followed by the characters
; themselves). It returns the length of the string and a pointer to the
; first actual character in the string.
        primitive 'count',count
        movzx eax, byte[ebx]
        inc ebx            ; Increment the address past the length byte so
                           ; it now points to the actual string.
        push ebx           ; Push the new address onto the stack.
        mov ebx, eax
        jmp next

; -----------------------
; Terminal Input / Output
; -----------------------

; accept - ( addr len -- len2 ) read a string from the terminal
; accept reads a string of characters from the terminal. The string
; is stored at addr and can be up to len characters long.
; accept returns the actual length of the string.
        primitive 'accept',accept
        xor edx, edx  ; Clear the EDX register.
        xchg edx, ebx ; now edx contains read byte count and ebx 0 (reading from stdin)
        xor eax, eax
        mov al, 3     ; sys_read
        pop ecx       ; buffer
        int 80h
        xchg ebx, eax ; eax after sys_read contains number of bytes read (negative number means error), let's move it to TOS
        dec ebx       ; last char is CR
        jmp next      ; 

; emit - ( char -- ) display char on the terminal
        primitive 'emit',emit
        push ebx
        xor eax, eax
        mov al, 4    ; sys_write
        xor ebx, ebx
        inc ebx      ; ebx now contains 1 (stdout)
        mov ecx, esp ; buffer
        mov edx, ebx ; write byte count
        int 80h
        pop ebx
        pop ebx
        jmp next

; >number - ( double addr len -- double2 addr2 zero    ) if successful, or
;           ( double addr len -- int     addr2 nonzero ) on error.
; Convert a string to an unsigned double-precision integer.
; addr points to a string of len characters which >number attempts to
; convert to a number using the current number base. >number returns
; the portion of the string which can't be converted, if any.
; Note that, as is standard for most Forths, >number attempts to
; convert a number into a double (most Forths also leave it as a double
; if they find a decimal point, but >number doesn't check for that) and
; that it's called with a dummy double value already on the stack.
; On return, if the top of the stack is 0, the number was successfully
; converted. If the top of the stack is non-zero, there was an error.
        primitive '>number',to_number
                              ; Start out by loading values from the stack
                              ; into various registers. Remember that the
                              ; top of the stack, the string length, is
                              ; already in bx.
        pop edi               ; Put the address into edi.
        pop ecx               ; Put the high word of the double value into ecx
        pop eax               ; and the low word of the double value into eax.
to_numl test ebx,ebx          ; Test the length byte.
        je to_numz            ; If the string's length is zero, we're done.
                              ; Jump to end.
        push eax              ; Push the contents of eax (low word) so we can
                              ; use it for other things.
        movzx eax,byte[edi]   ; Get the next byte in the string.
        cmp al,'a'            ; Compare it to a lower-case 'a'.
        jc to_nums            ; "jc", "jump if carry", is a little cryptic.
                              ; I think a better choice of mnemonic would be
                              ; "jb", "jump if below", for understanding
                              ; what's going on here. Jump if the next byte
                              ; in the string is less than 'a'. If the chr
                              ; is greater than or equal to 'a', then it may
                              ; be a digit larger than 9 in a hex number.
        sub al,32             ; Subtract 32 from the character. If we're
                              ; converting hexadecimal input, this'll have
                              ; the effect of converting lower case to
                              ; upper case.
to_nums cmp al,'9'+1          ; Compare the character to whatever character
                              ; comes after '9'.
        jc to_numg            ; If it's '9' or less, it's possibly a decimal
                              ; digit. Jump for further testing.
        cmp al,'A'            ; Compare the character with 'A'.
        jc to_numh            ; If it's one of those punctuation marks
                              ; between '9' and 'A', we've got an error.
                              ; Jump to the end.
        sub al,7              ; The character is a potentially valid digit
                              ; for a base larger than 10. Resize it so
                              ; that 'A' becomes the digit for 11, 'B'
                              ; signifies a 11, etc.
to_numg sub al,48             ; Convert the digit to its corresponding
                              ; number. This op could also have been
                              ; written as "sub al,'0'"
        cmp al,byte[val_base] ; Compare the digit's value to the base.
        jnc to_numh           ; If the digit's value is above or equal to
                              ; to the base, we've got an error. Jump to end.
                              ; (I think using "jae" would be less cryptic.)
                              ; (NASM's documentation doesn't list jae as a
                              ; valid opcode, but then again, it doesn't
                              ; list jnc in its opcode list either.)
        xchg eax,edx          ; Save the digit value in EAX by swapping it
                              ; the contents of EDX. (We don't care what's
                              ; in EDX; it's scratchpad.)
        pop eax               ; Recall the low word of our accumulated
                              ; double number and load it into EAX.
        push edx              ; Save the digit value. (The EDX register
                              ; will get clobbered by the upcoming mul.)
        xchg eax,ecx          ; Swap the low and high words of our double
                              ; number. EAX now holds the high word, and
                              ; ECX the low.
        mul dword[val_base]   ; 32-bit multiply the high word by the base.
                              ; High word of product is in DX, low in AX.
                              ; But we don't need the high word. It's going
                              ; to get overwritten by the next mul.
        xchg eax,ecx          ; Save the product of the first mul to the ECX
                              ; register and put the low word of our double
                              ; number back into EAX.
        mul dword[val_base]   ; 32-bit multiply the low word of our converted
                              ; double number by the base, then add the high
        add ecx,edx           ; word of the product to the low word of the
                              ; first mul (i.e. do the carry).
        pop edx               ; Recall the digit value, then add it in to
        add eax,edx           ; the low word of our accumulated double-
                              ; precision total.
                              ; NOTE: One might think, as I did at first,
                              ; that we need to deal with the carry from
                              ; this operation. But we just multiplied
                              ; the number by the base, and then added a
                              ; number that's already been checked to be
                              ; smaller than the base. In that case, there
                              ; will never be a carry out from this
                              ; addition. Think about it: You multiply a
                              ; number by 10 and get a new number whose
                              ; lowest digit is a zero. Then you add another
                              ; number less than 10 to it. You'll NEVER get
                              ; a carry from adding zero and a number less
                              ; than 10.
        dec ebx               ; Decrement the length.
        inc edi               ; Inc the address pointer to the next byte
                              ; of the string we're converting.
        jmp to_numl           ; Jump back and convert any remaining
                              ; characters in the string.
to_numz push eax              ; Push the low word of the accumulated total
                              ; back onto the stack.
to_numh push ecx              ; Push the high word of the accumulated total
                              ; back onto the stack.
        push edi              ; Push the string address back onto the stack.
                              ; Note that the character count is still in
                              ; BX and is therefore already at the top of
                              ; the stack. If BX is zero at this point,
                              ; we've successfully converted the number.
        jmp next              ; Done. Return to caller.

; word - ( char -- addr ) parse the next word in the input buffer
; word scans the "terminal input buffer" (whose address is given by the
; system constant tib) for words to execute, starting at the current
; address stored in the input buffer pointer >in. The character on the
; stack when word is called is the one that the code will look for as
; the separator between words. 999 times out of 1000,; this is going to
; be a space.
        primitive 'word',word
        mov edi,dword[val_dp]           ; Load the dictionary pointer into EDI.
                                        ; This is going to be the address that
                                        ; we copy the input word to. For the
                                        ; sake of tradition, let's call this
                                        ; scratchpad area the "pad".
        push edi                        ; Save the pad pointer to the stack.
        mov edx,ebx                     ; Copy the word separator to DX.
        mov ebx,dword[val_t_i_b]        ; Load the address of the input buffer
        mov ecx,ebx                     ; into BX, and save a copy to CX.
        add ebx,dword[val_to_in]        ; Add the value of >in to the address
                                        ; of tib to get a pointer into the
                                        ; buffer.
        add ecx,dword[val_number_t_i_b] ; Add the value of #tib to the address
                                        ; of tib to get a pointer to the last
                                        ; chr in the input buffer.
wordf   cmp ecx,ebx                     ; Compare the current buffer pointer to
                                        ; the end-of-buffer pointer.
        je wordz                        ; If we've reached the end, jump.
        mov al,byte[ebx]                ; Get the next chr from the buffer
        inc ebx                         ; and increment the pointer.
        cmp al,dl                       ; See if it's the separator.
        je wordf                        ; If so, jump.
wordc   inc edi                         ; Increment our pad pointer. Note that
                                        ; if this is our first time through the
                                        ; routine, we're incrementing to the
                                        ; 2nd address in the pad, leaving the
                                        ; first byte of it empty.
        mov byte[edi],al                ; Write the new chr to the pad.
        cmp ecx,ebx                     ; Have we reached the end of the
                                        ; input buffer?
        je wordz                        ; If so, jump.
        mov al,byte[ebx]                ; Get another byte from the input
        inc ebx                         ; buffer and increment the pointer.
        cmp al,dl                       ; Is the new chr a separator?
        jne wordc                       ; If not, go back for more.
wordz   mov byte[edi+1],32              ; Write a space at the end of the text
                                        ; we've written so far to the pad.
        mov eax,dword[val_dp]           ; Load the address of the pad into AX.
        xchg eax,edi                    ; Swap the pad address with the pad
        sub eax,edi                     ; pointer then subtract to get the
                                        ; length of the text in the pad.
                                        ; The result goes into EAX, leaving the
                                        ; pad address in EDI.
        mov byte[edi],al                ; Save the length byte into the first
                                        ; byte of the pad.
        sub ebx,dword[val_t_i_b]        ; Subtract the base address of the
                                        ; input buffer from the pointer value
                                        ; to get the new value of >in...
        mov dword[val_to_in],ebx        ; ...then save it to its variable.
        pop ebx                         ; Pop the value of the pad address
                                        ; that we saved earlier back out to
                                        ; the top of the stack as our return
                                        ; value.
        jmp next

; -----------------------
; Dictionary Search
; -----------------------

; find - ( addr -- addr2 flag ) look up word in the dictionary
; find looks in the Forth dictionary for a word with the name given in the
; counted string at addr. One of the following will be returned:
;   flag =  0, addr2 = counted string --> word was not found
;   flag =  1, addr2 = call address   --> word is immediate
;   flag = -1, addr2 = call address   --> word is not immediate
        primitive 'find',find
        mov edi,val_last      ; Get the address of the link field of the last
                              ; word in the dictionary. Put it in EDI.
findl   push edi              ; Save the link field pointer.
        push ebx              ; Save the address of the name we're looking for.
        movzx ecx, byte[ebx]  ; Copy the length of the string into ECX
        inc ecx               ; Increment the counter.
findc   mov al, byte[edi + 4] ; Get the length byte of whatever word in the
                              ; dictionary we're currently looking at.
        and al,07Fh           ; Mask off the immediate bit.
        cmp al,byte[ebx]      ; Compare it with the length of the string.
        je findm              ; If they're the same, jump.
        pop ebx               ; Nope, can't be the same if the lengths are
        pop edi               ; different. Pop the saved values back to regs.
        mov edi,dword[edi]    ; Get the next link address.
        test edi,edi          ; See if it's zero. If it's not, then we've not
        jne findl             ; hit the end of the dictionary yet. Then jump
                              ; back and check the next word in the dictionary.
findnf  push ebx              ; End of dictionary. Word wasn't found. Push the
                              ; string address to the stack.
        xor ebx,ebx           ; Clear the EBX register (make a "false" flag).
        jmp next              ; Return to caller.
findm   inc edi               ; The lengths match, but do the chrs? Increment
                              ; the link field pointer. (That may sound weird,
                              ; especially on the first time through this loop.
                              ; But remember that, earlier in the loop, we
                              ; loaded the length byte out the dictionary by an
                              ; indirect reference to EDI+4. We'll do that again
                              ; in a moment, so what in effect we're actually
                              ; doing here is incrementing what's now going to
                              ; be treated as a string pointer for the name in
                              ; the dictionary as we compare the characters
                              ; in the strings.)
        inc ebx               ; Increment the pointer to the string we're
                              ; checking.
        loop findc            ; Decrements the counter in ECX and, if it's not
                              ; zero yet, loops back. The same code that started
                              ; out comparing the length bytes will go through
                              ; and compare the characters in the string with
                              ; the chrs in the dictionary name we're pointing
                              ; at.
        pop ebx               ; If we got here, then the strings match. The
                              ; word is in the dictionary. Pop the string's
                              ; starting address and throw it away. We don't
                              ; need it now that we know we're looking at a
                              ; defined word.
        pop edi               ; Restore the link field address for the dictionary
                              ; word whose name we just looked at.
        xor ebx, ebx          ; Put a 1 at the top of the stack.
        inc ebx
        lea edi, [edi + 4]    ; Increment the pointer past the link field to the
                              ; name field.
        mov al,byte[edi]      ; Get the length of the word's name.
        test al,immediate     ; See if it's an immediate.
        jne findi             ; "test" basically performs an AND without
                              ; actually changing the register. If the
                              ; immediate bit is set, we'll have a non-zero
                              ; result and we'll skip the next instruction,
                              ; leaving a 1 in EBX to represent that we found
                              ; an immediate word.
        neg ebx               ; But if it's not an immediate word, we fall
                              ; through and generate a -1 instead to get the
                              ; flag for a non-immediate word.
findi   and eax,31            ; Mask off all but the valid part of the name's
                              ; length byte.
        add edi,eax           ; Add the length to the name field address then
        inc edi               ; add 1 to get the address of the code field.
        push edi              ; Push the CFA onto the stack.
        jmp next              ; We're done.

; -----------------------
; Colon Definition
; -----------------------

; : - ( -- ) define a new Forth word, taking the name from the input buffer.
; Ah! We've finally found a word that's actually defined as a Forth colon
; definition rather than an assembly language routine! Partly, anyway; the
; first part is Forth code, but the end is the assembly language run-time
; routine that, incidentally, executes Forth colon definitions. Notice that
; the first part is not a sequence of opcodes, but rather is a list of
; code field addresses for the words used in the definition. In each code
; field of each defined word is an "execution tag", or "xt", a pointer to
; the runtime code that executes the word. In a Forth colon definition, this
; is going to be a pointer to the docolon routine we see in the second part
; of the definition of colon itself below.
        colon ':',colon
        dd xt_lit,-1       ; If you write a Forth routine where you put an
                           ; integer number right in the code, such as the
                           ; 2 in the phrase, "dp @ 2 +", lit is the name
                           ; of the routine that's called at runtime to put
                           ; that integer on the stack. Here, lit pushes
                           ; the -1 stored immediately after it onto the
                           ; stack.
        dd xt_state        ; The runtime code for a variable leaves its
                           ; address on the stack. The address of state,
                           ; in this case.
        dd xt_store        ; Store that -1 into state to tell the system
                           ; that we're switching from interpret mode into
                           ; compile mode. Other than creating the header,
                           ; colon doesn't actually compile the words into
                           ; the new word. That task is performed in
                           ; interpret, but it needs this new value stored
                           ; into state to tell it to do so.
        dd xt_create       ; Now we call the word that's going to create the
                           ; header for the new colon definition we're going
                           ; to compile.
        dd xt_do_semi_code ; Write, into the code field of the header we just
                           ; created, the address that immediately follows
                           ; this statement: the address of the docolon
                           ; routine, which is the code that's responsible
                           ; for executing the colon definition we're
                           ; creating.
docolon xchg ebp, esp      ; Here's the runtime code for colon words.
                           ; Basically, what docolon does is similar to
                           ; calling a subroutine, in that we have to push
                           ; the return address to the stack. Since the 80x86
                           ; doesn't directly support more than one stack and
                           ; the "real" stack is used for data, we have to
                           ; operate the Forth virtual machine's return stack
                           ; by temporarily exchanging EBP (the return stack
                           ; pointer) and ESP (the data stack pointer).
        push esi           ; Pop the value of the return stack into the
                           ; instruction pointer, then restore the return and
        xchg ebp, esp      ; data stack pointers to the correct registers.
        lea esi,[eax+4]    ; We now have to tell Forth to start running the
                           ; words in the colon definition we just started.
                           ; The value in EAX was left pointing at the code
                           ; field of the word that we just started that just
                           ; jumped into docolon. By loading into the
                           ; instruction pointer the value that's 4 bytes
                           ; later, at the start of the data field, we're
                           ; loading into the IP the address of the first
                           ; word in that definition. Execution of the other
                           ; words in that definition will occur in sequence
                           ; from here on.
        jmp next           ; Now that we're pointing to the correct
                           ; instruction, go do it.

; ; - ( -- ) complete the Forth word being compiled
        colon ';',semicolon,immediate
                           ; Note above that ; is immediate, the first such
                           ; word we've seen here. It needs to be so because
                           ; it's used only during the compilation of a colon
                           ; definition and we want it to execute rather than
                           ; just being stored in the definition.
        dd xt_lit,xt_exit  ; Put the address of the code field of exit onto
                           ; the stack.
        dd xt_comma        ; Store it into the dictionary.
        dd xt_lit,0        ; Now put a zero on the stack...
        dd xt_state        ; along with the address of the state variable.
        dd xt_store        ; Store the 0 into state to indicate that we're
                           ; done compiling a word and are now back into
                           ; interpret mode.
        dd xt_exit         ; exit is the routine that finishes up the
                           ; execution of a colon definition and jumps to
                           ; next in order to start execution of the next
                           ; word.

; -----------------------
; Headers
; -----------------------

; create - ( -- ) build a header for a new word in the dictionary, taking
; the name from the input buffer
        colon 'create',create
        dd xt_dp,xt_fetch   ; Get the current dictionary pointer.
        dd xt_last,xt_fetch ; Get the LFA of the last word in the dictionary.
        dd xt_comma         ; Save the value of last at the current point in
                            ; the dictionary to become the link field for
                            ; the header we're creating. Remember that comma
                            ; automatically increments the value of dp.
        dd xt_last,xt_store ; Save the address of the link field we just
                            ; created as the new value of last.
        dd xt_lit,32        ; Parse the input buffer for the name of the
        dd xt_word          ; word we're creating, using a space for the
                            ; separation character when we invoke word.
                            ; Remember that word copies the parsed name
                            ; as a counted string to the location pointed
                            ; to by dp, which not coincidentally is
                            ; exactly what and where we need it for the
                            ; header we're creating.
        dd xt_count         ; Get the address of the first character of the
                            ; word's name, and the name's length.
        dd xt_plus          ; Add the length to the address to get the addr
                            ; of the first byte after the name, then store
        dd xt_dp,xt_store   ; that address as the new value of dp.
        dd xt_lit,0         ; Put a 0 on the stack, and store it as a dummy
        dd xt_comma         ; placeholder in the new header's CFA.
        dd xt_do_semi_code  ; Write, into the code field of the header we just
                            ; created, the address that immediately follows
                            ; this statement: the address of the dovar
                            ; routine, which is the code that's responsible
                            ; for pushing onto the stack the data field
                            ; address of the word whose header we just
                            ; created when it's executed.
dovar   push ebx            ; Push the stack to make room for the new value
                            ; we're about to put on top.
        lea ebx,[eax+4]     ; This opcode loads into ebx whatever four plus the
                            ; value of the contents of EAX might be, as opposed
                            ; to a "mov ebx,[eax+4]", which would move into EBX
                            ; the value stored in memory at that location.
                            ; What we're actually doing here is calculating
                            ; the address of the data field that follows
                            ; this header so we can leave it on the stack.
        jmp next            ; (eax value is set by next)

; # (;code) - ( -- ) replace the xt of the word being defined with a pointer
; to the code immediately following (;code)
; The idea behind this compiler word is that you may have a word that does
; various compiling/accounting tasks that are defined in terms of Forth code
; when its being used to compile another word, but afterward, when the new
; word is executed in interpreter mode, you want your compiling word to do
; something else that needs to be coded in assembly. (;code) is the word that
; says, "Okay, that's what you do when you're compiling, but THIS is what
; you're going to do while executing, so look sharp, it's in assembly!"
; Somewhat like the word DOES>, which is used in a similar manner to define
; run-time code in terms of Forth words.
        primitive '(;code)',do_semi_code
        mov edi,dword[val_last] ; Get the LFA of the last word in dictionary
                                ; (i.e. the word we're currently in the middle
                                ; of compiling) and put it in EDI. 
        mov al,byte[edi+4]      ; Get the length byte from the name field.
        and eax,31              ; Mask off the immediate bit and leave only
                                ; the 5-bit integer length.
        add edi,eax             ; Add the length to the pointer. If we add 5
                                ; to the value in EDI at this point, we'll
                                ; have a pointer to the code field.
        mov dword[edi+5],esi    ; Store the current value of the instruction
                                ; pointer into the code field. That value is
                                ; going to point to whatever follows (;code) in
                                ; the word being compiled, which in the case
                                ; of (;code) had better be assembly code.
        xchg ebp, esp           ; Okay, we just did something funky with the
                                ; instruction pointer; now we have to fix it.
        pop esi                 ; Directly load into the instruction pointer
        xchg esp, ebp           ; the value that's currently at the top of
                                ; the return stack.
        jmp next                ; Done. Go do another word.
; -----------------------
; Outer Interpreter
; -----------------------

; -------------------------------------------------------
; NOTE! The following line with the final: label MUST be
; immediately before the final word definition!
; -------------------------------------------------------

final:

        colon 'interpret',interpret
interpt dd xt_number_t_i_b  ; Get the number of characters in the input
        dd xt_fetch         ; buffer.
        dd xt_to_in         ; Get the index into the input buffer.
        dd xt_fetch         ; 
        dd xt_equals        ; See if they're the same.
        dd xt_zero_branch   ; If not, it means there's still some text in
        dd intpar           ; the buffer. Go process it.
        dd xt_t_i_b         ; if #tib = >in, we're out of text and need to
        dd xt_fetch
        dd xt_lit           ; read some more. Put a 50 on the stack to tell
        dd 50               ; accept to read up to 50 more characters.
        dd xt_accept        ; Go get more input.
        dd xt_number_t_i_b  ; Store into #tib the actual number of characters
        dd xt_store         ; that accept read.
        dd xt_lit           ; Reposition >in to index the 0th byte in the
        dd 0                ; input buffer.
        dd xt_to_in         ; 
        dd xt_store         ; 
intpar  dd xt_lit           ; Put a 32 on the stack to represent an ASCII
        dd 32               ; space character. Then tell word to scan the
        dd xt_word          ; buffer looking for that character.
        dd xt_find          ; Once word has parsed out a string, have find
                            ; see if that string matches the name of any
                            ; words already defined in the dictionary.
        dd xt_dupe          ; Copy the flag returned by find, then jump if
        dd xt_zero_branch   ; it's a zero, meaning that the string doesn't
        dd intnf            ; match any defined word names.
        dd xt_state         ; We've got a word match. Are we interpreting or
        dd xt_fetch         ; do we want to compile it? See if find's flag
        dd xt_equals        ; matches the current value of state.
        dd xt_zero_branch   ; If so, we've got an immediate. Jump.
        dd intexc           ; 
        dd xt_comma         ; Not immediate. Store the word's CFA in the
        dd xt_branch        ; dictionary then jump to the end of the loop.
        dd intdone          ; 
intexc  dd xt_execute       ; We found an immediate word. Execute it then
        dd xt_branch        ; jump to the end of the loop.
        dd intdone          ; 
intnf   dd xt_dupe          ; Okay, it's not a word. Is it a number? Copy
                            ; the flag, which we've already proved is 0,
                            ; thereby creating a double-precision value of
                            ; 0 at the top of the stack. We'll need this
                            ; shortly when we call >number.
        dd xt_rote          ; Rotate the string's address to the top of
                            ; the stack. Note that it's still a counted
                            ; string.
        dd xt_count         ; Use count to split the string's length byte
                            ; apart from its text.
        dd xt_to_number     ; See if we can convert the text into a number.
        dd xt_zero_branch   ; If we get a 0 from 0branch, we got a good
        dd intskip          ; conversion. Jump and continue.
        dd xt_state         ; We had a conversion error. Find out whether
        dd xt_fetch         ; we're interpreting or compiling.
        dd xt_zero_branch   ; If state=0, we're interpreting. Jump
        dd intnc            ; further down.
        dd xt_last          ; We're compiling. Shut the compiler down in an
        dd xt_fetch         ; orderly manner. Get the LFA of the word we
        dd xt_dupe          ; were trying to compile. Set aside a copy of it,
        dd xt_fetch         ; then retrieve from it the LFA of the old "last
        dd xt_last          ; word" and resave that as the current last word.
        dd xt_store         ; 
        dd xt_dp            ; Now we have to save the LFA of the word we just
        dd xt_store         ; tried to compile back into the dictionary
                            ; pointer.
intnc   dd xt_abort         ; Whether we were compiling or interpreting,
                            ; either way we end up here if we had an
                            ; unsuccessful number conversion. Call abort
                            ; and reset the system.
intskip dd xt_drop          ; >number was successful! Drop the address and
        dd xt_drop          ; the high word of the double-precision numeric
                            ; value it returned. We don't need either. What's
                            ; left on the stack is the single-precision
                            ; number we just converted.
        dd xt_state         ; Are we compiling or interpreting?
        dd xt_fetch         ; 
        dd xt_zero_branch   ; If we're interpreting, jump on down.
        dd intdone          ; 
        dd xt_lit           ; No, John didn't stutter here. These 4 lines are
        dd xt_lit           ; how "['] lit , ," get encoded. We need to store
        dd xt_comma         ; lit's own CFA into the word, followed by the
        dd xt_comma         ; number we just converted from text input.
intdone dd xt_branch        ; Jump back to the beginning of the interpreter
        dd interpt          ; loop and process more input.

freemem:

; That's it! So, there you have it! Only 33 named Forth words...
;
;     ,  @   >in  dup   base  word   abort   0branch   interpret
;     +  !   lit  swap  last  find   create  constant  (;code)
;     =  ;   tib  drop  emit  state  accept  >number
;     :  dp  rot  #tib  exit  count  execute
;
; ...plus 6 pieces of headerless code and run-time routines...
;
;     getchar  outchar  docolon  dovar  doconst  next
;
; ...are all that's required to produce a functional Forth interpreter
; capable of compiling colon definitions, only 978 bytes long! Granted,
; it's lacking a number of key critical words that make it nigh unto
; impossible to do anything useful, but this just goes to show just
; how small a functioning Forth system can be made.
filesize   equ   $ - $$
;; itsy-linux.asm:1 ends here
