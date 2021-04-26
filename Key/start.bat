@echo off

set target=r0kedrv
\masm32\bin\ml /nologo /c /coff %target%.asm
\masm32\bin\link /nologo /driver /base:0x10000 /align:32 /out:%target%.sys /subsystem:native /ignore:4078 %target%.obj
del %target%.obj

set target=r0ke
\masm32\bin\ml /nologo /c /coff %target%.asm
\masm32\bin\link /nologo /subsystem:windows /ignore:4078 %target%.obj
del %target%.obj

echo.
pause