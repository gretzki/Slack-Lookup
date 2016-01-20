# Usage

`ruby app.rb USERNAME PASSWORD`

Replace `USERNAME` and `PASSWORD` with your Atlassian Stash/Bitbucket credentials.

# What it does

1. Finds all repositories by their name with regex: /ios/i
2. For all repositories look up all files (default branch)
3. Filter all files by their extension with whitelist: .m, .h, .swift, .plist
4. For all filtered files check their content
5. For all lines of that content check regex: /maliciousURLe.g./
6. If regex returns positive, remember that file and the line number

Right now, the script is not configurable.
Feel free to extend.

# Gotchas

This script has been tested with `ruby 2.2.2p95`.
Execute `bundle` to install all dependencies.

# Author
Chris