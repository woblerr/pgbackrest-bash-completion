#!/usr/bin/env bash
#
# Bash completion support for pgBackRest (https://pgbackrest.org/)

_pgbackrest_commands() {
    local commands=$(${script} | awk '/^[[:space:]]+/ {print $1}' | grep -v ${script});
    echo ${commands}
}

_pgbackrest_command_options() {
    local command_options=$(${script} help ${COMP_WORDS[1]} | awk '/^([[:space:]]+)--/ {print $1}')
    echo ${command_options}
}

_pgbackrest_command_options_names() {
    local command_options_names=$(${script} help ${COMP_WORDS[2]} | awk '/^([[:space:]]+)--/ {gsub("--",""); print $1}')
    echo ${command_options_names}
}

_pgbackrest_command_options_values() {
    local command_options_values=$(${script} help ${COMP_WORDS[1]} ${prev#--} | awk '/^\*[[:space:]]/ {print $2}')
    echo ${command_options_values}
}

_pgbackrest() {
    local script cur prev arg_regex
    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    script=${COMP_WORDS[0]}
    # Regex for check previous argument
    arg_regex="^--([[:alnum:][:punct:]])+$"

    case $COMP_CWORD in
        1)
            COMPREPLY=($(compgen -W "$(_pgbackrest_commands)" -- ${cur}))
            return 0;;
        2)
            case ${COMP_WORDS[1]} in
                help)
                    COMPREPLY=($(compgen -W "$(_pgbackrest_commands)" -- ${cur}))
                    return 0;;
                *)
                    case ${cur} in
                        -*)
                            COMPREPLY=($(compgen -W "$(_pgbackrest_command_options)" -- ${cur}))
                            return 0;;
                        *)
                            return 1;;
                    esac;;
            esac;;
        3)
            case ${COMP_WORDS[1]} in
                help)
                    COMPREPLY=($(compgen -W "$(_pgbackrest_command_options_names)" -- ${cur}))
                    return 0;;
                *)
                    case ${cur} in
                        -*)
                            COMPREPLY=($(compgen -W "$(_pgbackrest_command_options)" -- ${cur}))
                            return 0;;
                        *)
                            if [[ ${prev} =~ ${arg_regex} ]]; then
                                COMPREPLY=($(compgen -W "$(_pgbackrest_command_options_values)" -- ${cur}))
                                return 0
                            else
                                return 1
                            fi;;
                    esac;;
            esac;;
        *)
            # Completing the fourth, etc args.
            case ${cur} in
                -*)
                    COMPREPLY=($(compgen -W "$(_pgbackrest_command_options)" -- ${cur}))
                    return 0;;
                *)
                    if [[ ${prev} =~ ${arg_regex} ]]; then
                        COMPREPLY=($(compgen -W "$(_pgbackrest_command_options_values)" -- ${cur}))
                        return 0
                    else
                        return 1
                    fi;;
            esac;;
    esac
}

complete -F _pgbackrest pgbackrest