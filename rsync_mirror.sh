#!/bin/bash
#
# --------------------------------------------------------------------------------------
# Filename:     rsync_mirrors.sh
# Version:      v1.0
# Author:       Heroown
# Email:        heroown@sina.com
#
# Create Date:  2014/10/20
# Description:  Shell script to rsync yum mirrors
# Notes:        centos, epel, saltstack, zabbix, docker, ceph, mongodb, webtatic
# --------------------------------------------------------------------------------------

# Shell env
SHELL_NAME="rsync_mirrors.sh"
SHELL_DIR="/tmp/shell"
SHELL_LOG="${SHELL_DIR}/${SHELL_NAME}.log"
LOCK_FILE="/tmp/${SHELL_NAME}.lock"
MIRRORS_DIR="/data/mirrors"
CHOWN_USER="nginx:nginx"

# Mirror url
MIRROR_USTC="rsync://rsync.mirrors.ustc.edu.cn"
MIRROR_TUNA="rsync://mirrors.tuna.tsinghua.edu.cn"
MIRROR_ZABBIX="rsync://repo.zabbix.com"
MIRROR_PDNS="rsync://repo.powerdns.com"

# Yum repo version
CENTOS_VERSIONS=(6.8 7.3.1611)
EPEL_VERSIONS=(6 7)
CEPH_VERSIONS=(el6 el7)
SALT_VERSIONS=(6 7)

# Rsync options
CENTOS_EXCLUDE="--exclude atomic --exclude paas --exclude centosplus --exclude cloud --exclude contrib --exclude cr --exclude extras --exclude fasttrack --exclude isos --exclude virt --exclude storage --exclude os/i386 --exclude updates/i386 --exclude updates/x86_64/drpms"
EPEL_EXCLUDE="--exclude SRPMS --exclude aarch64 --exclude i386 --exclude ppc64 --exclude ppc64le --exclude x86_64/debug"
CEPH_EXCLUDE="--exclude SRPMS --exclude aarch64 --exclude noarch --exclude flavors --exclude */x86_64/ceph-debuginfo-*"
SALT_EXCLUDE="--exclude SRPMS"
DOCKER_EXCLUDE="--exclude gpg"
ZABBIX_EXCLUDE="--exclude non-supported --exclude zabbix/*/ubuntu --exclude zabbix/*/debian --exclude zabbix/*/*/5 --exclude zabbix/*/*/*/SRPMS --exclude zabbix/*/*/*/i386"
RSYNC_OPTIONS="-avSHP --delete --no-perms --no-owner --no-group"

# Logging
shell_log(){
    LOG_INFO=$1
    echo "$(date "+%Y-%m-%d") $(date "+%H:%M:%S") ${SHELL_NAME} ${LOG_INFO}" >> ${SHELL_LOG}
}

# Shell usage
shell_usage(){
    echo $"Usage: $0 {centos, epel, salt, zabbix, docker, ceph, mongodb, all}"
}

# chown directories to nginx
chown_dir(){
    chown -R ${CHOWN_USER} ${MIRRORS_DIR}
}

# Lock the script
shell_lock(){
    touch ${LOCK_FILE}
}

# Unlock the script
shell_unlock(){
    rm -f ${LOCK_FILE}
}

# Sleep function
shell_sleep(){
    sleep 5
}

# Check to make sure we're not already running
check_running(){
    if [[ -f $LOCK_FILE ]]; then
        shell_log "${SHELL_NAME} is running"
        echo "${SHELL_NAME}" is running
        exit 1
    else
        shell_lock
    fi
}

# Check if directory exists
check_dirs(){
    [[ ! -d ${SHELL_DIR} ]] && mkdir -p ${SHELL_DIR}

    if [[ $1 == "all" ]]; then
        for dir in ${MAJOR_VERSIONS[@]}; do
            [[ ! -d ${MIRRORS_DIR}/${dir} ]] && mkdir -p ${MIRRORS_DIR}/${dir}
        done
    else
        [[ ! -d ${MIRRORS_DIR}/$1 ]] && mkdir -p ${MIRRORS_DIR}/$1
    fi
}

# Check return value
check_retval(){
    if [[ $1 -eq 0 ]]; then
        shell_log "Rsync $2 finished"
        shell_unlock
    else
        shell_log "Rsync $2 failed"
        trap shell_unlock SIGHUP SIGINT SIGTERM
        shell_unlock
    fi
}

# Rsync centos mirror
rsync_centos(){
    for centos_version in ${CENTOS_VERSIONS[@]}; do
        rsync ${RSYNC_OPTIONS} ${CENTOS_EXCLUDE} ${MIRROR_USTC}/$1/${centos_version} ${MIRRORS_DIR}/$1
        check_retval $? ${MIRROR_USTC}/$1/${centos_version}
    done
}

# Rsync epel mirror
rsync_epel(){
    for epel_version in ${EPEL_VERSIONS[@]}; do
        rsync ${RSYNC_OPTIONS} ${EPEL_EXCLUDE} ${MIRROR_TUNA}/$1/${epel_version} ${MIRRORS_DIR}/$1
        check_retval $? ${MIRROR_TUNA}/$1/${epel_version}
    done
}

# Rsync salt mirror
rsync_salt(){
    for salt_version in ${SALT_VERSIONS[@]}; do
        rsync ${RSYNC_OPTIONS} ${SALT_EXCLUDE} ${MIRROR_USTC}/$1/yum/redhat/${salt_version}/x86_64 ${MIRRORS_DIR}/$1/${salt_version}
        check_retval $? ${MIRROR_USTC}/$1/rpm/${salt_version}
    done
}

# Rsync ceph mirror
rsync_ceph(){
    for ceph_version in ${CEPH_VERSIONS[@]}; do
        rsync ${RSYNC_OPTIONS} ${CEPH_EXCLUDE} ${MIRROR_TUNA}/$1/rpm/${ceph_version} ${MIRRORS_DIR}/$1
        check_retval $? ${MIRROR_TUNA}/$1/rpm/${ceph_version}
    done
}

# Rsync docker mirror
rsync_docker(){
    rsync ${RSYNC_OPTIONS} ${DOCKER_EXCLUDE} ${MIRROR_TUNA}/$1/yum ${MIRRORS_DIR}/$1
    check_retval $? ${MIRROR_TUNA}/$1
}

# Rsync zabbix mirror
rsync_zabbix(){
    rsync ${RSYNC_OPTIONS} ${ZABBIX_EXCLUDE} ${MIRROR_ZABBIX}/mirror ${MIRRORS_DIR}/$1
    check_retval $? ${MIRROR_ZABBIX}/$1
}

# Rsync mongodb mirror
rsync_mongodb(){
    rsync ${RSYNC_OPTIONS} ${MIRROR_TUNA}/mongodb/yum/ ${MIRRORS_DIR}/$1
    check_retval $? ${MIRROR_TUNA}/$1
}

rsync_all(){
    rsync_centos centos
    rsync_epel epel
    rsync_ceph ceph
    rsync_salt salt
    rsync_docker docker
    rsync_zabbix zabbix
    rsync_mongodb mongodb
}

# Rsync Yum Mirrors
rsync_mirror(){
    check_dirs $1
    check_running

    case $1 in
        centos)
            rsync_centos $1
            ;;
        epel)
            rsync_epel $1
            ;;
        ceph)
            rsync_ceph $1
            ;;
        salt)
            rsync_salt $1
            ;;
        docker)
            rsync_docker $1
            ;;
        zabbix)
            rsync_zabbix $1
            ;;
        mongodb)
            rsync_mongodb $1
            ;;
        all)
            rsync_all $1
    esac
}

# Main Function
main(){
    case $1 in
        centos|epel|salt|zabbix|docker|ceph|mongodb|all)
            rsync_mirror $1
            chown_dir
            ;;
        unlock)
            shell_unlock
            ;;
        *)
            shell_usage
            ;;
    esac
}

# Exec function
main $1
