#!/usr/bin/env bash
#
# Bash completion support for pgBackRest (https://pgbackrest.org/)
# See 'allow-list' in https://github.com/pgbackrest/pgbackrest/blob/main/src/build/config/config.yaml

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


# For 'repo-ls' command displayed additional information in the same format. 
# To simplify the solution and not write additional regexp, the option values are specified directly.
__pgbackrest_command_options_values_output_repo_ls() {
    echo "text"$'\n'"json"
}

# The '--buffer-size' displays values in the user friendly format starting from pgBackRest v2.37.
# In earlier versions, values in bytes will be substituted.
# https://github.com/pgbackrest/pgbackrest/pull/1557
__pgbackrest_command_options_values_buffer_size() {
    local buffer_size_option_values
    # Regex for valid values like:
    #   16384,
    #   16777216.
    #   16KiB,
    #   16MiB.
    local size_regex="^[[:digit:]]+([[:alpha:]]+)?[[:punct:]]$"
    # Get full string with all values.
    local buffer_size_content=$(${script} help ${COMP_WORDS[1]} ${prev#--} 2>/dev/null | awk '/^Allowed values([[:graph:]]|[[:space:]])/ {print $0; getline; print $0}')
    # Parse string and add to array result.
    for line in ${buffer_size_content}; do
        [[ ${line} =~ ${size_regex} ]] &&  buffer_size_option_values+=(${line/[[:punct:]]/})
    done
    echo ${buffer_size_option_values[@]}
}



# If no stanza - return empty string; nothing to complete.
# May be some delays in getting stanza names.
__pgbackrest_stanza_values() {
    # Basic command for 'info' command.
    local info_command="${script} info --output text"
    [[ ${config_params} != '' ]] && info_command="${info_command} ${config_params}"
    local stanza_values=$(${info_command} 2>/dev/null | awk '/^stanza:/ {print $2}')
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
    # Basic command for 'repo-ls' command.
    local repo_ls_command="${script} repo-ls --output json"
    # Add config params, if they exists.
    [[ ${config_params} != '' ]] && repo_ls_command="${repo_ls_command} ${config_params}"
    # For compatibility with versions < v2.33.
    [[ ${repo_params} != '' ]] && repo_ls_command="${repo_ls_command} ${repo_params}"
    # Get repo content by using 'repo-ls' in json format.
    # For 'repo-get', the content is also obtained via 'repo-ls'.
    # The logic for type 'link' is equivalent to type 'path'.
    raw_content=$(${repo_ls_command} ${cur_value} 2>/dev/null)
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
    # If --repo parameter is not set, use the default parameter for pgBackRest or from env.
    local repo_params=''
    # Regex for check previous argument.
    arg_regex="^--([[:alnum:][:punct:]])+$"
    # If --config* parameters are not set, use the default parameters for pgBackRest or from env.
    local config_params=''
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
                            # get repo content from the highest priority repository (e.g. repo1).
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
                            # Different values for the '--output' option depending on the command.
                            case ${COMP_WORDS[1]} in
                                repo-ls)
                                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values_output_repo_ls)" -- ${cur}))
                                    return 0;;
                                *)
                                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values)" -- ${cur}))
                                    return 0;;
                            esac;;
                        --buffer-size)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values_buffer_size)" -- ${cur}))
                            return 0;;
                        --repo-storage-upload-chunk-size)
                            # Nothing to do. 
                            # The documentation provides default values for different repo types.
                            # But there are no definite values for the parameter.
                            return 1;;
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
                    local i
                    # 0 - script name (pgbackrest), 1 - command (info).
                    # There is no need to check them.
                    # Example:
                    # pgbackrest info --config /tmp/pgbackrest.conf --stanza <TAB>
                    for (( i=2; i<${#COMP_WORDS[@]}-1; i++)); do
                        case ${COMP_WORDS[$i]} in
                            # Checking whether --config* parameters are set.
                            --config)
                                config_params="${config_params} --config ${COMP_WORDS[$i+1]}";;
                            --config-include-path)
                                config_params="${config_params} --config-include-path ${COMP_WORDS[$i+1]}";;
                            --config-path)
                                config_params="${config_params} --config-path ${COMP_WORDS[$i+1]}";;
                            # Checking whether --repo parameter is set.
                            --repo)
                                repo_params="${repo_params} --repo ${COMP_WORDS[$i+1]}";;
                        esac
                    done
                    case ${prev} in
                        --stanza)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_stanza_values)" -- ${cur}))
                            return 0;;
                        --output)
                            case ${COMP_WORDS[1]} in
                                repo-ls)
                                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values_output_repo_ls)" -- ${cur}))
                                    return 0;;
                                *)
                                    COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values)" -- ${cur}))
                                    return 0;;
                            esac;;
                        --buffer-size)
                            COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values_buffer_size)" -- ${cur}))
                            return 0;;
                        --repo-storage-upload-chunk-size)
                            return 1;;
                        *)
                            if [[ ${prev} =~ ${arg_regex} ]]; then
                                COMPREPLY=($(compgen -W "$(__pgbackrest_command_options_values)" -- ${cur}))
                                return 0
                            else
                                case ${COMP_WORDS[1]} in
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
    esac
}

# -o nosort - disable bash sorting, use pgBackRest output sorting.
complete -o nosort -F _pgbackrest pgbackrest
