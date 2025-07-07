<h1 align="center">Scoop Ext<h1>

Scoop-ext is currently a simple extension of scoop installer.

## How doe it do?

It use symbolic link to redirect apps location as it supposed to do. If you can't ensure its safety by my words, you can check its main logic at [move.ps1](exec/move.ps1).

Currently:

- **There's no update currently!**
- It only move the main body of apps.
- It won't move persist(Usually the location of your personal data) to prevent potential destruction.  
- It won't move cache which can be cleared by scoop.

## Usage

```
scoop-ext install <app_id> [-pa/--path <location>] 
```

```
scoop-ext install fd --path D:\MyApps
```

- There's no need to create `D:\MyApps\fd`, it create automatically.
- You should use `,` to separate apps, for example `fd, ripgrep` due to the parse logic of powershell script.

## Installation

### Manual

You can clone the repo directly and read the help.
```shell
git clone https://github.com/lvyuemeng/Scoop-ext.git \
cd Scoop-ext \
.\scoop-ext --help
```

### Scoop

Currently is not supported and already planned.

## Why Bother?

It's a long-term issue on scoop that why it can't support custom location installation. Some people say that it should be managed by scoop itself, but due to the design of windows system, I guess manys want a independent storage of apps. So I made it.