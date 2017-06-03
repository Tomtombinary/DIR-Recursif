.386 ; jeu d'instructions
.model flat,stdcall
option casemap:none 

include c:\masm32\include\windows.inc
include c:\masm32\include\gdi32.inc
include c:\masm32\include\gdiplus.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\kernel32.inc
include c:\masm32\include\msvcrt.inc
include c:\masm32\macros\macros.asm

includelib c:\masm32\lib\gdi32.lib
includelib c:\masm32\lib\kernel32.lib
includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\msvcrt.lib


.DATA
; variables initialisees

; constantes string unicode
WSTR str_format_info,13,10,"Repertoire %ws",13,10,13,10,0
WSTR str_format_info_end,13,10,"Fin de listing du repertoire %ws",13,10,13,10,0
WSTR str_format_file,"%02.2d/%02.2d/%04.4d  %02.2d:%02.2d          %ws",13,10,0
; 60 <
; 62 >
WSTR str_format_dir,"%02.2d/%02.2d/%04.4d  %02.2d:%02.2d  ",60,"REP",62,"   %ws",13,10,0
WSTR str_parent_dir,"..",0
WSTR search_pattern,"\\*",0

; constantes string ascii
str_path_to_long db "Path is too long",10,0
help_str db "Usage program <directory>",10,0

.DATA?
; variables non-initialisees (bss)
current_systime SYSTEMTIME <>
fileData WIN32_FIND_DATAW <>

.CODE

; MAX_PATH * 2 = 520
; 
; -----------
; |         |
; |         |
; |         |
; |  520o   | 
; |         |
; |         |
; |         | <----- VAR_SEARCH
; -----------
; |         | <------ VAR_HANDLE
; -----------
; |         | <------ VAR_PTR
; -----------
VAR_SEARCH equ 524
VAR_HANDLE equ 528
VAR_PTR equ 532

list_directory:
    push ebp
    mov ebp,esp
    
    sub esp,VAR_PTR
    

    mov ebx,[ebp + 8]
    push ebx
    push offset str_format_info
    call crt_wprintf
    add esp,8
    
    mov esi,[ebp + 8] ; chaine de caractère
    
    ; Copie le chemin du répertoire dans VAR_SEARCH
    lea edi,[ebp - VAR_SEARCH] 
    copy_char:
    lodsw          
    stosw
    test ax,ax
    jnz copy_char
    sub edi,2
    
    ; Ajoute \* au répertoire
    mov ax,'\'
    stosw
    mov [ebp - VAR_PTR],edi ; sauvegarde le pointeur de fin du nom du repertoire courrant 
    mov ax,'*'
    stosw
    xor ax,ax
    stosw
    
    push offset fileData ; currentFileData
    lea ebx,[ebp - VAR_SEARCH]
    push ebx ; search string
    call FindFirstFileW
    
    mov [ebp - VAR_HANDLE],eax
    
    ; Boucle sur le répertoire courrant
    loop_in_dir:
    
    ; Récupère la date de création du fichier
    mov eax,offset current_systime
    push eax
    mov eax,offset fileData.ftCreationTime
    push eax
    call FileTimeToSystemTime
    test eax,eax
    jz next_file
    
    movzx ebx,WORD PTR [current_systime.wDay]
    movzx ecx,WORD PTR [current_systime.wMonth]
    movzx edx,WORD PTR [current_systime.wYear]
    movzx esi,WORD PTR [current_systime.wHour]
    movzx edi,WORD PTR [current_systime.wMinute]
    
    ; Préparation des arguments pour le printf
    push offset fileData.cFileName
    
    push edi
    push esi
    push edx
    push ecx
    push ebx
    
    ; Test si le fichier est un repertoire
    mov eax,[fileData.dwFileAttributes]
    and eax,FILE_ATTRIBUTE_DIRECTORY
    test eax,eax
    jnz is_directory
    
    ; Ce n'est pas un répertoire on affiche sans <REP>
    push offset str_format_file
    call crt_wprintf
    add esp,28 ; 7 arguments
    jmp next_file
    
    ; C'est un répertoire on affiche avec <REP> et on liste le repertoire du dessus
    is_directory:
    ;push offset fileData.cFileName
    push offset str_format_dir
    call crt_wprintf
    add esp,28 ; 7 arguments
    
    ; Compare le nom de fichier avec "."
    mov eax,DWORD PTR [fileData.cFileName]
    cmp eax,000002Eh
    je next_file

    ; Compare le nom de fichier avec ".."
    push 260
    push offset str_parent_dir
    push offset fileData.cFileName
    call crt_wcsncmp
    add esp,12
    test eax,eax
    je next_file
    
    ; Ajoute le nom du repertoire à la suite
    mov edi,[ebp - VAR_PTR]
    mov esi, offset fileData.cFileName
    
    lea ebx,[ebp - VAR_SEARCH]
    mov eax,[ebp - VAR_PTR]
    sub eax,ebx
    shr eax,1
    
    mov ecx,MAX_PATH
    sub ecx,eax
    jl path_to_long
    
    add_path:
    dec ecx
    test ecx,ecx 
    jz path_to_long
    lodsw
    stosw
    test ax,ax
    jnz add_path
    
    ; Liste le repertoire 
    lea esi,[ebp - VAR_SEARCH]
    push esi
    call list_directory
    add esp,4
    
    ; Remet le repertoire d'origine
    mov edi,[ebp - VAR_PTR]
    xor eax,eax
    stosw
    jmp next_file
    
    path_to_long:
    push offset str_path_to_long
    call crt_printf
    add esp,4
    
    ; Passe au fichier suivant
    next_file:
    push offset fileData
    mov eax,[ebp - VAR_HANDLE]
    push eax
    call FindNextFileW
    ; Test si on atteint de la boucle
    test eax,eax
    jnz loop_in_dir
    
    ; Clean
    mov eax,[ebp - VAR_HANDLE]
    push eax
    call FindClose
    
    ; Affiche le repertoire dans lequel on se trouve
    mov ebx,[ebp + 8]
    push ebx
    push offset str_format_info_end
    call crt_wprintf
    add esp,8
    
    leave
    ret
    
; Affiche l'aide et quitte
no_next_argv:
    push offset help_str
    call crt_printf
    add esp,4
    jmp exit_program
    
start:
    
    call GetCommandLineW ; récupère les arguments de la ligne de commande
    mov esi,eax
    
    xor ecx,ecx
    ; Trouve le prochain argument
    find_next_argv:
    lodsw
    test ax,ax
    jz no_next_argv
    cmp al,' ' ; s'il y'a un espace alors c'est le deuxième argument
    jne find_next_argv
    
    mov ax,[esi]   ; regarde s'il y a plusieurs espace
    cmp al,' '
    jne end_escape_space
    
    escape_space:    ; echappe les prochains espace
    lodsw
    test ax,ax
    jz no_next_argv
    cmp al,' '
    je escape_space
    sub esi,2
    
    end_escape_space:
    push esi
    call list_directory
    add esp,4
    
exit_program:
    xor eax,eax
    push eax
    call ExitProcess
end start

