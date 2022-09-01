#!/usr/bin/env python
from jinja2 import Environment, FileSystemLoader
import getopt
import os
import string
import sys

environment = Environment(loader=FileSystemLoader("./templates"))
root_markdown_template = "postdeploy-output-info.md.j2"
template = environment.get_template(root_markdown_template)

def help():
    print(
'''

jinja_fill.py: generate post-deployment info for included optional components/deployment patterns

Usage:

   jinja_fill.py [options ..]

Options:
   -c | --components=<optional components separated by commas>
   -p | --patterns=<optional deployment patterns separated by commas>)
   -o | --output=<output file in current directory; defaults to 'postdeploy.md'
''')
    return

def main(argv):
    try:
        opts, args = getopt.getopt(argv,"hc:p:o:",["components=","patterns=","output="])
    except getopt.GetoptError:
        print('Invalid arguments.')
        help();
        return

    sc_optional_components = []
    sc_deployment_patterns = []
    markdown_file = "postdeploy.md"

    for opt, arg in opts:
        if opt in("-c", "--components"): # stuff optional components into array
            sc_optional_components = arg.split(",")
        elif opt in("-p", "--patterns"): # stuff deployment patterns into array
            sc_deployment_patterns = arg.split(",")
        elif opt in("-o", "--output"): # output goes to this file
            markdown_file = arg
        elif (opt == '-h'):
            help()
            return

    # Render from templates. Conditional inclusion therein, starting with root markdown template.
    content = template.render(
        sc_optional_components = sc_optional_components,
        sc_deployment_patterns = sc_deployment_patterns
    )

    with open(markdown_file, mode="w", encoding="utf-8") as message:
        message.write(content)
        print(f"... wrote {markdown_file}")

if __name__ == "__main__":
   main(sys.argv[1:])

sys.exit;
