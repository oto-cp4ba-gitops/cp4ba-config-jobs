from jinja2 import Environment, FileSystemLoader

environment = Environment(loader=FileSystemLoader("./"))
template = environment.get_template("postdeploy-output-info.md.j2")
filename = "postdeploy.md"

content = template.render(
    cp4ba_universal_password = "sample-universal-password"
)
with open(filename, mode="w", encoding="utf-8") as message:
    message.write(content)
    print(f"... wrote {filename}")
