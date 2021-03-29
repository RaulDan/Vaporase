.586
.model flat, stdcall


;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf:proc
extern scanf:proc

includelib canvas.lib
extern BeginDrawing: proc


;declaram simbolul start ca public - de acolo incepe executia
public start

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Vaporase",0;Titlul ferestrei
area_width EQU 1200;Lungimea
area_height EQU 750;Latimea
area DD 0;Zona in care sunt stocati pixelii


info db "Dati dimensiunile initiale:",13,10,0;Mesaj informare utilizator
msg_linii db "Dati numarul de linii:",13,10,0;Mesaj prin care se cere numarul de linii
msg_coloane db "Dati numarul de coloane:",13,10,0;Mesaj prin care se cere numarul de coloane
afara db "Afara din matrice",13,10,0;MEsaj prin care afisez daca sunt in afara matricei
int_format db "%d",0;pentru a citi numarul de linii si de coloane
int_format2 db "	%d	%d ",0
ff db "%d  numar",13,10,0

initial dd 0
linii dd ?;numarul de linii dat de utilizator
coloane dd ? ;numarul de coloane dat de utilizator
val dd 0;variabila folosita pentru a trasa matricea
numar dd 0;variabila folosita pentru a genera aleator pozitiile in matrice

total dd 0;numarul total de elemente din matrice
elemente dd 0;cate elemente aleatoare voi avea in matrice, adica cate vaporase;stochez vaporasele din matrice

succes dd 0;numarul de vaporase lovite
lost dd 0;numarul de celule goale lovite
tries dd 0;numarul de incercari totale
ramase dd 0

elemente_generate dd 0;vectorul in care pun pozitiile in care s-au generat vaporase in matrice
lovite dd 0
counter DD 0 ; numara evenimentele de tip timer
count dd 0
indice dd 0;indice folosit pentru a parcurge vectorul de indici generati aleator



l1 dd 0
l2 dd 0
mx dd 0;folosit la desenare
my dd 0;folosit la desenare


arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20
but_x equ 500
but_y equ 150
dim equ 80
tabx equ 160
taby equ 60
latura_sus equ 420
latura_jos equ 420




symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

linie_orizontala macro x ,y ,lung ,color;macro pentru a trasa o linie dreapta orizontala

	local trasare
	mov eax,y;eax=y

	mov ebx,area_width;pt ca nu se poate inmulti cu o constanta
	mul ebx
	add eax,x;eax=y*area_width+x
	
	shl eax,2;eax=eax*4-pozitia in vectorul de pixeli
	add eax,area;adresa de inceput de unde vrem sa ducem linia
	mov ecx,lung
	
	trasare:
	mov dword ptr [eax],color
	;add eax,4*area_width;pentru linie verticala
	add eax,4;pentru linie orizontala
	loop trasare
	
endm

linie_verticala macro x ,y ,lung ,color;macro pentru a trasa o linie dreapta orizontala
	local trasare
	mov eax,y;eax=y

	mov ebx,area_width;pt ca nu se poate inmulti cu o constanta
	mul ebx
	add eax,x;eax=y*area_width+x
	
	shl eax,2;eax=eax*4-pozitia in vectorul de pixeli
	add eax,area;adresa de inceput de unde vrem sa ducem linia
	mov ecx,lung
	
	trasare:
	mov dword ptr [eax],color
	add eax,4*area_width;pentru linie verticala
	;add eax,4;pentru linie orizontala
	loop trasare
	
endm




; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	
	;Partea de inceput
	push offset info;afisez mesaj de informare la inceput
	call printf
	add esp,4
	
	push offset msg_linii;cer utilizatorului sa dea numarul de linii
	call printf
	add esp,4
	
	push offset linii;citesc numarul de linii
	push offset int_format
	call scanf
	add esp,8
	
	push offset msg_coloane;cer utilizatorului sa dea numarul de coloane
	call printf
	add esp,4
	
	push offset coloane;citesc numarul de coloane
	push offset int_format
	call scanf
	add esp,8
	
	;Calculez lungimea unui patratel
	mov eax,latura_sus	
	mov edx,0
	div linii
	mov l1,eax;pun pentru a colora un buton
	
	mov val,taby
	mov edx,linii
	
	;trasez liniile orizontale ale matricei
	generare_1:
	cmp edx,0
	jl gata
	push edx
	push eax
	linie_orizontala tabx,val,latura_sus,0ffd800h
	pop eax
	add val,eax
	pop edx
	sub edx,1
	jmp generare_1
	
	;trasez liniile verticale ale matricei
	gata:
	mov eax,latura_jos
	mov edx,0
	div coloane
	mov l2,eax;pun numarul de coloane pentru a colora un patrat
	;trasare coloane
	mov val,tabx
	mov edx,coloane
	generare_2:
	cmp edx,0
	jl gata_1
	push edx
	push eax
	linie_verticala val,taby,latura_jos,0ffd800h
	pop eax
	add val,eax
	pop edx
	sub edx,1
	jmp generare_2
	;sfarsitul trasarii matricei
	
	gata_1:
	
	mov eax,linii;vad cate elemente am in matrice
	mul coloane
	mov total,eax;numarul de n*m casute din matrice, adica totatul elementelor din matrice
	
	mov edx,0;impart in 2 numarul de pozitii random
	mov ebx,2
	div ebx
	mov elemente,eax;stochez cate vaporase voi genera
	
	mov eax,total;pun totalul elementelor din matrice
	shl eax,2
	push eax
	call malloc;aloc spatiu  pentru indicii generati aleator
	add esp,4
	mov elemente_generate,eax;mut spatiul alocat pentru vaporasele generate aleator
	
	mov eax,total
	push eax
	call malloc
	add esp,4
	mov lovite,eax
	mov ebx,eax
	mov eax,elemente_generate
	
	cmp initial,0
	jne afisare_litere
	
	;pun tot vectorul de pozitii aleatoare pe 0
	mov ecx,total
	zero:
	mov dword ptr[eax],0
	mov dword ptr[ebx],0
	add eax,4
	add ebx,4
	loop zero
	;aici incepe generarea aleatoare a vaporaselor
	
	mov ecx,elemente
	
	generare_vaporase_random:
	push ecx
	rdtsc;generez aleator un numar
	mov edx,0
	div linii
	mov esi,edx;indice aleator pentru numarul de linii
;rdtsc	
	mov edx,0
	div coloane
	mov edi,edx;indice aleator pentru coloana
	
	mov eax,esi 
	mul coloane
	add eax,edi
	shl eax,2;obtin noua pozitie din vectorul de elemente in care trebuie sa generez vaporasele
	
	add eax,elemente_generate;ma deplasez in vector la pozitia curenta
	
	verificare:
	pop ecx
	cmp dword ptr[eax],1
	je salt
	
	mov dword ptr[eax],1
	
	jmp finall

	
	salt:
	add ecx,1
	
	finall:
	loop generare_vaporase_random
	
	mov initial,1
	
	;Afisez vectorul de indici care s-au generat aleator, unde vor fi stocate vaporase
	mov ecx,total
	mov eax,elemente_generate
	mov ebx,0
	afisare:
	push ecx
	pusha
	push dword ptr[eax+ebx]
	push offset ff
	call printf
	add esp,8
	popa
	add ebx,4
	pop ecx
	loop afisare
	
	mov ecx,total
	mov eax,lovite
	mov ebx,0
	afisare2:
	push ecx
	pusha
	push dword ptr[eax+ebx]
	push offset ff
	call printf
	add esp,8
	popa
	add ebx,4
	pop ecx
	loop afisare2
	
	jmp afisare_litere
	
evt_click:

	;Verific daca am dat click in afara matricei
	mov esi,[ebp+arg2]
	cmp esi,tabx
	jl ext_matrice
	cmp esi,tabx+latura_sus
	jg ext_matrice
	mov edi,[ebp+arg3]
	cmp edi,taby
	jl ext_matrice
	cmp edi,taby+latura_jos
	jg ext_matrice
	
	;calculez linia pe care se afla patratul in care s-a dat click
	mov eax,esi
	sub eax,tabx
	mov edx,0
	div l2
	cmp edx,0
	je ext_matrice;Daca dau click pe o linie din matrice, nu se va colora nimic
	mov esi,eax;inidice pentru linie
	
	;calculez coloana din matrice corespunzatoare patratului in care s-a dat click
	mov eax,[ebp+arg3]
	sub eax,taby
	mov edx,0
	div l1
	cmp edx,0
	je ext_matrice;Daca dau click pe o linie, atunci nu se va colora nimic
	mov edi,eax;indice pentru coloana
	
	
	;Calculez inidicele din vectorul de pozitii sa vad daca in acel loc este sau nu un vaporas
	cmp elemente,0
	je skip1
	mov eax,edi
	mul coloane
	add eax,esi
	shl eax,2
	mov ecx,eax;Stochez indicele
	add eax,lovite
	cmp dword ptr[eax],0;Vad daca in patratul in care am dat click, am mai dat click inainte. 0=>Primul click, 1=>S-a mai dat click
	jne skip1
	inc tries;Cresc numarul de incercari ale utilizatorului
	mov dword ptr[eax],1;Marchez patratul curent ca patrat in care am dat click
	
	mov eax,ecx;Ma intorc in tabloul de indici generati aleator
	add eax,elemente_generate;In vectorul elementelor generate merg la indicele curent
	mov ebx,dword ptr[eax];Vad daca s-a selectat un vaporas sau un loc gol
	
	
	mov eax,l2;lungimea unui dreptunghi din matrice
	mul esi
	add eax,tabx;vad de unde sa incep desenarea patratului pe care s-a dat click
	mov ecx,l1
	sub ecx,1
	mov mx,eax
	add mx,1
	mov eax,l1
	mul edi
	add eax,taby
	mov my,eax
	inc my
	
	cmp ebx,1;Vad daca am dat click pe un vaporas sau pe un loc gol ;1=Vaporas, 0=Loc Gol
	
	jne gol;Daca am 0, atunci acolo am un loc gol
	sub elemente,1
	trasare_plin:
	push ecx
	linie_orizontala mx,my,l2,0ff0000h
	inc my
	pop ecx
	loop trasare_plin
	
	jmp afisare_litere
	gol:
	inc lost
	
	trasare_gol:
	push ecx
	linie_orizontala mx,my,l2,00000feh
	inc my
	pop ecx
	loop trasare_gol
	
	
	
	jmp afisare_litere
	ext_matrice:
	pusha
	push offset afara
	call printf
	add esp,4
	popa
	jmp afisare_litere
	
evt_timer:
	inc counter

	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
	;afisez un mesaj sugestiv pentru a arata cate vaporase au mai ramas
	make_text_macro 'R',area,950,60
	make_text_macro 'A',area,960,60
	make_text_macro 'M',area,970,60
	make_text_macro 'A',area,980,60
	make_text_macro 'S',area,990,60
	make_text_macro 'E',area,1000,60
	
	
	
	mov ecx,980;Coordonata x la care afisez cifra unitatilor a vaporaselor ramase
	mov eax,elemente;Pun in eax cate vaporase au mai ramas, pentru a afisa numarul lor
	afisare_vaporase_ramase:;Afisez numarul de vaporase ramase
	
	
	mov ebx,10
	mov edx,0
	div ebx
	add edx,'0'
	make_text_macro edx,area,ecx,80
	sub ecx,ebx;Coordonata x pentru a pune urmatoarea cifra din numarul vaporaselor ramase
	cmp eax,0;Daca am afisat fiecare cifra din cadrul numarului, atunci ma opresc
	jne afisare_vaporase_ramase
	
	;Mesaj sugestiv prin care afisez numarul de incercari ale utilizatorului
	make_text_macro 'T',area,950,100
	make_text_macro 'O',area,960,100
	make_text_macro 'T',area,970,100
	make_text_macro 'A',area,980,100
	make_text_macro 'L',area,990,100
	
	
	mov ecx,980
	mov eax,tries
	afisare_incercari:
	mov ebx,10
	mov edx,0
	div ebx
	add edx,'0'
	make_text_macro edx,area,ecx,120
	sub ecx,ebx
	cmp eax,0
	jne afisare_incercari
	
	make_text_macro 'R',area,950,140
	make_text_macro 'A',area,960,140
	make_text_macro 'T',area,970,140
	make_text_macro 'T',area,980,140
	make_text_macro 'A',area,990,140
	make_text_macro 'R',area,1000,140
	make_text_macro 'I',area,1010,140
	
	mov ecx,980
	mov eax,lost
	afisare_ratari:
	mov ebx,10
	mov edx,0
	div ebx
	add edx,'0'
	make_text_macro edx,area,ecx,160
	sub ecx,edx
	cmp eax,0
	jne afisare_ratari
	
	
	cmp elemente,0;Daca mai am vaporase de identificat, atunci numai afisez nimic
	jne skip1
	
	make_text_macro 'J',area,920,180
	make_text_macro 'O',area,930,180
	make_text_macro 'C',area,940,180
	make_text_macro 'T',area,960,180
	make_text_macro 'E',area,970,180
	make_text_macro 'R',area,980,180
	make_text_macro 'M',area,990,180
	make_text_macro 'I',area,1000,180
	make_text_macro 'N',area,1010,180
	make_text_macro 'A',area,1020,180
	make_text_macro 'T',area,1030,180
	jmp skip1
	
	
	
	skip1:
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start