# YAML module | [![build status](https://gitlab.com/space-sh/yaml/badges/master/pipeline.svg)](https://gitlab.com/space-sh/yaml/commits/master)

This helper module parses YAML files and make them available from code.



# Functions 

## YAML\_PARSE()  
  
  
Public function to parse yaml into Bash  
variables that could be evaluated by the caller.  
Note: Remember to set \_YAML\_NAMESPACE uniquely for each document loaded.  
  
Use like this:  
local \_YAML\_PREFIX\_ext  
local \_YAML\_NAMESPACE333  
local evals()  
parseYAML $file "\_evals"  
eval "${\_evals[@]}"  
Then use space's functions to read the YAML structure.  
  
$1: YAML file path.  
$2: out array variable name.  
  
  
  
## YAML\_PARSE\_IMPL()  
We use this internally for chainer functions to not pollute with SPACE\_ENV.  
  
## \_sort\_pad()  
  
  
  
Helper function for \_sort, to pad number parts of string.  
  
### Parameters:  
- $1: name of variable to store result in.  
- $2: string to zero pad to 10 digits.  
  
  
  
## \_parse\_yaml()  
  
  
  
parse well formatted YAML document into Bash variables.  
  
Caveats:  
arrays items must be indented at least one space from it's parent.  
### Example:  
  
` parent: `  
` - first: item `  
  
  
### Parameters:  
- $1: name of variable to read YAML from.  
- $2: name of array variable to append to.  
- $3: name of array to use as completion array.  
  
  
  
## \_yaml\_get\_next()  
  
  
  
MACRO helper to \_pp\_yaml and \_parse\_yaml.  
takes no arguments because it uses existing inherited variables.  
  
### Parameters:  
- $1: preprocessing switch  
  
  
  
## \_yaml\_get\_row()  
  
  
  
MACRO helper to get a single row from the feed  
and substitute preprocess variables in that row.  
  
### Parameters:  
- $1: row index  
- $2: preprocessing switch  
  
  
  
## \_yaml\_get\_multiline()  
  
  
  
### Parameters:  
- $1: preprocessing switch  
  
  
  
## \_parsed\_yaml\_to\_bash()  
  
  
Translate parsed YAML into Bash variables.  
  
$1: variable name of input array.  
$2: variable name of output array.  
  
  
  
## \_yaml\_find\_nextindent()  
  
  
  
Peek into object for the given indentation level.  
  
  
## \_list()  
  
  
  
List all nodes below a given node.  
  
### Parameters:  
- $1: name of output array to append to  
- $2: slash separated path, starts and ends with slash.  
- $3: include\_hidden, set to "1" to include leaf nodes beginning with underscore.  
- $4: include leaf node, set to "1" to include leaf nodes.  
  
  
  
## \_copy()  
  
  
  
Copy a YAML variable (leaf) to another variable by assignment.  
  
### Parameters:  
- $1: the name of the variable to copy to.  
- $2: the slash separated \_path of the variable to copy, do not end with slash.  
  
  
  
## \_match\_node()  
  
  
  
env:  
$\_nodes  
Array to add results to.  
  
$1: name of array containing sorted list of nodes.  
$2: pattern to match against list of nodes, ex: "/sites/.*/".  
$3: include hidden nodes. set to 1 to include hidden leave nodes  
beginning with an underscore.  
$4: simple, set to 1 to only return the last node part.  
$5: includeleafs, set to 1 to include leaf nodes.  
  
  
  
## \_module\_find\_yaml()  
  
  
  
Search for a modules YAML file using defaults and  
trying all the different YAML file name variants.  
  
### Parameters:  
- $1: module name: [username/]reponame  
- $2: variable name to assign found YAML file path to.  
  
  
  
