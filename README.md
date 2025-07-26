<div align="center">
	<h1>Scoop Link<h1>
</div>

Scoop-Link(scpl) currently is a simple **custom path** management extension of scoop installer.

## What does it do?

It use symbolic link to redirect apps location as it supposed to do. If you can't ensure its safety by my words, you can check its main logic at [move.ps1](lib/move.ps1).

Currently, it use `app.json` in its dir to record the path. If someone could provide a better design, I would like to refactor it. Thus if you **delete** the `apps.json`, you will lose the information about app paths.

Deed:

- It only move the main body of apps.
- It won't move persist(Usually the location of your personal data) to prevent potential destruction.  
- It won't move cache which can be cleared by scoop.

## Usage

It provide only two command: `move` and `sync`.

- `move` will move installed app without breaking scoop logic.
- `sync` will sync the state of `scoop/apps/<app>` in `<your_apps>/<app>` of moved apps for uninstall, update etc...

```bash
scpl move fd -R "D:\MyApps"
scpl move fd -R "./MyApps"
scpl sync fd
scpl sync 
```

**Caveat**: 

  - You should install scoop first.
  - You should use `,` to separate apps due to the parse logic of powershell script.
  - You should place `<[app,]>` always at the first argument due to the **partial** parse logic.

## Installation

### Manual

You can clone the repo directly and read the help.
```shell
git clone https://github.com/lvyuemeng/Scoop-Link.git \
cd Scoop-Link \
.\scpl --help
```

### Scoop

Currently is not supported and already planned.

## Why Bother?

It's a long-term issue on scoop that why it can't support custom location installation. Some people say that it should be managed by scoop itself, but due to the design of windows system, I guess manys want a independent storage of apps. So I made it.

## ⚖️ License

[Apache 2.0 License](/LICENSE-Apache) Or [MIT License](/LICENSE-MIT) - Copyright (C)