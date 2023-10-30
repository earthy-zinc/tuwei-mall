## 虚拟机配置指南

### 硬件配置

| 节点名        | IP              | CPU  | 内存 |
| ------------- | --------------- | ---- | ---- |
| Pei-Linux-100 | 192.168.210.100 | 24   | 16   |
| Pei-Linux-101 | 192.168.31.2 | 4    | 8    |
| Pei-Linux-102 | 192.168.210.102 | 4    | 8    |
| Pei-Linux-103 | 192.168.210.103 | 4    | 8    |

Pei-Linux-100需要开放的端口

| 端口  | 说明         | 网址 |
| ----- | ------------ | ---- |
| 3306  | mysql        |      |
| 6379  | redis        |      |
| 15672 | rabbitmq     |      |
| 8848  | nacos        |      |
| 9001  | minio        |      |
| 8000  | jenkins      |      |
| 80    | gitlab       |      |
| 9922  | gitlab ssh   |      |
| 8081  | maven nexus  |      |
|       |              |      |
|       |              |      |
|       |              |      |
| 9999  | gateway网关  |      |
| 9527  | 后台管理系统 |      |



### docker搭建

#### 安装docker

使用官方给出的脚本，https://get.docker.com/

```shell
# 获取并运行安装脚本
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh
# 启动docker服务
systemctl start docker
# 配置docker开机自启
systemctl enable docker
```

#### 配置国内镜像

修改配置文件

```shell
sudo vim /etc/docker/daemon.json
```

添加内容

```json
{
  "registry-mirrors":[
                      "https://o65lma2s.mirror.aliyuncs.com",
                      "http://hub-mirror.c.163.com"
                     ],
  "insecure-registries" :  ["192.168.210.100:5000"]
}
```

重启docker

```shell
systemctl daemon-reload
systemctl restart docker
```

#### 注意事项

如果以非 root 用户可以运行 docker 时，
需要执行 `sudo usermod -aG docker cmsblogs` 命令然后重新登陆，
否则会有如下报错

```md
docker: Cannot connect to the Docker daemon. 
Is the docker daemon running on this host ?
```

### mysql搭建

```bash
docker run --restart=always \
-d \
-p 3306:3306 \
--privileged=true \
-v /opt/docker_volume/mysql/log:/var/log/mysql \
-v /opt/docker_volume/mysql/data:/var/lib/mysql \
-v /opt/docker_volume/mysql/conf:/etc/mysql/conf.d \
-e MYSQL_ROOT_PASSWORD=123456 \
--name mysql \
mysql
```

### redis搭建

官网获取 `redis.conf` : http://www.redis.cn/download.html

解压后可在根目录查看到 `redis.conf` 配置文件，将其内容复制到 `/opt/docker_volume/redis/redis.conf`，然后修改以下内容：

- bind 127.0.0.1 ： 注释掉，redis可以外部访问
- --requirepass "123456" ： 设置Redis密码为123456，默认无密码
- --appendonly yes ： AOF持久化
- tcp-keepalive 60 ： 默认300，调小防止远程主机强迫关闭一个现有连接错误

```bash
docker run --restart=always \
--log-opt max-size=100m \
--log-opt max-file=2 \
-p 6379:6379 \
--name redis \
-v /opt/docker_volume/redis/redis.conf:/etc/redis/redis.conf \
-v /opt/docker_volume/redis/data:/data \
-d redis redis-server /etc/redis/redis.conf  \
--appendonly yes  \
--requirepass 123456
```

### rabbitmq搭建

```bash
docker run -d --restart=always \
--name rabbitmq  \
--hostname rabbitmq \
-p 15672:15672 \
-p 5672:5672 \
rabbitmq
```

- hostname: RabbitMQ存储数据的节点名称,默认是主机名,不指定更改主机名启动失败,默认路径
- p 指定宿主机和容器端口映射（5672：服务应用端口，15672：管理控制台端口）

#### 安装插件

```bash
# 打开bash
docker exec -it rabbitmq /bin/bash
# 安装插件
rabbitmq-plugins enable rabbitmq_management
```

#### 重置队列

```bash
docker exec -it rabbitmq /bin/sh
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app
```

#### 访问控制台

访问RabbitMQ控制台: [http://192.168.210.100:15672/](http://192.168.210.100:15672/)

用户名/密码：guest/guest

### nacos搭建

#### 创建数据库

运行[nacos-db.sql](../nacos/nacos-db.sql)在mysql中创建nacos数据库

#### 创建和启动容器

```bash
docker run -d --name nacos \
--restart=always \
## --network=host \
-p 8848:8848 \
-e MODE=standalone \
-e JVM_XMS=256m \
-e JVM_XMX=2048m \
-e SPRING_DATASOURCE_PLATFORM=mysql \
-e MYSQL_SERVICE_HOST=192.168.210.100 \
-e MYSQL_SERVICE_PORT=3306 \
-e MYSQL_SERVICE_DB_NAME=nacos \
-e MYSQL_SERVICE_USER=root \
-e MYSQL_SERVICE_PASSWORD=123456 \
-e MYSQL_DATABASE_NUM=1 \
-e MYSQL_SERVICE_DB_PARAM="characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=true&serverTimezone=UTC" \
-v /opt/docker_volume/nacos:/home/nacos/logs \
nacos/nacos-server:2.0.3
```

* MYSQL_SERVICE_DB_NAME 数据库的名称
* MYSQL_SERVICE_USER 数据库用户名
* MYSQL_SERVICE_PASSWORD 数据库密码
* MYSQL_DATABASE_NUM 数据库数量

#### 访问控制台

控制台地址： [http://192.168.210.100:8848/nacos/index.html](http://192.168.210.100:8848/nacos/index.html)

默认用户名/密码：nacos/nacos

### seata搭建

#### 创建数据库
[seata.sql](../seata/seata.sql)
#### 配置

##### 1. 获取Seata外置配置

获取Seata外置配置
* 本地地址：[config.txt](../seata/config.txt)
* 在线地址：[config.txt](https://github.com/seata/seata/blob/1.5.2/script/config-center/config.txt)

##### 2. 导入外置配置

Nacos 默认**public** 命名空间下 ，新建Data ID 为 seataServer.properties 的配置，Group为SEATA_GROUP的配置，并将Seata外置配置config.txt内容全量复制进来

##### 3. 修改外置配置

seataServer.properties 需要修改存储模式为db和db连接配置

```properties
# 修改store.mode为db，配置数据库连接
store.mode=db
store.db.dbType=mysql
store.db.driverClassName=com.mysql.cj.jdbc.Driver
store.db.url=jdbc:mysql://192.168.210.100:3306/seata?useUnicode=true&rewriteBatchedStatements=true
store.db.user=root
store.db.password=123456
```

- **store.mode=db** 存储模式选择为数据库
- **store.db.url** MySQL主机地址
- **store.db.user** 数据库用户名
- **store.db.password** 数据库密码

#### 创建和启动容器

##### 1. 获取应用配置

按照官方文档描述使用**自定义配置文件**的部署方式，需要先创建临时容器把配置copy到宿主机

**创建临时容器**

```bash
docker run -d --name seata-server -p 8091:8091 -p 7091:7091 seataio/seata-server:1.5.2
```

**创建挂载目录**

```bash
mkdir -p /opt/docker_volume/seata/config
```

**复制容器配置至宿主机**

```bash
docker cp seata-server:/seata-server/resources/ /opt/docker_volume/seata/config
```

注意复制到宿主机的目录，下文启动容器需要做宿主机和容器的目录挂载

**过河拆桥，删除临时容器**

```bash
docker rm -f seata-server
```

##### 2. 修改启动配置

目前seata的配置资源都在/opt/docker_volume/seata/config文件夹下，我们在获取到 seata-server 的应用配置之后，因为这里采用 Nacos 作为 seata 的配置中心和注册中心，所以需要修改 application.yml 里的配置中心和注册中心地址，详细配置我们可以从 application.example.yml 拿到。

**application.yml 原配置**

**修改后的配置**(参考 application.example.yml 示例文件)，以下是需要调整的部分，其他配置默认即可

```yaml
seata:
  config:
    type: nacos
    nacos:
      server-addr: 192.168.210.100:8848
      namespace:
      group: SEATA_GROUP
      data-id: seataServer.properties
  registry:
    type: nacos
    preferred-networks: 30.240.*
    nacos:
      application: seata-server
      server-addr: 192.168.210.100:8848
      namespace:
      group: SEATA_GROUP
      cluster: default
```

- **server-addr** 是Nacos宿主机的IP地址，Docker部署别错填 localhost 或Docker容器的IP(172.17. * . *)
- **namespace** nacos命名空间id，不填默认是public命名空间
- **data-id: seataServer.properties** Seata外置文件所处Naocs的Data ID，参考上小节的 **导入配置至 Nacos**
- **group: SEATA_GROUP** 指定注册至nacos注册中心的分组名
- **cluster: default** 指定注册至nacos注册中心的集群名

##### 3. 启动容器

```bash
docker run -d --restart=always \
--name seata-server   \
-p 8091:8091 \
-p 7091:7091 \
-e SEATA_IP=192.168.210.100 \
-v /opt/docker_volume/seata/config/re's:/seata-server/resources \
seataio/seata-server:1.5.2 
```

- **SEATA_IP：** Seata 宿主机IP地址

### minio搭建

#### 创建和启动容器

```bash
docker run -d \
  --restart always \
  -p 9000:9000 \
  -p 9001:9001 \
  --name minio \
  -v /opt/docker_volume/minio/data:/data \
  -v /opt/docker_volume/minio/config:/root/.minio \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  quay.io/minio/minio server /data \
  --console-address ":9001"
```

- -e "MINIO_ROOT_USER=minioadmin" ： MinIO控制台用户名
- -e "MINIO_ROOT_PASSWORD=minioadmin" ：MinIO控制台密码

#### 访问控制台

控制台地址： [http://192.168.210.100:9001](http://192.168.210.100:9001/)

用户名/密码： minioadmin/minioadmin

### jenkins搭建

#### JDK安装

```bash
mkdir /usr/local/src/jdk && cd /usr/local/src/jdk
# 解压
tar -zxvf jdk-8u351-linux-x64.tar.gz 
# 配置一下环境变量
vim  /etc/profile
```

在profile文件的最下面填入这四行配置
```
JAVA_HOME=/usr/local/src/jdk/jdk1.8.0_35
 
PATH=$JAVA_HOME/bin:$PATH
 
CLASSPATH=.:$JAVA_HOME/jre/lib/ext:$JAVA_HOME/lib/tools.jar
 
export PATH JAVA_HOME CLASSPATH
```

```bash
# 使配置立即生效
source /etc/profile
# 测试安装是否成功
java  -version
```

#### maven安装

```bash
mkdir /usr/local/maven && cd /usr/local/maven 
#然后将gz包放到maven目录里面
tar -zxvf apache-maven-3.8.5-bin.tar.gz	#解压gz包
vi   /etc/profile  
```

在profile中添加如下配置

```
export M2_HOME=/usr/local/maven/apache-maven-3.8.5
export PATH=${PATH}:$JAVA_HOME/bin:$M2_HOME/bin
```


```bash
source /etc/profile        #重新加载配置文件
mvn -v
```

#### git安装

```bash
mkdir /usr/local/git && cd /usr/local/git 
# 将上面获取到的gz包放入git目录中
tar -zxvf git-2.33.1.tar.gz   #解压gz包
# 安装相关依赖
yum update -y && yum install curl -y
yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel
# 编译源文件
make prefix=/usr/local/git/git-2.33.1 all      
make prefix=/usr/local/git/git-2.33.1 install

vi /etc/profile
```

在profile中添加如下配置

```
export PATH=/usr/local/git/git-2.33.1/bin:$PATH
```

```bash
source /etc/profile        #重新加载配置文件
git  --version
```

#### 创建和启动容器

```bash
docker run \
--restart=always \
-di \
--name=jenkins \
-p 8000:8080 \
-p 50000:5000 \
-v /opt/docker_volume/jenkins:/var/jenkins_home \
-v //usr/local/src/jdk/jdk1.8.0_351:/usr/local/jdk \
-v /usr/local/maven/apache-maven-3.8.5:/usr/local/maven \
-v /usr/local/git/git-2.33.1/bin/git:/usr/local/git \
-v /etc/localtime:/etc/localtime \
--privileged=true \
jenkins/jenkins:2.404
```

#### 访问控制台

* 控制台地址： http://192.168.210.100:8000
* 管理员密码：使用该命令查看管理员密码 `docker logs jenkins`
* 安装推荐的插件
* 创建管理员账号：
  * 用户名：admin
  * 密码：123456
  * 全名：管理员
  * 邮件地址：1066365803@qq.com
* 进行实例配置，配置Jenkins的URL：http://192.168.210.100:8000
* 点击系统管理->插件管理，进行自定义的插件安装：
  * 根据角色管理权限的插件：Role-based Authorization Strategy
  * 远程使用ssh的插件：SSH plugin
  * 中文插件：chinese
* 通过系统管理->全局工具配置来进行全局工具的配置
  * 新增maven的安装配置：/usr/local/maven
  * 新增git的安装配置：/usr/local/git
* 在系统管理->系统配置中添加全局ssh的配置，将4个虚拟机配置到jenkins中
  * hostname: 192.168.210.100
  * port: 22
  * username: root
  * key: `*****`

> ```bash
> # 被访问的服务器（被控制端）执行命令获取ssh公钥和私钥
> ssh-keygen -t rsa -C '1066365803@qq.com'
> # 到需要远程登录的服务器（控制端）中执行：
> cd /root/.ssh
> # 新建authorized_keys文件。把你在上一步生成的公钥（id_rsa.pub）写入到authorized_keys中
> touch  authorized_keys
> ```

#### 更改国内插件镜像

```bash
#进容器内部
docker exec -it jenkins /bin/bash
cd /var/jenkins_home/updates

sed -i 's/http:\/\/updates.jenkins-ci.org\/download/https:\/\/mirrors.tuna.tsinghua.edu.cn\/jenkins/g' default.json && sed -i 's/http:\/\/www.google.com/https:\/\/www.baidu.com/g' default.json
```

#### 替换国内插件更新地址

替换插件更新地址、将国外官方地址替换为国内清华大学jenkins插件地址

Jenkins > Manage Jenkins > Plugin Manager、点击Advanced页面替换Update Site的url、并submit

`https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json`

在浏览器输入 http://192.168.210.100:8000/restart 、重启jenkins使配置生效

### gitlab搭建

#### 创建和启动容器

```bash
docker run \
 -d \
 -p 80:80 \
 -p 9922:22 \
 -v /opt/docker_volume/gitlab/etc:/etc/gitlab  \
 -v /opt/docker_volume/gitlab/log:/var/log/gitlab \
 -v /opt/docker_volume/gitlab/opt:/var/opt/gitlab \
 --restart always \
 --privileged=true \
 --name gitlab \
 gitlab/gitlab-ce:latest
```

#### 开关防火墙的指定端口(无用)

```bash
# 开启1080端口
firewall-cmd --zone=public --add-port=1080/tcp --permanent
# 关闭1080端口
firewall-cmd --zone=public --remove-port=1080/tcp --permanent
# 重启防火墙才能生效
systemctl restart firewalld
# 查看已经开放的端口
firewall-cmd --list-ports
```

#### 修改配置

```bash
#进容器内部
docker exec -it gitlab /bin/bash
#修改gitlab.rb
vi /etc/gitlab/gitlab.rb
```

加入如下

```
#gitlab访问地址，可以写域名。如果端口不写的话默认为80端口
#经过测试，更改为其他端口就访问失败，因此不能修改
external_url 'http://192.168.210.100'
#ssh主机ip
gitlab_rails['gitlab_ssh_host'] = '192.168.210.100'
#ssh连接端口
gitlab_rails['gitlab_shell_ssh_port'] = 9922
```

```bash
# 让配置生效
gitlab-ctl reconfigure
```

修改http和ssh配置

```bash
vi /opt/gitlab/embedded/service/gitlab-rails/config/gitlab.yml
```

```yml
gitlab:
    host: 192.168.124.194
    port: 9980 # 这里改为9980
    https: false
```

```bash
#重启gitlab 
gitlab-ctl restart
#退出容器 
exit
```

#### 访问控制台

* 控制台地址： http://192.168.210.100:9980
* 重置root账号密码：如下所示
* 创建组织：pei group

#### 修改密码

```bash
# 进入容器内部
docker exec -it gitlab /bin/bash
# 进入控制台
gitlab-rails console -e production
# 查询id为1的用户，id为1的用户是超级管理员
user = User.where(id:1).first
# 修改密码为pei12345678
user.password='pei12345678'
# 保存
user.save!
# 退出
exit
```



### docker registry仓库搭建

不推荐

#### 创建和启动容器

```bash
docker run -d \
-p 5000:5000 \
-v /opt/docker_volume/registry:/tmp/registry \
--privileged=true \
--name registry \
--restart always \
registry
```

- `--privileged=true`：Docker挂载主机目录Docker访问出现`cannot open directory .: Permission denied`的解决办法。
- `registry`：docker registry镜像。
- 使用`docker ps`命令查看正在运行的registry的容器ID，需要之一的是`COMMAND`与别的容器不太一样。在进入registry容器的时候的命令参数不能使用`/bin/bash`，而要使用：`bin/sh`、`bash`、`sh`三个中的一个。输入命令进入registry容器。

#### 本地新建镜像发布到私有仓库

##### 查看私服库Registry镜像数量

```bash
curl -XGET http://192.168.210.100:5000/v2/_catalog
```

##### 修改镜像标签

为了符合私服规范，我们需要修改新镜像的Tag标签

```bash
docker tag <镜像ID或镜像名>:<Tag> Host:Port/Repository:Tag
```

* 镜像ID或镜像名：要上传到私有库Registry的镜像ID或名字；
* Tag：要上传的镜像版本号；
* Host：本地私有库的映射网址（本文为192.168.210.100）；
* Post：本地私有库的映射端口（本文为5000）；
* Repository:Tag：上传到私有库Registry后自定义的镜像名字、版本号。

##### 修改配置文件使docker支持http

修改`/etc/docker/daemon.json`配置文件，添加`"insecure-registries" :  ["192.168.210.100:5000"]`

##### 推送到私服

```bash
docker push Host:Port/Repository:Tag
```

##### 将私有库的镜像拉取到本地并运行

```bash
docker pull Host:Port/Repository:Tag
```

### docker harbor仓库搭建

#### 安装docker-compose
```bash
sudo curl -L https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 下载harbor镜像仓库

```bash
wget https://storage.googleapis.com/harbor-releases/release-1.10.0/harbor-offline-installer-v1.10.1-rc1.tgz

# 解压下载文件
tar zxf harbor-offline-installer-v1.10.1-rc1.tgz
```


#### 修改harbor.yml配置文件
```yml
hostname: 192.168.210.100  #这里配置的监听地址，也可以是域名
port: 5000 #这里配置监听端口
harbor_admin_password: 123456  # 配置admin用户的密码
data_volume: /data/harbor  #配置数据仓库
# 注释掉https块，不注释会报错
```

#### 安装harbor
```bash
./install.sh
```

> 注意harbor会创建redis和nginx容器，当前已启动容器中不能存在同名容器

#### 访问harbor界面

http://192.168.210.100:5000
* 用户：admin 
* 密码：123456

#### 配置harbor为本地仓库
需要在每个节点都配置
```bash
vi /etc/docker/daemon.json

“insecure-registries” : [“http://192.168.210.100:5000”]
```
配置完成后需要重启docker
```bash
systemctl restart docker
```



### maven/npm仓库搭建

#### 创建和启动容器

```bash
mkdir -p /opt/docker_volume/nexus
chmod 777 /opt/docker_volume/nexus
docker run \
-itd \
--restart=always \
-p 8081:8081 \
--name nexus \
-e NEXUS_CONTEXT=nexus \
-v /opt/docker_volume/nexus:/nexus-data \
sonatype/nexus3
```

* 控制台地址： http://192.168.210.100:8081/nexus
* 管理员账号：admin
* 密码：使用该命令查看管理员密码 `cat /opt/docker_volume/nexus/admin.password`
* 密码改为：123456

#### 默认仓库说明

* maven-central：maven中央库，默认从https://repo1.maven.org/maven2/拉取jar
* maven-releases：私库发行版jar，初次安装请将Deployment policy设置为Allow redeploy
* maven-snapshots：私库快照（调试版本）jar
* maven-public：仓库分组，把上面三个仓库组合在一起对外提供服务，在本地maven基础配置settings.xml或项目pom.xml中使用

#### Nexus仓库类型介绍
* hosted：本地仓库，通常我们会部署自己的构件到这一类型的仓库。比如公司的第二方库。
* proxy：代理仓库，它们被用来代理远程的公共仓库，如maven中央仓库。
* group：仓库组，用来合并多个hosted/proxy仓库，当你的项目希望在多个repository使用资源时就不需要多次引用了，只需要引用一个group即可。

#### 配置阿里云代理仓库

* 新建仓库(Create repository):
  * 填写仓库名称——maven-aliyun，并填入仓库url为`https://maven.aliyun.com/repository/public`
* 配置仓库组(默认已有一个maven-public)
  * 将maven-aliyun仓库添加到maven-public仓库组中

#### 修改maven配置文件

修改conf/setting.xml，添加如下内容

```xml
<xml>
    <!--nexus服务器,id为组仓库name-->
    <servers>
        <server>
            <id>maven-public</id>
            <username>admin</username>
            <password>123456</password>
        </server>
        <server>
            <id>maven-releases</id>  <!--对应pom.xml的id=releases的仓库-->
            <username>admin</username>
            <password>123456</password>
        </server>
        <server>
            <id>maven-snapshots</id> <!--对应pom.xml中id=snapshots的仓库-->
            <username>admin</username>
            <password>123456</password>
        </server>
    </servers>

    <!--仓库组的url地址，id和name可以写组仓库name，mirrorOf的值设置为central-->
    <mirrors>
        <mirror>
            <id>maven-public</id>
            <name>maven-public</name>
            <!--镜像采用配置好的组的地址-->
            <url>http://192.168.210.100:8081/nexus/repository/maven-public/</url>
            <mirrorOf>central</mirrorOf>
        </mirror>
        <mirror>
            <id>aliyunmaven</id>
            <mirrorOf>*</mirrorOf>
            <name>阿里云公共仓库</name>
            <url>https://maven.aliyun.com/repository/public</url>
        </mirror>
    </mirrors>
</xml>

```

#### 项目pom.xml配置

```xml
<xml>
    <repositories>
        <repository>
            <id>maven-public</id>
            <name>Nexus Repository</name>
            <url>http://192.168.210.100:8081/nexus/repository/maven-public/</url>
            <snapshots>
                <enabled>true</enabled>
            </snapshots>
            <releases>
                <enabled>true</enabled>
            </releases>
        </repository>
    </repositories>
    <pluginRepositories>
        <pluginRepository>
            <id>maven-public</id>
            <name>Nexus Plugin Repository</name>
            <url>http://192.168.210.100:8081/nexus/repository/maven-public/</url>
            <snapshots>
                <enabled>true</enabled>
            </snapshots>
            <releases>
                <enabled>true</enabled>
            </releases>
        </pluginRepository>
    </pluginRepositories>
    <!--项目分发信息，在执行mvn deploy后表示要发布的位置。有了这些信息就可以把网站部署到远程服务器或者把构件jar等部署到远程仓库。 -->
    <distributionManagement>
        <repository><!--部署项目产生的构件到远程仓库需要的信息 -->
            <id>maven-releases</id>
            <!-- 此处id和settings.xml的id保持一致 -->
            <name>Nexus Release Repository</name>
            <url>http://192.168.210.100:8081/nexus/repository/maven-releases/</url>
        </repository>
        <snapshotRepository>
            <!--构件的快照部署到哪里？如果没有配置该元素，默认部署到repository元素配置的仓库，参见distributionManagement/repository元素 -->
            <id>maven-snapshots</id>
            <!-- 此处id和settings.xml的id保持一致 -->
            <name>Nexus Snapshot Repository</name>
            <url>http://192.168.210.100:8081/nexus/repository/maven-snapshots/</url>
        </snapshotRepository>
    </distributionManagement>
</xml>

```



### sonarqube的搭建

#### 安装postgresql数据库

- 官网上已经声明 sonarQube 7.9 版本以上不再支持 mysql 了，所以我们使用 postgresql

```bash
# 1、安装镜像
docker pull postgres:11
# 2、新建目录
mkdir -p /home/apps/postgres/{postgresql,data}
# 3、创建并启动
docker run -d --name postgres -p 5432:5432 \
-v /home/apps/postgres/postgresql:/var/lib/postgresql \
-v /home/apps/postgres/data:/var/lib/postgresql/data \
-v /etc/localtime:/etc/localtime:ro \
-e POSTGRES_USER=admin \
-e POSTGRES_PASSWORD=123456 \
-e POSTGRES_DB=sonar \
-e TZ=Asia/Shanghai \
--restart always \
--privileged=true \
postgres:11
```



#### sysctl设置
不设置的话启动sonar的时候会报错，启动不起来

```bash
# 修改内核参数
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
# 重启
sysctl -p
```

#### 创建目录，并授予权限

```bash
mkdir -p /data/sonarqube/{conf,data,logs,extensions}
mkdir -p /data/postgres/{postgresql,data}
chmod -R 777 /data/sonarqube
```

#### 创建并启动容器

##### 选择1：准备docker-compose文件

```bash
vi docker-compose.yml

version: '3'
services:
  postgres:
    image: postgres:12
    restart: always
    container_name: postgres
    ports:
      - 5432:5432
    volumes:
      - /data/postgres/postgresql/:/var/lib/postgresql
      - /data/postgres/data/:/var/lib/postgresql/data
    environment:
      TZ: Asia/Shanghai
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar123
      POSTGRES_DB: sonar
    networks:
      - sonar-network
  sonar:
    image: sonarqube:8.2-community
    restart: always
    container_name: sonar
    depends_on:
      - postgres
    volumes:
      - /data/sonarqube/extensions:/opt/sonarqube/extensions
      - /data/sonarqube/logs:/opt/sonarqube/logs
      - /data/sonarqube/data:/opt/sonarqube/data
      - /data/sonarqube/conf:/opt/sonarqube/conf
    ports:
      - 9000:9000
    environment:
      TZ: Asia/Shanghai
      SONARQUBE_JDBC_USERNAME: sonar
      SONARQUBE_JDBC_PASSWORD: sonar123
      SONARQUBE_JDBC_URL: jdbc:postgresql://postgres:5432/sonar
    networks:
      - sonar-network
networks:
  sonar-network:
    driver: bridge
```

使用`docker-compose up -d `运行该文件

##### 选择2

```bash
docker run -d --name sonarqube -p 9000:9000 \
--link postgres \
-v /home/apps/sonarqube/extensions:/opt/sonarqube/extensions \
-v /home/apps/sonarqube/logs:/opt/sonarqube/logs \
-v /home/apps/sonarqube/data:/opt/sonarqube/data \
-e SONARQUBE_JDBC_URL=jdbc:postgresql://postgres:5432/sonar \
-e SONARQUBE_JDBC_USERNAME=admin \
-e SONARQUBE_JDBC_PASSWORD=123456 \
--restart always \
--privileged=true \
sonarqube:8.9.2-community
```



#### 访问控制台

地址：http://192.168.59.129:9000/
默认账号：admin 密码：admin

#### 插件安装

##### 离线方式
离线安装汉化包下载地址（不同版本对应地址）：https://github.com/SonarQubeCommunity/sonar-l10n-zh/tags

配置汉化包
下载完成之后将下载的jar包放到/data/sonarqube/extensions/plugins（注意看自己的目录）里面,没有plugins目录就创建该目录。

重启sonar
docker restart sonar

##### 在线方式
sonar应用市场安装中文插件

常用插件：
Chinese Pack – 中文语言包
Checkstyle – Java 代码规范检查
Crowd – Crowd 插件，实现统一登录
JaCoCo – Java 代码覆盖率
PMD – Java 静态代码扫描
ShellCheck Analyzer – Shell 代码规范检查
SonarCSS、SonarHTML、SonarJS等 – Sonar 针对不同编程语言代码分析
在线方式经常会因为网络问题下载不了。

#### 代码质量检测测试
##### maven测试
可以在页面上创建项目

创建令牌，可以随意输入，选择项目预言和编译工具

在下面就能看到maven命令了。
这样就可以直接在idea控制台进行测试了

###### 配置setting.xml（与配置项目pom.xml二选一）
注意：此项非必须
sonar插件在不配置的情况也是可以用的，如果每次不想带url、token等参数，而想简单的执行[mvn sonar:sonar]则需要在setting.xml将sonar信息配置进去
```xml
<settings>
	<!-- pluginGroups也可以不配置 -->
    <pluginGroups>
        <pluginGroup>org.sonarsource.scanner.maven</pluginGroup>
    </pluginGroups>
    <profiles>
        <profile>
            <id>sonar</id>
            <activation>
                <activeByDefault>true</activeByDefault>
            </activation>
            <properties>
                 <sonar.login>admin</sonar.login>          
                   <sonar.password>admin</sonar.password>
                   <sonar.host.url>http://192.168.59.129:9000</sonar.host.url>
                   <!-- 高版本的sonar需要指定编译的路径 -->
				   <sonar.java.binaries>target/classes</sonar.java.binaries> 
            </properties>
        </profile>
     </profiles>
     <!-- 官方未配置activeProfiles 但是个人建议配置上 -->
     <activeProfiles>
     	<!-- 这步配置，sonar的profile配置才能生效 -->
		<activeProfile>sonar</activeProfile>
     </activeProfiles>
</settings>
```

配置完成后执行如下命令即可扫描
`mvn sonar:sonar`
###### 配置pom.xml(与配置setting.xml二选一)
如果不想修改setting.xml，可考虑在pom文件里直接引入sonar插件即可
在project->build->plugins 下增加如下插件

```xml
<!-- sonar插件 -->
<plugin>
	<groupId>org.sonarsource.scanner.maven</groupId>
	<artifactId>sonar-maven-plugin</artifactId>
	<version>3.7.0.1746</version>
</plugin>
```

重新编译即可使用sonar，需要注意的是sonar插件未传递token（或者username/password）、host、prokectKey时，需要在执行`mvn sonar:sonar`时带上
检测完成后可以在sonar页面看到检测的结果


##### sonar-scanner检测方式
###### 安装sonar-scanner
下载地址：
https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.7.0.2747-linux.zip
解压
```bash
unzip sonar-scanner-cli-4.7.0.2747-linux.zip
mv sonar-scanner-4.7.0.2747-linux/ sonar-scanner
```
编辑/etc/profile，在底部追加：
```
export PATH=$PATH:/root/sonar-scanner/bin
```
然后执行`source /etc/profile`，使修改后的环境变量生效
执行`sonar-scanner -v`

在项目根目录下新建文件sonar-project.properties，添加如下配置
```properties
#sonarqube服务器地址
sonar.host.url=http://192.168.59.129:9000
#sonarqube用户名
sonar.login=admin
#sonarqube密码
sonar.password=admin
#项目唯一标识（不能出现重复）
sonar.projectKey=hello-demo
#项目名称
sonar.projectName=hello-demo
#源代码目录
sonar.sources=src/main
#编译生成的class文件的所在目录
sonar.java.binaries=target
#版本号
sonar.projectVersion=0.0.1-SNAPSHOT
#语言
sonar.language=java
#源代码文件编码
sonar.sourceEncoding=UTF-8
```

然后在项目根目录运行命令` sonar-scanner`


### nginx搭建

#### 创建临时容器

启动前需要先创建Nginx外部挂载的配置文件，之所以要先创建 , 是因为Nginx本身容器只存在/etc/nginx 目录 , 本身就不创建 nginx.conf 文件
当服务器和容器都不存在 nginx.conf 文件时, 执行启动命令的时候 docker会将nginx.conf 作为目录创建 , 这并不是我们想要的结果 。

（ /home/nginx/conf/nginx.conf）

```bash
# 创建挂载目录
mkdir -p /opt/docker_volume/nginx/conf
mkdir -p /opt/docker_volume/log
mkdir -p /opt/docker_volume/nginx/html
# 创建文件
touch /opt/docker_volume/nginx/conf/nginx.conf
# 生成容器
docker run --name nginx -p 9527:80 -d nginx
# 将容器nginx.conf文件, conf.d文件夹下内容, html文件夹复制到宿主机
docker cp nginx:/etc/nginx/nginx.conf /opt/docker_volume/nginx/conf/nginx.conf

docker cp nginx:/etc/nginx/conf.d /opt/docker_volume/nginx/conf/conf.d

docker cp nginx:/usr/share/nginx/html /opt/docker_volume/nginx
# 删除临时容器
docker rm -f nginx
```

#### 创建和启动容器

```bash
docker run --restart=always \
--name nginx \
-p 9527:9527 \
-p 9528:9528 \
-v /opt/docker_volume/nginx/conf/nginx.conf:/etc/nginx/nginx.conf \
-v /opt/docker_volume/nginx/conf/conf.d:/etc/nginx/conf.d \
-v /opt/docker_volume/nginx/log:/var/log/nginx \
-v /opt/docker_volume/nginx/html:/usr/share/nginx/html \
-d nginx
```

* -v /opt/docker_volume/nginx/conf/nginx.conf:/etc/nginx/nginx.conf	挂载nginx.conf配置文件
* -v /opt/docker_volume/nginx/conf/conf.d:/etc/nginx/conf.d	挂载nginx配置文件
* -v /opt/docker_volume/nginx/log:/var/log/nginx	挂载nginx日志文件
* -v /opt/docker_volume/nginx/html:/usr/share/nginx/html	挂载nginx内容

## 项目启动

### 数据库创建和数据初始化

- **系统数据库**

  进入 `docs/sql` 目录 ， 根据 MySQL 版本选择对应的脚本；

  先执行 `database.sql` 完成数据库的创建；

  再执行 `youlai.sql` 、`mall_*.sql` 完成数据表的创建和数据初始化。

- **Nacos数据库**

  创建名为 `nacos` 的数据库，执行 `middleware/nacos/conf/nacos-mysql.sql` 脚本完成 Nacos 数据库初始化。

- **Seata数据库**

  创建名为 `seata` 的数据库，执行 `docs/seata/seata.sql` 脚本完成 Seata 数据库初始化。

### Naco配置和启动

1. **Nacos配置持久化至MySQL**

   > Nacos默认使用内嵌的derby数据库，如果需要持久化至MySQL做以下调整即可

   修改项目 `middleware/nacos/conf/application.properties` 文件的数据库连接，完整修改示例如下：

   ```properties
   spring.datasource.platform=mysql
   db.num=1
   db.url.0=jdbc:mysql://localhost:3306/nacos?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=UTC
   db.user.0=root
   db.password.0=123456
   ```

2. **导入Nacos配置**

   IDEA 打开命令行终端 Terminal，输入 `cd middleware/nacos/bin` 切换到 Nacos 的 bin 目录，执行 `startup -m standalone` 启动 Nacos 服务；

   打开浏览器，地址栏输入 Nacos 控制台的地址 [http://localhost:8848/nacos ](http://localhost:8848/nacos)；

   输入用户名/密码：nacos/nacos ；

   进入控制台，点击左侧菜单 `配置管理` → `配置列表` 进入列表页面，点击 `导入配置` 选择项目中的 `docs/nacos/DEFAULT_GROUP.zip` 文件。

3. **修改Nacos配置**

   在 Nacos 控制台配置列表选择共享配置 `youlai-common.yaml` 进行编辑，修改 MySQL、Redis、RabbitMQ等中间件信息为您自己本地环境，默认是「有来」线上环境。

4. **修改Nacos配置中心地址**

   批量替换应用的 bootstrap-dev.yml 文件的配置中心地址 `http://c.youlai.tech:8848` →`http://localhost:8848` ，默认是「有来」线上的配置中心地址。

### 微服务启动

- `youlai-gateway` 模块的启动类 GatewayApplication 启动网关；
- `youlai-auth` 模块的启动类 AuthApplication 启动认证中心；
- `youlai-admin` → `admin-boot` 模块的启动类 AdminApplication 启动系统服务；
- 至此完成基础服务的启动，商城服务按需启动，启动方式和 `youlai-admin` 一致；
- 访问接口文档地址测试: [http://localhost:9999/doc.html ](http://localhost:9999/doc.html)。

```bash
# 启动网关
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/youlai-gateway
docker build -t youlai-gateway:1.0 .
docker run --restart=always -p 9999:9999 --name youlai-gateway -d youlai-gateway:1.0

# 启动鉴权
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/youlai-auth
docker build -t youlai-auth:1.0 .
docker run --restart=always -p 8998:8000 --name youlai-auth -d youlai-auth:1.0

# 启动系统
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/youlai-system/system-boot
docker build -t youlai-admin:1.0 .
docker run --restart=always -p 8997:8800 --name youlai-admin -d youlai-admin:1.0

# 启动订单系统
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/mall-oms/oms-boot
docker build -t youlai-order:1.0 .
docker run --restart=always -p 9002:8603 --name youlai-order -d youlai-order:1.0

# 启动商品系统
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/mall-pms/pms-boot
docker build -t youlai-product:1.0 .
docker run --restart=always -p 9003:8802 --name youlai-product -d youlai-product:1.0

# 启动营销系统
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/mall-sms/sms-boot
docker build -t youlai-sell:1.0 .
docker run --restart=always -p 9004:8804 --name youlai-sell -d youlai-sell:1.0

# 启动用户系统
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/mall-ums/ums-boot
docker build -t youlai-user:1.0 .
docker run --restart=always -p 9005:8601 --name youlai-user -d youlai-user:1.0

# 启动实验室系统
cd /opt/docker_volume/jenkins/workspace/tuwei-mall/laboratory
docker build -t youlai-laboratory:1.0 .
docker run --restart=always -p 9006:8000 --name youlai-laboratory -d youlai-laboratory:1.0
```



### 前端启动

1. 本机安装 Node 环境
2. npm install
3. npm run dev
4. 访问 http://localhost:9527

### 移动端Html5启动

1. 下载 `HBuilder X` ;
2. 导入 [mall-app ](https://gitee.com/youlaitech/youlai-mall-weapp)源码至 `HBuilder X`;
3. `Hbuilder X` 工具栏点击 `运行` -> `运行到内置浏览器` 。
