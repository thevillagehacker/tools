# Vim Setup Guide

This file explains how to use the `.vimrc` configuration.

## 1. Install the config

1. Open the file:
   ```bash
   vim ~/.vimrc
   ```

2. Paste the full configuration (see the section below), then save and quit:
   ```vim
   :wq
   ```

3. Create the required folders (run once):
   ```bash
   mkdir -p ~/.vim/{undo,backup,swap}
   ```

4. Restart Vim, or reload inside Vim with:
   ```vim
   :source ~/.vimrc
   ```

## 2. Full `.vimrc` (copy everything below)

```vim
" =============================================================================
" .vimrc — general-purpose setup
" =============================================================================

" --- Core ---
syntax on
filetype plugin indent on
set nocompatible

" --- Line numbers & cursor ---
set number
" set relativenumber          " uncomment if you want relative numbers by default
set cursorline
highlight CursorLine cterm=NONE ctermbg=0 ctermfg=NONE guibg=#000000 guifg=NONE

" Leader key (used by mappings below)
let mapleader = ","

" --- Indentation ---
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set smartindent
set autoindent

" --- Search ---
set incsearch
set hlsearch
set ignorecase
set smartcase
set magic

" --- UI ---
set showcmd
set showmode
set ruler
set laststatus=2
set scrolloff=8
set sidescrolloff=8
set signcolumn=yes
set mouse=a
set wildmenu
set wildmode=longest:full,full
set completeopt=menuone,noinsert,noselect
set updatetime=300
set lazyredraw
set ttyfast

" --- Editing behaviour ---
set backspace=indent,eol,start
set whichwrap+=<,>,h,l
set hidden
set confirm
set history=1000
set undolevels=1000

" --- Invisible characters ---
set list
set listchars=tab:▸\ ,trail:·,extends:>,precedes:<,nbsp:+

" --- Files, backup, undo ---
set encoding=utf-8
set fileencoding=utf-8
set undofile
set undodir=~/.vim/undo//
set backup
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set noswapfile

" --- Clipboard ---
set clipboard=unnamedplus

" --- Performance ---
set synmaxcol=200

" =============================================================================
" Mappings
" =============================================================================

" Clear search highlight with Esc
nnoremap <silent> <Esc> :nohlsearch<CR>

" Center cursor after search jumps
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap * *zzzv
nnoremap # #zzzv

" Better window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Toggle relative numbers  (press ,rn)
nnoremap <leader>rn :set relativenumber!<CR>

" Quick save  (press ,w)
nnoremap <leader>w :w<CR>

" =============================================================================
" Filetype-specific tweaks
" =============================================================================

autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
autocmd FileType yaml,yml,json setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType markdown setlocal wrap linebreak
autocmd FileType sh,bash,zsh setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType c,cpp,java,rust,go setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
autocmd FileType html,css,javascript,typescript setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
```

## 3. How to use the important features

### Line numbers
- By default you get **absolute** line numbers (1, 2, 3…).
- Press `,rn` to toggle **relative** numbers on/off.
  - Relative numbers show distance from the cursor — useful when editing.
  - Absolute numbers are better when reviewing or looking up a specific line.

### Leader key
The leader key is set to comma (`,`).

| Keys   | Action                          |
|--------|---------------------------------|
| `,rn`  | Toggle relative line numbers    |
| `,w`   | Save the file                   |
| `Esc`  | Clear search highlighting       |

### Window navigation
| Keys     | Action              |
|----------|---------------------|
| `Ctrl-h` | Move to left split  |
| `Ctrl-j` | Move to lower split |
| `Ctrl-k` | Move to upper split |
| `Ctrl-l` | Move to right split |

### Search
- Type `/text` to search forward, `?text` to search backward.
- Matches are highlighted as you type.
- Press `Esc` to clear the highlights.
- Search is case-insensitive unless you type a capital letter.

### Invisible characters
Tabs, trailing spaces, and non-breaking spaces are shown with symbols so you can spot them easily.

### Clipboard
Copy and paste works with the system clipboard (`yy`, `p`, etc.).

### Persistent undo
You can undo changes even after closing and reopening the file.

## 4. Quick tips

- Press `:help` followed by any option name (example: `:help number`) to see the official docs.
- To temporarily turn relative numbers on without the toggle:
  ```vim
  :set relativenumber
  ```
- To turn them off:
  ```vim
  :set norelativenumber
  ```

## 5. Reload after changes

Whenever you edit `~/.vimrc`, reload it with:
```vim
:source ~/.vimrc
```
or just restart Vim.
