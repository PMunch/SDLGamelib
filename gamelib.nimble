[Package]
name		= "gamelib"
version		= "0.0.1"
author		= "Peter Munch-Ellingsen"
description	= """A library of functions to make creating games using Nim and SDL2 easier.
This does not intend to be a full blown engine and tries to keep all the components loosly coupled so that individual parts can be used separately."""
license		= "MIT"

SkipFiles	= """
alite.html
LICENSE
.gitignore
README
"""

[Deps]
Requires: """
nim  >= 0.14.0
sdl2 >= 1.1
"""
