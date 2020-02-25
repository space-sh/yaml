#
# Copyright 2016-2020 Blockie AB
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

#==================
# _TEST_YAML_PARSE()
#
#==================
_TEST_YAML_PARSE()
{
    SPACE_DEP="YAML_PARSE PRINT"

    local evals=()
    YAML_PARSE "./test/reference.yaml" "evals"
    eval "${evals[*]}"

    local volumes_name_expected="nginx-files"
    local volumes_type_expected="config"
    local containers_name_expected="webserver"
    local containers_image_expected="imagename"

    local volumes=()
    _list "volumes" "/volumes/"
    for index in "${volumes[@]}"; do
        local name=
        local type=
        _copy "name" "/volumes/${index}/name"
        _copy "type" "/volumes/${index}/type"
        if [ "${name}" != "${volumes_name_expected}" ]; then
            PRINT "Could not parse YAML file" "error"
            PRINT "Expected: '${volumes_name_expected}' got '${name}'"
            return 1
        fi
        if [ "${type}" != "${volumes_type_expected}" ]; then
            PRINT "Could not parse YAML file" "error"
            PRINT "Expected: '${volumes_type_expected}' got '${type}'"
            return 1
        fi
    done

    local containers=()
    _list "containers" "/containers/"
    for index in "${containers[@]}"; do
        local name=
        local image=
        _copy "name" "/containers/${index}/name"
        _copy "image" "/containers/${index}/image"
        if [ "${name}" != "${containers_name_expected}" ]; then
            PRINT "Could not parse YAML file" "error"
            PRINT "Expected: '${containers_name_expected}' got '${name}'"
            return 2
        fi
        if [ "${image}" != "${containers_image_expected}" ]; then
            PRINT "Could not parse YAML file" "error"
            PRINT "Expected: '${containers_image_expected}' got '${image}'"
            return 2
        fi
    done

    PRINT "No errors detected during YAML parsing" "info"
}
