#!/usr/bin/env bash

if [[ $(arch) == "x86_64" ]]; then
  DOCKER_PKG="docker-amd-20.10.9.tgz"
else
  DOCKER_PKG="docker-arm-20.10.9.tgz"
fi

ONLINE=false
UPDATE_DEPLOY_ENV=false
DATA_DIR=/data/
DEPLOY_IMAGE=ghcr.io/jokerdevops/kube-cluster
IMAGE_TAG=main
NAME=kube-cluster

ORCHSYM_INSTALLER_ANSIBLE_PACKAGES_FILES='http://bspackage.ss.bscstorage.com/packages/docker/files/'
item=1
function h2() {
  printf "\n${underline}${bold}${white}%s${reset}\n" "$@"
}

set -e
function printInfo() {
  echo -e "::\033[34m $@ \033[0m"
}

function printError() {
  echo -e "::\033[31m $@ \033[0m"
  exit 1
}

function perCheck() {
  # 确保当前用户为root
  if [[ $(whoami) != root ]]; then
    printError "此脚本必须使用 root 执行,当前用户为 ${USER},正在退出脚本..."
  fi

  # 获取命令行参数
  if [[ $1 == "-h" || $1 == "--help" ]]; then
    infostr="用法: bash initDeployEnv.sh [选项]...\n\n
    此脚本用于初始化部署机，如果可以访问公网，执行时要加 -o 选项，否则为离线初始化;\n
    离线初始化的话，需要将docker-amd-20.10.9.tgz、kube-cluster.tgz(部署环境的镜像包)
    上传至 /tmp/ 目录下;\n\n\n
    Support options:\n
    \t-o: 如果携带此选项，则表示为在线初始化部署机;\n
    \t-t: 此选项用于指定 kube-cluster 镜像的 tag,默认为 $IMAGE_TAG ;\n
    \t-u: 仅更新 deploy 容器;\n
    \t-d: 指定 kube-cluster 容器的持久化目录,默认为 $DATA_DIR ;\n
    \t-n: 指定部署容器的名称, 默认为 $NAME ;\n"

    printInfo $infostr
    exit 0
  fi

  while getopts ":uot:d:" optname; do
    case "$optname" in
    "o")
      ONLINE=true
      ;;
    "u")
      UPDATE_DEPLOY_ENV=true
      ;;
    "d")
      DATA_DIR=$OPTARG
      ;;
    "t")
      IMAGE_TAG=$OPTARG
      ;;
    "n")
      CONTAINER_NAME=$OPTARG-$IMAGE_TAG
      ;;
    *)
      infoStr="./initDeployEnv.sh：包含无效选项,\nTry './initDeployEnv.sh --help' for more information."
      printError "$infoStr"
      ;;
    esac
  done

  FULL_IMAGE_NAME=${DEPLOY_IMAGE}:${IMAGE_TAG}
  ORCHSYM_INSTALL_PKG=kube-cluster-$IMAGE_TAG.tgz
  printInfo "是否为在线部署: $ONLINE"
  printInfo "部署镜像名称: $FULL_IMAGE_NAME"
}

function checkPackage() {
  local savePath=/tmp/$DOCKER_PKG
  if [[ ! -f $savePath ]]; then
    if $ONLINE; then
      local downloadUrl="${ORCHSYM_INSTALLER_ANSIBLE_PACKAGES_FILES}${DOCKER_PKG}"
      local cmd="curl -s $downloadUrl -o $savePath"
      printInfo "Running: $cmd"
      $cmd
    else
      printError "$savePath Not Found... "
    fi
  fi
}

function installDocker() {
  set +e
  rm -rf /tmp/docker &>/dev/null
  set -e
  tar zxf /tmp/$DOCKER_PKG -C /tmp/ &>/dev/null || printError "/tmp/$DOCKER_PKG解压失败，请检查安装包的md5值。"

  # 同时将docker安装包copy到kube-cluster容器的持久化目录上一份
  [[ -d ${DATA_DIR}/kube-cluster/deploy/packages ]] || mkdir -p ${DATA_DIR}/kube-cluster/deploy/packages
  cp -a /tmp/$DOCKER_PKG ${DATA_DIR}/kube-cluster/deploy/packages

  chmod -R 755 /tmp/docker
  cp -a /tmp/docker/* /usr/bin/

  cat >/usr/lib/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-ONLINE.target firewalld.service
Wants=network-ONLINE.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd --live-restore
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

  [[ -d /etc/docker ]] || mkdir /etc/docker
  cat >/etc/docker/daemon.json <<EOF
{
    "data-root": "${DATA_DIR}/docker"
}
EOF
}

function startDocker() {
  systemctl daemon-reload
  systemctl start docker
  systemctl enable docker
}

function checkOrchsymInstaller() {
  if [[ ! $ONLINE ]]; then
    local savePath=/tmp/$ORCHSYM_INSTALL_PKG
    local downloadUrl="${ORCHSYM_INSTALL_DOWNLOAD_URL}${ORCHSYM_INSTALL_PKG}"
    ls $savePath &>/dev/null || curl -s $downloadUrl -o $savePath
    docker load <$savePath || printError "$savePath导入失败，请检查包的md5值。"
  fi
}

function runDeployEnv() {
  set +e
  /usr/bin/docker ps -a | grep kube-cluster- | awk '{print $1}' | xargs -I {} /usr/bin/docker rm -f {}
  set -e

  /usr/bin/docker run -itd --privileged --name ${CONTAINER_NAME} --restart=always --network host \
    -v ~/.ssh:/root/.ssh \
    -v ${DATA_DIR}/kube-cluster/deploy:/workspace/ansible/deploy \
    $FULL_IMAGE_NAME >/dev/null

}

function main() {
  h2 "[Step $item]: perCheck..."
  let item+=1
  perCheck $@

  # 确认是否为升级deploy-docker服务
  if $UPDATE_DEPLOY_ENV; then
    h2 "[Step $item]: update deploy container..."
    let item+=1
    checkOrchsymInstaller
    runDeployEnv
    printInfo "deploy container update successfully，login command: docker exec -it ${CONTAINER_NAME} bash"
    exit 0
  fi

  # 如果docker不存在则安装并启动docker
  if [[ ! -f /usr/bin/docker ]]; then
    h2 "[Step $item]: installDocker..."
    let item+=1
    checkPackage
    installDocker
    startDocker
  fi

  # 安装deploy服务
  h2 "[Step $item]: run deploy container..."
  let item+=1
  checkOrchsymInstaller
  runDeployEnv
  printInfo "deploy container run successfully，login command: docker exec -it ${CONTAINER_NAME} bash"
}

main $@

