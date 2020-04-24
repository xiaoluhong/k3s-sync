#!/bin/bash

token=$token
access_key=$access_key
access_key_secret=$access_key_secret
bucket_name=$bucket_name
loglevel=${loglevel:-debug}

auth_command="--loglevel=$loglevel -i $access_key -k $access_key_secret -e oss-cn-shenzhen.aliyuncs.com"

chmod +x ./ossutil

k3s()
{
    dir=$(/bin/pwd)
    repo=rancher/k3s
    echo '获取前三个releases版本'
    k3s_new_ver=$( curl -u ${token} -LSs https://api.github.com/repos/${repo}/releases | jq -r .[].tag_name | grep -v -E 'rc|alpha' | head -n 5 )

    echo '通过releases获取文件下载链接'
    for new_ver in ${k3s_new_ver};
    do
        # 创建oss目录
        #./ossutil ${auth_command} mkdir oss://${bucket_name}/download/`echo ${new_ver} | sed 's/+/-/g'`
        # 获取下载链接
        url_path=$( curl -u ${token} -LSs https://api.github.com/repos/${repo}/releases/tags/${new_ver} | jq -r .assets[].browser_download_url | grep -v -E 'rc|alpha|.log|.tar' )
        # 下载文件；
        for url in ${url_path};
        do
            mkdir -p download/`echo ${new_ver} | sed 's/+/-/g'`
            cd download/`echo ${new_ver} | sed 's/+/-/g'`
            wget -q ${url}
            cd ${dir}
        done
    done

   echo '上传文件到oss'
    ./ossutil ${auth_command} cp -r download oss://${bucket_name}/download -u -f

    echo '获取oss中已有版本'
    k3s_old_ver=$( ./ossutil ${auth_command} ls oss://${bucket_name}/download/ -d -s | grep "oss://${bucket_name}/download/v" | awk -F'/' '{print $5}' )

    echo '用oss中已有的版本号与获取的新版本号做匹配，不匹配的则删除'
    for old_ver in ${k3s_old_ver};
    do
        if ! echo ${k3s_new_ver} | sed 's/+/-/g' | grep -w ${old_ver} > /dev/null; then
            ./ossutil ${auth_command} rm oss://${bucket_name}/download/${old_ver}/ -r -f
        fi
    done
}

k3s
