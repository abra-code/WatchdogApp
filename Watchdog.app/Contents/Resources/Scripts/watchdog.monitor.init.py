import sys
import os

script_path = sys.argv[0]
script_name = os.path.basename(script_path)
print(script_name)

for name in sorted(os.environ):
    print(f"{name: <32} = {os.environ[name]}")
