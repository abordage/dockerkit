# Laravel/PHP aliases (artisan/art handled by functions in bashrc)
alias fresh='php artisan migrate:fresh --ansi'
alias migrate='php artisan migrate --ansi'
alias rollback='php artisan migrate:rollback --ansi'
alias seed='php artisan db:seed --ansi'

# Development tools
alias pint='./vendor/bin/pint'
alias pest='./vendor/bin/pest'
alias phpstan='./vendor/bin/phpstan'
alias phpunit='./vendor/bin/phpunit'

# OPcache management (when enabled)
alias opcache-status='php -r "print_r(opcache_get_status());"'
alias opcache-reset='php -r "opcache_reset(); echo \"OPcache cleared!\n\";"'
alias opcache-info='php -r "print_r(opcache_get_configuration());"'

# Modern file listing (with colors)
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias tree='tree -I vendor -C'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
