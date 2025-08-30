<div align="center">
	<h1>Scoop Link<h1>
</div>

Scoop-Link(scpl) currently is a simple **custom path** management extension of scoop installer.

## What does it do?

It use symbolic link to redirect apps location as it supposed to do. If you can't ensure its safety by my words, you can check its main logic at [move.ps1](lib/move.ps1).

Currently, it use `app.json` in its working directory to record the path. If someone could provide a better design, I would like to refactor it. Thus if you **delete** the `apps.json`, you will **lose** the all information about app paths.

Deed:

- It only move the main body of apps.
- It won't move persist(Usually the location of your personal data) to prevent potential destruction.  
- It won't move cache which can be cleared by scoop.

## Usage

It provide below commands: `move`, `sync`, `back`.

- `move` will move installed app to your desired place without breaking scoop logic.
- `sync` will sync the state of `scoop/apps/<app>` in `<your_apps>/<app>` of moved apps for uninstall, update etc...
- `back` will move installed app back to scoop.

```bash
scpl move fd -R "D:\MyApps"
scpl move fd -R "./MyApps"
scpl sync fd
scpl sync # sync all moved apps!
scpl back fd # move app back!
```

**Caveat**: 

  - You should install scoop first.
  - You should use `,` to separate apps due to the parse logic of powershell script.
  - You should place `<[app,]>` always at the first argument due to the **partial** parse logic.

## Installation

### Scoop

Currently, you can copy and paste below or check the repo for this [manifest](scoop-link.json):

```bash
scoop install https://raw.githubusercontent.com/lvyuemeng/Scoop-Link/master/scoop-link.json
scoop update # update to newest version
```

### Manual

You can clone the repo directly and read the help.
```shell
git clone https://github.com/lvyuemeng/Scoop-Link.git \
cd Scoop-Link \
.\scpl --help
```

## Why Bother?

It's a long-term issue on scoop that why it can't support custom location installation. Some people say that it should be managed by scoop itself, but due to the design of windows system, I guess manys want a independent storage of apps. So I made it.

## ⚖️ License

[Apache 2.0 License](/LICENSE-Apache) Or [MIT License](/LICENSE-MIT) - Copyright (C)