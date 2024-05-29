# HARBOR

## Installation:

```
sh harbor.sh
```

## What is HARBOR

Harbor's Arch; Reggs Btw On Reggs

## Customization

By default, HARBOR uses the programs [here in reggs.csv](static/reggs.csv) and
installs [jasmine's dotfile repo](https://github.com/bashcats/jasmine_rice)
but you can easily change this by either modifying the default variables at
the beginning of the script or giving the script one of these options:

- `-r`: custom dotfiles repository (URL)
- `-p`: custom programs list/dependencies (local file or URL)
- `-a`: a custom AUR helper (must be able to install with `-S` unless you
  change the relevant line in the script
