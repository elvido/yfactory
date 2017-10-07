#
# yfactory.sh
#

function yfactory()
{
  [ -d "${TMPDIR}" ] || local TMPDIR="/tmp/${LOGNAME:-$(id -n -u)}" ; mkdir -p -m 700 "${TMPDIR}"

  local JMPBX_USER='rhofmann'
  local JMPBX_NAME='k8s.jb.eu.yaas.io'
  local K8S_NAME='yfactory-dev.k8s.prod.eu.yaas.io'
  local K8S_JMPBOX="${JMPBX_USER}@${JMPBX_NAME}"
  local K8S_API_HOST='k8s-api.ydev-prod.eu.yaas.io'
  local K8S_API_PORT=6443
  local K8S_UI_PORT=8011
  local K8S_UI_URL="http://localhost:${K8S_UI_PORT}/ui"
  local SSH_CTRL="${TMPDIR}/yfactory-ssh-ctrl"
  local PROXY_PID="${TMPDIR}/yfactory-ui-proxy.pid"
  local KUBECTL_BIN='kubectl'
  local KUBEHLM_BIN='helm'
  local KUBECTL_CONFIG="${HOME}/.kube/${K8S_NAME}.kubeconfig"
  local KUBECTL_ARGS="--kubeconfig ${KUBECTL_CONFIG}"

  case $1 in
    connect )
      yfactory disconnect
      ssh -MS "${SSH_CTRL}" -Nfo ExitOnForwardFailure=yes -L"${K8S_API_PORT}:${K8S_API_HOST}:443" "${K8S_JMPBOX}"
      alias yfctl="${KUBECTL_BIN} ${KUBECTL_ARGS}"
      alias yfhlm="KUBECONFIG=${KUBECTL_CONFIG} ${KUBEHLM_BIN}"
      alias yfrun="yfactory run"
      yfactory completion
      ;;
    disconnect )
      [ -S "${SSH_CTRL}" ] && ( ssh -S "${SSH_CTRL}" -O exit "${K8S_JMPBOX}" &>/dev/null )
      yfactory close
      unalias yfctl &>/dev/null
      unalias yfhlm &>/dev/null
      unalias yfrun &>/dev/null
      ;;
    manage )
      if [ ! -s "${PROXY_PID}" ] ||  ! ps -p $(cat "${PROXY_PID}") >/dev/null; then
        rm -f "${PROXY_PID}"
        yfactory connect
        ( "${KUBECTL_BIN}" $(echo ${KUBECTL_ARGS}) --port=${K8S_UI_PORT} proxy &>/dev/null & ; echo $! >"${PROXY_PID}" ) &>/dev/null
        sleep 3
      fi
      ( type "xdg-open" &>/dev/null ) && xdg-open "${K8S_UI_URL}" || open "${K8S_UI_URL}"
      ;;
    run )
      [ ! -S "${SSH_CTRL}" ] && yfactory connect
      shift
      if [ $# -lt 1 ]; then
      	{ ( type "x-terminal-emulator" &>/dev/null ) && x-terminal-emulator -T "yfactory - ${K8S_NAME}" -e "env KUBECONFIG=${KUBECTL_CONFIG} $SHELL" } || \
      	{ ( type "exo-open" &>/dev/null ) && exo-open --launch TerminalEmulator env KUBECONFIG="${KUBECTL_CONFIG}" $SHELL } || \
      	open -a Terminal env KUBECONFIG="${KUBECTL_CONFIG}" $SHELL
      else
      	KUBECONFIG=${KUBECTL_CONFIG} $*
      fi
      ;;
    close )
      [ -s "${PROXY_PID}" ] && kill $(cat "${PROXY_PID}") &>/dev/null
      rm -f "${PROXY_PID}"
      ;;
    completion )
      if [ -n "$ZSH_VERSION" ]; then
        source <("${KUBECTL_BIN}" completion zsh)
        source <("${KUBEHLM_BIN}" completion zsh)
      else
        source <("${KUBECTL_BIN}" completion bash)
        source <("${KUBEHLM_BIN}" completion bash)
      fi
      ;;
    * )
      echo "usage: yfactory connect|disconnect|manage|run"
      return 1
      ;;
  esac
}
