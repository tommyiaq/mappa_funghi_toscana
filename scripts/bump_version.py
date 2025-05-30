import re

PUBSPEC_PATH = "pubspec.yaml"

def read_version_line():
    with open(PUBSPEC_PATH, "r") as file:
        for line in file:
            if line.startswith("version: "):
                return line.strip()
    raise ValueError("No version line found in pubspec.yaml")

def bump_version(version_line):
    match = re.match(r"version:\s*([\d.]+)\+(\d+)", version_line)
    if not match:
        raise ValueError("Invalid version format")

    version_name, version_code = match.groups()
    new_version_code = int(version_code) + 1
    return f"version: {version_name}+{new_version_code}"

def update_version_line(new_version_line):
    with open(PUBSPEC_PATH, "r") as file:
        lines = file.readlines()

    with open(PUBSPEC_PATH, "w") as file:
        for line in lines:
            if line.startswith("version: "):
                file.write(new_version_line + "\n")
            else:
                file.write(line)

    print(f"✅ Updated version to: {new_version_line}")

if __name__ == "__main__":
    current = read_version_line()
    updated = bump_version(current)
    update_version_line(updated)
