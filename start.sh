#!/bin/bash

DIR=$(/bin/pwd)

token=$token
access_key=$access_key
access_key_secret=$access_key_secret
bucket_name=$bucket_name
loglevel=${loglevel}

auth_command="--loglevel=$loglevel -i $access_key -k $access_key_secret -e oss-cn-shenzhen.aliyuncs.com"
wget -q -c http://gosspublic.alicdn.com/ossutil/1.6.16/ossutil64 -O ossutil
chmod +x ./ossutil

download_file(){
    # 获取下载链接

    for url in ${url_path};
    do
        mkdir -p ${DIR}/download/`echo ${1} | sed 's/+/-/g'`
        cd ${DIR}/download/`echo ${1} | sed 's/+/-/g'`
        echo "下载 ${url}"
        wget -q ${url}
        cd ${DIR}
    done
}

push_file(){
    echo "上传 ${1}"
    ${DIR}/ossutil ${auth_command} cp -r ${DIR}/download/`echo ${1} | sed 's/+/-/g'` oss://${bucket_name}/download/`echo ${1} | sed 's/+/-/g'` -u --output-dir=${DIR}
}

repo=rancher/k3s

echo '获取前三个 releases 版本'
k3s_new_ver=$( curl -LSs https://api.github.com/repos/$repo/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}'  | grep -v -E 'rc|alpha' | tail -n 6 )
echo "${k3s_new_ver}"

echo '通过 releases 获取文件下载链接'
for new_ver in ${k3s_new_ver};
do
    cd ${DIR}
    # 创建 OSS 目录，如果存在则跳过
    echo "创建版本目录: oss://${bucket_name}/download/`echo ${new_ver} | sed 's/+/-/g'`"
    ${DIR}/ossutil ${auth_command} mkdir oss://${bucket_name}/download/`echo ${new_ver} | sed 's/+/-/g'`
    url_path=$( curl -u ${token} -LSs https://api.github.com/repos/${repo}/releases/tags/${new_ver} | jq -r .assets[].browser_download_url | grep -v -E 'rc|alpha|.log|.tar' )

    # 下载文件
    download_file ${new_ver}
    cd ${DIR}/download/`echo ${new_ver} | sed 's/+/-/g'`
    ls

    stats_code=100

    while [[ ${stats_code} < 110 ]];
    do
        if [[ $( ls | wc -l ) == `echo "${url_path}" | wc -l` ]]; then
            for file in `ls | grep -v '.txt'`;
            do
                if ! cat *.txt | grep -w `sha256sum ${file} | awk '{print $1}'` > /dev/null; then
                    rm -rf ${DIR}/download/`echo ${new_ver} | sed 's/+/-/g'`/*
                    download_file ${new_ver} ${url_path}
                    # 设置状态码继续循环
                    let stats_code=$((${stats_code}-50))
                    break;
                fi
            done

            if [[ ${stats_code} == 100 ]]; then
                let stats_code=$((${stats_code}+50))
                echo "当前版本文件下载完成退出下载逻辑 $stats_code"

                # 上传文件
                push_file ${new_ver}
            fi
        else
            # 设置循环状态码
            let stats_code=$((${stats_code}-50))
            echo '已下载文件数与需要下载文件数不对应，将重新下载'
            rm -rf ${DIR}/download/`echo ${new_ver} | sed 's/+/-/g'`/*
            download_file ${new_ver} ${url_path}
        fi
    done
done

## 列出 OSS 中已有版本
#k3s_old_ver=$( ${DIR}/ossutil ${auth_command} ls oss://${bucket_name}/download/ -d -s | grep "oss://${bucket_name}/download/v" | awk -F'/' '{print $5}' )

#echo '用 OSS 中已有的版本号与获取的新版本号做匹配，不匹配的则删除'
#for old_ver in ${k3s_old_ver};
#do
#    if ! echo ${k3s_new_ver} | sed 's/+/-/g' | grep -w ${old_ver} > /dev/null; then
#        echo "删除老版本: ${old_ver}"
#        ${DIR}/ossutil ${auth_command} rm oss://${bucket_name}/download/${old_ver}/ -r -f
#    else
#        echo '没有新版本增加，无需删除'
#    fi
#done




