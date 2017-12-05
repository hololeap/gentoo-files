To set up this repo when installing Gentoo:

- Mount all directories (except dev, proc, and sys)
- `cd /mnt/gentoo`
- `git init`
- `git remote add origin https://github.com/hololeap/gentoo-files`
- `git pull origin $branch`
- `git submodule update --init --depth 1 --recursive` 
- `tar --skip-old-files jxpf stage3-*.tar.bz2`
