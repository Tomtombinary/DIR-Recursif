@echo off
c:\masm32\bin\ml /c /Zd /coff DIRRecursif.asm
c:\\masm32\bin\Link /SUBSYSTEM:CONSOLE DIRRecursif.obj
pause