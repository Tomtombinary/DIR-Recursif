.386 ; jeu d'instructions
.model flat,stdcall
option casemap:none 

include c:\masm32\include\windows.inc
include c:\masm32\include\gdi32.inc
include c:\masm32\include\gdiplus.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\kernel32.inc
include c:\masm32\include\msvcrt.inc
include c:\masm32\include\comctl32.inc

include c:\masm32\macros\macros.asm

includelib c:\masm32\lib\comctl32.lib
includelib c:\masm32\lib\gdi32.lib
includelib c:\masm32\lib\kernel32.lib
includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\msvcrt.lib

.CONST

; Identifiant des composants de la fenêtre
ID_B_SEARCH equ 1 ; identifiant du bouton pour lister le repertoire
ID_E_PATH   equ 2 ; identifiant de la zone de saisie
ID_T_VIEW   equ 3 ; identifiant du treeview

; Identifiant des ressource embarquée
IDB_FILE equ 4001      ; bitmap de fichier
IDB_OFOLDER equ 4002   ; bitmap de dossier ouvert
IDB_CFOLDER equ 4003   ; bitmap de dossier fermé

; Dimension de la fenêtre 
WINDOW_WIDTH     equ 400 ; largeur
WINDOW_HEIGHT    equ 300 ; hauteur

; Dimension de la zone de saisie
EDIT_PATH_WIDTH  equ WINDOW_WIDTH * 3/4
EDIT_PATH_HEIGHT equ 18  

; Dimension du bouton
BTN_WIDTH        equ WINDOW_WIDTH * 1/4
BTN_HEIGHT       equ 18

; Dimension du treeview
TVIEW_WIDTH      equ EDIT_PATH_WIDTH + BTN_WIDTH 
TVIEW_HEIGHT     equ WINDOW_HEIGHT - EDIT_PATH_HEIGHT - 20

; Constante pour les images du TreeView 
CX_BITMAP   equ 16 ; Largeur en pixels
CY_BITMAP   equ 16 ; Hauteur en pixels
NUM_BITMAPS equ 3  ; Nombre d'image

; Constantes en UNICODE
WSTR str_parent_dir,"..",0   ; nom du dossier parent
; WSTR search_pattern,"\\*",0  ; pattern à concaténer

; Constantes en ASCII
window_classname db "MyWin",0    ; nom de classe de la fenêtre
window_title db "DIR Recursif",0 ; titre de la fenêtre
szButtonName db "Lister",0       ; texte du button

; Identifiant des type de composants graphiques
WC_SYSTREEVIEW32 db "SysTreeView32",0
WC_BUTTON db "Button",0
WC_EDIT db "Edit",0

.DATA
; variables initialisees
; variables concernant l'interface graphique
wcWinClass     WNDCLASS <0,0,0,0,0,0,0,0,0,0> ; Classe de fenêtre
rcScreen       RECT <0,0,0,0>                 ; Dimension de la fenêtre

g_Instance     HINSTANCE 0 ; Handle passé en paramètre par WinMain
g_hWnd         HWND      0 ; Handle sur la fenêtre principale
g_ButtonSearch HWND      0 ; Handle sur le bouton lister
g_EditPath     HWND      0 ; Handle sur la zone de saisie
g_DirView      HWND      0 ; Handle sur le TreeView
g_Module       HANDLE    0 ; Handle sur le module executable

g_tvins TV_INSERTSTRUCT <> ; Structure pour insérer un item dans un TreeView

g_Open   dd -1 ; Indice du bitmap dossier ouvert dans la liste du TreeView
g_Closed dd -1 ; Indice du bitmap dossier fermée dans la liste du TreeView
g_File   dd -1 ; Indice du bitmap fichier dans la liste du TreeView



.DATA?
; variables non-initialisees (bss)
fileData WIN32_FIND_DATAW <> ; Informations sur le fichier courrant
message MSG <>               ; Message transmis à la fenêtre

.CODE

ARG_lpszText equ 8
ARG_hParent equ 12
ARG_bIsFile equ 16

; Fonction : add_item_to_tree_view
; Description : Ajoute un item dans le TreeView de la fenêtre. L'image associé à 
; l'item est définie en fonction du paramètre bIsFile.
; 
; Argument1 : lpszText, texte de l'item
; Argument2 : hParent, handle vers le l'item parent, sous lequel l'item courant doit être ajouté
; Argument3 : bIsFile, 1 indique un répertoire
;                      0 indique un fichier
; Return: un handle vers l'item ajouté

add_item_to_tree_view:
    push ebp
    mov ebp,esp
    
    mov eax,[ebp + ARG_hParent] ; hParent
    mov [g_tvins.hParent],eax
    mov [g_tvins.hInsertAfter],TVI_LAST ; L'item seras ajouté en fin de liste
    
    ; Seul les paramètre pszText, iImage et iSelectedImage serons valable
    mov DWORD PTR[g_tvins.item], TVIF_TEXT OR TVIF_IMAGE OR TVIF_SELECTEDIMAGE 
    mov eax,[ebp + ARG_lpszText]
    mov [g_tvins.item.pszText],eax
    
    mov eax,[ebp + ARG_bIsFile] ; is_file
    test eax,eax ; Si 0 c'est un fichier, si 1 c'est un repertoire
    jz if_file
    ; En temps normal l'item affiche un dossier
    mov eax,[g_Closed]
    mov [g_tvins.item.iImage],eax
    ; Si il est selectionné, l'item affiche un dossier ouvert
    mov eax,[g_Open]
    mov [g_tvins.item.iSelectedImage],eax
    
    jmp end_if_file
    if_file:
    ; Lorsque c'est un fichier dans les deux cas l'item affiche un fichier
    mov eax,[g_File]
    mov [g_tvins.item.iImage],eax
    mov [g_tvins.item.iSelectedImage],eax
    
    end_if_file:
    
    push offset g_tvins
    push 0
    push TVM_INSERTITEMW
    push [g_DirView]
    call SendMessageW
    ; SendMessageW retourne l'handle de l'item ajouté,
    ; donc eax contient déjà la bonne valeur de retour
    leave
    ret
    
; MAX_PATH * 2 = 520
; 
; —---------
; |         |
; |         |
; |         |
; |  520o   | 
; |         |
; |         |
; |         | <---— VAR_SEARCH
; —---------
; |         | <------ VAR_HANDLE
; —---------
; |         | <------ VAR_HPARENT
; ----------
; |         | <------ VAR_PTR
; —---------
VAR_SEARCH equ 524
VAR_HANDLE equ 528
VAR_HPARENT equ 532
VAR_PTR equ 536

; Fonction : list_directory
; Description : liste un repertoire recursivement et met à jour le résultat dans le TreeView
; 
; Argument1 : lpszDirectoryToList, le chemin relatif ou absolu du répertoire à lister
; Argument2 : hParent, le handle de l'item dans le TreeView représentant le répertoire parent
;
; Return : Rien
list_directory:
    push ebp
    mov ebp,esp
    ; Alloue assez de place pour toutes les variables dans la pile
    sub esp,VAR_PTR

    ; Copie le chemin du répertoire dans VAR_SEARCH
    mov esi,[ebp + 8] 
    lea edi,[ebp - VAR_SEARCH]
    copy_char:      ; boucle pour copier les caractères
    lodsw           ; les caractères sont en UNICODE on travaille donc avec des mots
    stosw
    test ax,ax      ; test si la fin de la chaîne
    jnz copy_char
    
    ; Ajoute \* au répertoire
    sub edi,2       ; On se place sur le caractère final \0
    mov ax,'\'      
    stosw
    ; edi pointe sur la fin du nom de dossier
    mov [ebp - VAR_PTR],edi ; On sauvgarde sa valeur pour une utilisation future
    mov ax,'*'      ; On ajoute le caractère * pour lister tout les fichiers
    stosw
    xor ax,ax       ; On met eax à 0
    stosw           ; Place le caractère final
    
    push offset fileData         ; &fileData
    lea ebx,[ebp - VAR_SEARCH]   
    push ebx                     ; lpFileName
    call FindFirstFileW          
    mov [ebp - VAR_HANDLE],eax   ; Recupèration du handle pour parcourir le dossier
    
    ; Boucle sur le répertoire courrant
    loop_in_dir:
    ; Test si le fichier est un repertoire
    mov eax,[fileData.dwFileAttributes]
    and eax,FILE_ATTRIBUTE_DIRECTORY
    test eax,eax
    
    ; On prépare les arguments pour add_item_to_tree_view
    ; On place dans l'ordre : 
    ; - boolean pour savoir si le fichier est un repertoire ou non
    ; - Argument2, hParent
    ; - Nom court du fichier
    push eax                       
    push [ebp + 12]                 
    push offset fileData.cFileName  

    ; En fonction du test précedent on applique la procédure correspondante
    jnz is_directory
    
    ; Ce n'est pas un repertoire on se contente d'ajouter un item au TreeView
    call add_item_to_tree_view
    add esp,12
    ; Ensuite on passe au fichier suivant
    jmp next_file
    
    ; C'est un répertoire on ajoute un item au TreeView,
    ; on sauvegarde le handle de l'item représentant ce repertoire
    ; et on liste le repertoire du dessus
    is_directory:
    call add_item_to_tree_view
    add esp,12
    mov [ebp - VAR_HPARENT],eax ;
    
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
    
    ; Calcule la taille disponible pour la concatenation
    lea ebx,[ebp - VAR_SEARCH]
    mov eax,[ebp - VAR_PTR]
    sub eax,ebx
    shr eax,1          ; division par 2
    mov ecx,MAX_PATH
    sub ecx,eax
    jl path_to_long
    ; Si la taille est suffisante on ajoute le nom du dossier au nom du répertoire courant
    add_path:
    dec ecx
    test ecx,ecx 
    jz path_to_long
    lodsw
    stosw
    test ax,ax
    jnz add_path
    
    ; Appel recursif sur list_directory, on place dans l'ordre
    ; - Le handle de l'item qui va contenir les items fichiers
    ; - Le repertoire à lister
    push [ebp - VAR_HPARENT]
    lea esi,[ebp - VAR_SEARCH]
    push esi
    call list_directory
    add esp,8
    
    ; Remet le repertoire d'origine
    mov edi,[ebp - VAR_PTR]
    xor eax,eax
    stosw
    jmp next_file
    
    ; Si le nom de repertoire est trop long
    path_to_long:
    ; Passe au fichier suivant
    next_file:
    push offset fileData
    push [ebp - VAR_HANDLE]
    call FindNextFileW
    ; Test si on atteint de la boucle
    test eax,eax
    jnz loop_in_dir
    
    ; On ferme le handle qui servait à lister le repertoire
    push [ebp - VAR_HANDLE]
    call FindClose

    leave
    ret
    
; Fonction : window_proc
; Description : Procedure de callback, permettant de traiter les messages envoyés à la fenêtre
;   Si le message WM_CREATE est envoyé le programme créer les composants de la fenêtre
;   Si le message WM_COMMAND est envoyé le programme traite l'evenement concernant le bouton lister
;   Si le message WM_DESTROY est envoyé le programme fait une requête pour quitter
;   Sinon l'evenement est traité avec la procédure par défaut DefWindowProc
; Argument1 : hwnd, handle de la fenêtre
; Argument2 : uMsg, message transmis à la fenêtre
; Argument3 : wParam, information supplémentaire en fonction de uMsg
; Argument4 : wParam, information supplémentaire en fonction de uMsg
; Return : le résultat du traitement en fonction du paramètre uMsg
window_proc:
    push ebp
    mov ebp,esp
    
    mov eax,[ebp + 12]    ; uMsg
    cmp eax,WM_CREATE     
    je window_proc_create
    cmp eax,WM_DESTROY
    je window_proc_destroy
    cmp eax,WM_COMMAND
    je window_proc_command
    ; Traitement par défaut
    mov eax,[ebp + 8]  ; hwnd  
    mov ebx,[ebp + 12] ; message 
    mov ecx,[ebp + 16] ; wparam
    mov edx,[ebp + 20] ; lParam
    
    push edx
    push ecx
    push ebx
    push eax
    call DefWindowProc
    jmp window_proc_end
    
    ; Création des composants fils de la fenêtre
    window_proc_create:
    
    ; Récupère les dimensions de la fenêtre
    push offset rcScreen      ; rect
    push [ebp + 8]            ; hwnd
    call GetClientRect
    
    ; Création du bouton
    push NULL                 ; lpParam
    push [g_Instance]         ; hInstance
    push ID_B_SEARCH          ; hMenu
    push [ebp + 8]            ; hWndParent
    push BTN_HEIGHT           ; nHeight
    push BTN_WIDTH            ; nWidth
    push [rcScreen.top]       ; y
    mov eax,[rcScreen.left]
    add eax,EDIT_PATH_WIDTH
    push eax                  ; x
    mov eax,WS_CHILD+WS_VISIBLE
    push eax                  ; dwStyle
    push offset szButtonName  ; lpWindowName
    push offset WC_BUTTON     ; lpClassName
    push 0                    ; dwExtStyle
    call CreateWindowEx
    mov [g_ButtonSearch],eax
   
    ; Création de la zone d'édition
    push NULL                          ; lpParam
    push [g_Instance]                  ; hInstance
    push ID_E_PATH                     ; hMenu
    push [ebp + 8]                     ; hWndParent
    push EDIT_PATH_HEIGHT              ; nHeight
    push EDIT_PATH_WIDTH               ; nWidth
    push [rcScreen.top]                ; y
    push [rcScreen.left]               ; x
    push WS_CHILD+WS_VISIBLE+WS_BORDER ; dwStyle
    push NULL                          ; lpWindowName
    push offset WC_EDIT                ; lpClassName
    push 0                             ; dwExtStyle
    call CreateWindowEx
    mov [g_EditPath],eax
    
    ; Création du treeview
    push 0                       ; lpParam
    push [g_Instance]            ; hInstance
    push ID_T_VIEW               ; hMenu
    push [ebp + 8]               ; hWndParent
    push TVIEW_HEIGHT            ; nHeight
    push TVIEW_WIDTH             ; nWidth
    mov eax,[rcScreen.top]
    add eax,EDIT_PATH_HEIGHT
    push eax                     ; y
    push [rcScreen.left]         ; x
    push WS_CHILD+WS_VISIBLE+TVS_HASLINES+TVS_HASBUTTONS+TVS_LINESATROOT ; dwStyle
    push 0                       ; lpWindowName
    push offset WC_SYSTREEVIEW32 ; lpClassName
    push 0                       ; dwExtStyle
    call CreateWindowEx
    mov [g_DirView],eax

    ; Initialise une liste d'image contenu dans le TreeView
    push eax
    call init_tree_view_image_list
    add esp,4
    
    xor eax,eax
    jmp window_proc_end
    
    window_proc_destroy:
    push 0
    call PostQuitMessage
    xor eax,eax
    jmp window_proc_end
    
    window_proc_command:
    cmp WORD PTR [ebp + 16],ID_B_SEARCH  ; wParam
    jnz window_proc_command_end
    
    push TVI_ROOT
    push 0
    push TVM_DELETEITEM
    push [g_DirView]
    call SendMessage
    
    sub esp,MAX_PATH*2
    mov eax,esp
    
    push MAX_PATH
    push eax
    push [g_EditPath]
    call GetWindowTextW
    
    mov eax,esp
    
    push TVI_ROOT
    push eax
    call list_directory  ; list_directory(chemin,g_hPrev)
    add esp,8
    add esp,MAX_PATH*2
    
    window_proc_command_end:
    xor eax,eax
    inc eax
    
    window_proc_end:
    leave
    ret
    
init_tree_view_image_list:
    push ebp
    mov ebp,esp
    sub esp,12
    
    mov eax,[ebp + 8] ; hwn tree view
    
    push 0
    push NUM_BITMAPS
    push FALSE
    push CY_BITMAP
    push CX_BITMAP
    call ImageList_Create
    mov [ebp - 4],eax
    test eax,eax
    jz init_tree_view_image_list_fail
    
    ; Charge la resource bitmap (Dossier ouvert)
    push IDB_OFOLDER
    mov eax,[g_Module]
    push eax
    call LoadBitmap
    mov [ebp - 8],eax
    ; Ajoute l'image
    push 0
    push eax
    mov eax,[ebp - 4]
    push eax
    call ImageList_Add
    mov [g_Open],eax
    ; Libère la ressource
    mov eax,[ebp - 8]
    push eax
    call DeleteObject
    
    ; Charge la ressource bitmap (Dossier fermé)
    push IDB_CFOLDER
    mov eax,[g_Module]
    push eax
    call LoadBitmap
    mov [ebp - 8],eax
    ; Ajoute l'image
    push 0
    push eax
    mov eax,[ebp - 4]
    push eax
    call ImageList_Add
    mov [g_Closed],eax
    ; Libère la ressource
    mov eax,[ebp - 8]
    push eax
    call DeleteObject
    
    ; Charge la ressource  bitmap (Fichier)
    push IDB_FILE
    mov eax,[g_Module]
    push eax
    call LoadBitmap
    mov [ebp - 8],eax
    ; Ajoute l'image
    push 0
    push eax
    mov eax,[ebp - 4]
    push eax
    call ImageList_Add
    mov [g_File],eax
    ; Libère la ressource
    mov eax,[ebp - 8]
    push eax
    call DeleteObject
    
    mov eax,[ebp - 4] ; image list handle
    push eax
    call ImageList_GetImageCount
    cmp eax,3
    jl init_tree_view_image_list_fail
    
    ; Equivaut à TreeView_SetImageList(hwndTV, himl, TVSIL_NORMAL); 
    mov eax,[ebp - 4] ; image list handle
    push eax
    push TVSIL_NORMAL
    push TVM_SETIMAGELIST
    mov eax,[ebp + 8] ; hwnd
    push eax
    call SendMessage
    
    jmp init_tree_view_image_list_end
    init_tree_view_image_list_fail:
    xor eax,eax
    init_tree_view_image_list_end:
    leave
    ret
    
WinMain:
    push ebp
    mov ebp,esp
    
    call InitCommonControls
    ; Récupère le handle de l'executable
    push 0
    call GetModuleHandle
    mov [g_Module],eax
    
    mov eax,[ebp + 8] ; instance courante 
    mov [g_Instance],eax
    
    ; Initialisation de la classe de fenêtre
    mov [wcWinClass.hInstance],eax
    mov [wcWinClass.lpfnWndProc],window_proc
    
    ; Icone de la fenêtre
    push IDI_SHIELD
    push 0
    call LoadIcon
    mov [wcWinClass.hIcon],eax

    ; Curseur de la fenetre
    push IDC_ARROW
    push 0
    call LoadCursor
    mov [wcWinClass.hCursor],eax
    
    mov [wcWinClass.hbrBackground],COLOR_APPWORKSPACE
    mov [wcWinClass.lpszClassName],offset window_classname
    mov [wcWinClass.style], CS_HREDRAW or CS_VREDRAW  
    
    ; Enregistre la classe de la fenetre
    push offset wcWinClass
    call RegisterClass
    
    ; Creation de la fenêtre en utilisant la classe précedement enregistré
    push 0
    mov eax,[g_Instance]
    push eax
    push 0
    push 0
    push WINDOW_HEIGHT
    push WINDOW_WIDTH
    push CW_USEDEFAULT
    push CW_USEDEFAULT
    push WS_OVERLAPPED+WS_CAPTION+WS_SYSMENU+WS_MINIMIZEBOX+WS_MAXIMIZEBOX+WS_VISIBLE
    push offset window_title
    push offset window_classname
    push 0
    call CreateWindowEx
    mov [g_hWnd],eax
    
    
    ; Affiche la fenetre
    push SW_SHOW
    push eax
    call ShowWindow
   
    mov eax,[g_hWnd]
    push eax
    call UpdateWindow
    
    message_loop:
    push 0
    push 0
    push 0
    push offset message 
    call GetMessage
    test eax,eax
    jz exit_program
    push offset message
    call TranslateMessage
    push offset message
    call DispatchMessage
    jmp message_loop
    
    
exit_program:
    xor eax,eax
    push eax
    call ExitProcess
end WinMain