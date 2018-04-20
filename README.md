# Command Line Parser (Bash)

## Introduction

The Command Line Parser is an easy to use command line parser for Bash shell
scripts. The interface is such that you:
1. Use the *cli_options()* function to:
    - Define the command line options.
    - Define arguments for the option, if any.
    - Give a description of what the command does.
2. Parse the input options with the *cli_parse()* function.
3. Call the *cli_get()* function to retrieve your options for a given option.

With the given information, *cli_usage()* is used to automatically generate a
help message.

## Example

A standard way of initializing your command line options would be something like:
```
cli_options "-h|--help            |Print program usage." \
            "-o|--option=required:|Option with a required argument." \
            "  |--another-option  |Just a long option, no short option and no argument." \
            "-s|--stuff=optional::|Optional argument for this option." \
            "-t|--things=list:::  |Do things with this list argument." \
            "-v|--verbose         |Verbose output."
cli_parse "${@}"
...
option=$(cli_get "option")
another=$(cli_get "another-option")
stuff=$(cli_get "stuff")
things=$(cli_get "things")
...
```

In order, this will do the following:
1. Define the possible command line options for your program.
2. Add them to the command line options global variable so that it knows the
   possible options.
3. Parse the user input through the *${@}* variable.
4. Calling *cli_get* will either return the argument and exit with a status of
   0, or return nothing and the exit status will be non-zero.

For more information on the types of arguments and the meaning behind the ":",
click [here](#types-of-arguments).

## Install

If this file resides under your *PATH* environment variable, then in a shell
script, you can source it simply with either:

```
. "commandline.sh"
```

or

```
source "commandline.sh"
```

If it does not reside under the *PATH*, you will need to give the full or
relative path to *commandline.sh*.

## Uninstall

Remove the file from where you copied it and delete the line above, which
sources it.

## Types of Arguments

When declaring command line options, there are various different types of
arguments that can be used. They are denoted by the use of ':' characters after
the argument name in the long option section.
- **argument** = This option does not take an argument.
- **argument:** = This option takes a single, required argument.
- **argument::** = This option may or may not take an argument.
- **argument:::** = This argument takes one or more arguments. Arguments stop
    being read once a new option is encountered.
