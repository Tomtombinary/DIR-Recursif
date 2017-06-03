@echo off
c:\masm32\bin\ml /c /Zd /coff DIRRecursifGUI.asm
c:\masm32\bin\rc /v rsrc.rc
c:\masm32\bin\cvtres /machine:ix86 rsrc.res
c:\masm32\bin\Link /SUBSYSTEM:WINDOWS DIRRecursifGUI.obj rsrc.obj
pause