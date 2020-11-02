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

_pgbackrest_command_options_name() {
    local command_options_name=$(${script} help ${COMP_WORDS[2]} | awk '/^([[:space:]]+)--/ {gsub("--",""); print $1}')
    echo ${command_options_name}
}

_pgbackrest() {    
    local script cur

    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    script=${COMP_WORDS[0]}

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
                    COMPREPLY=($(compgen -W "$(_pgbackrest_command_options_name)" -- ${cur}))
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
        *)
            # Completing the fourth, etc arg.
            case ${cur} in 
                -*)
                    COMPREPLY=($(compgen -W "$(_pgbackrest_command_options)" -- ${cur}))
                    return 0;;
                *)
                    return 1;;
            esac;;
    esac
}

complete -F _pgbackrest pgbackrest