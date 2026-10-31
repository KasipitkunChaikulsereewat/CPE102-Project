#!/usr/bin/env python3
"""
iPad UI System Builder — Quick launcher
Run from E:/unreal/MyProject directory
"""
import subprocess, sys, os

script = os.path.join(
    r"C:/Users/User/.gemini/antigravity/brain/599928ea-650d-42b5-afda-4f0594a992b1/scratch",
    "ipad_ui_builder_final.py"
)

if "--dry-run" in sys.argv:
    subprocess.run([sys.executable, script, "--dry-run"])
else:
    subprocess.run([sys.executable, script] + sys.argv[1:])
