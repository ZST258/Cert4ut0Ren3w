# Let's Encrypt SSL证书自动更新脚本
---
## 适用于CentOS 7 系统的自动更新脚本，支持证书批量续签
#### 脚本目前特点
- [x] 支持证书定时续签
- [x] 支持二级域名批量续签
- [x] 多个顶级域名共存
- [x] 自定义脚本和证书存放位置
- [ ] 支持泛域名证书签署
---
## 使用方法
#### 下载脚本并赋予权限
      wget https://raw.githubusercontent.com/ZST258/Cert4ut0Ren3w/main/renewCert.sh && chmod 777 renewCert.sh
#### 脚本基本指令
| 参数名 | 简介 | 用法示例 |
| --- | --- | --- |
| -td | 指定顶级域名 | -td example.com |
| -dr | 指定域名的解析记录，可以指定多个记录 | -dr \[a,b,c\] |
| -ip | 指定证书文件安装路径 | -ip /my/cert/path |
| -sp | 指定脚本存放路径 | -sp /my/shell/path |
| -f | 指定配置文件，指定后其他参数将会直接失效 | -f /path/to/config.txt |
| -au | 自动更新开关 | -au 0 |
#### 脚本使用实例
开启自动更新，并且申请a.exam.com,b.exam.com,c.exam.com三个域名的证书，并指定脚本和证书的存放路径。

    bash renewCert.sh -td exam.com -dr \[a,b,c\] -sp /my/shell/path -ip /my/cert/path -au 1
