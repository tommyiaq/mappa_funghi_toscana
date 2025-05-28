from pathlib import Path

script_dir = Path(__file__).parent
file_path = script_dir / "empty_file.txt"

with open(file_path, "w") as f:
    pass