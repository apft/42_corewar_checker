# Corewar Checker

This is a set of scripts to check both programs of the [42]'s project Corewar.

* [*asm_checker.sh*](#asm-checker)
* [*vm_checker.sh*](#vm-checker)


#### TL;DR
```
# Run a set of unit tests on your asm (assume it is in the parent directory)
$ ./asm_checker.sh ../asm

# Check for potential leaks (requires valgrind)
$ ./asm_checker.sh -l ../asm

# Run only the tests for the live op
$ ./asm_checker.sh -l ../asm champs/unit_tests/test_op/01_live*.s

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

## Asm checker

Assuming your `asm` file is in the parent directory, you can run the set of unit tests with the following command
```
./asm_checker.sh ../asm
```

If you want to check for potential leaks (requires valgrind)
```
./asm_checker.sh -l ../asm
```
Finally if you like to run only some tests, you can define the path to each test. For instance to run only the unit test of the `live` operation do as follow
```
./asm_checker.sh -l ../asm champs/unit_tests/test_op/01_live*.s
```

#### Ouptut
We tried to make the output of the script as easy as possible.
* `success` : both program created a _.cor_ file and their content is similar
* `good` : both program encounter an error, each error is displayed on the shell
* `segfault` : one of the program encounter a segfault
* `leaks`* : the _asm_ file provided has some leaks (with the `-l` option only)
* `error` :
 * both program created a _.cor_ file, their content differ
 * one of the program did not create the file (encounter a parsing error maybe)


 \* a `.leak` folder stores the valgrind output of the faulty check

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

Assuming your `corewar` file is in the parent directory, you can use the script to run it against a set of _.cor_ file (provided in the repo)
```
./vm_checker.sh ../corewar champs/bytecode/*.cor
```

You can check for potential leaks (requires valgrind). This is compatible with all the other options.
```
./vm_checker.sh -l ../corewar champs/bytecode/*.cor
```
In case of leaks, the valgrind ouptut is stored in the `.leaks` folder in your current directory.

If you get some `timeout`, you can change the value with the `-t` option (set to 20 seconds in the following example)
```
./vm_checker.sh -lt 20 ../corewar champs/bytecode/*.cor
```

You can also use a mixed set of `.s` and `.cor` file as arguments, for this run with the `-b` option to use the _asm_ provided by 42. To use your _asm_ file, use `-B <path_to_your_asm>` (the second example will also check for _leaks_, may take some time due to the length of the provided set)
```
./vm_checker.sh -b ../corewar champs/unit_tests/**/*.s
./vm_checker.sh -bl -B ../asm ../corewar champs/**/*.{s,cor}
```

#### Fight mode
There is a **fight mode** available. You need to specify the number of game to run and the script will randomly generate a set of 2, 3 or 4 champions for each game. Or you can fix the number of contestants with the `-m` option.  
The following command will run 25 time your _corewar_ with a set of 3 champions randomly chosen in the provided set.
```
./vm_checker.sh -f 25 -m 3 ../corewar champs/bytecode/*.cor
```

With the `-p` option, you can ask for a champion to fight in each game
```
./vm_checker.sh -f 10 -m 2 -p ../your_champion ../corewar champs/bytecode/*.cor
```

#### Diff mode
In order to ease our development and debug, we chose to follow Zaz's verbose mode and output. There is a `-d` option to run _diff_ against Zaz's output. You can set the verbose mode with the `-v` option
```
./vm_checker.sh -dv 31 ../corewar champs/bytecode/zork.cor
```
If the outputs differ, a diff file is stored under the `.diff` folder.

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

## Unit tests
The repo has a set of unit tests under the `champs/unit_tests/` folder. Some of the tests are hard coded, others (for the op) can be generated by a script.  
Composition of the `champs/unit_tests` folder :
* `valid/` : set of hard coded tests that we assume should be valid
* `invalid/` : set of hard coded tests that we assume should fail
* `list.txt` : formatted file used by the `op_asm_gen.sh` script to create some _.s_ file
* `op_asm_gen.sh` : script that parse the `list.txt` file and create _.s_ file in the provided folder
* `test_op/` : folder with the tests created from the `list.txt` and `op_asm_gen.sh` files

Here is how is formatted the `list.txt` file :
```
(1) op_number; (2) op_name; (3) test name; (4) op args [; (5)]
```
1. number of the op
2. name of the op
3. some more specific text about the test
4. the args of the op
5. (optional) a set of operation to perform before the op to test, this set should be separated by ';'  
(see _zjmp_ unit tests for an exemple)

For instance,
```
01;live;dir value is null;%0
```
will produce the following file `01_live-dir_value_is_null.s` with the following code :
```
.name "live"
.comment "live: dir value is null"

live %0
```


[42]: https://42.fr

