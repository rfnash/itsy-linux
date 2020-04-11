;; [[file:~/ghq/github.com/rfnash/itsy-linux/README.org::*itsy-linux.asm][itsy-linux.asm:1]]
; nasm itsy-linux.asm -fbin -l itsy-linux.lst -o itsy-linux && chmod +x itsy-linux
; Itsy Forth
;   Written by John Metcalf
;   Commentary by John Metcalf and Mike Adams
;
; Itsy Forth was written for use with NASM, the "Netwide Assembler"
; (http://www.nasm.us/). It uses a number of macros to deal with the tedium
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
%define SP0 TIBPTR - 4
%define RP0 SP0 - STACKSIZE

BITS 32
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

; esp - data stack pointer
; ebp - return stack pointer
; esi - Forth instruction pointer
; ebx - TOS (top of data stack)

    variable 'state', state, 0
    variable '>in', to_in, 0
    variable '#tib', number_t_i_b, 0
    variable 'dp', dp, freemem
    variable 'base', base, 10
    variable 'last', last, final
    variable 'tib', t_i_b, TIBPTR

    primitive 'execute', execute
        mov eax, ebx ; eax is important here, it is used by docolon and dovar
        pop ebx
        jmp dword[eax]

    primitive 'abort', abort
        mov eax, dword[val_number_t_i_b]
        mov dword[val_to_in], eax
        xor ebp, ebp
        mov dword[val_state], ebp
        mov esp, SP0
        mov ebp, RP0
        mov esi, xt_interpret + 4
        jmp next

    primitive ',', comma
        xchg eax, ebx
        mov ebx, val_dp
        mov edi, [ebx]
        stosd
        mov [ebx], edi
        pop ebx
        jmp next

    primitive 'lit', lit
        push ebx
        lodsd
        xchg eax, ebx
        jmp next

    primitive 'rot', rote
        pop edx
        pop eax
        push edx
        push ebx
        xchg eax, ebx
        jmp next

    primitive 'drop', drop
        pop ebx
        jmp next

    primitive 'dup', dupe
        push ebx
        jmp next

    primitive 'swap', swap
        xchg ebx, [esp]
        jmp next

    primitive '+', plus
        pop eax
        add ebx, eax
        jmp next

    primitive 'exit', exit
        xchg ebp, esp
        pop esi
        xchg ebp, esp
next    lodsd
        jmp dword[eax] ; eax is later used by docolon and dovar

    primitive '=', equals
        pop eax
        sub ebx, eax
        sub ebx, 1
        sbb ebx, ebx
        jmp next

    primitive '@', fetch
        mov ebx, dword[ebx]
        jmp next

    primitive '!', store
        pop dword[ebx]
        pop ebx
        jmp next

    primitive '0branch', zero_branch
        lodsd
        test ebx, ebx
        jne zerob_z
        xchg eax, esi
zerob_z pop ebx
        jmp next

    primitive 'branch', branch
        mov esi, dword[esi]
        jmp next

    primitive 'count', count
        movzx eax, byte[ebx]
        inc ebx
        push ebx
        mov ebx, eax
        jmp next

    primitive 'accept', accept
        xor edx, edx
        xchg edx, ebx ; now edx contains read byte count and ebx 0 (reading from stdin)
        xor eax, eax
        mov al, 3     ; sys_read
        pop ecx       ; buffer
        int 80h
        xchg ebx, eax ; eax after sys_read contains number of bytes read (negative number means error), let's move it to TOS
        dec ebx       ; last char is CR
        jmp next

    primitive 'emit', emit
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

    primitive '>number', to_number
        pop edi
        pop ecx
        pop eax
to_numl test ebx, ebx
        je to_numz
        push eax
        movzx eax, byte[edi]
        cmp al, 'a'
        jc to_nums
        sub al, 32
to_nums cmp al, '9' + 1
        jc to_numg
        cmp al, 'A'
        jc to_numh
        sub al, 7
to_numg sub al, 48
        cmp al, byte[val_base]
        jnc to_numh
        xchg eax, edx
        pop eax
        push edx
        xchg eax, ecx
        mul dword[val_base]
        xchg eax, ecx
        mul dword[val_base]
        add ecx, edx
        pop edx
        add eax, edx
        dec ebx
        inc edi
        jmp to_numl
to_numz push eax
to_numh push ecx
        push edi
        jmp next

    primitive 'word', word
        mov edi, dword[val_dp]
        push edi
        mov edx, ebx
        mov ebx, dword[val_t_i_b]
        mov ecx, ebx
        add ebx, dword[val_to_in]
        add ecx, dword[val_number_t_i_b]
wordf   cmp ecx, ebx
        je wordz
        mov al, byte[ebx]
        inc ebx
        cmp al, dl
        je wordf
wordc   inc edi
        mov byte[edi], al
        cmp ecx, ebx
        je wordz
        mov al, byte[ebx]
        inc ebx
        cmp al, dl
        jne wordc
wordz   mov byte[edi + 1], 32
        mov eax, dword[val_dp]
        xchg eax, edi
        sub eax, edi
        mov byte[edi], al
        sub ebx, dword[val_t_i_b]
        mov dword[val_to_in], ebx
        pop ebx
        jmp next

    primitive 'find', find
        mov edi, val_last
findl   push edi
        push ebx
        movzx ecx, byte[ebx]
        inc ecx
findc   mov al, byte[edi + 4]
        and al, 07Fh
        cmp al, byte[ebx]
        je findm
        pop ebx
        pop edi
        mov edi, dword[edi]
        test edi, edi
        jne findl
findnf  push ebx
        xor ebx, ebx
        jmp next
findm   inc edi
        inc ebx
        loop findc
        pop ebx
        pop edi
        xor ebx, ebx
        inc ebx
        lea edi, [edi + 4]
        mov al, byte[edi]
        test al, immediate
        jne findi
        neg ebx
findi   and eax, 31
        add edi, eax
        inc edi
        push edi
        jmp next

    colon ':', colon
        dd xt_lit, -1
        dd xt_state
        dd xt_store
        dd xt_create
        dd xt_do_semi_code

docolon xchg ebp, esp
        push esi
        xchg ebp, esp
        lea esi, [eax + 4] ; eax value is set by next
        jmp next

    colon ';', semicolon, immediate
        dd xt_lit, xt_exit
        dd xt_comma
        dd xt_lit, 0
        dd xt_state
        dd xt_store
        dd xt_exit

    colon 'create', create
        dd xt_dp, xt_fetch
        dd xt_last, xt_fetch
        dd xt_comma
        dd xt_last, xt_store
        dd xt_lit, 32
        dd xt_word
        dd xt_count
        dd xt_plus
        dd xt_dp, xt_store
        dd xt_lit, 0
        dd xt_comma
        dd xt_do_semi_code

dovar   push ebx
        lea ebx, [eax + 4] ; eax value is set by next
        jmp next

    primitive '(;code)', do_semi_code
        mov edi, dword[val_last]
        mov al, byte[edi + 4]
        and eax, 31
        add edi, eax
        mov dword[edi + 5], esi
        xchg ebp, esp
        pop esi
        xchg esp, ebp
        jmp next

final:

    colon 'interpret', interpret
interpt dd xt_number_t_i_b
        dd xt_fetch
        dd xt_to_in
        dd xt_fetch
        dd xt_equals
        dd xt_zero_branch
        dd intpar
        dd xt_t_i_b
        dd xt_fetch
        dd xt_lit, 50
        dd xt_accept
        dd xt_number_t_i_b
        dd xt_store
        dd xt_lit, 0
        dd xt_to_in
        dd xt_store
intpar  dd xt_lit, 32
        dd xt_word
        dd xt_find
        dd xt_dupe
        dd xt_zero_branch
        dd intnf
        dd xt_state
        dd xt_fetch
        dd xt_equals
        dd xt_zero_branch
        dd intexc
        dd xt_comma
        dd xt_branch
        dd intdone
intexc  dd xt_execute
        dd xt_branch
        dd intdone
intnf   dd xt_dupe
        dd xt_rote
        dd xt_count
        dd xt_to_number
        dd xt_zero_branch
        dd intskip
        dd xt_state
        dd xt_fetch
        dd xt_zero_branch
        dd intnc
        dd xt_last
        dd xt_fetch
        dd xt_dupe
        dd xt_fetch
        dd xt_last
        dd xt_store
        dd xt_dp
        dd xt_store
intnc   dd xt_abort
intskip dd xt_drop
        dd xt_drop
        dd xt_state
        dd xt_fetch
        dd xt_zero_branch
        dd intdone
        dd xt_lit
        dd xt_lit
        dd xt_comma
        dd xt_comma
intdone dd xt_branch
        dd interpt

freemem:

filesize   equ   $ - $$
;; itsy-linux.asm:1 ends here
