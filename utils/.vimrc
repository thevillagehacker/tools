" =============================================================================
" .vimrc — general-purpose setup
" =============================================================================

" --- Core ---
syntax on
filetype plugin indent on
set nocompatible

" --- Line numbers & cursor ---
set number
" set relativenumber
set cursorline
highlight CursorLine cterm=NONE ctermbg=0 ctermfg=NONE guibg=#000000 guifg=NONE

" --- Indentation (sensible defaults for most languages) ---
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

" Resize splits with arrows
nnoremap <silent> <C-Left>  :vertical resize -2<CR>
nnoremap <silent> <C-Right> :vertical resize +2<CR>
nnoremap <silent> <C-Up>    :resize +2<CR>
nnoremap <silent> <C-Down>  :resize -2<CR>

" Move lines up/down in visual mode
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Toggle relative numbers
nnoremap <leader>rn :set relativenumber!<CR>

" Quick save
nnoremap <leader>w :w<CR>

" =============================================================================
" Filetype-specific tweaks (light, non-intrusive)
" =============================================================================

" Python
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab

" YAML / JSON / Markdown
autocmd FileType yaml,yml,json setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType markdown setlocal wrap linebreak

" Shell / config
autocmd FileType sh,bash,zsh setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab

" C / C++ / Java / Rust / Go
autocmd FileType c,cpp,java,rust,go setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab

" HTML / CSS / JS / TS
autocmd FileType html,css,javascript,typescript setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab

" Set leader key to comma (easier than backslash)
let mapleader = ","

" Toggle relative numbers
nnoremap <leader>rn :set relativenumber!<CR>

" =============================================================================
" End
" =============================================================================
