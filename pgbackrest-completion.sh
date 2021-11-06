#!/usr/bin/env bash
#
# Bash completion support for pgBackRest (https://pgbackrest.org/)

# For all executed commands stderr is sent to /dev/null. 
# Errors are not needed for completion.
# They will be displayed when the command is finally executed.

__pgbackrest_commands() {
    local commands=$(${script} 2>/dev/null | awk '/^[[:space:]]+/ {print $1}' | grep -v ${script});
    echo ${commands}
}

__pgbackrest_command_options() {
    local command_options=$(${script} help ${COMP_WORDS[1]} 2>/dev/null | awk '/^([[:space:]]+)--/ {print $1}')
    echo ${command_options}
}

__pgbackrest_command_options_names() {
    local command_options_names=$(${script} help ${COMP_WORDS[2]} 2>/dev/null | awk '/^([[:space:]]+)--/ {gsub("--",""); print $1}')
    echo ${command_options_names}
}

__pgbackrest_command_options_values() {
    local command_options_values=$(${script} help ${COMP_WORDS[1]} ${prev#--} 2>/dev/null | awk '/^\*[[:space:]]/ {print $2}')
    echo ${command_options_values}
}

# The '--output' option is available for 2 commands ('repo-ls' and 'info') with the same values.
# For 'repo-ls' command displayed additional information in the same format. 
# To simplify the solution, the option values are specified directly.
# If the values for different commands will be different, this code must be reviewed.
__pgbackrest_command_options_values_output() {
    echo "text"$'\n'"json"
}

# If no stanza - return empty string; nothing to complete
# May be some delays in getting stanza names
__pgbackrest_stanza_values() {
    local stanza_values=$(${script} info --output text 2>/dev/null | awk '/^stanza:/ {print $2}')
    echo ${stanza_values} 
}

# List repo content
__pgbackrest_repo_content() {
    local repo_content raw_content content position substr_path tail_value cur_line_value
    # Regex: the ${cur}'s tail ends with '/'.
    local folder_regex="^([[:graph:]])+\/$"
    # Regex: get full path to last '/'.
    local path_regex="^(([[:graph:]])+\/)+([[:graph:]])+$"
    # By default, do not substitute the full path.
    local substr_path="false"
    # Check that ${cur} already contains a directory.
    # If true - need to add the last directory full path.
    # Valid example:
    #     archive/ 
    #     archive/dem
    #     archive/demo/arch
    [[ ${cur} =~ ${folder_regex} || ${cur} =~ ${path_regex} ]] && cur_value=${cur%/*} && substr_path="true"
    # Get repo content by using 'repo-ls' in json format.
    # For 'repo-get', the content is also obtained via 'repo-ls'.
    # The logic for type 'link' is equivalent to type 'path'.
    if [[ ${repo_key} == '' ]]; then
        # For compatibility with versions < v2.33.
        raw_content=$(${script} repo-ls --output json ${cur_value} 2>/dev/null)
    else
        raw_content=$(${script} repo-ls --repo ${repo_key} --output json ${cur_value} 2>/dev/null)
    fi
    # When incorrect value for '--repo' is used (e.g. '--repo 300'),
    # the command above returns an error, which is discarded,  and an empty result.
    # The completion will not show anything.
    content=$(echo ${raw_content} | grep -o '"[^"]*":{"type":"[^"]*"' | awk '{gsub("\"|{|}",""); print}' | grep -v -E "\.:type:(path|link)")
    for line in ${content}; do
        # By default, don't contain '/' at the end.
        tail_value=""
        # By default, don't contain full path.
        line_value="${line}"
        [[ ${substr_path} == "true" ]] && line_value="${cur%/*}/${line}"
        [[ "$(echo ${line} | awk -F':' '{print $3}')" =~ ^("path"|"link")$ ]] && tail_value="/"
        repo_content+="$(echo ${line_value} | awk -F':' '{print $1}')${tail_value}"$'\n'
    done
    echo ${repo_content}
}

_pgbackrest() {
    local script cur prev arg_regex
    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    script=${COMP_WORDS[0]}
    # Repo id allowed values: 1-256.
    # https://pgbackrest.org/command.html#command-repo-ls
    # Defaul value ''.
    local repo_key=''
    # Regex for check previous argument.
    arg_regex="^--([[:alnum:][:punct:]])+$"
    case $COMP_CWORD in
        1)
            COMPREPLY=($(compgen -W "$(__pgbackrest_commands)" -- ${cur}))
            return 0;;
        2)  
            case ${cur} in
                -*)
                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options)" -- ${cur}))
                    return 0;;
                *)
                    case ${COMP_WORDS[1]} in
                        help)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_commands)" -- ${cur}))
                            return 0;;
                        repo-ls | repo-get)
                            # Because '--repo' flag not specified yet,
                            # Get repo content from the highest priority repository (e.g. repo1)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_repo_content)" -- ${cur}))
                            compopt -o nospace
                            return 0;;
                        *)
                        return 1;;
                    esac;;
            esac;;
        3)
            case ${cur} in
                -*)
                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options)" -- ${cur}))
                    return 0;;
                *)
                    case ${prev} in
                        --stanza)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_stanza_values)" -- ${cur}))
                            return 0;;
                        --output)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values_output)" -- ${cur}))
                            return 0;;
                        *)
                            if [[ ${prev} =~ ${arg_regex} ]]; then
                                COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values)" -- ${cur}))
                                return 0
                            else
                                case ${COMP_WORDS[1]} in
                                    help)
                                        COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_names)" -- ${cur}))
                                        return 0;;
                                    repo-ls | repo-get)
                                        COMPREPLY=($(compgen -W "$(__pgbackrest_repo_content)" -- ${cur}))
                                        compopt -o nospace
                                        return 0;;
                                    *)
                                        return 1;;
                                esac
                            fi;;
                    esac;;
            esac;;
        *)
            # Completing the fourth, etc args.
            case ${cur} in
                -*)
                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options)" -- ${cur}))
                    return 0;;
                *)
                    case ${prev} in
                        --stanza)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_stanza_values)" -- ${cur}))
                            return 0;;
                        --output)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values_output)" -- ${cur}))
                            return 0;;
                        *)
                            if [[ ${prev} =~ ${arg_regex} ]]; then
                                COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values)" -- ${cur}))
                                return 0
                            else
                                case ${COMP_WORDS[1]} in
                                    repo-ls | repo-get)
                                        # Check construction like '--repo 2'.
                                        [[ ${COMP_WORDS[COMP_CWORD - 2]} == "--repo" ]] && repo_key=${prev}
                                        COMPREPLY=($(compgen -W "$(__pgbackrest_repo_content)" -- ${cur}))
                                        compopt -o nospace
                                        return 0;;
                                    *)
                                        return 1;;
                                esac
                            fi;;
                    esac;;
            esac;;
    esac
}

complete -F _pgbackrest pgbackrest
