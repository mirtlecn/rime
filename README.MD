# Note

Personal use only.

Install

```pwsh
# pwsh

irm aka.mirtle.cn/rime -output rime.ps1 # use a shorten-url service ( point at the raw rime.ps1 ).
./rime.ps1 InitScript
rime init -initpackages <tab> # select mirtlecn/rime/mirtle-packages.conf
# or
rime i mirtlecn/rime/mirtle-packages.conf
```

<details>
<summary>/plum/ from 0 to 1:</summary>

```bat
cd %APPDADA%
git clone https://github.com/rime/plum.git plum
cd %APPDADA%/plum
bash
bash rime-install mirtlecn/rime
rime_dir="~/Rime" bash rime-install mirtlecn/rime
```

Install all package:

```bash
bash rime-install mirtlecn/rime/mirtle-packages.conf
```

Select install:

```bash
bash rime-install --select mirtlecn/rime/mirtle-packages.conf
```

Install & update this repo via plum:

```sh
bash rime-install mirtlecn/rime
```

</details>

## Credit

`res/*.ico`: (C) EasyIME/PIME

Unless otherwise specified by a separate license, all files in this project are released under the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) License (C) 2023 Mirtle.
