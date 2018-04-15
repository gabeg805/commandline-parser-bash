# Command Line Parser

## Introduction

The Command Line Parser is an easy to use command line parser for Bash shell
scripts.  The interface is such that you define the command line options, any
arguments, and a description of what the command does. Then you parse the input
options in the *${@}* variable. Finally, you call a *get()* function to retrieve
your options. Because of the information provided by the user, it is trivial to
display a usage message; all the pertinent information is already provided. If
an input error occurs, *usage()* will be called. For examples of how to use it,
click [here](#example).

When declaring command line options, there are various different types of
arguments that can be used. They are denoted by the use of ':' characters after
the argument name in the long option section.
- **argument** = This option does not take an argument.
- **argument:** = This option takes a single, required argument.
- **argument::** = This option may or may not take an argument.
- **argument:::** = This argument takes one or more arguments. Arguments stop
    being read once a new option is encountered.

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

## Install

Copy the shell script to your location of choice of source the file in your
script using:

```
. "/path/to/file/commandline.sh"
```

## Uninstall

Remove the file from where you copied it and delete the line above, which sources it.
