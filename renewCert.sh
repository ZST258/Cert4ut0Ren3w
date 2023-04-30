#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
HOME=/root
export HOME
AddCrontabAndCheck(){
    #首先检查crontab中是否存在定时任务了，如果已经存在，则获取行号删除。
    /usr/bin/crontab -l | grep -v "${scriptName}" > conf && crontab conf && rm -f conf
    echo -e "\033[0;32;1m 开始添加定时任务... \033[0m"
    (/usr/bin/crontab -l 2>/dev/null || true; echo "0 0 1 * * bash ${shellPath}/${scriptName} -td ${infoVar["-td"]} -dr ${infoVar["-dr"]} -ip ${infoVar["-ip"]} -sp ${infoVar["-sp"]} -au 1 ") | crontab -
}

BuildEnv(){
   echo -e "\033[0;32;1m 正在安装脚本运行环境...请稍后...   \033[0m"
   softArr=("curl" "awk" "sed" "tr" "grep" "cat" "wget")
   for(( i=0;i<7;i++)) do
    if [ ! -f "/usr/bin/${softArr[$i]}" ];then
      echo -e "\033[0;31;1m 检测到${softArr[$i]}未安装,安装中...  \033[0m"
      yum install -y "${softArr[$i]}"
    else
      echo -e "\033[0;34;1m ${softArr[$i]}已安装   \033[0m"
    fi
   done;
}

CheckDns() {
  domain="$1"
  
  # 获取本机公网 IP 地址
  expected_ip=$(curl -s ifconfig.me)

  # 解析域名对应的 IP 地址
  dns_ip=$(ping -c1 "$domain" | grep -oP '(\d+\.){3}\d+' | head -n1)

  # 检查解析的 IP 地址与本机公网 IP 地址是否相同
  if [ "$dns_ip" == "$expected_ip" ]; then
    echo "DNS 解析正常，继续执行证书更新流程..."
  else
    echo "DNS 解析异常，请检查 DNS 设置或网络连接。"
    /usr/bin/crontab -l | grep -v "${scriptName}" > conf && crontab conf && rm -f conf
    exit 1
  fi
}

HelpInfo(){
echo -e "\033[0;37;1m -----------------------------------使用说明------------------------------------- \033[0m"
echo -e "\033[0;32;1m 使用功能命令执行脚本   \033[0m"
echo -e "\033[0;34;1m 例如，申请my.domain.com your.domain.com their.domain.com 三个证书 \033[0m"
echo -e "\033[0;37;1m 基本使用:renewCert.sh -td domain.com -tr [my,your,their] \\033[0m"
echo -e "\033[0;33;1m 注意，-tr 与 -td是必备的！\033[0m"
echo -e "\033[0;34;1m 在基本使用的基础上指定证书安装路径：\033[0m"
echo -e "\033[0;37;1m renewCert.sh -td domain.com -tr [my,your,their] -ip /root \033[0m"
echo -e "\033[0;34;1m 在上面的基础上指定续期脚本安装路径：\033[0m"
echo -e "\033[0;37;1m renewCert.sh -td domain.com -tr [my,your,their] -ip /root -sp /root \033[0m"
echo -e "\033[0;34;1m 在上面的基础上指定是否开启自动更新,1开启，0关闭，其余值会被报错：\033[0m"                                                   
echo -e "\033[0;37;1m renewCert.sh -td domain.com -tr [my,your,their] -ip /root -sp /root -au 1 \033[0m"
echo -e "\033[0;37;1m --------------------------------------------------------------------------------- \033[0m"
echo -e "\033[0;32;1m 使用指定的配置文件进行申请证书   \033[0m"
echo -e "\033[0;34;1m 例如，使用/root/abc.txt作为配置文件执行证书申请 \033[0m"
echo -e "\033[0;34;1m renewCert.sh -f /root/abc.txt \033[0m"
echo -e "\033[0;34;1m 配置文件写法如下,所有行必须顶格： \033[0m"
echo ">>>"
configStart=`cat $0 | grep -n "config------config"|sed -n '2p'|tr -cd 0-9`
configEnd=`cat $0 | grep -n "/config------/config"|sed -n '2p'|tr -cd 0-9`
sed -n "$[$configStart+1]","$[$configEnd-1]"p $0 |sed 's/.//'
echo "<<<EOF"
echo -e "\033[0;37;1m --------------------------------------------------------------------------------- \033[0m"
}

Menu(){
echo -e "\033[0;32;1m -----------欢迎使用本脚本！-------------\033[0m"
echo -e "\033[0;32;1m 1.申请证书说明                             \033[0m"
echo -e "\033[0;31;1m 2.关闭自动更新                      \033[0m"
echo -e "\033[0;32;1m ---------------------------------------\033[0m"
echo -e "\033[0;33;1m 请输入数字前的标号! \033[0m"
echo -e "\033[0;32;1m ---------------------------------------\033[0m"
read -n 1 -p "请输入> " char1
printf "\n"
if [ "${char1}" == "1" ];then
  HelpInfo
  exit 0
elif [ "${char1}" == "2" ];then
  /usr/bin/crontab -l | grep -v "${scriptName}" > conf && crontab conf && rm -f conf
  exit 0
else
  echo -e "\033[0;31;1m 非法输入！\033[0m"
  exit 0
fi
}

BuildEnv

if [ $# -eq 0 ];then
Menu
fi

declare -a options
declare -a values
declare -a optionFork=("-td" "-dr" "-sp" "-ip" "-au" "-f")
declare -i num=0
declare -A infoOpt=(["-td"]="" ["-dr"]="" ["-sp"]="" ["-ip"]="" ["-au"]="" ["-f"]="")
declare -A infoVar=(["-td"]="" ["-dr"]="" ["-sp"]="" ["-ip"]="" ["-au"]="" ["-f"]="")
#判断命令行数，不为偶数报错
if [ `expr $# % 2` -ne 0 ];then
echo -e "\033[0;31;1m 错误的命令条数，正在退出脚本...\033[0m"
exit 1
fi
#获取命令
cache="$*"
cmdStr=($cache)
for(( i=0;i<"$#";i++)) do
  options[num]=${cmdStr[$i]}
  i=`expr $i + 1`
  values[num]=${cmdStr[$i]}
  num=`expr $num + 1`	
done;

for(( i=0;i<${num};i++)) do
for(( j=`expr $i + 1`;j<${num};j++)) do
  if [ "${options[i]}" == "${options[j]}" ];then 
   echo -e "\033[0;31;1m 存在相同指令，正在退出...\033[0m"
   exit 1
  fi
done;
done;

for(( i=0;i<${num};i++)) do
  if [ "${options[$i]}" == "-td" ]; then
    infoOpt["-td"]=${options[$i]}
    infoVar["-td"]=${values[$i]}
    options[i]=""
  fi
  if [ "${options[$i]}" == "-dr" ]; then
    infoOpt["-dr"]=${options[$i]}
    infoVar["-dr"]=${values[$i]}
    options[i]=""
  fi
  if [ "${options[$i]}" == "-sp" ]; then
    infoOpt["-sp"]=${options[$i]}
    infoVar["-sp"]=${values[$i]}
    options[i]=""
  fi
  if [ "${options[$i]}" == "-ip" ]; then
    infoOpt["-ip"]=${options[$i]}
    infoVar["-ip"]=${values[$i]}
    options[i]=""
  fi
  if [ "${options[$i]}" == "-au" ]; then
    infoOpt["-au"]=${options[$i]}
    infoVar["-au"]=${values[$i]}
    options[i]=""
  fi
  if [ "${options[$i]}" == "-f" ]; then
    infoOpt["-f"]=${options[$i]}
    infoVar["-f"]=${values[$i]}
    options[i]=""
  fi
done;


#########################命令校验，查看是否有非法输入#############################

for(( i=0;i<${num};i++)) do
if [ "${options[i]}" != "" ];then
  echo -e "\033[0;31;1m 存在非法的输入选项，正在退出...\033[0m"
  exit 1
fi
done;

if [ "${infoOpt["-f"]}" != "" ];then
echo -e "\033[0;34;1m 检测到指定文件指令，正在引入....忽略其余指令....\033[0m"
  if [ ! -f "${infoVar["-f"]}" ];then
    echo -e "\033[0;31;1m 未找到该文件！正在退出 \033[0m"
    exit 1
  else
    echo -e "\033[0;34;1m 正在读取文件信息....\033[0m"
      orDR=`cat "${infoVar["-f"]}" | grep "domainRecord" |grep -v "#"`
      infoOpt["-dr"]="-dr"
	infoVar["-dr"]=${orDR: 13}

	orTD=`cat "${infoVar["-f"]}" | grep "topDomain" |grep -v "#"`
	orTD=${orTD: 10}
      infoOpt["-td"]="-td"
	infoVar["-td"]=`echo "${orTD}" | sed 's:^.\(.*\).$:\1:'`

	orSP=`cat "${infoVar["-f"]}" | grep "shellPath" |grep -v "#"`
	orSP=${orSP: 10}
      infoOpt["-sp"]="-sp"
	infoVar["-sp"]=`echo "${orSP}" | sed 's:^.\(.*\).$:\1:'`

	orIP=`cat "${infoVar["-f"]}" | grep "installPath" |grep -v "#"`
	orIP=${orIP: 12}
      infoOpt["-ip"]="-ip"
	infoVar["-ip"]=`echo "${orIP}" | sed 's:^.\(.*\).$:\1:'`

	orAU=`cat "${infoVar["-f"]}" | grep "autoUpdate" |grep -v "#"`
      infoOpt["-au"]="-au"
	infoVar["-au"]=${orAU: 11}
  fi
else
if [ "${infoOpt["-td"]}" == "" ] || [ ${infoOpt["-dr"]} == "" ];then
  echo -e "\033[0;31;1m 未发现域名和记录，正在退出...\033[0m"
  HelpInfo
  exit 1
fi
if [ "${infoOpt["-au"]}" == "" ];then
  echo -e "\033[0;34;1m 未指定自动更新选项，采用默认值 \033[0m"
  infoVar["-au"]=1
fi
if [ "${infoOpt["-sp"]}" == "" ];then
  echo -e "\033[0;34;1m 未指定脚本安装路径选项，采用默认值 \033[0m"
  infoVar["-sp"]="/.renew"
fi
if [ "${infoOpt["-ip"]}" == "" ];then
  echo -e "\033[0;34;1m 未指定证书安装路径选项，采用默认值 \033[0m"
  infoVar["-ip"]="/etc/ssl/private"
fi
fi

if [ "${infoVar["-au"]}" != "0" ] && [ "${infoVar["-au"]}" != "1" ];then
  echo -e "\033[0;31;1m 非法值，自动更新选项只能输入0/1 \033[0m"
  HelpInfo
  exit 1
fi
if [[ ! "${infoVar["-sp"]}" =~ ^/.* ]] || [[ ! "${infoVar["-ip"]}" =~ ^/.* ]];then
  echo -e "\033[0;31;1m 路径非法，退出脚本...\033[0m"
  HelpInfo
  exit 1
fi
if [ "${infoOpt["-sp"]}" != "" ] || [ "${infoOpt["-ip"]}" != "" ];then
  echo -e "\033[0;33;1m 警告，请输入正确的路径，否则安装很可能失败，路径请勿输入中文以及特殊符号:\$\#\%\&\* \033[0m"
fi
if [[ ! "${infoVar["-dr"]}" =~ ^\[.*\]$ ]];then
  echo -e "\033[0;31;1m 记录输入错误，请按[A,b,cd]这样的格式输入 \033[0m"
    HelpInfo
    exit 1
fi


###############################################################################

################################基本参数######################################
#填写你的顶级域名,例如www.baidu.com 的顶级域名为baidu.com
topDomain=${infoVar["-td"]} 
#填写你的A记录名称，@代表顶级域名,www.yourdomain.com就填"www"

scriptName="${topDomain}.sh"

#想申请几个记录就申请几个记录，可以在括号内任意添加多个记录
#申请5个记录的证书就写：domainRecord=("A" "B" "C" "D" "E"),A~E代表A记录名称。
#申请7个记录的证书就写：domainRecord=("A" "B" "C" "D" "E" "F" "G"),A~G代表A记录名称。
#注意名称使用""括起来，并且名称与名称之间用空格隔开。

rsArr=`echo "${infoVar["-dr"]}" | sed 's:^.\(.*\).$:\1:'`
domainRecord=(${rsArr//,/ })
 
#脚本安装位置，如无必要不建议更改
shellPath=${infoVar["-sp"]}

#证书和私钥的存放位置，如无必要不建议更改
installPath=${infoVar["-ip"]}

#自动更新按钮，设置为1则每个月运行一次该脚本,设置为其他则不开启自动更新。
autoUpdate=${infoVar["-au"]}


################################################################################

####################################环境检查######################################
#--关闭防火墙
systemctl stop firewalld > /dev/null 2>&1

if [ ! -f "/usr/sbin/lsof" ]; then
  echo -e "\033[0;31;1m 检测到未安装lsof，安装中... \033[0m"
  yum install -y lsof
else
  echo -e "\033[0;32;1m lsof已安装！，进行下一步校验... \033[0m"
fi

declare -a isOnPid
declare -a isOnName
declare -i pidCount
pidCount=`lsof -i :80|grep -v "PID"|awk 'END{print NR}'`
#--检查80端口是否存在进程
if [ "$pidCount" -eq 0 ]; then
	echo -e "\033[0;32;1m 80端口无程序使用，进行下一步校验... \033[0m"
else
      echo -e "\033[0;31;1m 80端口存在以下程序占用： \033[0m"
for(( i=0;i<${pidCount};i++)) do
	isOnpid[$i]=`lsof -i :80|grep -v "PID"|awk '{print $2}'|sed -n "$[$i+1]"p`
      isOnName[$i]=`lsof -i :80|grep -v "PID"|awk '{print $1}'|sed -n "$[$i+1]"p` 
	echo -e "\033[0;33;1m 端口号:${isOnpid[$i]} , 端口进程:${isOnName[$i]} \033[0m"
done;
      echo -e "\033[0;32;1m 正在释放80端口... \033[0m"
	for(( i=0;i<${pidCount};i++)) do
		if [ "${isOnName[$i]}" == "nginx" ];then
		  echo -e "\033[0;32;1m 检测到是nginx占用80端口，进行关闭... \033[0m"
              systemctl	stop nginx
              break
            fi
	done;
      /usr/sbin/lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh
fi

#--检查是否安装socat
if [ -f "/usr/bin/socat" ]; then
  echo -e "\033[0;32;1m socat已安装，进行下一步校验... \033[0m"
else
  echo -e "\033[0;31;1m 未发现socat,执行安装命令... \033[0m"
  /usr/bin/yum install -y socat
  if [ "$?" -eq 0 ]; then
	echo -e "\033[0;32;1m socat安装成功，进行下一步校验... \033[0m"
  else
	echo -e "\033[0;31;1m socat安装失败,请手动安装，退出脚本中... \033[0m"
      exit 0
  fi
fi

#--检查是否安装了crontab
if [ -f "/usr/bin/crontab" ];then
  echo -e "\033[0;32;1m crontab已安装，正在初始化... \033[0m"
  (/usr/bin/crontab -l 2>/dev/null || true; echo "0 0 1 * * bash ${shellPath}/${scriptName} -td ${infoVar["-td"]} -dr ${infoVar["-dr"]} -ip ${infoVar["-ip"]} -sp ${infoVar["-sp"]} -au 1 ") | crontab -
 else
  echo -e "\033[0;31;1m 未发现crontab,执行安装命令... \033[0m"
  /usr/bin/yum install -y crontabs
  if [ "$?" -eq 0 ]; then
	echo -e "\033[0;32;1m crontab安装成功，正在初始化... \033[0m"
      (/usr/bin/crontab -l 2>/dev/null || true; echo "0 0 1 * * bash ${shellPath}/${scriptName} -td ${infoVar["-td"]} -dr ${infoVar["-dr"]} -ip ${infoVar["-ip"]} -sp ${infoVar["-sp"]} -au 1 ") | crontab -
  else
	echo -e "\033[0;31;1m crontab安装失败,请手动安装，退出脚本中... \033[0m"
      exit 0
 fi
fi

#--检查是否安装了acme脚本
if [ -d "/root/.acme.sh/" ]; then
  echo -e "\033[0;32;1m acme已安装，进行下一步校验... \033[0m"
else
  echo -e "\033[0;31;1m 未发现acme,执行安装命令... \033[0m"
  /usr/bin/curl https://get.acme.sh | sh
  if [ "$?" -eq 0 ]; then
	echo -e "\033[0;32;1m acme安装成功，进行下一步校验... \033[0m"
  else
	echo -e "\033[0;31;1m acme安装失败,请手动安装，退出脚本中... \033[0m"
      exit 0
  fi
fi

if [ -d "${installPath}/${topDomain}/" ]; then
  echo -e "\033[0;32;1m 证书文件夹已创建！ \033[0m"
else
  echo -e "\033[0;32;1m 创建证书存储文件夹... \033[0m"
  mkdir "${installPath}"
  mkdir "${installPath}/${topDomain}"
  echo -e "\033[0;32;1m 证书文件夹已创建！ \033[0m"
fi

chown -R nobody "${installPath}/${topDomain}"
#/root/.acme.sh/acme.sh --upgrade --auto-upgrade
#检查DNS解析
for(( i=0;i<${#domainRecord[@]};i++)) do
  if [ "${domainRecord[${i}]}" == "@" ]; then
	CheckDns "${topDomain}"
  else
	CheckDns "${domainRecord[${i}]}.${topDomain}"
  fi
done;
#############################################################################

###############################申请证书#######################################
echo -e "\033[0;32;1m 开始申请证书... \033[0m"

declare -i success
declare -i fail
fail=0
declare -a successDomain
declare -i index=0

/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
for(( i=0;i<${#domainRecord[@]};i++)) do #${#array[@]}获取数组长度用于循环
if [ "${domainRecord[${i}]}" == "@" ]; then
  echo -e "\033[0;32;1m 申请${topDomain}的证书中... \033[0m"
  bash /root/.acme.sh/acme.sh --issue -d "${topDomain}" --standalone --keylength ec-256 --force
  echo -e "\033[0;32;1m 安装${topDomain}的证书中... \033[0m"
  bash /root/.acme.sh/acme.sh --install-cert -d "${topDomain}" --ecc --fullchain-file "${installPath}/${topDomain}/fullchain.cer" --key-file "${installPath}/${topDomain}/private.key"
  if [ ! -f "/root/.acme.sh/${topDomain}_ecc/fullchain.cer" ]; then
    echo -e "\033[0;31;1m ${topDomain}证书安装失败,请手动安装! \033[0m"
    rm -f "${installPath}/${topDomain}/fullchain.cer"
    rm -f "${installPath}/${topDomain}/private.key"
    fail=$[$fail+1]
  else
    successDomain[${index}]=${domainRecord[${i}]}
    index=`expr ${index} + 1`
  fi
else
  echo -e "\033[0;32;1m 申请${domainRecord[${i}]}.${topDomain}的证书中... \033[0m"
  bash /root/.acme.sh/acme.sh --issue -d "${domainRecord[${i}]}.${topDomain}" --standalone --keylength ec-256 --force
  echo -e "\033[0;32;1m 安装${domainRecord[${i}]}.${topDomain}的证书中... \033[0m"
  bash /root/.acme.sh/acme.sh --install-cert -d "${domainRecord[${i}]}.${topDomain}" --ecc --fullchain-file "${installPath}/${topDomain}/fullchain-${domainRecord[${i}]}.cer" --key-file "${installPath}/${topDomain}/private-${domainRecord[${i}]}.key"
  if [ ! -f "/root/.acme.sh/${domainRecord[${i}]}.${topDomain}_ecc/fullchain.cer" ]; then
    echo -e "\033[0;31;1m ${domainRecord[${i}]}.${topDomain}证书安装失败,请手动安装! \033[0m"
    rm -f "${installPath}/${topDomain}/fullchain-${domainRecord[${i}]}.cer"
    rm -f "${installPath}/${topDomain}/private-${domainRecord[${i}]}.key"
    fail=$[$fail+1]
  else
    successDomain[${index}]=${domainRecord[${i}]}
    chown -R nobody "${installPath}/${topDomain}/fullchain-${domainRecord[${i}]}.cer"
    chown -R nobody "${installPath}/${topDomain}/private-${domainRecord[${i}]}.key"
    index=`expr ${index} + 1`
  fi
fi
done;

success=`expr ${#domainRecord[@]}-${fail}`
echo -e "\033[0;33;1m 所有证书安装完成！成功个数:${success},失败个数${fail} \033[0m"

infoVar["-dr"]="["
for(( i=0;i<${success};i++)) do
    infoVar["-dr"]="${infoVar["-dr"]}${successDomain[${i}]},"
done;
infoVar["-dr"]="`echo "${infoVar["-dr"]%?}"`]"


if [ ${success} -ne 0 ];then
#检测自动更新是否开启
if [ ${autoUpdate} -eq 1 ];then
  echo -e "\033[0;32;1m 自动更新已开启...正在部署... \033[0m"
  echo -e "\033[0;32;1m 以下证书安装成功...为您写入定时计划... \033[0m"
  for(( i=0;i<${success};i++)) do
    echo -e "\033[0;33;1m ${successDomain[$i]}.${topDomain} \033[0m"
  done;
  AddCrontabAndCheck
else
  /usr/bin/crontab -l | grep -v "${scriptName}" > conf && crontab conf && rm -f conf
  echo -e "\033[0;31;1m 自动更新未开启，进行下一步骤... \033[0m"
fi
else
  echo -e "\033[0;31;1m 没有证书安装成功，跳过自动更新步骤... \033[0m"
fi

###############################################################################

##################################还原配置#######################################

flag=0
echo -e "\033[0;32;1m 打开防火墙... \033[0m"
sysetmctl start firewalld > /dev/null 2>&1
for(( i=0;i<${pidCount};i++)) do
if [ "${isOnName[$i]}" == "nginx" ];then
 if [ "${flag}" -eq 0 ];then
	echo -e "\033[0;32;1m 检测到程序为nginx，为您重新启动 \033[0m"
	systemctl start nginx
      flag=1
 fi
else
echo -e "\033[0;31;1m 你的进程${isOnName[$i]}被杀死，请手动启动 \033[0m"
fi	 
done;

##################################移动脚本#########################################

if [ -d "${shellPath}/" ]; then
  echo -e "\033[0;32;1m 脚本文件夹已创建！ \033[0m"
  if [ ! -f "${shellPath}/${scriptName}" ]; then
    /usr/bin/cp -f "$0" "${shellPath}/${scriptName}"
  fi
else
  echo -e "\033[0;32;1m 创建脚本安装路径... \033[0m"
  mkdir "${shellPath}"
  cp "$0" "${shellPath}/${scriptName}"
  echo -e "\033[0;32;1m 脚本安装文件夹已创建！ \033[0m"
fi

chmod 777 "${shellPath}"
chmod 777 "${shellPath}/${scriptName}"

workDir=`cd $(dirname $0); pwd`


if [ "${workDir}" != "${shellPath}" ]; then
if [ ! -f "${workDir}/$0" ]; then
  exit 0
else
  echo -e "\033[0;32;1m 清理中... \033[0m"
  echo "rm -f ${workDir}/$0" > /root/clean.sh
  echo "rm -f /root/clean.sh" >> /root/clean.sh
  chmod 777 /root/clean.sh
  sleep 3
  bash /root/clean.sh
fi
else
  exit 0
fi
#<------config------config------请勿删除、复制本行------本行为定位行------->
##填写你的顶级域名,例如www.baidu.com 的顶级域名为baidu.com
#topDomain="cloudkingzst.xyz" 
##填写你的A记录名称，@代表顶级域名,www.yourdomain.com就填"www"

##想申请几个记录就申请几个记录，可以在括号内任意添加多个记录
##申请5个记录的证书就写：domainRecord=("A" "B" "C" "D" "E"),A~E代表A记录名称。
##申请7个记录的证书就写：domainRecord=("A" "B" "C" "D" "E" "F" "G"),A~G代表A记录名称。
##注意名称使用""括起来，并且名称与名称之间用空格隔开。

#domainRecord=("cv" "movie" "v2" "gia" "@")
 
##脚本安装位置，如无必要不建议更改
#shellPath="/.renew"

##证书和私钥的存放位置，如无必要不建议更改
#installPath="/etc/ssl/private"

##自动更新按钮，设置为1则每个月运行一次该脚本,设置为其他则不开启自动更新。
#autoUpdate=1
#<------/config------/config------请勿删除、复制本行------本行为定位行------->



