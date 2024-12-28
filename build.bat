@REM ----- Assembling using NASM -----
nasm ^
    guessme.asm ^
    -f win64 ^
    -o guessme.obj ^
    -gcv8

@REM ----- Linking using the Microsoft linker -----
link guessme.obj ^
    /entry:main ^
    /subsystem:console ^
    /defaultlib:kernel32.lib ^
    /out:guessme.exe ^
    /incremental:no ^
    /debug:full ^
    /pdb:guessme.pdb
    
@REM ----- Linking using the GCC linker -----
@REM ld ^
@REM     guessme.obj ^
@REM     --entry=main ^
@REM     --subsystem=console ^
@REM     -LD:\Farzan\Applications\winlibs\mingw64\x86_64-w64-mingw32\lib ^
@REM     -lkernel32 ^
@REM     -o guessme.exe ^
@REM     -g

@REM ----- Linking using rhe Clang linker -----
@REM uses MS linker under the hood so the developers' command line is needed.
@REM lld-link ^
@REM     guessme.obj ^
@REM     /entry:main ^
@REM     /subsystem:console ^
@REM     /defaultlib:kernel32 ^
@REM     /out:guessme.exe ^
@REM     /incremental:no ^
@REM     /debug ^
@REM     /pdb:guessme.pdb

@REM ----- Cleaning up -----
DEL guessme.obj