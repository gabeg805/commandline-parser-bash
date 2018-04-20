#!/bin/bash
# ------------------------------------------------------------------------------
# 
# File: commandline.sh
# Author: Gabriel Gonzalez
# Brief: Parse command line options in an easily definable manner.
# 
# Globals:
# 
#     * PROJECT - The name of the parent shell script.
# 
# Public functions:
# 
#     * cli_options
#     * cli_parse
#     * cli_test
#     * cli_get
#     * cli_usage
# 
# Private functions:
# 
#     * cli_option_add
#     * cli_input_add
#     * cli_parse_argument
#     * cli_parse_argument_none
#     * cli_parse_argument_required
#     * cli_parse_argument_optional
#     * cli_parse_argument_list
#     * cli_parse_argument_shift
#     * cli_usage_line
#     * cli_option_find
#     * cli_option_find_full
#     * cli_option_list
#     * cli_input_list
#     * cli_option_get_key
#     * cli_input_get
#     * cli_input_get_guess
#     * cli_option_get_field
#     * cli_option_get_option_field
#     * cli_option_get_argument_field
#     * cli_option_get_length
#     * cli_input_get_length
#     * cli_option_has_argument
#     * cli_option_is_long
#     * cli_argument_type_is_none
#     * cli_argument_type_is_required
#     * cli_argument_type_is_optional
#     * cli_argument_type_is_list
# 
# Exit codes:
# 
#     * EXIT_INVALID_ARGUMENT_TYPE = 1
#     * EXIT_INVALID_OPTION        = 2
#     * EXIT_INVALID_ARGUMENT      = 3
#     * EXIT_OPTION_NOT_FOUND      = 4
#     * EXIT_INDEX_NOT_FOUND       = 5
#     * EXIT_OPTION_LENGTH_ZERO    = 6
#     * EXIT_INPUT_LENGTH_ZERO     = 7
#     * EXIT_INVALID_FIELD         = 8
#     * EXIT_INVALID_GET_OPTION    = 9
#     * EXIT_INVALID_GET_KEY       = 10
#     * EXIT_GET_OPTION_NOT_FOUND  = 11
# 
# ------------------------------------------------------------------------------

##
# The name of the project.
# 
# Determined by taking the basename of the parent shell script.
##
PROJECT="${0##*/}"

##
# Command line interface option information.
##
declare -A CLI_OPTION
declare -A CLI_OPTION_MAP

##
# Command line interface options and arguments that a user has input into the
# current running program.
##
declare -A CLI_INPUT

##
# Command line interface argument types.
##
CLI_ARGUMENT_TYPE_INVALID=-1
CLI_ARGUMENT_TYPE_NONE=0
CLI_ARGUMENT_TYPE_REQUIRED=1
CLI_ARGUMENT_TYPE_OPTIONAL=2
CLI_ARGUMENT_TYPE_LIST=3

##
# List of exit statuses.
##
EXIT_INVALID_ARGUMENT_TYPE=1
EXIT_INVALID_OPTION=2
EXIT_INVALID_ARGUMENT=3
EXIT_OPTION_NOT_FOUND=4
EXIT_INDEX_NOT_FOUND=5
EXIT_OPTION_LENGTH_ZERO=6
EXIT_INPUT_LENGTH_ZERO=7
EXIT_INVALID_FIELD=8
EXIT_INVALID_GET_OPTION=9
EXIT_INVALID_GET_KEY=10
EXIT_GET_OPTION_NOT_FOUND=11

##
# Define all the command line options and how they should be used.
# 
# When adding a long option, there will be a check for what the argument name
# and type are, if there is one.
##
cli_options()
{
    for line in "${@}"
    do
        local IFS=$'|'
        local options=(${line})
        local short="${options[0]}"
        local long="${options[1]}"
        local description="${options[2]}"
        local argument=
        local key="${long}"
        local other="${short}"

        if [ -z "${long}" ]
        then
            key="${short}"
            other="${long}"
        else
            if cli_option_has_argument "${long}"
            then
                argument="$(cli_option_get_argument_field "${long}")"
                long="$(cli_option_get_option_field "${long}")"
                key="${long}"
            fi
        fi

        cli_option_add "${key}" "${other}" "${argument}" "${description}"
    done
    return 0
}

##
# Parse all the input command line options and arguments.
# 
# Options with no arguments will have an argument value of 'true', to indicate
# the option has been set. Options with a LIST argument type will have their
# values separated by a '|'.
##
cli_parse()
{
    local opt=
    local info=
    local key=
    local type=
    local arg=
    local skip=
    local status=0

    while [ -n "${1}" ]
    do
        # Option information
        opt="${1}"
        info=($(cli_option_find "${opt}"))
        if [ $? -ne 0 ]
        then
            echo "${PROJECT}: Invalid option '${opt}'." 1>&2
            exit ${EXIT_INVALID_OPTION}
        fi

        # Parse the argument
        key="${info[0]}"
        type="${info[3]}"
        arg=$(cli_parse_argument "${key}" "${type}" "${@}")
        status=$?
        if [ ${status} -ne 0 ]
        then
            exit ${status}
        fi

        # Add the argument(s) to the list of inputs
        cli_input_add "${key}" "${arg}"

        skip=$(cli_parse_argument_shift "${opt}" "${arg}")
        shift ${skip}
        continue
    done

    return 0
}

##
# Test out which options have been entered on the command line.
##
cli_test()
{
    local opt=
    local arg=
    local length=0
    for opt in $(cli_input_list)
    do
        if [ ${#opt} -gt ${length} ]
        then
            length=${#opt}
        fi
    done
    for opt in $(cli_input_list)
    do
        arg="$(cli_input_get "${opt}")"
        printf "Key: %${length}s | Value: %s\n" "${opt}" "${arg}"
    done
}

##
# Return the value for the given option.
# 
# The input option must be a long option; however, if there is no long option,
# then the short option should be used.
##
cli_get()
{
    local opt="${1}"
    if [ "${opt:0:1}" == "-" ]
    then
        echo "${PROJECT}: Invalid option to retrieve. Do not use dashes when specifying the option." 1>&2
        return ${EXIT_INVALID_GET_OPTION}
    fi
    cli_input_get_guess "${opt}"
    return $?
}

##
# Print the usage message for the program.
##
cli_usage()
{
    echo "Usage: ${PROJECT} [options]"
    echo
    echo "Options:"
    local opt=
    for opt in $(cli_option_list | sort)
    do
        local IFS=$'|'
        local full=($(cli_option_find_full "${opt}"))
        local key="${full[0]}"
        local other="${full[1]}"
        local argname="${full[2]}"
        local desc="${full[4]}"
        local line=$(cli_usage_line "${key}" "${other}" "${argname}")
        echo "    ${line}"
        echo "        ${desc}" | fmt -c -w 80
        echo
    done
}

##
# Add an option to the list of valid options.
# 
# This will add the key option, the other option, the argument and its type, and
# the description.
# 
# Key         - Typically the long option, but if there is no long option, this
#               will be the short option.
# Other       - Typically the short option, but will be empty if the short
#               option is the Key.
# Argument    - This will be the argument name and its type, denoted by the
#               number of ':' after it.
# Description - Usage description for this option.
##
cli_option_add()
{
    local key="${1// /}"
    local other="${2// /}"
    local argname="${3// /}"
    local desc="${4}"
    local type=
    local count=$(echo "${argname}" | tr -c -d ':' | wc -c)
    case ${count} in
        0) type=${CLI_ARGUMENT_TYPE_NONE} ;;
        1) type=${CLI_ARGUMENT_TYPE_REQUIRED} ;;
        2) type=${CLI_ARGUMENT_TYPE_OPTIONAL} ;;
        3) type=${CLI_ARGUMENT_TYPE_LIST} ;;
        *) echo "${PROJECT}: Error adding argument '${argname}'." 1>&2
           exit ${EXIT_INVALID_ARGUMENT_TYPE}
           ;;
    esac
    argname="${argname//:/}"
    if [ -z "${other}" ]
    then
        other="none"
    fi
    if [ -z "${argname}" ]
    then
        argname="none"
    fi
    cli_option_add_key "${key}" "${other}" "${argname}" "${type}" "${desc}"
    cli_option_add_conv "${other}" "${key}"
}

##
# Add the key option and its arguments to the list of valid options.
##
cli_option_add_key()
{
    local key="${1}"
    local other="${2}"
    local type="${3}"
    local desc="${4}"
    local argname="${5}"
    if [ -z "${key}" ]
    then
        return ${EXIT_INVALID_OPTION}
    fi
    CLI_OPTION["${key}"]="${other}|${type}|${desc}|${argname}"
    return 0
}

##
# Add the conversion option to the list of valid conversion options.
# 
# This is used to convert from the Other option (see cli_option_add()) to the
# Key option.
##
cli_option_add_conv()
{
    local other="${1}"
    local key="${2}"
    if [ -z "${other}" -o "${other}" == "none" ]
    then
        return ${EXIT_INVALID_OPTION}
    fi
    CLI_OPTION_MAP["${other}"]="${key}"
    return 0
}

##
# Add the input option and corresponding argument to the list of inputs the
# user has entered on the command line.
##
cli_input_add()
{
    local opt="${1}"
    local arg="${2}"
    if [ -z "${opt}" ]
    then
        return ${EXIT_INVALID_OPTION}
    fi
    CLI_INPUT["${opt}"]="${arg}"
    return 0
}

##
# Parse different argument types and return their argument.
##
cli_parse_argument()
{
    local key="${1}"
    local type="${2}"
    local opt="${3}"
    local arg=true
    local status=0
    shift 3

    if cli_argument_type_is_none "${type}"
    then
        arg="$(cli_parse_argument_none "${key}")"
    elif cli_argument_type_is_required "${type}"
    then
        arg="$(cli_parse_argument_required "${opt}" "${1}")"
    elif cli_argument_type_is_optional "${type}"
    then
        arg="$(cli_parse_argument_optional "${opt}" "${1}")"
    elif cli_argument_type_is_list "${type}"
    then
        arg="$(cli_parse_argument_list "${opt}" "${@}")"
    else
        echo "${PROJECT}: Unknown argument type for option '${opt}', type '${type}'." 1>&2
        return ${EXIT_INVALID_ARGUMENT_TYPE}
    fi

    status=$?
    if [ ${status} -ne 0 ]
    then
        return ${status}
    fi

    echo "${arg}"
    return 0
}

##
# Parse an argument with the type NONE.
##
cli_parse_argument_none()
{
    echo "true"
    return 0
}

##
# Parse an argument with the type REQUIRED.
# 
# An argument is required. If there is no argument specified, return an error.
##
cli_parse_argument_required()
{
    local opt="${1}"
    local next="${2}"
    local arg="${next}"
    local nextinfo=
    if cli_option_is_long "${opt}"
    then
        arg="$(cli_option_get_argument_field "${opt}")"
    else
        nextinfo=($(cli_option_find "${next}"))
        if [ $? -eq 0 -o -z "${next}" ]
        then
            echo "${PROJECT}: An argument must be given for option '${opt}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Parse an argument with the type OPTIONAL.
# 
# An argument is optional. If there is no argument specified, the argument is
# set to "true" to indicate it has been set.
##
cli_parse_argument_optional()
{
    local opt="${1}"
    local next="${2}"
    local arg="${next}"
    local nextinfo=
    if cli_option_is_long "${opt}"
    then
        arg="$(cli_option_get_argument_field "${opt}")"
    else
        nextinfo=($(cli_option_find "${next}"))
        if [ $? -eq 0 -o -z "${next}" ]
        then
            arg="true"
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Parse an argument with the type LIST.
# 
# One or more arguments are required. If there is no argument set, return an
# error.
##
cli_parse_argument_list()
{
    local opt="${1}"
    shift
    local arg=
    local nextinfo=
    local next="${1}"

    if cli_option_is_long "${opt}"
    then
        # Make sure an argument was specified
        arg="$(cli_option_get_argument_field "${opt}")"
        if [ "${arg}" == "true" ]
        then
            echo "${PROJECT}: An argument must be given for option '${opt}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi
    else
        # Make sure next item is not an option
        nextinfo=($(cli_option_find "${next}"))
        if [ $? -eq 0 -o -z "${next}" ]
        then
            echo "${PROJECT}: An argument must be given for option '${opt}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi

        # Append options
        for a in "${@}"
        do
            if [ -z "${arg}" ]
            then
                arg="${a}"
            else
                arg="${arg}|${a}"
            fi
        done
    fi
    echo "${arg}"
    return 0
}

##
# Determine the number of times the argument list (${1}, ${2}, etc.) must be
# shifted.
##
cli_parse_argument_shift()
{
    local opt="${1}"
    local arg="${2}"
    local skip=
    if [ "${arg}" == "true" ] || cli_option_is_long "${opt}"
    then
        skip=1
    else
        skip=$[ $(echo "${arg}" | tr '|' '\n' | wc -l) + 1 ]
    fi
    echo "${skip}"
}

##
# Create a line in the usage message for the given option.
##
cli_usage_line()
{
    local key="${1}"
    local other="${2}"
    local argname="${3}"
    local line=
    if [ -n "${other}" -a "${other}" != "none" ]
    then
        line="${other}"
    fi
    if [ -n "${key}" ]
    then
        if [ -n "${line}" ]
        then
            line+=", ${key}"
        else
            line="${key}"
        fi
    fi
    if [ -n "${argname}" -a "${argname}" != "none" ]
    then
        if [ -n "${key}" ]
        then
            line+="=<${argname}>"
        else
            line+=" <${argname}>"
        fi
    fi
    echo "${line}"
}

##
# Find the option information for the given option.
# 
# The input must be a short or long option key.
##
cli_option_find()
{
    local opt="${1}"
    local status=0
    local key=

    key="$(cli_option_get_key "${opt}")"
    status=$?
    if [ ${status} -ne 0 ]
    then
        return ${status}
    fi

    local IFS=$'|'
    local info=($(cli_option_get "${key}"))
    echo "${key} ${info[@]:0:3}"
    return 0
}

##
# Find the full option information (contains the description) for the given
# option.
# 
# The input must be a short or long option.  This is to be used when printing
# program usage because normally, the description is not needed.
##
cli_option_find_full()
{
    local opt="${1}"
    local status=0
    local key=

    key="$(cli_option_get_key "${opt}")"
    status=$?
    if [ ${status} -ne 0 ]
    then
        return ${status}
    fi
    echo "${key}|$(cli_option_get "${key}")"
    return 0
}

##
# Return a list of all options.
# 
# What is returned are the option keys. If there is a long option, this is the
# key, but if there is no long option, then the short option is the key.
##
cli_option_list()
{
    local n=$(cli_option_get_length)
    local o=
    if [ ${n} -eq 0 ]
    then
        return ${EXIT_OPTION_LENGTH_ZERO}
    else
        for o in "${!CLI_OPTION[@]}"
        do
            echo "${o}"
        done
    fi
    return 0
}

##
# Return a list of all the input options.
##
cli_input_list()
{
    local n=$(cli_input_get_length)
    local i=
    if [ ${n} -eq 0 ]
    then
        return ${EXIT_INPUT_LENGTH_ZERO}
    else
        for i in "${!CLI_INPUT[@]}"
        do
            echo "${i}"
        done
    fi
    return 0
}

##
# Return the option argument for the given option.
##
cli_option_get()
{
    local opt="${1}"
    if [ -z "${opt}" ]
    then
        return ${EXIT_INVALID_OPTION}
    fi
    local arg="${CLI_OPTION[${opt}]}"
    if [ -z "${arg}" ]
    then
        return ${EXIT_GET_OPTION_NOT_FOUND}
    fi
    echo "${arg}"
    return 0
}

##
# Return the option argument given the conversion option.
##
cli_option_get_conv()
{
    local opt="${1}"
    if [ -z "${opt}" ]
    then
        return ${EXIT_INVALID_OPTION}
    fi
    local arg="${CLI_OPTION_MAP[${opt}]}"
    if [ -z "${arg}" ]
    then
        return ${EXIT_GET_OPTION_NOT_FOUND}
    fi
    echo "${arg}"
    return 0
}

##
# Return the option key that has an element in the associative array.
##
cli_option_get_key()
{
    local opt="${1}"
    local key=
    local arg=
    if [ -z "${opt}" ]
    then
        return ${EXIT_INVALID_GET_KEY}
    fi
    key="$(cli_option_get_option_field "${opt}")"
    arg="$(cli_option_get "${key}")"
    if [ $? -ne 0 ]
    then
        key="$(cli_option_get_conv "${key}")"
        if [ $? -eq 0 ]
        then
            arg="$(cli_option_get "${key}")"
        fi
    fi
    if [ -z "${arg}" ]
    then
        return ${EXIT_OPTION_NOT_FOUND}
    fi
    echo "${key}"
    return 0
}

##
# Return the input argument for the given option.
##
cli_input_get()
{
    local opt="${1}"
    if [ -z "${opt}" ]
    then
        return ${EXIT_INVALID_OPTION}
    fi
    local arg="${CLI_INPUT[${opt}]}"
    if [ -z "${arg}" ]
    then
        return ${EXIT_GET_OPTION_NOT_FOUND}
    fi
    echo "${arg}"
    return 0
}

##
# Return the input argument for the given option, but guess as to what the
# option key is.
# 
# The guess work happens by prepending either '--' or '-' to the option.
##
cli_input_get_guess()
{
    local arg="$(cli_input_get "--${1}")"
    local status=$?
    if [ ${status} -ne 0 ]
    then
        arg="$(cli_input_get "-${1}")"
        status=$?
        if [ ${status} -ne 0 ]
        then
            return ${status}
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Return the desired field from a long option that has an argument.
# 
# Example: '--long=argument'
# 
# Possible field values:
# 
#   1 - The option field. From the example above, returns '--long'.
#   2 - The argument field. From the example above, returns 'argument'.
##
cli_option_get_field()
{
    local string="${1}"
    local field="${2}"
    case "${field}" in
        1) echo "${string%%=*}"
           ;;

        2) if [ "${string//=/}" != "${string}" ]
           then
               echo "${string##*=}"
           else
               echo "true"
           fi
           ;;

        *) return ${EXIT_INVALID_FIELD}
           ;;
    esac
    return 0
}

##
# Return the option field from a long option that has an argument.
##
cli_option_get_option_field()
{
    cli_option_get_field "${1}" 1
    return $?
}

##
# Return the argument field from a long option that has an argument.
##
cli_option_get_argument_field()
{
    cli_option_get_field "${1}" 2
    return $?
}

##
# Return the number of options that there are for this program.
##
cli_option_get_length()
{
    echo ${#CLI_OPTION[@]}
}

##
# Return the number of options that were input by the user.
##
cli_input_get_length()
{
    echo ${#CLI_INPUT[@]}
}

##
# Check if a provided long option has an argument.
# 
# Used in cli_options(), checks if a long option is of the form
# '--long=argument', as opposed to an option having no argument, like '--long'.
##
cli_option_has_argument()
{
    local string="${1}"
    if [ "${string//=/}" != "${string}" ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the input option is a long option.
##
cli_option_is_long()
{
    local opt="${1}"
    if [ "${opt:0:2}" == "--" ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is NONE type.
##
cli_argument_type_is_none()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_NONE} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is REQUIRED type.
##
cli_argument_type_is_required()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_REQUIRED} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is OPTIONAL type.
##
cli_argument_type_is_optional()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_OPTIONAL} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is LIST type.
##
cli_argument_type_is_list()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_LIST} ]
    then
        return 0
    else
        return 1
    fi
}
