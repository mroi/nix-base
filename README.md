Lightweight Declarative Nix System Base
=======================================

This repostitory provides a [Nix](https://nixos.org/) flake for lightweight declarative 
system configuration and maintenance. Different from the real NixOS, it is meant to realize 
its configuration on top of an underlying macOS or Linux installation.

The main entry point is the `rebuild` script. It manifests the configuration of the current 
host within the underlying system. To set up a brand new machine, it is sufficient to 
download this repository, create a configuration, and run `rebuild`.

The `rebuild` script supports a series of subcommands as arguments:

**`activate`**  
This is the default when no subcommands are given. It manifests the configuration on the host 
and is intended to be idempotent, reducing to a no-op on subsequent executions.

**`update`**  
This subcommand pulls external sources for package updates.

**`all`**  
Runs all the above subcommands.

The flake outputs are driven by subdirectories in this repository:

**[`machines`](/machines)**  
Declarative configurations for individual machines, organized by hostname.

**[`modules`](/modules)**  
NixOS-style configuration modules that are composed to form a final configuration.

**[`packages`](/packages)**  
Custom package declarations. Some are meant for direct consumption by end users and are 
included in the flake’s output. Others are only used internally by `rebuild`, for example to 
install macOS applications in `/Applications`.

**[`templates`](/templates)**  
Nix flake templates.

___
This work is licensed under the [WTFPL](http://www.wtfpl.net/), so you can do anything you 
want with it.
