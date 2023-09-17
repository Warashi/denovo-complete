#/usr/bin/env zsh

typeset -gx DENOVO_COMPLETE_ZSH_CACHE_DIR=${DENOVO_COMPLETE_ZSH_CACHE_DIR:-"${XDG_CACHE_HOME:-"$HOME/.cache"}/denovo-complete/zsh"}

mkdir -p "$DENOVO_COMPLETE_ZSH_CACHE_DIR"

# no prompt!
PROMPT=

# load completion system
_compinit() {
    autoload -Uz compinit
    setopt local_options extended_glob
    local zcompdumpfile="$DENOVO_COMPLETE_ZSH_CACHE_DIR/compdump"
    if [[ ! -e $zcompdumpfile.zwc(#qN.mh-24) ]]; then
        compinit -d $zcompdumpfile
        zcompile $zcompdumpfile
    else
        compinit -C -d $zcompdumpfile
    fi
    which carapace &>/dev/null && eval "$(carapace _carapace zsh)"
}
_compinit

# never run a command
bindkey '^M' undefined
bindkey '^J' undefined
bindkey '^I' complete-word

# send a line with null-byte at the end before and after completions are output
null-line () {
    echo -E - $'\0'
}
compprefuncs=( null-line )
comppostfuncs=( null-line exit )

# never group stuff!
zstyle ':completion:*' list-grouped false
zstyle ':completion:*' force-list always
# don't insert tab when attempting completion on empty line
zstyle ':completion:*' insert-tab false
# no list separator, this saves some stripping later on
zstyle ':completion:*' list-separator ''
# for list even if too many
zstyle ':completion:*' list-prompt   ''
zstyle ':completion:*' select-prompt ''
zstyle ':completion:*' menu true

# we use zparseopts
zmodload zsh/zutil

# override compadd (this our hook)
compadd () {

    # check if any of -O, -A or -D are given
    if [[ ${@[1,(i)(-|--)]} == *-(O|A|D)\ * ]]; then
        # if that is the case, just delegate and leave
        builtin compadd "$@"
        return $?
    fi

    # ok, this concerns us!
    # echo -E - got this: "$@"

    # be careful with namespacing here, we don't want to mess with stuff that
    # should be passed to compadd!
    typeset -a __hits __dscr __tmp

    # do we have a description parameter?
    # note we don't use zparseopts here because of combined option parameters
    # with arguments like -default- confuse it.
    if (( $@[(I)-d] )); then # kind of a hack, $+@[(r)-d] doesn't work because of line noise overload
        # next param after -d
        __tmp=${@[$[${@[(i)-d]}+1]]}
        # description can be given as an array parameter name, or inline () array
        if [[ $__tmp == \(* ]]; then
            eval "__dscr=$__tmp"
        else
            __dscr=( "${(@P)__tmp}" )
        fi
    fi

    # capture completions by injecting -A parameter into the compadd call.
    # this takes care of matching for us.
    builtin compadd -A __hits -D __dscr "$@"

    # JESUS CHRIST IT TOOK ME FOREVER TO FIGURE OUT THIS OPTION WAS SET AND WAS MESSING WITH MY SHIT HERE
    setopt localoptions norcexpandparam extendedglob

    # extract prefixes and suffixes from compadd call. we can't do zsh's cool
    # -r remove-func magic, but it's better than nothing.
    typeset -A apre hpre hsuf asuf
    zparseopts -E P:=apre p:=hpre S:=asuf s:=hsuf

    # append / to directories? we are only emulating -f in a half-assed way
    # here, but it's better than nothing.
    integer dirsuf=0
    # don't be fooled by -default- >.>
    if [[ -z $hsuf && "${${@//-default-/}% -# *}" == *-[[:alnum:]]#f* ]]; then
        dirsuf=1
    fi

    # just drop
    [[ -n $__hits ]] || return

    # this is the point where we have all matches in $__hits and all
    # descriptions in $__dscr!

    # display all matches
    local dsuf dscr
    for i in {1..$#__hits}; do

        # add a dir suffix?
        # use GLOB_SUBST to expand `~/`
        local prefix="$IPREFIX$apre$hpre"
        (( dirsuf )) && [[ -d ${~prefix}$__hits[$i] ]] && dsuf=/ || dsuf=
        # description to be displayed afterwards
        (( $#__dscr >= $i )) && dscr=$'\0'"${${__dscr[$i]}##$__hits[$i] #}" || dscr=

        echo -E - $IPREFIX$apre$hpre$__hits[$i]$dsuf$hsuf$asuf$dscr

    done

}

# signal success!
echo ok
