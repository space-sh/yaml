#
# Copyright 2016 Blockie AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# TODO
# YAML parsing module.
# This is still just a copy of the functions in the space script.
# We will have to decide if this also should have preprocessing capabilities, etc.



#==========
#
# Public function to parse yaml into Bash
# variables that could be evaluated by the caller.
# Note: Remember to set _YAML_NAMESPACE uniquely for each document loaded.
#
# Use like this:
#   local _YAML_PREFIX=_ext
#   local _YAML_NAMESPACE=333
#   local evals=()
#   parseYAML $file "_evals"
#   eval "${_evals[@]}"
# Then use space's functions to read the YAML structure.
#
# $1: YAML file path.
# $2: out array variable name.
#
#==========
YAML_PARSE()
{
    SPACE_SIGNATURE="filepath outvarname"
    SPACE_DEP="YAML_PARSE_IMPL _parse_yaml _yaml_get_next _yaml_get_row _yaml_get_multiline _parsed_yaml_to_bash _sort _sort_pad _yaml_find_nextindent _list _copy _match_node _module_find_yaml"
    SPACE_ENV="_YAML_PREFIX _YAML_NAMESPACE _SPACEGAL_EOF_TAG"

    YAML_PARSE_IMPL "$@"
}

# We use this internally for chainer functions to not pollute with SPACE_ENV.
YAML_PARSE_IMPL()
{
    SPACE_SIGNATURE="filepath outvarname"

    local _filepath=$1
    shift

    local _outvarname=$1
    shift

    local _parsedyamlcompletion=()
    local _parsedyaml=()
    local _yamlrows=()

    IFS=$'\n' read -d '' -r -a _yamlrows < $_filepath

    _parse_yaml "_yamlrows" "_parsedyaml" "_parsedyamlcompletion"
    _sort "_parsedyamlcompletion"
    eval "_parsedyamlnodelist${_YAML_PREFIX}${_YAML_NAMESPACE}=(\"\${_parsedyamlcompletion[@]}\")"
    _parsed_yaml_to_bash "_parsedyaml" "$_outvarname"
}

#==========
# _sort_pad
#
# Helper function for _sort, to pad number parts of string.
#
# Parameters:
#   $1: name of variable to store result in.
#   $2: string to zero pad to 10 digits.
#
#==========
_sort_pad()
{
    local _output=$1
    shift

    local _s=$1
    shift

    local _s2="" _tmp=""
    while [[ $_s =~ ([^0-9.]*)([0-9]+)(.*) ]]; do
        printf -v _tmp "%010d" ${BASH_REMATCH[2]}
        _s2=$_s2${BASH_REMATCH[1]}$_tmp
        _s=${BASH_REMATCH[3]}
    done
    _s2=$_s2$_s
    eval "$_output=\$_s2"
}

_sort()
{
    local _arrname=$1
    shift

    eval "local _last=\${#${_arrname}[@]}"
    ((_last-=1))
    local _i=
    for (( ; _last>0; _last-- )); do
        for (( _i=0; _i<_last; _i++ )); do
            eval "local _line1=\${${_arrname}[$_i]}"
            eval "local _line2=\${${_arrname}[$((_i+1))]}"
            local _line1padded= _line2padded=
            _sort_pad "_line1padded" "$_line1"
            _sort_pad "_line2padded" "$_line2"
            if [[ "${_line1padded}" > "${_line2padded}" ]]; then
                eval "${_arrname}[$_i]=\"$_line2\""
                eval "${_arrname}[$((_i+1))]=\"$_line1\""
            fi
        done
    done
}



#==========
# _parse_yaml
# 
# parse well formatted YAML document into Bash variables.
#
# Caveats: 
#   arrays items must be indented at least one space from it's parent. 
#   Example:
#
#   parent:
#    - first: item
#
#
# Parameters:
#   $1: name of variable to read YAML from.
#   $2: name of array variable to append to.
#   $3: name of array to use as completion array.
#
#==========
_parse_yaml()
{
    local _invarname=$1
    shift
    local _outvarname=$1
    shift
    local _outcompletionvarname=$1
    shift

    local _allrows=()
    eval "_allrows=(\"\${"${_invarname}"[@]}\")"

    local _numrows=${#_allrows[@]}
    local _rowindex=0
    local _lastindent=0 _nodes=("/") _lastkey="" _prefix="/"
    local _indent=0 _rowtype= _key= _readahead=() _nextindent=0
    local _arrayextraindent= _output=

    while _yaml_get_next 0;
    do
        # Set node prefix for changed indentation level.
        if (($_indent > $_lastindent)); then
            # Increasing indentation level, add to prefix.
            _prefix=$_prefix$_lastkey\/
            _nodes[$_indent]=$_prefix
        elif (($_indent < $_lastindent)); then
            # Decreasing indentation level, fallback to earlier prefix.
            _prefix=${_nodes[$_indent]}
        fi
        _lastindent=$_indent
        case "${_rowtype}" in
            leaf) # A regular key value row.
                local _varname=$_prefix$_key

                # Add to node name completion list.
                local _completionname="${_varname}/"
                local _item=
                # Break down the path and add each sub path as completion name, early quit when
                # a path is found since we are guaranteed all the remaining sub paths are already added.
                while :; do
                    eval '
                    for _item in "${'$_outcompletionvarname'[@]-}"; do
                        if [[ $_item == "${_completionname} 0" || $_item == "${_completionname} 1" ]]; then
                            break 2
                        fi
                    done
                    '
                    if [[ $_completionname == "${_varname}/" ]]; then
                        # The leaf node
                        eval "$_outcompletionvarname+=(\"${_completionname} 1\")"
                    else
                        eval "$_outcompletionvarname+=(\"${_completionname} 0\")"
                    fi
                    if [[ $_completionname == "/" ]]; then
                        break
                    fi
                    _completionname=${_completionname%/*/}/
                done
                unset _item
                unset _completionname

                _varname=${_varname//_/0a95}
                _varname=${_varname//\//_}
                if ((${#_readahead[@]} == 0)); then
                    # Simulate multiline value for the single line
                    if [[ ${value//\ } != "" ]]; then
                        _readahead[0]="$value"
                    else
                        _readahead[0]=""
                    fi
                else
                    # Check if to collapse new lines.
                    if [[ ${value:0:1} == ">" ]]; then
                        local _s=${_readahead[@]}
                        _readahead=("$_s")
                    fi
                fi
                eval "$_outvarname+=(\"\$_varname\")"
                local _line=
                for _line in "${_readahead[@]}"; do
                    printf -v _output "%s" "$_line"
                    eval "$_outvarname+=(\"\$_output\")"
                done
                eval "$_outvarname+=(\"\$_SPACEGAL_EOF_TAG\")"
                _lastkey=$_key
                ;;
            object) # Start of new object
                _lastkey=$_key
                ;;
            arrayobject)
                # New array object begins
                # Output key index at given indent
                local _i=$(($_indent+$_arrayextraindent))
                local _varname="_index_count${_prefix//\//_}"
                local _count=${!_varname-0}
                eval "local $_varname=$(($_count+1))"
                local _subrows=()
                # Reinsert the key value of first line to have it handled as a normal leaf.
                if [[ -z $_key ]]; then
                    printf -v _output "%*s%s" $_i "" "$_count: $value"
                else
                    printf -v _output "%*s%s" $_i "" "$_key: $value"
                fi
                _subrows+=("$_output")
                if ((${#_readahead[@]} > 0)); then
                    ((_i+=4))
                    local _line=
                    for _line in "${_readahead[@]}"; do
                        printf -v _output "%*s%s" $_i "" "$_line"
                        _subrows+=("$_output")
                    done
                fi
                _allrows=("${_allrows[@]:0:$_rowindex}" "${_subrows[@]}" \
                    "${_allrows[@]:$_rowindex:$_numrows-$_rowindex}")
                ((_numrows+=${#_subrows[@]}))
                _lastkey=$_count
                ;;
        esac
    done
}

#==========
# _yaml_get_next
#
# MACRO helper to _pp_yaml and _parse_yaml.
# takes no arguments because it uses existing inherited variables.
#
# Parameters:
#   $1: preprocessing switch
#
#==========
_yaml_get_next()
{
    if (( $_rowindex >= $_numrows )); then
        return 1
    fi

    local _dopreprocess=${1}
    shift

    # This particular preprocess value will have its substitution postponed because
    # we do not know the correct parent node already.
    local _PP_PARENT=_PP_PARENT
    local _PP_PARENTPATH=_PP_PARENTPATH

    local _row=
    _yaml_get_row $_rowindex $_dopreprocess
    ((_rowindex+=1))

    _key=""
    value=""
    _rowtype=""
    _readahead=()

    if [[ $_row =~ ^([\ ]*)(\@include)[\ ]*:(-?)[\ ]+(.*) ]]; then
        _indent=${#BASH_REMATCH[1]}
        _key=
        local _op=${BASH_REMATCH[3]}
        value=${BASH_REMATCH[4]}
        _includevariables=
        if [[ $value =~ ^(.*)[\ ]*\|[\ ]*(.*) ]]; then
            _includefile=${BASH_REMATCH[1]}
            local _s=${BASH_REMATCH[2]}
            if [[ $_s =~ (.*)\((.*)\)$ ]]; then
                _includefilter=${BASH_REMATCH[1]}
                _includevariables=${BASH_REMATCH[2]}
            else
                _includefilter=$_s
            fi
        else
            _includefile=$value
            _includefilter=""
        fi
        _yaml_get_multiline 0
        # Check if $_includefile is a module
        if [[ -n $_includefile && ! $_includefile =~ \.yaml$ ]]; then
            _module_find_yaml "$_includefile" "_includefile"
        fi
        if [[ $_op == "-" && ! -f $_includefile ]]; then
             # Ignore missing yaml file.
            _rowtype=""
        else
            _rowtype="include"
        fi
    elif [[ $_row =~ ^([\ ]*)(\@clone)[\ ]*:[\ ]+(.*) ]]; then
        _indent=${#BASH_REMATCH[1]}
        _key=
        value=${BASH_REMATCH[3]}
        _rowtype="clone"
    elif [[ $_row =~ ^([\ ]*)(\@debug)[\ ]*:[\ ]+(.*) ]]; then
        _indent=${#BASH_REMATCH[1]}
        _key=
        value=${BASH_REMATCH[3]}
        _rowtype="debug"
    elif [[ $_row =~ ^([\ ]*)(\@assert)[\ ]*:[\ ]+(.*) ]]; then
        _indent=${#BASH_REMATCH[1]}
        _key=
        value=${BASH_REMATCH[3]}
        _rowtype="assert"
    elif [[ $_row =~ ^([\ ]*)(\@cache)[\ ]*:[\ ]+(.*) ]]; then
        _indent=${#BASH_REMATCH[1]}
        _key=
        value=${BASH_REMATCH[3]}
        _rowtype="cache"
    elif [[ $_row =~ ^([\ ]*)(\@prompt)[\ ]*:(-?)[\ ]+([^\ ]+)[\ ](.*) ]]; then
        _indent=${#BASH_REMATCH[1]}
        local _op=${BASH_REMATCH[3]}
        _key=${BASH_REMATCH[4]}
        value=${BASH_REMATCH[5]}
        if [[ $_op == "-" ]]; then
            # @prompt:- means only prompt on variable if it lacks a value or is unset.
            local _pp_varname="_PP_$_key"
            if [[ -n ${!_pp_varname-} ]]; then
                return 0
            fi
        fi
        _rowtype="prompt"
    elif [[ $_row =~ ^([\ ]*)\@([a-zA-Z0-9_]+)[\ ]*(:|:-|:\+)\ (.*) ]]; then
        # Assign preprocess variable.
        _indent=${#BASH_REMATCH[1]}
        _key=${BASH_REMATCH[2]}
        local _op=${BASH_REMATCH[3]}
        if [[ $_op == ":-" ]]; then
            # @var:- means only assign variable if it lacks a value or is unset.
            local _pp_varname="_PP_$_key"
            if [[ -n ${!_pp_varname-} ]]; then
                return 0
            fi
        elif [[ $_op == ":+" ]]; then
            # @var:+ means only assign variable if it already has a value.
            local _pp_varname="_PP_$_key"
            if [[ -z ${!_pp_varname-} ]]; then
                return 0
            fi
        elif [[ $_op == ":" ]]; then
            # @var: means always assign to variable.
            # Fall through.
            :
        fi
        value=${BASH_REMATCH[4]}
        _rowtype="assign"
    elif [[ $_row =~ ^([\ ]*)\@([a-zA-Z0-9_]+)[\ ]*(:|:-|:\+)$ ]]; then
        # Unset a preprocess variable.
        _indent=${#BASH_REMATCH[1]}
        _key=${BASH_REMATCH[2]}
        local _op=${BASH_REMATCH[3]}
        if [[ $_op == ":-" ]]; then
            # @var:- means only unset variable if it lacks a value or is unset.
            local _pp_varname="_PP_$_key"
            if [[ -n ${!_pp_varname-} ]]; then
                return 0
            fi
        elif [[ $_op == ":+" ]]; then
            # @var:+ means only unset variable if it has a value.
            local _pp_varname="_PP_$_key"
            if [[ -z ${!_pp_varname-} ]]; then
                return 0
            fi
        elif [[ $_op == ":" ]]; then
            # @var: means always unset variable.
            # Fall through.
            :
        fi
        eval "unset _PP_$_key"
    elif [[ $_row =~ ^([\ ]*)([a-zA-Z0-9_]+)[\ ]*:[\ ]?(.*) ]]; then
        # Key value or new object/array row
        _indent=${#BASH_REMATCH[1]}
        _key=${BASH_REMATCH[2]}
        value=${BASH_REMATCH[3]}
        if [[ ${value//\ } != "" ]]; then
            # This row has a value (other than spaces)
            _rowtype="leaf"
            # Check if we should do a read ahead.
            if [[ ${value:0:1} == "|" || ${value:0:1} == ">" ]]; then
                _yaml_get_multiline $_dopreprocess
            fi
        else
            value=""
            # This node has no value, we must figure out if it's
            # an empty leaf or an object.

            # Find out the nextindent level for an object row.
            local _yamlindent=0
            _yaml_find_nextindent
            if (( $_yamlindent > $_indent )); then
                _rowtype="object"
            else
                _rowtype="leaf"
            fi
            unset _yamlindent
        fi
    elif [[ $_row =~ ^([\ ]*)\-([\ ]+)([a-zA-Z0-9_]+)[\ ]*:[\ ]+(.*) ||
             $_row =~ ^([\ ]*)\-([\ ]+)([a-zA-Z0-9_]+)[\ ]*:($) ]]; then
        # Array item with child object.
        _indent=${#BASH_REMATCH[1]}
        _arrayextraindent=$((${#BASH_REMATCH[2]}+1))
        _key=${BASH_REMATCH[3]}
        value=${BASH_REMATCH[4]}
        _rowtype="arrayobject"
        if [[ ${value//\ } != "" ]]; then
            # This row has a value (other than spaces)
            # Check if we should do a read ahead.
            if [[ ${value:0:1} == "|" || ${value:0:1} == ">" ]]; then
                _yaml_get_multiline $_dopreprocess
            fi
        fi
    elif [[ $_row =~ ^([\ ]*)\-[\ ]+(.*) || $_row =~ ^([\ ]*)\-($) ]]; then
        # Array index item with only value.
        _indent=${#BASH_REMATCH[1]}
        _arrayextraindent=0
        _key=
        value=${BASH_REMATCH[2]}
        _rowtype="arrayobject"
        if [[ ${value//\ } != "" ]]; then
            # This row has a value (other than spaces)
            # Check if we should do a read ahead.
            if [[ ${value:0:1} == "|" || ${value:0:1} == ">" ]]; then
                _yaml_get_multiline $_dopreprocess
            fi
        fi
    else
        # Unknown row
        :
    fi
    return 0
}

#==========
# _yaml_get_row
#
# MACRO helper to get a single row from the feed
# and substitute preprocess variables in that row.
#
# Parameters:
#   $1: row index
#   $2: preprocessing switch
#
#==========
_yaml_get_row()
{
    local _index=$1
    shift
    local _dopreprocess=$1
    shift

    _row=${_allrows[$_index]}
    while [[ $_dopreprocess == "1" && $_row =~ ^(.*)\@\{([\ @a-zA-Z0-9_:-]+)\}(.*)$ ]]; do
        # Substitute preprocessed variable
        local _left=${BASH_REMATCH[1]}
        local _s=${BASH_REMATCH[2]}
        local _right=${BASH_REMATCH[3]}
        if [[ $_s =~ ([a-zA-Z0-9_]+)(:?\-)(.+) ]]; then
            local _substvar=_PP_${BASH_REMATCH[1]}
            local _op=${BASH_REMATCH[2]}
            local _substvar2=${BASH_REMATCH[3]}
            if [[ ${_substvar2:0:1} == "@" ]]; then
                _substvar2=_PP_${_substvar2:1}
                local _substvalue2=${!_substvar2-}
            else
                local _substvalue2=$_substvar2
            fi
            local _substvalue=
            if [[ $_op == "-" ]]; then
                _substvalue=${!_substvar-$_substvalue2}
            else
                _substvalue=${!_substvar:-$_substvalue2}
            fi
        else
            local _substvar=_PP_$_s
            local _substvalue=${!_substvar-}
        fi

        _row=${_left}${_substvalue}${_right}
    done
}

#==========
# _yaml_get_multiline
#
# Parameters:
#   $1: preprocessing switch
#
#==========
_yaml_get_multiline()
{
    local _dopreprocess=$1
    shift

    if (( $_rowindex >= $_numrows )); then
        return
    fi
    local _row=
    _yaml_get_row $_rowindex $_dopreprocess
    if [[ $_row =~ ^([\ ]+)([^\ ].*) ]]; then
        local _subindent=${#BASH_REMATCH[1]}
        local _subvalue=${BASH_REMATCH[2]}
        if (($_subindent > $_indent)); then
            _readahead+=("$_subvalue")
            while :; do
                ((_rowindex+=1))
                if (( $_rowindex >= $_numrows )); then
                    break
                fi
                _yaml_get_row $_rowindex $_dopreprocess
                if [[ $_row =~ ^([\ ]+)([^\ ].*) || $_row =~ ^([\ ]{$_subindent})(.*) ]]; then
                    local _subindent2=${#BASH_REMATCH[1]}
                    if (($_subindent2 < $_subindent)); then
                        break
                    fi
                    printf -v _subvalue "%*s%s" $(($_subindent2-$_subindent)) "" \
                        "${BASH_REMATCH[2]}"
                    _readahead+=("$_subvalue")
                else
                    break
                fi
            done
        fi
    fi
}

#============
#
# Translate parsed YAML into Bash variables.
#
# $1: variable name of input array.
# $2: variable name of output array.
#
#============
_parsed_yaml_to_bash()
{
    local _invarname=$1
    shift

    local _outvarname=$1
    shift

    local _allrows=()
    eval "_allrows=(\"\${"${_invarname}"[@]}\")"

    local _line= _str= _varname=
    for _line in "${_allrows[@]}"; do
        if [[ -z $_varname ]]; then
            _varname="${_YAML_PREFIX}${_YAML_NAMESPACE}${_line}"
            _str="local $_varname="$'\n'" read -d '' -r $_varname << \"$_SPACEGAL_EOF_TAG\""
        elif [[ $_line == "$_SPACEGAL_EOF_TAG" ]]; then
            _str=$_str$'\n'$_SPACEGAL_EOF_TAG$'\n'":"$'\n'
            eval "$_outvarname+=(\"\$_str\")"
            _str=""
            _varname=
        else
            _str=$_str$'\n'$_line
        fi
    done
}

#==========
# _yaml_find_nextindent
#
# Peek into object for the given indentation level.
#==========
_yaml_find_nextindent()
{
    local _i=$_rowindex
    _nextindent=4  # Default value
    _yamlindent=0

    while :; do
        if (( $_i >= $_numrows )); then
            return
        fi
        local _peekrow=${_allrows[$_i]}
        #_error PEEK $_peekrow
        ((_i+=1))
        if [[ $_peekrow =~ ^([\ ]*)\-([\ ]+)[a-zA-Z0-9_]+[\ ]*:[\ ]*.* ]]; then
            _yamlindent=$((${#BASH_REMATCH[1]}+${#BASH_REMATCH[2]}+1))
            break
        elif [[ $_peekrow =~ ^([\ ]*)([a-zA-Z0-9_@]+)[\ ]*:[\ ]*(.*) ]]; then
            _yamlindent=${#BASH_REMATCH[1]}
            break
        elif [[ $_peekrow =~ ^([\ ]*)\-[\ ]*$ ]]; then
            _yamlindent=$((${#BASH_REMATCH[1]}))
            break
        fi
    done
    if [[ $_yamlindent -gt $_indent ]]; then
        _nextindent=$(($_yamlindent-$_indent))
    fi
}

#========
# _list
#
# List all nodes below a given node.
#
# Parameters:
#   $1: name of output array to append to
#   $2: slash separated path, starts and ends with slash.
#   $3: include_hidden, set to "1" to include leaf nodes beginning with underscore.
#   $4: include leaf node, set to "1" to include leaf nodes.
#
#========
_list()
{
    local _output=$1
    shift

    local _path=$1
    shift

    local _includehidden=${1:-0}
    shift || :

    local _includeleafs=${1:-0}
    shift || :

    if [[ ! $_path =~ (^/.+/$)|(^/$) ]]; then
        _error "Malformed path ($_path) as argument to _list. Must start and end with a slash. Lonesome cowboy slashes are OK dough."
        return 1
    fi

    local _nodes=()
    _match_node "_parsedyamlnodelist${_YAML_PREFIX}${_YAML_NAMESPACE}" "${_path}.*/" "${_includehidden}" "1" "${_includeleafs}"
    if (( ${#_nodes[@]} == 0 )); then
        eval "${_output}=()"
    else
        eval "${_output}=(\"\${_nodes[@]}\")"
    fi
}


#==========
# _copy
#
# Copy a YAML variable (leaf) to another variable by assignment.
#
# Parameters:
#   $1: the name of the variable to copy to.
#   $2: the slash separated _path of the variable to copy, do not end with slash.
#
#==========
_copy()
{
    local _var=$1
    shift

    local _path=${1//_/0a95}
    shift

    _path="${_YAML_PREFIX}${_YAML_NAMESPACE}${_path//\//_}"
    eval "$_var=\${$_path-}"
}

#==========
# _match_node
#
# env:
#   $_nodes
#       Array to add results to.
#
# $1: name of array containing sorted list of nodes.
# $2: pattern to match against list of nodes, ex: "/sites/.*/".
# $3: include hidden nodes. set to 1 to include hidden leave nodes
#   beginning with an underscore.
# $4: simple, set to 1 to only return the last node part.
# $5: includeleafs, set to 1 to include leaf nodes.
#
#==========
_match_node()
{
    local _inputname=$1
    shift

    local _nodepath=$1
    shift

    local _includehidden=${1:-0}
    shift || :

    local _simple=${1:-0}
    shift || :

    local _includeleafs=${1:-0}
    shift || :

    local _item= _node= _isleaf=
    local _nodelist=()
    eval '
    for _item in "${'$_inputname'[@]-}"; do
        if [[ $_item =~ ([^ ]+)\ (.*) ]]; then
            _node=${BASH_REMATCH[1]}
            _isleaf=${BASH_REMATCH[2]}
            if [[ ($_isleaf == "1" && $_includeleafs == "1") || $_isleaf == "0" ]]; then
                _nodelist+=($_node)
            fi
        fi
    done
    '
    unset _item _node _isleaf

    if ((${#_nodelist[@]} == 0)); then
        return 0
    fi

    local _item= _levels=
    local _match= _matched=

    # Figure out how many levels we have by counting slashes.
    _levels=${_nodepath//[^\/]}
    _levels=${#_levels}
    ((_levels-=1))
    if (($_levels == 0)); then
        _nodes+=("/")
    else
        _match=""
        for ((i=0; i<$_levels; i++)); do
            if ((i < _levels-1)) || [[ $_includehidden == "1" ]]; then
                _match="${_match}/[a-zA-Z0-9_]+"
            else
                _match="${_match}/[a-zA-Z0-9][a-zA-Z0-9_]*"
            fi
        done
        _match="${_match}/"
        for _item in "${_nodelist[@]}"; do
            if [[ $_item =~ ^($_match)$ ]]; then
                _matched=${BASH_REMATCH[1]}
                if [[ $_matched =~ $_nodepath ]]; then
                    if [[ $_simple == "0" ]]; then
                        _nodes+=("$_matched")
                    else
                        local _arr=()
                        IFS='/' read -r -a _arr <<< "${_matched}"
                        _nodes+=("${_arr[$((${#_arr[@]}-1))]}")
                        unset _arr
                    fi
                fi
            fi
        done
    fi
    unset _item _levels
    unset _match _matched
    unset _nodepath
}

#=============
# _module_find_yaml
#
# Search for a modules YAML file using defaults and
# trying all the different YAML file name variants.
#
# Parameters:
#   $1: module name: [username/]reponame
#   $2: variable name to assign found YAML file path to.
#
#=============
_module_find_yaml()
{
    local _module=$1
    shift

    local _outvarname=$1
    shift

    local _domainname=""
    local _username="space-sh"
    local _reponame=$_module
    if [[ $_module =~ (.+)/(.+)/(.+) ]]; then
        _domainname=${BASH_REMATCH[1]}
        _username=${BASH_REMATCH[2]}
        _reponame=${BASH_REMATCH[3]}
    elif [[ $_module =~ (.+)/(.+) ]]; then
        _username=${BASH_REMATCH[1]}
        _reponame=${BASH_REMATCH[2]}
    fi
    #[[ $_reponame =~ ([^:]+) ]]
    #local _reponameclean=${BASH_REMATCH[1]}
    unset _module

    if [ "${_domainname}" = "" ]; then
        if [ "${_username}" = "space-sh" ]; then
            _domainname="gitlab.com"
        fi
    fi

    local _dir= _f=
    for _dir in ${_INCLUDEPATH[@]}; do
        for _f in "$_dir/$_domainname/$_username/$_reponame/Spacefile.yaml"; do
            if [[ -f $_f ]]; then
                _debug "Found module $_f"
                eval "$_outvarname=\$_f"
                return
            fi
        done
    done
}
