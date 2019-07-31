# Corewar Checker

This is a set of scripts to check both programs of the [42]'s project Corewar.

* [*asm_checker.sh*](#asm_checker)
* [*vm_checker.sh*](#vm_checker)

## Asm checker

#### TL;DR
```
# Run a set of unit tests on your asm (assume it is in the parent directory)
$ ./asm_checker.sh ../asm

# Check for potential leaks (requires valgrind)
$ ./asm_checker.sh -l ../asm
```

#### Usage
```
Usage:   ./asm_checker.sh [-chl] <asm> [<player>...]

    -l             check for leaks
    -c             clean directory at first
    -h             print this message and exit
    <asm>          path to your asm executable file
    <champion>...  path to the champions to test, if empty use a set of predefined champs
````

## Vm checker

#### TL;DR
```
# Check your corewar against a set of .cor file (assume your executable is in the parent directory)
$ ./vm_checker.sh ../corewar champs/bytecode/*.cor

# Check for potential leaks
$ ./vm_checker.sh -l ../corewar champs/bytecode/*.cor

# Set the timeout to 20 seconds and check for leaks
$ ./vm_checker.sh -lt 20 ../corewar champs/bytecode/*.cor

# Convert .s files first with the 42 asm bin
$ ./vm_checker.sh -blt 20 ../corewar champs/unit_tests/**/*.s

# Same as the previous one but use your asm file
$ ./vm_checker.sh -blt 20 -B ../asm ../corewar champs/**/*.{s,cor}

# Run 25 fights (1vs1) with your champion against random champions
$ ./vm_checker.sh -f 25 -m 2 -p ../your_champion.s ../corewar champs/bytecode/*.cor
````

#### Usage
```
Usage:   ./vm_checker.sh [-abcdhl] [-t N] [-v N] [-f N] [-F N] [-m <1|2|3|4>]
                         [-p <player>] [-B <asm>] <corewar> <player>...

      -a                 enable aff operator
      -b                 convert all player file with an extension different to .cor into bytecode first
      -c                 clean directory at first
      -d                 enable diff mode
      compare exec output with corewar exec provided by 42 (zaz's corewar)
      -h                 print this message and exit
      -l                 check for leaks
      -t N               timeout value in seconds (default 10 seconds)
      -v N               verbose mode (mode should be between 0 and 31)
      -f N               enable fight mode, run N fights
      if enabled use the set of players to randomly populate
      the arena with 2, 3 or 4 players and let them fight,
      each player is unique in the arena
      -F N               same as -f except that a player can fight against himself
      -m <1|2|3|4>       set the number of contestants (works only in fight mode)
      -p <player>        define a fixed contestant that will appear in all fights (works only in fight mode)
      -B <asm>           path to the asm executable to use to convert into bytecode with -b option (default
      to asm provided by 42) assume that the .cor file is created with the same
      pathname than the input file
      <corewar>          path to your corewar executable
      <player>...        list of players (.cor file, or .s file with the -b option)
```


[42]: https://42.fr

