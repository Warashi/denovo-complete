typeset -gaU DENOVO_PATH
DENOVO_PATH+=("${0:a:h}")

function denovo-complete() {
	denovo-dispatch complete complete > /dev/null
}
zle -N denovo-complete
